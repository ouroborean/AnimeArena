extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 piercing damage to one enemy, Bypassing Invulnerability. This may only be used on a target King damaged on the previous turn."
	
func split_desc():
	return [
		"Deals 15 damage to target enemy not affected by Disaster",
		["Deals 35 damage to target enemy while Empowered", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	if user.marked_by("True Spirit Spear Chastifold"):
		base_damage = 35
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_single_require_mark(context, "Disaster", EffectType.Type.MARK, 50, false, true)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		
		if not character.has_effect("Disaster", EffectType.Type.TICKING_TRIGGER, user):
			check_hostile_target(user, character, context)
