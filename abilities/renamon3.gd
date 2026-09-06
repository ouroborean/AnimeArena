extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Cleanses Renamon of enemy effects and heals it 40 HP",
		["Deals 10 Affliction damage to a random enemy each turn for 4 turns", Color.CADET_BLUE],
		["All of Renamon's skills swap to Foxtail Inferno while active", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	user.effects.cleanse_all_enemy_effects(user)
	Character.resolve_healing(context, user, 40)
	var potential_targets = []
	for enemy in context['enemy_team'].characters:
		if not (enemy.dead or enemy.banished):
			potential_targets.append(enemy)
	
	if len(potential_targets) > 0:
		var roll = battle.roll(0, len(potential_targets) - 1)
		var chosen_enemy = potential_targets[roll]
		Character.resolve_damage(context, chosen_enemy, 10, DamageType.Type.AFFLICTION)
	
	for i in range(4):
		var copy = Effect.copy_effect(user.moveset.abilities[4], i, 7, user)
		copy.system = true
		copy.set_source(self)
		Character.add_allied_effect(context, user, user, copy)
	
	var trigger = Effect.trigger_effect(Trigger.always(renamon_trigger), EffectType.Type.TICKING_TRIGGER, 7, "Renamon will deal 10 Affliction damage to a random enemy")
	trigger.set_source(self)
	trigger.damage_type = DamageType.Type.AFFLICTION
	Character.add_allied_effect(context, user, user, trigger)
	var portrait = Effect.portrait_change_effect(0, 7)
	portrait.set_source(self)
	Character.add_allied_effect(context, user, user, portrait)
	

func renamon_trigger(context):
	var potential_targets = []
	for enemy in context['enemy_team'].characters:
		if not (enemy.dead or enemy.banished):
			potential_targets.append(enemy)
	var effect = context.effect
	if len(potential_targets) > 0:
		var roll = context.battle.roll(0, len(potential_targets) - 1)
		var chosen_enemy = potential_targets[roll]
		Character.resolve_effect_damage(context, effect, chosen_enemy, 10, DamageType.Type.AFFLICTION)
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 250)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here

	default_self_target_function(user, battle)
