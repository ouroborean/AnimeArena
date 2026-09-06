## MatchEventRecorder
##
## Subscribes to a server-side BattleManager's protocol-facing signals
## (declared in `new multiplayer/battle_manager.gd`) and accumulates
## wire-format event dictionaries that match the schema in MATCH_PROTOCOL.md
## § 3.3. The server flushes the accumulated events into an
## `apply_turn_result(events, snapshot)` RPC after every processed turn
## package and then calls `clear()`.
##
## Phase 5: built and attached on the server-side shadow inside
## `Match.begin_match`. Clients do not run a recorder; their managers emit
## the same signals locally but no one is subscribed.

extends RefCounted
class_name MatchEventRecorder

var manager: BattleManager
var events: Array = []


func attach(m: BattleManager) -> void:
	manager = m
	m.turn_started_event.connect(_on_turn_started)
	m.turn_ended_event.connect(_on_turn_ended)
	m.energy_gained_event.connect(_on_energy_gained)
	m.energy_spent_event.connect(_on_energy_spent)
	m.energy_exchanged_event.connect(_on_energy_exchanged)
	m.damage_dealt.connect(_on_damage_dealt)
	m.healing_done.connect(_on_healing_done)
	m.effect_added_to.connect(_on_effect_added)
	m.effect_removed_from.connect(_on_effect_removed)
	m.cooldown_set_event.connect(_on_cooldown_set)
	m.character_died.connect(_on_character_died)
	m.character_banished.connect(_on_character_banished)
	m.match_ended_event.connect(_on_match_ended)
	m.message_request.connect(func (text): _on_message(text, false))
	m.message_demand.connect(func (text): _on_message(text, true))
	m.ability_will_execute.connect(_on_ability_will_execute)


func clear() -> void:
	events.clear()


# ===========================================================================
# Handlers
# ===========================================================================

func _on_turn_started(turn_number: int, acting_role: int) -> void:
	events.append({
		"type": "TURN_STARTED",
		"turn_number": turn_number,
		"acting_role": _role_str(acting_role),
	})


func _on_turn_ended(turn_number: int) -> void:
	events.append({
		"type": "TURN_ENDED",
		"turn_number": turn_number,
	})


func _on_energy_gained(team_role: int, energy_list: Array) -> void:
	var int_list := []
	for energy_type in energy_list:
		int_list.append(int(energy_type))
	events.append({
		"type": "ENERGY_GAINED",
		"side": _role_str(team_role),
		"energy_list": int_list,
	})


func _on_energy_spent(team_role: int, energy_dict: Dictionary) -> void:
	var spent := {}
	for key in energy_dict.keys():
		spent[int(key)] = int(energy_dict[key])
	events.append({
		"type": "ENERGY_SPENT",
		"side": _role_str(team_role),
		"spent": spent,
	})


func _on_energy_exchanged(team_role: int, offer: Dictionary, request) -> void:
	var offer_dict := {}
	for key in offer.keys():
		offer_dict[int(key)] = int(offer[key])
	events.append({
		"type": "ENERGY_EXCHANGED",
		"side": _role_str(team_role),
		"offer": offer_dict,
		"request": int(request),
	})


func _on_ability_will_execute(character, ability) -> void:
	var targets: Array = []
	for target in character.targeter.targets:
		targets.append(manager._canonical_index(target))
	var ability_idx = character.moveset.get_active_abilities(character).find(ability)
	events.append({
		"type": "ABILITY_USED",
		"char_idx": manager._canonical_index(character),
		"ability_idx": ability_idx,
		"targets": targets,
		# Ability-side hidden flag, mirroring battle_manager._should_show_action's
		# ability condition (`ability.invisible` — set from abilities_data.json in
		# Ability.from_database). The viewer-side exceptions there (own team always
		# sees, Toph reveals Physical) can't be baked into a recorded event; the
		# spectator strip drops invisible=true events, replays keep full data.
		# classes.get("Invisible") is a defensive forward-compat check — the classes
		# dict has no such key today.
		"invisible": bool(ability.invisible or ability.classes.get("Invisible", false)),
		# Caster HP at the moment of the cast. ability_will_execute fires immediately
		# before ability.execute(), so this is exactly the value the skill's own
		# HP-threshold branches read — which the PRE-turn snapshot is NOT (a DoT can
		# tick earlier in the same turn's execution order). Lets the client gate
		# HP-conditional VFX accurately (Mine's High Output Blast Blade). HP is
		# already public in every snapshot, so this reveals nothing new.
		"caster_hp": int(character.health.hp),
	})


