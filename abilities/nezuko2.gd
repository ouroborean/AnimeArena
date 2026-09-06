extends Ability
var base_power = 20
var base_self_heal = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Nezuko targets every character marked by 'Blood Demon Art', casting 'Blood Demon Art' on them then healing herself 15HP for every character affected. Bypasses invulnerability."

func split_desc():
	return [
		"Casts Blood Demon Art on every character marked by it (heals allies, damages enemies), Bypassing Invulnerability",
		["Nezuko heals 15 HP for each character affected", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var target_count = 0
	for target in user.targeter.targets:
		var hostile = Condition.is_hostile(user, target)
		target_count += 1
		if hostile.satisfied(context):
			Character.resolve_damage(context, target, base_power, DamageType.Type.NORMAL)
		else:
			Character.resolve_healing(context, target, base_power)
			target.effects.cleanse_hostile_afflictions(target)
	if target_count >= 3:
		user.manually_advance_mission(10, 1)
	Character.resolve_healing(context, user, base_self_heal * target_count)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	var context = QueryContext.from_game_state(user, user.battle)
	for character in user.battle.all_characters():
		var marked = Condition.has_effect(character, "Blood Demon Art", EffectType.Type.MARK, user)
		if marked.satisfied(context):
			return true
	return false

func custom_behavior(context):
	var variations = []
	for character in context['ally_team'].characters:
		#TODO: add isolation check
		if not character.is_isolated() and not (character.dead or character.banished) and not character == user:
			variations.append([120 + ((100 - character.health.hp) * 1.5), [user, self, [character]]])
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished):
			variations.append([120, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		var marked = Condition.has_effect(character, "Blood Demon Art", EffectType.Type.MARK, user)
		if marked.satisfied(context):
			character.set_targeted()
