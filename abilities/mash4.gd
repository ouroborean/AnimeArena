extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mash targets one of her allies, making them permanently invulnerable to non-Strategic skills and reflecting all harmful skills used on them to herself. During this time, Mash gains 30 Shield and this skill is replaced by Shield of White Walls. This effect will end if the Shield is destroyed."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var invuln = Effect.invuln_effect(-1, [], ["Strategic"])
		invuln.set_source(self)
		Character.add_allied_effect(context, user, target, invuln)
		var eff = Effect.reflect_effect(Trigger.always(reflect_trigger), EffectType.Type.REFLECT_RECEIVE, user, -1, "Harmful skills will be reflected to Mash.", ["Harmful"])
		eff.set_source(self)
		Character.add_allied_effect(context, user, target, eff)
	
	var shield = Effect.shield_effect(30, -1)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)
	var swap = Effect.ability_swap_effect(5, 3, user, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_selfless_helpful(context, 100, 1.2)
	
	return variations
	
func target(user, battle):
	default_allied_target_function(user, battle)
