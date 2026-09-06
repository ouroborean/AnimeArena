extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.
 
func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 damage to target enemy. If used during Hard Lessons, this skill will activate Class Is In Session on a random ally with a random instance of its normal effects."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["If used during Hard Lessons, also activates a random Class Is In Session effect (heal or Shield) on a random ally", Color.CADET_BLUE],
		["During Pitch Black, the target is also marked for Impossible Speed", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	if user.has_effect("Hard Lessons", EffectType.Type.TICKING_TRIGGER, user):
		user.manually_advance_mission(7, 1)
	if user.marked_by("Pitch Black", user):
		user.manually_advance_mission(8, 1)

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		if user.marked_by("Pitch Black", user) and not target.marked_by("Pitch Black", user):
			var mark = Effect.mark(user.has_effect("Pitch Black", EffectType.Type.MARK, user).duration, "This character will also be targeted with Impossible Speed.")
			mark.set_source(self)
			Character.add_hostile_effect(context, user, target, mark, true)
	if user.has_effect("Hard Lessons", EffectType.Type.TICKING_TRIGGER, user):
		var valid_characters = []
		for character in user.team.characters:
			if not character == user and not (character.dead or character.banished):
				valid_characters.append(character)
		if not len(valid_characters) == 0:
			var random_ally = valid_characters[battle.roll(0, len(valid_characters) - 1)]
			
			var roll = battle.roll(0, 1)
			if roll != 0:
				Character.resolve_healing(context, random_ally, 10)
			else:
				var shield = Effect.shield_effect(10, 2)
				shield.set_source(user.moveset.base_abilities[4])
				Character.add_allied_effect(context, user, random_ally, shield)
						
	

func and_target(character):
	return character.marked_by("Impossible Speed", user) and character != user

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	var bypassing = false
	if user.marked_by("Pitch Black", user):
		bypassing = true
	
	variations += behavior_hostile_spread_out(context, "Impossible Speed", EffectType.Type.MARK, 25, 0.5, bypassing)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	
	var bypassing = false
	if user.marked_by("Pitch Black", user):   # Pitch Black grants the Bypass (matches execute() and custom_behavior); "Impossible Speed" is an enemy mark the user never carries
		bypassing = true

	default_hostile_target_function(user, battle, bypassing)
