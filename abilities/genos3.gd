extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 Affliction damage to one enemy for 3 turns. Any enemy to use a new Affliction skill on Genos during this time will recieve 10 Affliction damage. While active, this skill swaps to 'Lightning Drill Cannon'."


func split_desc():
	return [
		"Deals 10 Affliction damage to target enemy for 3 turns",
		"While active, deals 10 Affliction damage to enemies who use Affliction skills on Genos",
		["Swaps to Lightning Drill Cannon while active", Color.AQUAMARINE]
	]
	


func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var cancels = []
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.AFFLICTION, 5)
		damage_eff.set_source(self)
		cancels.append(damage_eff)
		Character.add_hostile_effect(context, user, target, damage_eff)
	
	var trigger_eff = Effect.trigger_effect(Trigger.always(affliction_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 4, "Genos will deal 10 Affliction damage to any enemy who uses a new Affliction skill on him.")
	trigger_eff.set_source(self)
	var swap_eff = Effect.ability_swap_effect(4, 2, user, 5)
	swap_eff.set_source(self)
	cancels.append(trigger_eff)
	cancels.append(swap_eff)
	
	var cancel_eff = Effect.control_cancel(5, ability_name, cancels)
	cancel_eff.set_source(self)
	
	Character.add_allied_effect(context, user, user, trigger_eff)
	Character.add_allied_effect(context, user, user, swap_eff)
	Character.add_allied_effect(context, user, user, cancel_eff)
	
func affliction_trigger(context):
	if not context['owner'].used_ability.classes["Affliction"]:
		return
	Character.resolve_effect_damage(context, context['effect'], context['owner'], base_damage, DamageType.Type.AFFLICTION)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
