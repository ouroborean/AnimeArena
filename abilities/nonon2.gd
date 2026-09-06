extends Ability
var base_damage = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Nonon deals 5 damage to all enemies for 3 turns. During this time, this skill swaps to Concentrated Climax."

func split_desc():
	return [
		"Deals 5 Piercing damage to all enemies each turn for 3 turns",
		["Affected enemies are auto-targeted by Unstoppable Performance and Concentrated Climax Bypasses against them", Color.ORANGE_RED],
		["Swaps to Concentrated Climax while active", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var damage = Effect.damage_effect(base_damage, DamageType.Type.PIERCING, 5)
		damage.set_source(self)
		var mark = Effect.mark(5, "Concentrated Climax will Bypass invulnerability against this target, and they will be automatically targeted by Unstoppable Performance.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)
		Character.add_hostile_effect(context, user, target, damage)
	var swap = Effect.ability_swap_effect(4, 1, user, 5)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 25)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
