extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sakura gains 10 points of Damage Reduction and ignores enemy stun effects for 3 turns. While active, swaps to Mind Strangle."

func split_desc():
	return [
		"Removes all cleansable enemy effects and hostile damage-over-time from target ally and heals them 20 HP",
		["Continues for up to 3 turns (Channeled)", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var cancels = []
	
	for target in user.targeter.targets:
		target.effects.cleanse_all_enemy_effects(target)
		var to_remove = []
		for damage_eff in target.effects.get_effects_by_type(EffectType.Type.DAMAGE):
			if damage_eff.damage_type == DamageType.Type.BLEED or damage_eff.damage_type == DamageType.Type.AFFLICTION:
				to_remove.append(damage_eff)
		for eff in to_remove:
			target.effects.erase_effect(eff)
		var ticking = Effect.trigger_effect(Trigger.always(custom_tick), EffectType.Type.TICKING_TRIGGER, 5, "Sakura will heal this character for 20 HP and fully cleanse them of enemy effects and damage-over-time.")
		ticking.set_source(self)
		ticking.channel = true
		cancels.append(ticking)
		
		Character.add_allied_effect(context, user, target, ticking)
		Character.resolve_healing(context, target, 20)
	
	var cancel_eff = Effect.channel_cancel(-1, ability_name, cancels)
	cancel_eff.set_source(self)
	Character.add_allied_effect(context, user, user, cancel_eff)
	
func custom_tick(context):
	var eff = context['source']
	var heal_target = context['source'].target
	heal_target.effects.cleanse_all_enemy_effects(heal_target)
	var to_remove = []
	for damage_eff in heal_target.effects.get_effects_by_type(EffectType.Type.DAMAGE):
		if damage_eff.damage_type == DamageType.Type.BLEED or damage_eff.damage_type == DamageType.Type.AFFLICTION:
			to_remove.append(damage_eff)
	for remove_eff in to_remove:
		heal_target.effects.erase_effect(remove_eff)
	
	Character.resolve_effect_healing(context, eff, heal_target, 20)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_heal(context, 40, 1.2)
	
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
