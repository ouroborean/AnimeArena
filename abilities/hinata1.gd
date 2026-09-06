extends Ability

var base_damage = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 damage to target enemy for 4 turns. During this time, this skill can be used again to deal 5 Piercing damage to the originally targeted enemy."

func split_desc():
	return [
		"Deals 10 damage to target enemy each turn for 4 turns",
		["While active, can be reused to deal 5 Piercing damage to the original target", Color.CADET_BLUE],
		["Eight Trigrams: Air Palm costs 1 less Random while active", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	if user.marked_by("Gentle Fist Taijutsu"):
		for target in user.targeter.targets:
			if target.has_effect("My Turn To Protect", EffectType.Type.TAUNT):
				user.manually_advance_mission(6, 1)
			Character.resolve_damage(context, target, 5, DamageType.Type.PIERCING)
	else:
		for target in user.targeter.targets:
			if target.has_effect("My Turn To Protect", EffectType.Type.TAUNT):
				user.manually_advance_mission(6, 1)
			Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
			var damage_eff = Effect.damage_effect(10, DamageType.Type.NORMAL, 7)
			damage_eff.set_source(self)
			Character.add_hostile_effect(context, user, target, damage_eff)
		var mark = Effect.mark(7, "Hinata is using Gentle Fist Taijutsu. If she is stunned, it will be paused.")
		mark.set_source(self)
		Character.add_allied_effect(context, user, user, mark)
		var cost_change = Effect.cost_change_effect({}, 7, ["Gentle Fist Taijutsu"])
		cost_change.system = true
		cost_change.set_source(self)
		Character.add_allied_effect(context, user, user, cost_change)
		var cost_mod = Effect.cost_mod_effect(-1, 7, 4, ["Eight Trigrams: Air Palm"])
		cost_mod.set_source(self)
		cost_mod.unique_render_id = 4
		Character.add_allied_effect(context, user, user, cost_mod)
		



func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 30)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
