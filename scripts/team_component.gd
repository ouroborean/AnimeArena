extends Node
class_name TeamComponent

@export var max_members = 3
@export var energy: EnergyPool

var characters: Array

## Energy generation this team owes to drains it could not pay in cash.
## Team-level on purpose: the drain targets a character, but energy is a team
## resource, so three drains landing on one character deny the TEAM three points.
## Deliberately a raw int and not an Effect — it has no duration, is not
## cleansable, and must never be visible to the effect/dispel machinery.
## Lives on the team (not the EnergyPool) because the pool node is freed and
## replaced wholesale by reset_energy_pool(); those calls are all match
## boundaries, which is exactly where this must be zeroed, so both of them
## clear it explicitly below.
var denied_energy_generation: int = 0

signal energy_changed(val, element)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func add_character(character):
	if not character in characters and len(characters) < max_members:
		character.team = self
		characters.append(character)
		# Characters are scene instances (~10 nodes each); parent them under the
		# team so freeing the team/player subtree reclaims them. Without this
		# every match's characters were orphaned nodes for the process lifetime.
		if character.get_parent() == null:
			add_child(character)

func character_in_team(path, alive=true):
	for character in characters:
		if path == character.path_name and not (character.dead or character.banished):
			return true
	return false

func remove_character(character):
	characters.erase(character)
	# The team is the character's only owner — free it, or it orphans.
	if is_instance_valid(character):
		character.queue_free()

## Free every per-match Character instance along with the roster array. A bare
## `characters.clear()` (the old idiom at match build) leaked all six character
## subtrees of the previous match, every match.
func clear_characters():
	for character in characters:
		if is_instance_valid(character):
			character.queue_free()
	characters.clear()

func reset_energy_pool():
	energy.queue_free()
	energy = load("res://components/energypool.tscn").instantiate()
	add_child(energy)   # replacement pool must be owned too, or it orphans
	# Player/Team objects are reused across matches on the server; a pending
	# denial left over from the previous match would otherwise eat the first
	# generation of the next one.
	denied_energy_generation = 0

func instantiate_energy_pool():
	energy.queue_free()
	energy = load("res://components/energypool.tscn").instantiate()
	add_child(energy)
	denied_energy_generation = 0


func pretty_print():
	for character in characters:
		character.pretty_print()

func refund_ability(ability):
	for element in ability.cost():
		energy.change_promised_energy(element, -ability.cost()[element])

func pay_for_ability(ability):
	for element in ability.cost():
		energy.change_promised_energy(element, ability.cost()[element])

func change_energy(element, val):
	energy.change_energy(element, val)

## Drain `val` energy from this team's pool. Whatever the pool cannot pay in
## cash is charged against the team's NEXT energy generation instead.
##
## This replaces a vacuous bail: draining an empty pool used to `return` and do
## literally nothing, which made every drain skill dead weight against the very
## players it was meant to punish (the acting team's pool is already debited
## before abilities execute, so it is empty far more often than not).
##
## RNG: the unpayable path must consume NO roll — the old bail returned before
## battle.roll too, so the seeded stream (shadow parity, replays, seeded
## self-play) is bit-identical to before on every branch.
func lose_energy(val, battle):
	for i in range(val):
		var drained = false
		while not drained:
			# `_drainable_total()` is a second, raw guard on top of the original
			# total_available() test. total_available() subtracts promised
			# energy and lose_promised_energy has no floor, so a refund without
			# a matching payment can report "energy available" while every color
			# bucket is 0 — which used to spin this loop forever on a headless
			# server. Both conditions agree in every reachable state (promised is
			# 0 during ability resolution), so this changes no roll count.
			if energy.total_available() <= 0 or _drainable_total() <= 0:
				# Partial payment is intentional: i points came out of the pool,
				# the rest is owed by the next generation.
				denied_energy_generation += val - i
				return
			var roll = battle.roll(0, 3, "Valid energy loss type")
			if energy.pool[roll] >= 1:
				energy.change_energy(roll, -1)
				drained = true

func _drainable_total():
	var count = 0
	for key in energy.pool:
		count += energy.pool[key]
	return count

func get_active_energy_types():
	var used_elements = [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]
	return used_elements

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
