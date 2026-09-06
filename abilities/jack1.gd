extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Jack deals 15 normal damage and 10 affliction damage to one enemy. Can only target Isolated enemies or enemies affected by Fog of London. If this skill targets an Isolated enemy, Fog of London will cost 1 Random energy the following turn."

func split_desc():
	return [
		"Deals 15 damage and 10 Affliction damage to target enemy",
		["Can only target Isolated enemies or enemies affected by Fog of London", Color.DIM_GRAY],
		["If it hits an Isolated enemy, Fog of London costs 1 Random next turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		Character.resolve_damage(context, target, 10, DamageType.Type.AFFLICTION)
		if target.is_isolated():
			var cost_change = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, 3, ["Fog of London"])
			cost_change.set_source(self)
			Character.add_allied_effect(context, user, user, cost_change)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished) and (character.is_isolated() or character.marked_by("Fog of London", user)):
			variations.append([130, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and (character.is_isolated() or character.marked_by("Fog of London", user)):
			check_hostile_target(user, character, context)
	
