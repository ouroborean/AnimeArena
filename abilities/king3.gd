extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "King awakens his Sacred Treasure for 2 turns, replacing Chastiefol: Increase with Chastiefol: Sunflower and this skill with Chastiefol: Pollen Garden. Disaster will target all targets King has damaged during this time."

func split_desc():
	return [
		"For 4 turns, any enemy that uses a Harmful skill will be affected by Disaster",
		["During this time, King's skills are Empowered", Color.CADET_BLUE],
		["Swaps to Chastifold: Pollen Garden", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	for enemy in context.enemy_team.characters:
		var trigger = Effect.trigger_effect(Trigger.always(harmful_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, 8, "If this character uses a Harmful skill, they will take 10 Bleed damage on the following turn.")
		trigger.set_source(self)
		Character.add_hostile_effect(context, user, enemy, trigger)
	
	var mark = Effect.mark(7, "King's skills are Empowered.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	
	var abi_swap2 = Effect.ability_swap_effect(4, 2, user, 7)
	abi_swap2.set_source(self)
	Character.add_allied_effect(context, user, user, abi_swap2)
	
	
func harmful_trigger(context):
	var bleed = Effect.damage_effect(10, DamageType.Type.BLEED, 2)
	bleed.last_turn_only = true
	bleed.set_source(user.moveset.base_abilities[5])
	Character.add_hostile_effect(context, user, context.target, bleed)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 140)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
