extends Ability
var base_per_turn = 5
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 damage to all enemies. Enemies currently affected by Smoke Star take 5 more damage for each turn left on its duration. This ends Smoke Star on all affected targets, and any damaged enemy will have Smoke Star permanently last one more turn against them."

func split_desc():
	return [
		"Deals 10 damage to all enemies, +5 per turn left on Smoke Star's duration against each affected enemy",
		["Ends Smoke Star on all affected targets", Color.ORANGE_RED],
		["Each damaged enemy permanently has Smoke Star last 1 more turn against them (stacks)", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		
		var smoke_star = target.has_effect("Smoke Star", EffectType.Type.BLIND, user)
		var turns = 0
		if smoke_star != null:
			turns = (smoke_star.duration + 1) / 2
		Character.resolve_damage(context, target, base_damage + (base_per_turn * turns), DamageType.Type.NORMAL)
		if smoke_star != null:
			target.effects.erase_effect(smoke_star)
		var mark = Effect.mark(-1, "Smoke Star will last 1 more turn against this character.")
		mark.set_source(user.moveset.base_abilities[3])
		mark.stackable = true
		mark.display_stacks = true
		Character.add_hostile_effect(context, user, target, mark)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 15, 1.2)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
