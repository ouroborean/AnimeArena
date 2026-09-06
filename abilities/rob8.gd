extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Rob gains 20 Damage Reduction for 1 turn. During this time, any Harmful skill used on him is Reflected to the user. This skill is invisible. Swaps with Rokushigi: Tekkai on use."

func split_desc():
	return [
		"Rob gains 20 Damage Reduction for 1 turn",
		["While active, any Harmful skill used on him is reflected to its user", Color.CADET_BLUE],
		["Invisible", Color.DIM_GRAY],
		["Swaps with Rokushiki: Tekkai on use", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var dr = Effect.damage_reduction_effect(20, 2)
	dr.set_source(self)
	dr.invisible = true
	var reflect_eff = Effect.reflect_effect(Trigger.always(shield_reflect_trigger), EffectType.Type.REFLECT_RECEIVE, -1, 2, "Any Harmful skills this character receives will be reflected back to the user.", ["Harmful"])
	reflect_eff.set_source(self)
	reflect_eff.invisible = true
	reflect_eff.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, reflect_eff)
	
	user.effects.remove_effect("Rokushiki: Tekkai", EffectType.Type.ABILITY_SWAP)
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


func shield_reflect_trigger(context):
	var attacker = context['owner']
	var ally = context['target']
	var rob = context['effect'].user
	var tt = attacker.used_ability.target_type()
	if tt == TargetType.Type.SINGLE:
		attacker.targeter.targets.erase(attacker.targeter.main_target)
		attacker.targeter.targets.append(attacker)
	elif tt != TargetType.Type.SELF:
		# AoE reflected back to its user: re-aim onto the attacker's team.
		var valid = reflect_retarget_to_team(attacker)
		attacker.targeter.targets = valid
		attacker.targeter.main_target = valid[0]

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
