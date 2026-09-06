extends Ability
var base_damage = 35
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Maka deals 35 true damage to the enemy affected by Witch Hunter. This skill gains double effect from allied damage increases."

func split_desc():
	return [
		"Deals 35 true damage to the enemy affected by Witch Hunter",
		["Gains double effect from allied damage increases", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	modifier_value = 2
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.TRUE)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 80, 1.1)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	for character in battle.all_characters():
		if not character in user.team.characters:
			# Keyed on Witch Hunter's per-turn DAMAGE effect. The HARMFUL_USE_TRIGGER this
			# used to read no longer exists (maka3 dropped it this patch), and a stale
			# lookup here greys Figure-6 Hunter out forever with no error.
			if character.has_effect("Witch Hunter", EffectType.Type.DAMAGE, user):
				check_hostile_target(user, character, QueryContext.from_game_state(user, battle))
