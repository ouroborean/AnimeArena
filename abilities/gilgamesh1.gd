extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "If used on Gilgamesh, adds one stack of Gate of Babylon. If used on an enemy, deals 10 damage to that enemy, then consumes all stacks of Gate of Babylon from Gilgamesh to repeat this effect once per stack consumed."

func split_desc():
	return [
		"Deals 10 damage to target enemy. Consumes all Gate of Babylon stacks to repeat once for each stack",
		"If used on Gilgamesh, +1 stack of Gate of Babylon"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target == user:
			var gate = Effect.mark(-1, func (eff): return "Gilgamesh has opened " + str(eff.stacks) + " Gates of Babylon.")
			gate.set_source(self)
			gate.stackable = true
			gate.display_stacks = true
			Character.add_allied_effect(context, user, user, gate)
		else:
			var gates = 1
			if user.marked_by("Gate of Babylon", user):
				gates += user.has_effect("Gate of Babylon", EffectType.Type.MARK, user).stacks
			if gates >= 5:
				user.manually_advance_mission(10, 1)
			for i in range(gates):
				Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
			user.effects.full_remove_effect_by_name("Gate of Babylon", user)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var gates = 1
	if user.marked_by("Gate of Babylon", user):
		gates += user.has_effect("Gate of Babylon", EffectType.Type.MARK, user).stacks
	
	variations += behavior_hostile_aoe_damage(context, 25 * gates, 1.1)
	variations += behavior_self_panic_button(context, 75)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_self_target_function(user, battle)
