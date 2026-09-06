extends Ability
var base_power = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Nezuko heals another ally for 20 HP and removes all afflictions from them, or deals 20 damage to an enemy. The targeted character is permanently marked."

func split_desc():
	return [
		["Heals another ally for 20 HP and removes all enemy afflictions from them", Color.CADET_BLUE],
		["Or deals 20 damage to an enemy", Color.ORANGE_RED],
		"The targeted character is permanently marked by Blood Demon Art"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var hostile = Condition.is_hostile(user, target)
		var marked = Condition.has_effect(target, "Blood Demon Art", EffectType.Type.MARK, user)
		if hostile.satisfied(context):
			Character.resolve_damage(context, target, base_power, DamageType.Type.NORMAL)
			if not marked.satisfied(context):
				var mark = Effect.mark(-1, "Nezuko will target this character with Demonic Frenzy.")
				mark.set_source(self)
				Character.add_hostile_effect(context, user, target, mark)
		else:
			Character.resolve_healing(context, target, base_power)
			target.effects.cleanse_hostile_afflictions(target)
			if not marked.satisfied(context):
				var mark = Effect.mark(-1, "Nezuko will target this character with Demonic Frenzy.")
				mark.set_source(self)
				Character.add_allied_effect(context, user, target, mark)
			
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

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
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
	default_hostile_target_function(user, battle)
