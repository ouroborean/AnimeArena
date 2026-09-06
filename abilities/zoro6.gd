extends Ability

var base_damage = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 piercing damage to one enemy, reduces their non-affliction damage by 10, and grants him 10 Shield for 3 turns. Swaps to 'One-Sword Style: Lion Strike'."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var cancels = []
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var weakness_eff = Effect.damage_mod_effect(-10, 6, [], [], [DamageType.Type.AFFLICTION])
		weakness_eff.set_source(self)
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.PIERCING, 5)
		damage_eff.set_source(self)
		
		cancels.append(weakness_eff)
		cancels.append(damage_eff)
		
		Character.add_hostile_effect(context, user, target, damage_eff)
		Character.add_hostile_effect(context, user, target, weakness_eff)
	var shield_eff = Effect.shield_effect(10, 2)
	shield_eff.set_source(self)
	
	
	var trigger = Trigger.always(three_sword_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.TICKING_TRIGGER, 5, "This character will receive 10 Shield.")
	trigger_eff.set_source(self)
	trigger_eff.system = true
	cancels.append(trigger_eff)
	
	var ability_swap = Effect.ability_swap_effect(6, 0, user, -1)
	ability_swap.set_source(self)
	
	ability_swap.unique_render_id = 1
	var cancel_effect = Effect.control_cancel(6, ability_name, cancels)
	cancel_effect.set_source(self)
	
	user.effects.remove_effect("Crab Grab", EffectType.Type.ABILITY_SWAP, user)
	
	Character.add_allied_effect(context, user, user, shield_eff)
	Character.add_allied_effect(context, user, user, ability_swap)
	Character.add_allied_effect(context, user, user, trigger_eff)
	Character.add_allied_effect(context, user, user, cancel_effect)

func three_sword_trigger(context):
	var shield_eff = Effect.shield_effect(10, 2)
	shield_eff.set_source(self)
	Character.add_allied_effect(context, context['owner'], context['target'], shield_eff)
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 25)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
