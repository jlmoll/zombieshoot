extends SceneTree
## Attribution, reward policy and global spawn coordinates without the application.

var checks: int = 0
var failures: int = 0
var fixture: Node3D
var rewards: RunRewards
var pickups: PickupManager
var first: Survivor
var second: Survivor


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("REWARDS: " + description)


func make_enemy(context: DamageContext, kind: String = "walker") -> Zombie:
	var enemy := load("res://scenes/enemies/%s.tscn" % kind).instantiate() as Zombie
	fixture.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = Vector3(11, 0, 8)
	enemy.defeated.connect(rewards.reward_defeat)
	enemy.take_damage(100000, context)
	return enemy


func run() -> void:
	const PLAYER_SCENE = preload("res://scenes/actors/player.tscn")
	fixture = Node3D.new()
	root.add_child(fixture)
	first = PLAYER_SCENE.instantiate()
	second = PLAYER_SCENE.instantiate()
	fixture.add_child(first)
	fixture.add_child(second)
	first.set_physics_process(false)
	second.set_physics_process(false)
	first.global_position = Vector3(-20, 0, -20)
	second.global_position = Vector3(20, 0, 20)
	rewards = load("res://scenes/gameplay/run_rewards.tscn").instantiate()
	pickups = PickupManager.new()
	fixture.add_child(pickups)
	pickups.position = Vector3(30, 4, -12)
	pickups.rotation.y = PI / 3
	pickups.player = first
	pickups.supply_collected.connect(rewards.collect_supply)
	fixture.add_child(rewards)
	rewards.pickups = pickups
	rewards.waves = WaveDirector.new()
	fixture.add_child(rewards.waves)
	rewards.waves.wave = 3
	make_enemy(null)
	check(
		rewards.kills == 0 and rewards.score == 0, "unattributed death does not credit a survivor"
	)
	var context := DamageContext.create(second, second, second.get_damage_team(), &"test")
	var enemy := make_enemy(context)
	check(
		rewards.kills == 1 and rewards.score == enemy.score_value * 2,
		"attributed death applies current wave score multiplier"
	)
	check(first.kills == 0 and second.kills == 1, "kill belongs to the actual carrier")
	rewards.reward_defeat(enemy)
	check(rewards.kills == 1, "repeated defeat callback cannot award twice")
	var boss := make_enemy(context, "boss")
	check(pickups.get_child_count() == 1, "boss guarantees a health drop")
	var drop := pickups.get_child(0) as SupplyPickup
	check(drop.target == second, "drop targets the credited carrier")
	check(
		drop.global_position.is_equal_approx(boss.global_position + Vector3.UP * 0.5),
		"drop spawn accepts global position under transformed manager"
	)
	await physics_frame
	await physics_frame
	check(
		absf(drop.global_position.y - 0.5) < 0.13,
		"pickup bobbing preserves its global ground height"
	)
	second.take_damage(60)
	rewards.collect_supply("health", second)
	check(second.health == 65 and first.health == 100, "medkit policy heals only its recipient")
	var before: int = rewards.score
	rewards.reward_wave(second, false)
	check(
		rewards.score == before + 750 and second.health == 77,
		"wave completion awards score and configured healing"
	)
	rewards.reward_wave(second, false)
	check(rewards.score == before + 750 and second.health == 77, "wave completion is idempotent")
	rewards.waves.wave = 8
	rewards.reward_wave(second, true)
	check(
		second.health == 77 and rewards.score == before + 2750,
		"final wave awards bonus without intermission healing"
	)
	second.health = 50
	second.global_position = drop.global_position - Vector3.UP * 0.5
	await physics_frame
	await physics_frame
	await process_frame
	check(
		second.health == 75 and pickups.get_child_count() == 0,
		"real collection signal routes reward once to the carrier"
	)
	var effects := ImpactEffects.new()
	fixture.add_child(effects)
	effects.position = Vector3(15, 3, 5)
	effects.rotation.y = PI / 4
	effects.spawn_particles(Vector3(8, 0.5, 9), Color.WHITE, 3)
	check(
		(effects.get_child(0) as Node3D).global_position.is_equal_approx(Vector3(8, 0.5, 9)),
		"impact effects accept global coordinates under transformed parent"
	)
	fixture.queue_free()
	await process_frame
	await process_frame
	print(
		(
			"REWARDS %s: %d checks, %d failures"
			% ["PASSED" if failures == 0 else "FAILED", checks, failures]
		)
	)
	quit(0 if failures == 0 else 1)
