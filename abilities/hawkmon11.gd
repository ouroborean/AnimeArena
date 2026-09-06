extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 30 damage to target enemy",
		["Stuns the target for 2 turns if an ally has applied a Stun effect in the last 3 turns", Color.CADET_BLUE],
		["The same is true for Silence, Taunt, Shatter, Isolate, and Blind", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 30, DamageType.Type.NORMAL)
		for effect in user.effects.get_effects_by_type(EffectType.Type.EMPTY):
			match effect.mag:
				0:
					continue
				1:
					var stun = Effect.stun_effect(4)
					stun.set_source(self)
					Character.add_hostile_effect(context, user, target, stun)
				2:
					var silence = Effect.silence_effect(4)
					silence.set_source(self)
					Character.add_hostile_effect(context, user, target, silence)
				3:
					var shatter = Effect.def_negate(4)
					shatter.set_source(self)
					Character.add_hostile_effect(context, user, target, shatter)
				4:
					var isolation = Effect.isolate(4)
					isolation.set_source(self)
					Character.add_hostile_effect(context, user, target, isolation)
				5:
					var taunt = Effect.taunt_effect(4, user)
					taunt.set_source(self)
					Character.add_hostile_effect(context, user, target, taunt)
				6:
					var blind = Effect.blind_effect(4)
					blind.set_source(self)
					Character.add_hostile_effect(context, user, target, blind)
		
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
