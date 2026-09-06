extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 3 turns, deals 20 Piercing damage to 2 randomly chosen targets at the end of each turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var potential_targets = []
	for enemy in context['enemy_team'].characters:
		if not (enemy.dead or enemy.banished or enemy.is_invuln(self)):
			potential_targets.append(enemy)
	
	for i in range(2):
		if len(potential_targets) > 0:
			var roll = battle.roll(0, len(potential_targets) - 1)
			var chosen_enemy = potential_targets[roll]
			Character.resolve_damage(context, chosen_enemy, 20, DamageType.Type.PIERCING)
	
	var tick = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, 5, "Frieren will deal 20 Piercing damage to 2 random targets.")
	tick.set_source(self)
	tick.damage_type = DamageType.Type.PIERCING
	Character.add_allied_effect(context, user, user, tick)
	

func tick_trigger(context):
	var potential_targets = []
	for enemy in context['enemy_team'].characters:
		if not (enemy.dead or enemy.banished or enemy.is_invuln(self)):
			potential_targets.append(enemy)
	
	for i in range(2):
		if len(potential_targets) > 0:
			var roll = context.battle.roll(0, len(potential_targets) - 1)
			var chosen_enemy = potential_targets[roll]
			Character.resolve_effect_damage(context, context.effect, chosen_enemy, 20, DamageType.Type.PIERCING)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 45)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
