extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Rob targets one enemy, checking them for Shield, Damage Reduction, and if they are below 60 health. If any two of the three conditions are true, the target is instantly killed. This cannot be Countered or Reflected. Swaps with Rokushiki: Rokuogan on use."

func split_desc():
	return [
		["Instantly kills target enemy if at least two of these are true: they have Shield, have Damage Reduction, or are below 60 health", Color.ORANGE_RED],
		["Cannot be countered or reflected", Color.DIM_GRAY],
		["Swaps with Rokushiki: Rokuogan on use", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var conditions = 0
		if target.get_effects_by_type(EffectType.Type.SHIELD):
			conditions += 1
		if target.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION):
			conditions += 1
		if target.health.hp < 60:
			conditions += 1
		if conditions >= 2:
			target.execute_attempt(100, user, self)
	
	
	user.effects.remove_effect("Rokushiki Ogi: Rokuogan", EffectType.Type.ABILITY_SWAP)
	activate_neko_neko()

func activate_neko_neko():
	user.manually_advance_mission(8, 1)
	if user.has_effect("Neko Neko no Mi, Model: Leopard", EffectType.Type.IGNORE_NON_DAMAGE):
		var ignore = user.has_effect("Neko Neko no Mi, Model: Leopard", EffectType.Type.IGNORE_NON_DAMAGE)
		var mod = user.has_effect("Neko Neko no Mi, Model: Leopard", EffectType.Type.COST_MOD)
		var prof_swap = user.has_effect("Neko Neko no Mi, Model: Leopard", EffectType.Type.PORTRAIT_CHANGE)
		ignore.duration = 5
		mod.duration = 5
		prof_swap.duration = 5
	else:
		var source = Ability.from_database("rob9")
		source.user = user
		var ignore = Effect.ignore_non_damage_effect(5)
		ignore.set_source(source)
		var mod = Effect.cost_mod_effect(-1, 5, Energy.Type.RED, ["Tobu Shigan Bachi", "Rankyaku Gaicho", "Sai Dai Rin: Rokuogan", "Tekkai Utsugi"])
		mod.set_source(source)
		mod.description = func desc (eff):
			return "Rob's alternate skills cost one less Red energy."
		var prof_swap = Effect.portrait_change_effect(0, 5)
		prof_swap.set_source(source)
		prof_swap.system = true
		var context = QueryContext.from_game_state(user, user.battle)
		Character.add_allied_effect(context, user, user, ignore)
		Character.add_allied_effect(context, user, user, mod)
		Character.add_allied_effect(context, user, user, prof_swap)

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
