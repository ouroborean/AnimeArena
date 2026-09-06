class_name BattleLogEvent

enum Kind {
	ABILITY_USE,
	DAMAGE,
	HEALING,
	EFFECT_APPLIED,
	EFFECT_EXPIRED,
	COUNTER,
	REFLECT,
	INVULN_BLOCK,
	MISS,
	DEATH,
	REVIVE,
	ENERGY_GAIN,
	TURN_HEADER,
	SYSTEM,
}

const ALL_PLAYERS = -1

var kind: int
var turn: int = 0
var actor_path: String = ""
var actor_name: String = ""
var actor_team: int = -1
var target_paths: Array[String] = []
var target_names: Array[String] = []
var ability_name: String = ""
var ability_path: String = ""
var effect_name: String = ""
var effect_source_path: String = ""
var effect_id = null
var effect_type: int = -1
var amount: int = 0
var damage_type: int = -1
var extra: Dictionary = {}
var visible_to: int = ALL_PLAYERS
var demand: bool = false

static func make(p_kind: int) -> BattleLogEvent:
	var e = BattleLogEvent.new()
	e.kind = p_kind
	return e

func with_actor(character) -> BattleLogEvent:
	if character != null:
		actor_path = character.path_name
		actor_name = character.character_name
		actor_team = _resolve_team_index(character)
	return self

static func _resolve_team_index(character) -> int:
	if character == null or character.battle == null:
		return -1
	var b = character.battle
	if b.player != null and character in b.player.team.characters:
		return 0
	if b.enemy != null and character in b.enemy.team.characters:
		return 1
	return -1

func with_target(character) -> BattleLogEvent:
	if character != null:
		target_paths.append(character.path_name)
		target_names.append(character.character_name)
	return self

func with_ability(ability) -> BattleLogEvent:
	if ability != null:
		ability_name = ability.ability_name
		if "path_name" in ability:
			ability_path = ability.path_name
	return self

func with_effect(effect) -> BattleLogEvent:
	if effect != null:
		effect_name = effect.effect_name()
		effect_id = effect.id
		effect_type = effect.effect_type
		if effect.source != null:
			effect_source_path = effect.source.ability_name
	return self

func with_amount(p_amount: int) -> BattleLogEvent:
	amount = p_amount
	return self

func with_damage_type(p_type: int) -> BattleLogEvent:
	damage_type = p_type
	return self

func with_extra(key: String, value) -> BattleLogEvent:
	extra[key] = value
	return self

func with_visibility(player_id: int) -> BattleLogEvent:
	visible_to = player_id
	return self

func as_demand() -> BattleLogEvent:
	demand = true
	return self

func _cap(name: String) -> String:
	if name == "":
		return ""
	return name.capitalize()

func _target_list() -> String:
	if target_names.is_empty():
		return ""
	if target_names.size() == 1:
		return _cap(target_names[0])
	if target_names.size() == 2:
		return _cap(target_names[0]) + " and " + _cap(target_names[1])
	var out = ""
	for i in range(target_names.size() - 1):
		out += _cap(target_names[i]) + ", "
	out += "and " + _cap(target_names[-1])
	return out

func _damage_type_word() -> String:
	if damage_type == -1:
		return ""
	return DamageType.get_damage_type_name(damage_type)

func to_plain_string() -> String:
	match kind:
		Kind.ABILITY_USE:
			return _cap(actor_name) + " used " + ability_name
		Kind.DAMAGE:
			var dt = _damage_type_word()
			var dt_part = ""
			if dt != "":
				dt_part = " " + dt
			var src = ""
			if effect_source_path != "":
				src = " with an effect from " + effect_source_path
			elif ability_name != "":
				src = " with " + ability_name
			return _cap(actor_name) + " is dealing " + str(amount) + dt_part + " damage to " + _target_list() + src
		Kind.HEALING:
			return _cap(actor_name) + " is healing " + _target_list() + " for " + str(amount)
		Kind.EFFECT_APPLIED:
			return _cap(actor_name) + " applied " + effect_name + " to " + _target_list()
		Kind.EFFECT_EXPIRED:
			var reason = extra.get("reason", "expired")
			return effect_name + " " + reason + " on " + _target_list()
		Kind.COUNTER:
			return _cap(actor_name) + " was countered!"
		Kind.REFLECT:
			return _cap(actor_name) + " was reflected!"
		Kind.INVULN_BLOCK:
			return _target_list() + " was invulnerable to " + _cap(actor_name) + "'s attack"
		Kind.MISS:
			return _cap(actor_name) + " missed " + _target_list()
		Kind.DEATH:
			return _cap(actor_name) + " has fallen"
		Kind.REVIVE:
			return _cap(actor_name) + " has been revived"
		Kind.ENERGY_GAIN:
			var element = extra.get("element", "")
			return _cap(actor_name) + "'s team gained " + element + " energy"
		Kind.TURN_HEADER:
			return "--- Turn " + str(turn) + " ---"
		Kind.SYSTEM:
			return str(extra.get("text", ""))
	return ""
