extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Whenever Rob uses one of his Alternate skills, he activates Neko Neko no Mi, Model: Leopard for 2 turns. While active, he ignores non-damage effects and his alternate skills cost 1 less Red energy."

func split_desc():
	return [
		["Using an Alternate skill activates Neko Neko no Mi, Model: Leopard for 2 turns", Color.CADET_BLUE],
		["While active, Rob ignores negative non-damage effects and his alternate skills cost 1 less Red energy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		#Put execution per target here
		pass

func activate_neko_neko():
	if user.has_effect("Neko Neko no Mi, Model: Leopard", EffectType.Type.IGNORE_NON_DAMAGE):
		var ignore = user.has_effect("Neko Neko no Mi, Model: Leopard", EffectType.Type.IGNORE_NON_DAMAGE)
		var mod = user.has_effect("Neko Neko no Mi, Model: Leopard", EffectType.Type.COST_MOD)
		var prof_swap = user.has_effect("Neko Neko no Mi, Model: Leopard", EffectType.Type.PORTRAIT_CHANGE)
		ignore.duration = 5
		if mod != null:
			mod.duration = 5
		else:
			# The cost-reduction (a cleansable OUTCOME) was stripped while the form's protected anchor
			# still stands — re-apply it so it re-earns on this alternate-skill use (was a null-deref crash).
			var src = Ability.from_database("rob9")
			src.user = user
			mod = Effect.cost_mod_effect(-1, 5, Energy.Type.RED, ["Tobu Shigan Bachi", "Rankyaku Gaicho", "Sai Dai Rin: Rokuogan", "Tekkai Utsugi"])
			mod.set_source(src)
			mod.description = func desc (eff):
				return "Rob's alternate skills cost one less Red energy."
			Character.add_allied_effect(QueryContext.from_game_state(user, user.battle), user, user, mod)
		if prof_swap != null:
			prof_swap.duration = 5
	else:
		var source = Ability.from_database("rob9")
		source.user = user
		var ignore = Effect.ignore_non_damage_effect(5)
		ignore.set_source(source)
		ignore.cleansable = false
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
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