# Is the CAUSE of an event hidden (an invisible ability or an invisible/visibility-scoped effect)?
# Feeds the generic "invisible" event tag: players' clients hide by role as always, while the
# spectator strip (_spectator_safe_events) drops every tagged event outright — otherwise DAMAGE /
# EFFECT_ADDED / COOLDOWN_SET frames would reveal an invisible cast's existence to spectators.
func _source_hidden(source) -> bool:
	if source == null:
		return false
	if "invisible" in source and source.invisible:
		return true
	return false


func _on_damage_dealt(target, amount: int, source, dealer) -> void:
	events.append({
		"type": "DAMAGE",
		"target": manager._canonical_index(target),
		"amount": int(amount),
		"damage_class": _damage_class(source),
		"source": _source_name(source),
		"from": manager._canonical_index(dealer) if dealer != null else null,
		"invisible": _source_hidden(source),
	})


func _on_healing_done(target, amount: int, source, healer) -> void:
	events.append({
		"type": "HEALING",
		"target": manager._canonical_index(target),
		"amount": int(amount),
		"source": _source_name(source),
		"from": manager._canonical_index(healer) if healer != null else null,
		"invisible": _source_hidden(source),
	})


func _on_effect_added(character, effect) -> void:
	events.append({
		"type": "EFFECT_ADDED",
		"target": manager._canonical_index(character),
		"effect": _build_effect_payload(effect),
		"invisible": _source_hidden(effect) or _visibility(effect) != "all",
	})


func _on_effect_removed(character, effect) -> void:
	events.append({
		"type": "EFFECT_REMOVED",
		"target": manager._canonical_index(character),
		"effect_id": _effect_id(effect),
		"invisible": _source_hidden(effect) or _visibility(effect) != "all",
	})


func _on_cooldown_set(character, ability, value: int) -> void:
	var ability_idx = character.moveset.get_active_abilities(character).find(ability)
	events.append({
		"type": "COOLDOWN_SET",
		"char_idx": manager._canonical_index(character),
		"ability_idx": ability_idx,
		"value": int(value),
		"invisible": _source_hidden(ability),
	})


func _on_character_died(character) -> void:
	events.append({
		"type": "DIED",
		"char_idx": manager._canonical_index(character),
	})


func _on_character_banished(character) -> void:
	events.append({
		"type": "BANISHED",
		"char_idx": manager._canonical_index(character),
	})


func _on_match_ended(winner_role: int) -> void:
	events.append({
		"type": "MATCH_ENDED",
		"winner_role": _role_str(winner_role),
	})


func _on_message(text: String, demand: bool) -> void:
	events.append({
		"type": "MESSAGE",
		"text": text,
		"demand": demand,
	})


# ===========================================================================
# Helpers
# ===========================================================================

func _role_str(role: int) -> String:
	return "p1" if role == 0 else "p2"


func _source_name(source) -> String:
	if source == null:
		return ""
	if source is Ability:
		return source.ability_name
	if source is Effect:
		return source.source.ability_name if source.source else source.effect_name()
	return str(source)


func _damage_class(source) -> String:
	var ability_ref = null
	if source is Ability:
		ability_ref = source
	elif source is Effect and source.source != null:
		ability_ref = source.source
	if ability_ref == null or not ("classes" in ability_ref):
		return "Physical"
	for cls in ["Physical", "Energy", "Mental", "Affliction"]:
		if ability_ref.classes.get(cls, false):
			return cls
	return "Physical"


func _effect_id(effect) -> String:
	var source_basename := ""
	if effect.source != null:
		source_basename = effect.source.get_script().resource_path.get_file().get_basename()
	var user_path := ""
	if effect.user != null:
		user_path = effect.user.path_name
	# Must match battle_manager._serialize_wire_effect / _effect_id_for_validation
	# — effect_type is part of the id so multi-effect abilities (midoriya4) don't
	# collide when passive clients dedupe by id in add_display_effect.
	return effect.effect_name() + "@" + user_path + "@" + source_basename + "@" + str(int(effect.effect_type))


func _visibility(effect) -> String:
	if not effect.invisible:
		return "all"
	if effect.user != null and effect.user.enemy:
		return "enemy_hidden"
	return "user_only"


func _build_effect_payload(effect) -> Dictionary:
	# Delegate to the manager so EFFECT_ADDED payloads and snapshot effect
	# entries are guaranteed to share the same shape — passive clients build
	# DisplayEffects from either path and would crash if the schemas drifted.
	return manager._serialize_wire_effect(effect)
