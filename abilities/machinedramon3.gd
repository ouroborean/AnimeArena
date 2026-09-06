extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 damage to the enemy team for 3 turns. During this time, any enemy that uses a harmful skill on a target other than Machinedramon will be Taunted by him for 1 turn."

func split_desc():
	return [
		"Deals 15 damage to all enemies each turn for 3 turns",
		["Any enemy who uses a Harmful skill on an ally other than Machinedramon is Taunted by him for 1 turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var cancels = []
	for target in user.targeter.targets:
		if target in user.team.characters:
			if target == user:
				continue
			var trigger_desc = func (eff):
				return "Any character who uses a harmful skill on this character will be Taunted by Machinedramon for 1 turn."
			var trigger = Effect.trigger_effect(Trigger.always(damage_taken_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 5, trigger_desc)
			trigger.set_source(self)
			Character.add_allied_effect(context, user, target, trigger)
			cancels.append(trigger)
		else:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
			var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 5)
			damage_eff.set_source(self)
			cancels.append(damage_eff)
			Character.add_hostile_effect(context, user, target, damage_eff)
	var cancel_eff = Effect.control_cancel(5, "Infinite Hand", cancels)
	cancel_eff.set_source(self)
	Character.add_allied_effect(context, user, user, cancel_eff)
		
func damage_taken_trigger(context):
	var damaged_ally = context['effect'].target
	var machinedramon = context['effect'].user
	var damaging_enemy = context['owner']
	if context['effect'].triggered:
		return
	if context['source'] is Effect:
		return
	context['effect'].triggered = true
	var taunt = Effect.taunt_effect(3, user)
	taunt.set_source(self)
	Character.add_hostile_effect(context, user, damaging_enemy, taunt)
	
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 30, 1.4)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
	default_hostile_target_function(user, battle)
