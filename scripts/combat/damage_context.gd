class_name DamageContext
extends RefCounted
## Per-shot provenance. Weak references never keep an actor alive after despawn.

enum Team { NEUTRAL, PLAYER, ENEMY }

var team: Team = Team.NEUTRAL
var attack_id: StringName = &""
var hit_position := Vector3.ZERO
var hit_direction := Vector3.ZERO
var friendly_fire: bool = false
var _source: WeakRef
var _instigator: WeakRef


static func create(
	source: Node, instigator: Node, source_team: Team, id: StringName = &""
) -> DamageContext:
	var context := DamageContext.new()
	context._source = weakref(source) if is_instance_valid(source) else null
	context._instigator = weakref(instigator) if is_instance_valid(instigator) else null
	context.team = source_team
	context.attack_id = id
	return context


func get_source() -> Node:
	return _source.get_ref() as Node if _source != null else null


func get_instigator() -> Node:
	return _instigator.get_ref() as Node if _instigator != null else null


func for_hit(at: Vector3, direction: Vector3) -> DamageContext:
	var context := DamageContext.new()
	context._source = _source
	context._instigator = _instigator
	context.team = team
	context.attack_id = attack_id
	context.friendly_fire = friendly_fire
	context.hit_position = at
	context.hit_direction = direction.normalized()
	return context


func can_damage(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if friendly_fire:
		return true
	if target == get_instigator() or target == get_source():
		return false
	if target.has_method("get_damage_team"):
		var target_team: int = target.get_damage_team()
		return team == Team.NEUTRAL or target_team == Team.NEUTRAL or target_team != team
	return true
