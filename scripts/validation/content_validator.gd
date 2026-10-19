@tool
class_name ContentValidator
extends RefCounted
## Shared preflight used by runtime, tests and the editor's Validate Content menu.


static func validate_campaign(
		campaign: WaveCampaign, arena: Arena, enemy_scenes: Dictionary[String, PackedScene]
) -> PackedStringArray:
	var errors := PackedStringArray()
	if campaign == null:
		errors.append("Assign a WaveCampaign resource.")
		return errors
	errors.append_array(campaign.get_configuration_errors())
	if not is_instance_valid(arena):
		errors.append("Assign an Arena map.")
		return errors
	errors.append_array(arena.get_configuration_errors())
	var serial: int = 0
	for index in range(campaign.waves.size()):
		var definition := campaign.waves[index]
		if definition == null:
			continue
		var kinds: Array[String] = []
		for offset in range(definition.enemy_count):
			var kind := definition.get_enemy_kind(serial + offset + 1)
			if not kind in kinds:
				kinds.append(kind)
		serial += definition.enemy_count
		if not definition.boss_kind.is_empty():
			kinds.append(definition.boss_kind)
		for kind in kinds:
			if not enemy_scenes.has(kind) or enemy_scenes[kind] == null:
				errors.append("Wave %d: enemy '%s' has no registered scene." % [index + 1, kind])
			if not arena.has_spawn_for(kind, index + 1):
				errors.append("Wave %d: no enabled entrance accepts '%s'." % [index + 1, kind])
	return errors


static func validate_enemy_scenes(enemy_scenes: Dictionary[String, PackedScene]) -> PackedStringArray:
	var errors := PackedStringArray()
	for kind in enemy_scenes:
		var scene := enemy_scenes[kind]
		if scene == null:
			errors.append("Enemy '%s' has no registered scene." % kind)
			continue
		var instance := scene.instantiate()
		if not instance is Zombie:
			errors.append("Enemy '%s' scene root must be a Zombie." % kind)
		else:
			if instance.kind != kind:
				errors.append("Enemy '%s' scene declares kind '%s'." % [kind, instance.kind])
			errors.append_array(validate_enemy(instance))
		instance.free()
	return errors


static func validate_enemy(enemy: Zombie) -> PackedStringArray:
	var errors := PackedStringArray()
	for property in ["visuals", "movement", "combat", "attack_origin", "health_component"]:
		var component: Node = enemy.get(property)
		if not is_instance_valid(component) or not enemy.is_ancestor_of(component):
			errors.append("Enemy '%s' needs an owned %s component." % [enemy.kind, property])
	if enemy.combat != null:
		var attack_count: int = 0
		for child in enemy.combat.get_children():
			if child is EnemyAttack:
				attack_count += 1
				errors.append_array(validate_attack(child))
			else:
				errors.append("Enemy '%s' combat child '%s' needs an EnemyAttack payload." % [enemy.kind, child.name])
		if enemy.movement != null and enemy.movement.keep_distance and attack_count == 0:
			errors.append("Enemy '%s' keeps its distance but has no ranged attack." % enemy.kind)
	return errors


static func validate_attack(attack: EnemyAttack) -> PackedStringArray:
	var errors := PackedStringArray()
	if attack.get_script() == preload("res://scripts/enemies/enemy_attack.gd"):
		errors.append("Attack '%s' has no concrete payload." % attack.name)
	if attack.attack_id.is_empty() or attack.minimum_distance < 0.0 \
			or attack.maximum_distance <= attack.minimum_distance \
			or attack.windup_duration <= 0.0 or attack.cooldown <= 0.0:
		errors.append("Attack '%s' has invalid identity, range or timing." % attack.name)
	if attack is EnemyFanAttack or attack is EnemyRadialAttack:
		if attack.projectile_count < 1 or attack.projectile_speed <= 0.0 or attack.damage <= 0.0:
			errors.append("Attack '%s' has invalid projectile parameters." % attack.name)
		if _has_property(attack, &"projectile_scene"):
			errors.append_array(validate_projectile_scene(attack.get("projectile_scene")))
	if attack is EnemySlamAttack:
		if not is_instance_valid(attack.ring) or not attack.is_ancestor_of(attack.ring):
			errors.append("Slam '%s' needs an owned radial ring payload." % attack.name)
	for child in attack.get_children():
		if child is EnemyAttack:
			errors.append_array(validate_attack(child))
	return errors


static func validate_projectile_scene(scene: PackedScene) -> PackedStringArray:
	if scene == null:
		return PackedStringArray(["Projectile scene is missing."])
	var instance := scene.instantiate()
	var errors := PackedStringArray()
	if not instance is Bullet:
		errors.append("Projectile scene '%s' needs a Bullet root." % scene.resource_path)
	else:
		errors.append_array(instance.get_configuration_errors())
	instance.free()
	return errors


static func validate_grenade_scene(scene: PackedScene) -> PackedStringArray:
	if scene == null:
		return PackedStringArray(["Grenade scene is missing."])
	var instance := scene.instantiate()
	var errors := PackedStringArray()
	if not instance is Grenade:
		errors.append("Grenade scene '%s' needs a Grenade root." % scene.resource_path)
	else:
		errors.append_array(instance.get_configuration_errors())
	instance.free()
	return errors


static func validate_run(arena: Arena, session: Node) -> PackedStringArray:
	var errors := validate_tree(session)
	var director := session.get_node_or_null("WaveDirector") as WaveDirector
	var spawner := session.get_node_or_null("Enemies") as EnemySpawner
	if director == null or spawner == null:
		errors.append("Run scene needs WaveDirector and EnemySpawner components.")
	else:
		errors.append_array(validate_campaign(director.campaign, arena, spawner.enemy_scenes))
	var unique := PackedStringArray()
	for error in errors:
		if not error in unique:
			unique.append(error)
	return unique


static func validate_tree(root: Node) -> PackedStringArray:
	var errors := PackedStringArray()
	var arenas: Array[Arena] = []
	var directors: Array[WaveDirector] = []
	var registries: Array[EnemySpawner] = []
	var nodes: Array[Node] = [root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children():
			nodes.append(child)
		if node is Arena:
			arenas.append(node)
			errors.append_array(node.get_configuration_errors())
		elif node is WaveDirector:
			directors.append(node)
		elif node is EnemySpawner:
			registries.append(node)
			errors.append_array(validate_enemy_scenes(node.enemy_scenes))
		elif node is Zombie:
			errors.append_array(validate_enemy(node))
		elif node is Weapon:
			errors.append_array(validate_projectile_scene(node.projectile_scene))
		elif node is CombatService:
			errors.append_array(validate_grenade_scene(node.grenade_scene))
		elif node == root and node is EnemyAttack:
			errors.append_array(validate_attack(node))
		elif node == root and node is Bullet:
			errors.append_array(node.get_configuration_errors())
		elif node == root and node is Grenade:
			errors.append_array(node.get_configuration_errors())
	for director in directors:
		if director.campaign == null:
			errors.append("WaveDirector needs a campaign.")
		else:
			errors.append_array(director.campaign.get_configuration_errors())
			if not arenas.is_empty() and not registries.is_empty():
				errors.append_array(validate_campaign(director.campaign, arenas[0], registries[0].enemy_scenes))
	return errors


static func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if property.name == property_name:
			return true
	return false
