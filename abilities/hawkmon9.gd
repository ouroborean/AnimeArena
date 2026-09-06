extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 25 damage to target enemy and Stuns, Silences, and Taunts them for 1 turn",
		["Does not apply effects if allies have applied effects of that type in the last 3 turns", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 25, DamageType.Type.NORMAL)
		var effect_ids = [1, 2, 5]
		var marks = user.effects.get_effects_by_type(EffectType.Type.EMPTY)
		for mark in marks:
			if mark.mag in effect_ids:
				effect_ids.erase(mark.mag)
		for effect_id in effect_ids:
			match effect_id:
				1:
					var stun = Effect.stun_effect(2)
					stun.set_source(self)
					Character.add_hostile_effect(context, user, target, stun)
				2:
					var silence = Effect.silence_effect(2)
					silence.set_source(self)
					Character.add_hostile_effect(context, user, target, silence)
				5:
					var taunt = Effect.taunt_effect(2, user)
					taunt.set_source(self)
					Character.add_hostile_effect(context, user, target, taunt)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
