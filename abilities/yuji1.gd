extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 damage to one enemy. The following turn, that enemy takes 5 True damage."

func split_desc():
	return [
		"Deals 15 damage to one enemy",
		["The following turn, that enemy takes 5 True damage", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var special = false
	
	var base_damage = 15
	if user.marked_by("Consume Finger"):
		var mark = user.has_effect("Consume Finger", EffectType.Type.MARK)
		base_damage += (mark.stacks * 5)
	
	if user.marked_by("Combat Awakening", user):
		special = user.has_effect("Combat Awakening", EffectType.Type.MARK).mag == 1
		var valid_targets = []
		for character in context['enemy_team'].characters:
			if not character.dead and not character.banished and not character.is_invuln(self):
				valid_targets.append(character)
		if len(valid_targets) > 0:
			var roll = user.battle.roll(0, len(valid_targets) - 1)
			var random_target1 = valid_targets[roll]
			
			var roll2 = user.battle.roll(0, len(valid_targets) - 1)
			var random_target2 = valid_targets[roll2]
			user.targeter.clear_targets()
			user.targeter.targets.append(random_target1)
			user.targeter.targets.append(random_target2)
		user.effects.full_remove_effect_by_name("Combat Awakening")
	var tick_id = 0
	for target in user.targeter.targets:
		var damage_type = DamageType.Type.NORMAL
		if special:
			damage_type = DamageType.Type.TRUE
		Character.resolve_damage(context, target, base_damage, damage_type)
		if special:
			user.call_unique("yuji", "check_black_flash", [target])
		var ticking = Effect.trigger_effect(Trigger.always(ticking_trigger), EffectType.Type.TICKING_TRIGGER, 3, "This character will take 5 True damage.")
		ticking.set_source(self)
		ticking.damage_type = DamageType.Type.TRUE
		ticking.unique_render_id = tick_id
		tick_id += 1
		Character.add_hostile_effect(context, user, target, ticking)
	
func ticking_trigger(context):
	Character.resolve_effect_damage(context, context['effect'], context['target'], 5, DamageType.Type.TRUE)
	user.call_unique("yuji", "check_black_flash", [context['target']])
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	if user.marked_by("Combat Awakening"):
		variations += behavior_self_panic_button(context, 150)
	else:
		variations += behavior_single_target_damage(context, 30)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	if user.marked_by("Combat Awakening"):
		default_self_target_function(user, battle)
	else:
		default_hostile_target_function(user, battle)
