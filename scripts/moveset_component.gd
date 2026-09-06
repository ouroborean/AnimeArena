extends Node
class_name MovesetComponent

var abilities: Array
var base_abilities: Array
# Server-authoritative active ability list. On passive clients the server
# resolves ABILITY_SWAP / SKILL_COPY effects (which walk _effects, empty on
# the client) and ships the resulting ability names each snapshot. When set,
# display_abilities() returns these instead of the default abilities[0..3],
# so the UI, targeting, description, and cost all reflect the swapped state
# without mutating the base moveset.
var server_active_abilities: Array = []

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_base_abilities(moveset, user):
	for ability in moveset:
		if ability == null:
			continue
		if not "Uncounterable" in ability.classes.keys():
			ability.classes["Uncounterable"] = false

		ability.user = user
		# Ability instances are Nodes created by Ability.from_database — parent
		# them under the moveset so they're freed with the character (they were
		# orphaned for the process lifetime before).
		if ability.get_parent() == null:
			add_child(ability)
	base_abilities = moveset
	abilities = moveset

func add_ability(ability):
	abilities.append(ability)
	if ability != null and ability.get_parent() == null:
		add_child(ability)

func advance_cooldowns(user):
	#TODO: include check for cooldown tick rate mods?
	var paralyzed: bool = user.paralyzed()
	var checked_abilities = []
	for ability in base_abilities:
		checked_abilities.append(ability)
		_advance_one(ability, paralyzed)
	for ability in get_active_abilities(user):
		if not ability in checked_abilities:
			_advance_one(ability, paralyzed)


# Paralyze freezes cooldown COUNTDOWN. It must not freeze the +1 that start_cooldown adds to a skill
# as it is used — that is bookkeeping for this very decrement, not a turn of progress, and leaving it
# in place would push every freshly-used skill one turn past its printed cooldown (a cooldown-0 skill
# would land on 1). start_cooldown stamps the ability precisely so the two cases can be told apart
# here; a Paralyze applied mid-action, after start_cooldown has already run, is the normal case
# (reactives fire from check_ability_use_triggers, which runs later).
#
# The test is "is there an UNRECLAIMED stamp", not "was it stamped this turn". Normally those are the
# same thing — the stamp is cleared by the advance at the end of the turn it was written. They differ
# only when that advance never ran, which end_of_turn_effect_handling skips for a dead or banished
# holder: the +1 is then still owed, and is reclaimed on the first advance that does run.
func _advance_one(ability, paralyzed: bool) -> void:
	if ability == null:
		return   # set_base_abilities tolerates nulls, and display_abilities can return a short array
	var owed: bool = int(ability.cooldown_started_turn) >= 0
	ability.cooldown_started_turn = -1
	if paralyzed and not owed:
		return
	if ability.cooldown_remaining > 0:
		ability.cooldown_remaining -= 1


func get_replacement_terms():
	var output = []
	for ability in base_abilities:
		if ability.mastery_name != "":
			var pairing = [ability.ability_name, ability.mastery_name]
			output.append(pairing)
	
	var sort_func = func (a, b):
		if len(a[0]) > len(b[0]):
			return true
		return false
	
	output.sort_custom(sort_func)
	
	return output

func get_active_abilities(user):
	var working_abilities = display_abilities()
	var swaps = user.get_ability_swap_effects()
	
		
	for swap in swaps:
		if swap.source not in base_abilities:
			continue
		var swap_target = swap.mag[1]
		var swap_payload = swap.mag[0]
		if int(swap_target) >= working_abilities.size():
			continue
		working_abilities[int(swap_target)] = base_abilities[int(swap_payload)]
	for copy in user.effects.get_effects_by_type(EffectType.Type.SKILL_COPY):
		var copied_skill = copy.ability_targets
		var swap_target = copy.mag
		if int(swap_target) >= working_abilities.size():
			continue
		working_abilities[swap_target] = copied_skill
	
	return working_abilities

func display_abilities():
	if server_active_abilities.size() == 4:
		return [server_active_abilities[0], server_active_abilities[1], server_active_abilities[2], server_active_abilities[3]]
	# Every shipped character has at least 4 display abilities, but an authored
	# one is built from a spec and could be short. Slicing instead of indexing
	# 0..3 matters because this runs inside _serialize_wire_team: an index error
	# here aborts the whole snapshot and both players get an empty battle.
	if abilities.size() < 4:
		return abilities.slice(0, abilities.size())
	return [abilities[0], abilities[1], abilities[2], abilities[3]]

func match_used_ability(ability_name, user):
	return
	var active_abilities = get_active_abilities(user)
	for ability in active_abilities:
		if ability.ability_name == ability_name:
			return active_abilities.find(ability)
	return -1

func pretty_print():
	print("\tAbilities:")
	for ability in abilities:
		print("\t\t" + ability.ability_name)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

var laria_moveset = [
	
]
