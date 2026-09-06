extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Shiro permanently taunts the enemy team. During this time, Shiro takes 5 additional damage from new skills and she gains one stack of Ganta Fever each turn this skill remains active. Channeled."

func split_desc():
	return [
		["Shiro permanently taunts the enemy team", Color.ORANGE_RED],
		["Shiro takes 5 additional damage from new skills while active", Color.ORANGE_RED],
		["Shiro gains one stack of Ganta Fever each turn this skill remains active", Color.CADET_BLUE],
		["Channeled", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var cancels = []
	
	for target in user.targeter.targets:
		var taunt_eff = Effect.taunt_effect(-1, user)
		taunt_eff.set_source(self)
		cancels.append(taunt_eff)
		Character.add_hostile_effect(context, user, target, taunt_eff)
	
	var vuln = Effect.vulnerability_effect(5, -1, [], [])
	vuln.set_source(self)
	cancels.append(vuln)
	var ticking = Effect.trigger_effect(Trigger.always(sing_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Shiro will gain 1 stack of Ganta Fever.")
	ticking.set_source(self)
	cancels.append(ticking)
	
	
	
	var cancel_eff = Effect.channel_cancel(-1, ability_name, cancels)
	cancel_eff.set_source(self)
	if user.path_name == "shiro":
		var mark_desc = func (eff):
			return "Shiro has " + str(eff.stack_count()) + " stacks of Ganta Fever."
		var mark = Effect.mark(-1, mark_desc)
		mark.stackable = true
		mark.display_stacks = true
		mark.set_source(user.moveset.base_abilities[4])
		Character.add_allied_effect(context, user, user, mark)
	
	Character.add_allied_effect(context, user, user, vuln)
	Character.add_allied_effect(context, user, user, ticking)
	Character.add_allied_effect(context, user, user, cancel_eff)
	

func sing_trigger(context):
	if not user.path_name == "shiro":
		return
	var user = context['owner']
	var mark_desc = func (eff):
		return "Shiro has " + str(eff.stack_count()) + " stacks of Ganta Fever."
	var mark = Effect.mark(-1, mark_desc)
	mark.stackable = true
	mark.display_stacks = true
	mark.set_source(user.moveset.base_abilities[4])
	Character.add_allied_effect(context, user, user, mark)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 10, 0.5)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
