extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Whenever Shiro uses a damaging skill, she will consume one stack of Ganta Fever to extend that skill's improvement effect for two turns."

func split_desc():
	return [
		["Whenever Shiro uses a damaging skill, she consumes one stack of Ganta Fever to extend that skill's improvement effect for two turns", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var passive_eff = Effect.empty(-1, "If Shiro uses a damaging skill, she will consume one stack of Ganta Fever to extend that skill's improvement effect for two turns.")
	passive_eff.set_source(self)
	Character.add_allied_effect(context, user, user, passive_eff)

func get_fever_duration():
	var duration = 3
	if user.effects.has_effect("Ganta Fever", EffectType.Type.MARK, user) != null and user.effects.has_effect("Ganta Fever", EffectType.Type.MARK, user).stacks > 0:
		user.effects.has_effect("Ganta Fever", EffectType.Type.MARK, user).consume_stack(1)
		duration += 4
	return duration
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	pass
