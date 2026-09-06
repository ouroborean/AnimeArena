extends Node
class_name EffectStorageComponent

var _effects: Array[Effect]
# Passive multiplayer clients populate this with DisplayEffect instances built
# from incoming wire EffectPayloads. Display effects are rendered the same as
# runtime effects (via get_renderable_effects + get_effect_clusters) but are
# never touched by game-logic functions like cleanse / has_effect / tick, so
# they coexist safely with the empty _effects array on a passive client.
var _display_effects: Array = []
signal effect_added(effect)
signal effect_removed(effect)
signal effects_changed()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func add_effect(effect: Effect, prepend=false):
	# Effects are NODES (effect_component.tscn) — without a parent nothing ever
	# frees them, and the server orphaned every effect it ever created (~500+
	# nodes/match; 478k orphans after one active day). Stored effects become
	# children of this storage so the match subtree cascade-free reclaims them;
	# a removed effect keeps its parent (harmless, bounded per match, and the
	# restore-on-removal pattern can re-add the same node). Guarded connects:
	# re-adding a previously-removed effect must not double-connect.
	if not effect.effect_expired.is_connected(erase_effect):
		effect.effect_expired.connect(erase_effect)
	if not effect.effect_updated.is_connected(announce_change):
		effect.effect_updated.connect(announce_change)
	var eff_match = has_effect(effect.effect_name(), effect.effect_type, effect.user)
	if eff_match:
		#TODO handle stacking/refreshing logic
		if eff_match.stackable:
			if effect.stack_mag:
				eff_match.mag += effect.mag
			eff_match.stacks += effect.stack_count()
			if eff_match.effect_type in EffectType.use_or_receive_triggers():
				eff_match.fresh_stack = true
			# The incoming effect merged into the existing stack and is NOT
			# stored — free it (deferred: callers may still write fields on it
			# in this same frame, e.g. wrapup_func assignment after add).
			if effect.get_parent() == null:
				effect.queue_free()
		elif eff_match.refresh:
			remove_effect(eff_match.effect_name(), eff_match.effect_type, effect.user)
			_store_effect(effect, prepend)
		else:
			_store_effect(effect, prepend)
		effect_added.emit(effect)
		announce_change()
	else:
		_store_effect(effect, prepend)
		effect_added.emit(effect)
		announce_change()

# Append/prepend to the runtime list AND parent the node under this storage so
# battle teardown frees it. Re-added effects may already be parented here.
func _store_effect(effect: Effect, prepend: bool):
	if prepend:
		_effects.insert(0, effect)
	else:
		_effects.append(effect)
	if effect.get_parent() == null:
		add_child(effect)

func has_effect(eff_name, eff_type, user=null):
	for eff in _effects:
		if eff_name == eff.effect_name() and eff_type == eff.effect_type and (user == eff.user or user == null):
			return eff
	return null

func has_any_effect(effect_name):
	for eff in _effects:
		if effect_name == eff.effect_name():
			return true
	return false

func remove_effect(eff_name, eff_type, user=null):
	var eff_match = has_effect(eff_name, eff_type, user)
	if eff_match:
		erase_effect(eff_match)

# Forcibly remove one effect as part of a cleanse/dispel, running the SAME
# teardown a natural expiry or shield-break would — so wrapup_func AND the
# shield/barrier break hooks in Character.check_effect_breaking (break_vow,
# gain_shield_break, break_hero, Metal Armor, Soul Gem corruption…) fire. The
# old cleanse dropped effects with a bare _effects.filter(), skipping ALL of
# that and stranding paired state (e.g. Mash's protected ally stuck permanently
# invulnerable after her shield was cleansed).
# `owner` is the character these effects sit on; `breaker` attributes the
# removal (whoever stripped the shield eats Around Round Axe's punish, etc.).
func dispel_with_teardown(eff, owner, breaker=null):
	if eff.removed:
		return
	eff.breaker = breaker
	if eff.effect_type == EffectType.Type.SHIELD or eff.effect_type == EffectType.Type.BARRIER:
		# Mirror shatter_shields / shatter_barrier exactly (character_component.gd):
		# break hooks first, then consume (CONSUMED never re-fires wrapup_func).
		owner.check_effect_breaking(eff)
		eff.mag = 0
		consume_effect(eff)
	else:
		# CANCELLED fires wrapup_func once, then effect_expired -> erase_effect
		# -> effect_removed (also drives the restore-on-removal hook path).
		eff.end_effect(EndingType.Type.CANCELLED)

