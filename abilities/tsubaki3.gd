extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Target ally gains 20 Shield",
		["If that ally is wielding Tsubaki, their first skill is replaced by Tsubaki Mode: Uncanny Sword for 1 turn", Color.AQUAMARINE],
		["If the target is Black Star, Tsubaki also gains 15 Shield", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var shield = Effect.shield_effect(20, 2)
		shield.set_source(self)
		Character.add_allied_effect(context, user, target, shield)

		# The wield gate stays - what the patch removed is the "uses a skill" requirement,
		# so the copy lands at cast time instead of waiting on an ACTION_USE_TRIGGER.
		if target.marked_by("Tsubaki Mode: Kusarigama"):
			# Slot 0, hardcoded, exactly like Mavis's Bestow (mavis2:16-19): Uncanny Sword
			# now occupies the ally's FIRST skill rather than whichever one they happened to
			# use. base_abilities[5] is tsubaki6, Tsubaki Mode: Uncanny Sword.
			# dur 3, not 2: the copy is applied on Tsubaki's turn, so a dur-2 (1-turn) copy expired at
			# the end of the OPPONENT's turn — before the ally's next turn — so the ally never got to use
			# it. +1 carries the copy through to the end of the ally's next turn (owner ruling Q15).
			var copy = Effect.copy_effect(user.moveset.base_abilities[5], 0, 3, target)
			copy.set_source(self)
			Character.add_allied_effect(context, user, target, copy)

		if target.path_name == "blackstar":
			var sub_shield = Effect.shield_effect(15, 2)
			sub_shield.set_source(self)
			Character.add_allied_effect(context, user, user, sub_shield)
		
	
			
			
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
