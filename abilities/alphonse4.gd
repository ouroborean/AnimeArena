extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Alphonse starts the game with 30 Shield. He can use this skill to refresh the Shield to 30 points and gain 5 permanent damage reduction (stacks)."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.has_effect("Golem Armor", EffectType.Type.SHIELD, user):
		user.has_effect("Golem Armor", EffectType.Type.SHIELD, user).mag = 30
	else:
		var shield = Effect.shield_effect(30, -1)
		shield.set_source(self)
		Character.add_allied_effect(context, user, user, shield)
	var dr = Effect.damage_reduction_effect(5, -1)
	dr.set_source(self)
	dr.unique_render_id = 1
	dr.stackable=true
	dr.display_stacks=true
	dr.per_stack=true
	Character.add_allied_effect(context, user, user, dr)

func split_desc():
	return [
		"Alphonse gains up to 30 Shield and 5 permanent Damage Reduction (stacks)",
		"Alphonse starts the game with 30 Shield from this effect"
	]

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 35, 1.2)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here

	default_self_target_function(user, battle)