func cleanse_all_enemy_effects(character, by=null):
	# IGNORE_CLEANSE on the target (e.g. from Deadly Gas) blocks the cleanse
	# wholesale — the offending effects stay put.
	if character.get_effects_by_type(EffectType.Type.IGNORE_CLEANSE).size() > 0:
		return 0
	# Cleanse removes ALL hostile effects gated only on the per-effect `cleansable` flag — the old
	# `eff.effect_type in silenced_effects()` type-whitelist is gone (that gave players "cleanse SOME").
	# Machinery/identity effects opt out via cleansable=false (set at the trigger/empty/transform
	# factories + per-effect on mode-anchors/immunities/etc.).
	# Snapshot first, then tear each down through the proper path — dispel mutates _effects (and can
	# add/remove effects via break hooks), so iterating a copy keeps it safe and skips freshly-added ones.
	var to_remove: Array = []
	for eff in _effects:
		if not (character in eff.user.team.characters) and eff.cleansable:
			to_remove.append(eff)
	for eff in to_remove:
		dispel_with_teardown(eff, character, by)
	announce_change()
	return to_remove.size()

func cleanse_all_ally_effects(character, by=null):
	# See cleanse_all_enemy_effects for rationale on the IGNORE_CLEANSE bailout + teardown.
	if character.get_effects_by_type(EffectType.Type.IGNORE_CLEANSE).size() > 0:
		return 0
	# Buff-strip (remove an enemy's own effects) — same model: gate only on `cleansable`, type-whitelist
	# dropped. Permanent identity buffs/immunities opt out via cleansable=false.
	var to_remove: Array = []
	for eff in _effects:
		if (character in eff.user.team.characters) and eff.cleansable:
			to_remove.append(eff)
	for eff in to_remove:
		dispel_with_teardown(eff, character, by)
	announce_change()
	return to_remove.size()

# A cleanse narrowed by effect NAME, by SIDE, or by COUNT — the partial cleanses
# authored abilities need ("remove one Burn", "strip their buffs"). It lives beside
# the two whole-cleanses on purpose: the IGNORE_CLEANSE bailout, the `cleansable`
# gate, the snapshot-before-teardown and the dispel path are the rules of cleansing,
# and a caller reimplementing them over a copy of _effects would drift from them.
# eff_name "" = any name; scope "hostile"|"own"|"any"; limit <= 0 = no limit.
func cleanse_filtered(character, by=null, eff_name := "", scope := "hostile", limit := 0):
	if character.get_effects_by_type(EffectType.Type.IGNORE_CLEANSE).size() > 0:
		return 0
	var to_remove: Array = []
	for eff in _effects:
		if not eff.cleansable:
			continue
		var own: bool = character in eff.user.team.characters
		if scope == "hostile" and own:
			continue
		if scope == "own" and not own:
			continue
		if eff_name != "" and eff.effect_name() != eff_name:
			continue
		to_remove.append(eff)
		if limit > 0 and to_remove.size() >= limit:
			break
	for eff in to_remove:
		dispel_with_teardown(eff, character, by)
	announce_change()
	return to_remove.size()

func get_all_death_cleansable_effects(user):
	var output = []
	for effect in _effects:
		if effect.user == user and (not effect.system or effect.remove_on_death):
			output.append(effect)
	return output

func get_all_effects_by_name(eff_name, user=null):
	var output = []
	for effect in _effects:
		if effect.source.ability_name == eff_name and (user == effect.user or user == null):
			output.append(effect)
	return output

func eff_special_removal_criteria(eff):
	return eff.source.ability_name != "Dragon's Sin of Wrath"

func clear_non_system_effects(character):
	# Belt-and-suspenders for a torn-down battle reference — from_game_state would otherwise
	# dereference a previously-freed BattleManager (frequent in bot matches) and abort the turn.
	if not is_instance_valid(character.battle):
		return
	var context = QueryContext.from_game_state(character, character.battle)
	
	var system = func (eff):
		return eff.system and eff.source.ability_name != "Dragon's Sin of Wrath"
	_effects = _effects.filter(system)
	announce_change()

func cleanse_hostile_afflictions(character, by=null):
	# See cleanse_all_enemy_effects for rationale on the IGNORE_CLEANSE bailout + teardown.
	if character.get_effects_by_type(EffectType.Type.IGNORE_CLEANSE).size() > 0:
		return
	var context = QueryContext.from_game_state(character, character.battle)

	var to_remove: Array = []
	for eff in _effects:
		var hostile = Condition.is_hostile(character, eff.user)
		var affliction = Condition.has_ability_class("Affliction", eff.source)
		var multi = Condition.multi([hostile, affliction])
		if multi.satisfied(context) and eff.cleansable:
			to_remove.append(eff)
	for eff in to_remove:
		dispel_with_teardown(eff, character, by)
	announce_change()

