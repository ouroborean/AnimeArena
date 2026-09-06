extends Ability
var base_damage = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 5 damage to one enemy twice. The next time this skill is used it will deal Affliction damage instead* then permanently increase this skill's damage by 5 and revert back to Normal damage (stacks)."

func split_desc():
	return [
		"Deals 5 damage to target enemy twice",
		"If this skill didn't deal Affliction damage, it deals Affliction damage and permanently gets +5 damage on its next use"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var damage_type = DamageType.Type.NORMAL
	var primed = Condition.has_effect(user, "Machine-Gun Blows", EffectType.Type.MARK, user)
	if primed.satisfied(context):
		damage_type = DamageType.Type.AFFLICTION
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, damage_type)
		Character.resolve_damage(context, target, base_damage, damage_type)
	
	if primed.satisfied(context):
		var damage_mod = Effect.damage_mod_effect(5, -1, ["Machine-Gun Blows"])
		damage_mod.set_source(self)
		Character.add_allied_effect(context, user, user, damage_mod)
		user.effects.remove_effect("Machine-Gun Blows", EffectType.Type.MARK, user)
	else:
		var mark = Effect.mark(-1, "The next time Machine-Gun Blows is used, it will deal affliction damage and permanently increase its damage by 5.")
		mark.set_source(self)
		Character.add_allied_effect(context, user, user, mark)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
