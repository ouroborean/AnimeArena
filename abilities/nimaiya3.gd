extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Targets either of Oetsu's allies. The first time this skill is used on them, they permanently ignore Counter and Reflect skills. The second time, their cooldowns are permanently reduced by 1. The third time, their skills permanently cost 1 less Random energy."

func split_desc():
	return [
		["1st use on an ally: they permanently ignore Counter and Reflect skills", Color.CADET_BLUE],
		["2nd use: their cooldowns are permanently reduced by 1", Color.CADET_BLUE],
		["3rd use: their skills permanently cost 1 less Random energy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		
		var first_forge = target.has_effect("God of the Sword", EffectType.Type.IGNORE_COUNTER, user)
		var second_forge = target.has_effect("God of the Sword", EffectType.Type.COOLDOWN_MOD, user)
		var third_forge = target.has_effect("God of the Sword", EffectType.Type.COST_MOD, user)
		
		if not first_forge:
			var counter_ignore = Effect.ignore_counter_effect(-1, [])
			counter_ignore.set_source(self)
			Character.add_allied_effect(context, user, target, counter_ignore)
		elif not second_forge:
			var cooldown_mod = Effect.cooldown_mod(-1, -1)
			cooldown_mod.set_source(self)
			Character.add_allied_effect(context, user, target, cooldown_mod)
		elif not third_forge:
			var cost_mod = Effect.cost_mod_effect(-1, -1, Energy.Type.RANDOM)
			cost_mod.set_source(self)
			Character.add_allied_effect(context, user, target, cost_mod)
		
			
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_selfless_helpful(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if selfless and character == user:
			continue
		if character.has_effect("God of the Sword", EffectType.Type.COST_MOD, user) == null:
			check_allied_target(user, character, context)