func effect_count(eff_name, eff_type, user=null):
	var count = 0
	for eff in _effects:
		if eff_name == eff.effect_name() and eff_type == eff.effect_type and (user == eff.user or user == null):
			count += 1
	return count

func erase_effect(eff):
	_effects.erase(eff)
	eff.removed = true
	effect_removed.emit(eff)
	announce_change()

func consume_effect(eff, full = false):
	eff.end_effect(EndingType.Type.CONSUMED)
	if full:
		full_remove_effect_by_name(eff.source.ability_name, eff.user)

func full_remove_effect_by_name(eff_name, user=null):
	var has_name = func (eff):
		return not(eff_name == eff.effect_name() and (user == eff.user or user == null))
	_effects = _effects.filter(has_name)
	announce_change()


func full_remove_effect_by_type(eff_type, user=null):
	var effects = get_effects_by_type(eff_type)
	for eff in effects:
		if user == eff.user or user == null:
			erase_effect(eff)
			announce_change()

func get_effects_by_type(eff_type):
	var output = []
	for effect in _effects:
		if eff_type == effect.effect_type:
			output.append(effect)
	return output

# The raw live effect list, read-only for callers that need to enumerate with their OWN predicate
# (BlockRunner._matching_effects filters by name/type AND the display_system visibility filter for
# value readings). Returns the backing array by reference for cheapness — callers must not mutate it;
# every writer goes through add_effect/erase_effect so the render clusters stay in sync.
func get_all_effects():
	return _effects

func add_display_effect(display_effect) -> void:
	for existing in _display_effects:
		if existing.id == display_effect.id:
			return
	_display_effects.append(display_effect)
	effect_added.emit(display_effect)
	announce_change()

func remove_display_effect_by_id(effect_id: String) -> void:
	for i in range(_display_effects.size()):
		if _display_effects[i].id == effect_id:
			var removed_eff = _display_effects[i]
			removed_eff.removed = true
			_display_effects.remove_at(i)
			effect_removed.emit(removed_eff)
			announce_change()
			return

func get_display_effect_by_id(effect_id: String):
	for de in _display_effects:
		if de.id == effect_id:
			return de
	return null

func clear_display_effects() -> void:
	_display_effects.clear()
	announce_change()

func has_display_effect(effect_name, effect_type):
	for effect in _display_effects:
		if effect.source.ability_name == effect_name and effect.effect_type == effect_type:
			return true
	return false

# Returns the union of runtime and display effects for UI consumption. On a
# normal (non-passive) client _display_effects is empty so this is identical
# to _effects; on a passive client _effects is empty so it returns the wire-
# driven view.
func get_renderable_effects() -> Array:
	var combined: Array = []
	combined.append_array(_effects)
	combined.append_array(_display_effects)
	return combined

func get_effect_clusters(effects):
	var cluster_dict = {}
	for effect in effects:
		if effect.invisible and effect.user.enemy:
			var local_team = effect.user.enemy_team()
			var revealed = false
			# Toph: invisible Physical effects from enemies are sensed.
			if effect.source.classes["Physical"] and local_team.character_in_team("toph"):
				revealed = true
			# Kurotsuchi: Data Collection reveals every invisible effect from
			# an enemy while the mark is active on a living Mayuri on the
			# observing team.
			if not revealed and local_team.character_in_team("kurotsuchi"):
				for c in local_team.characters:
					if c.path_name != "kurotsuchi":
						continue
					if c.dead or c.banished:
						continue
					if c.marked_by("Data Collection") or c.has_display_effect("Data Collection", EffectType.Type.MARK):
						revealed = true
					break
			if not revealed:
				continue
		if effect.system and not effect.display_system:
			continue
		if [effect.effect_name() + str(effect.unique_render_id), effect.user] not in cluster_dict:
			cluster_dict[ [effect.effect_name() + str(effect.unique_render_id), effect.user] ] = [effect]
		else:
			cluster_dict[ [effect.effect_name() + str(effect.unique_render_id), effect.user] ].append(effect)
			
	return cluster_dict

func pretty_print():
	print("\tCurrent effects: ")
	for effect in _effects:
		print("\t\t" + effect.effect_name() + "- Type: " + str(effect.effect_type))

func tick_all_effects_durations():
	var reference_list = []
	for effect in _effects:
		effect.waiting = false
		effect.fresh_stack = false
		effect.triggered = false
		reference_list.append(effect)
	for effect in reference_list:
		effect.tick_effect()

func announce_change(eff=null):
	effects_changed.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
