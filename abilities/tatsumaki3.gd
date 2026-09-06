extends Ability
var base_damage = 30
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 damage to all enemies. Stunned enemies have the duration of their stun effects increased by 1 turn. Swaps to Spear of Green Light for 3 turns."

func split_desc():
	return [
		"Deals 30 damage to all enemies",
		["Stunned enemies have their stun durations increased by 1 turn", Color.ORANGE_RED],
		["Swaps to Spear of Green Light for 3 turns", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
	
		if target.has_stuns() and not (target.dead or target.banished):
			for effect in target.effects.get_effects_by_type(EffectType.Type.STUN):
				user.manually_advance_mission(8, 1)
				effect.duration += 2
	var abi_swap = Effect.ability_swap_effect(4, 2, user, 5)
	abi_swap.set_source(self)
	Character.add_allied_effect(context, user, user, abi_swap)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 35, 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
