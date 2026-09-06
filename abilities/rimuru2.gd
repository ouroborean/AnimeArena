extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Rimuru marks an enemy for 1 turn. If they use a new skill, it will be copied and the target will have their cooldowns paralyzed for 2 turns. Invisible. Swaps to 'Beezlebuth' during 'Passive: Demon Lord Awakening'."

func split_desc():
	return [
		"Marks target enemy for 1 turn (Invisible). If that enemy uses a skill, their cooldowns will be Paralyzed for 2 turns and the skill will be copied",
		["Counters the marked enemy instead of Paralyzing them after Megiddo is used", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if not user.marked_by("Megiddo"):
			var trigger_eff = Effect.trigger_effect(Trigger.always(gluttony_trigger), EffectType.Type.ACTION_USE_TRIGGER, 2, "If this character uses a new skill, it will be copied and they have their cooldowns paralyzed for 2 turns.")
			trigger_eff.set_source(self)
			trigger_eff.invisible = true
			Character.add_allied_effect(context, user, target, trigger_eff)
		else:
			var counter = Effect.counter_effect(Trigger.always(beelz_trigger), EffectType.Type.COUNTER_USE, 2, "If this character uses a new harmful skill, it will be countered and copied for 1 turn.", ["Harmful"])
			counter.set_source(self)
			counter.wrapup_func = default_counter_timeout
			counter.invisible = true
			Character.add_hostile_effect(context, user, target, counter)
		
		
func beelz_trigger(context):
	var attacker = context['owner']
	var user = context['effect'].user
	var ability = attacker.used_ability
	user.manually_advance_mission(6, 1)
	var copy_effect = Effect.copy_effect(ability, 1, 2, user)
	copy_effect.set_source(self)
	var cost_change_effect = Effect.cost_change_effect({}, 2, [ability.ability_name])
	cost_change_effect.set_source(self)
	
	Character.add_allied_effect(context, user, user, copy_effect)
	Character.add_allied_effect(context, user, user, cost_change_effect)
	
	default_counter_trigger(context)


func gluttony_trigger(context):
	var user = context['effect'].user
	var attacker = context['owner']
	var ability = context['source']
	
	attacker.effects.full_remove_effect_by_name("Gluttony", user)
	user.manually_advance_mission(6, 1)
	var copy = Effect.copy_effect(ability, 1, 4, user)
	copy.set_source(self)
	Character.add_allied_effect(context, user, user, copy)
	
	var paralyze = Effect.paralyze_effect(3)
	paralyze.set_source(self)
	Character.add_hostile_effect(context, user, attacker, paralyze)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 20)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
