extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 3 turns, Maka and another ally ignore negative non-damage effects and their skills have 1 less cooldown."

func split_desc():
	return [
		["For 3 turns, Maka and another ally ignore negative non-damage effects", Color.CADET_BLUE],
		["Their skills have 1 less cooldown", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if not target == user:
			if target.has_stuns():
				user.manually_advance_mission(10, 1)
			var non_damage_ign = Effect.ignore_non_damage_effect(6)
			non_damage_ign.set_source(self)
			var cooldown_mod = Effect.cooldown_mod(-1, 5)
			cooldown_mod.set_source(self)
			Character.add_allied_effect(context, user, target, non_damage_ign)
			Character.add_allied_effect(context, user, target, cooldown_mod)
	var self_ndi = Effect.ignore_non_damage_effect(6)
	self_ndi.set_source(self)
	var self_cooldown_mod = Effect.cooldown_mod(-1, 5)
	self_cooldown_mod.set_source(self)
	Character.add_allied_effect(context, user, user, self_ndi)
	Character.add_allied_effect(context, user, user, self_cooldown_mod)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	var partner = false
	for character in context['ally_team'].characters:
		if character.path_name == "soul":
			partner = true
	
	for character in context['ally_team'].characters:
		#TODO: add isolation check
		if not character.is_isolated() and not (character.dead or character.banished) and not character == context['owner'] and (not partner or character.path_name == "soul"):
			variations.append([100, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

	
func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var partnered = Condition.has_effect(user, "Partner: Soul", EffectType.Type.COST_CHANGE, user)
	if not partnered.satisfied(context):
		default_allied_target_function(user, battle)
	else:
		for character in user.team.characters:
			if character.path_name == "soul":
				check_allied_target(user, character, context)
