extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For the rest of the game, Explosion bypasses invulnerability",
		["If used again, Megumin will ignore Counter and Reflect skills permanently", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	user.manually_advance_mission(6, 1)
	if user.marked_by("Waga wa Megumin!"):
		var counter_ignore = Effect.ignore_counter_effect(-1, [])
		counter_ignore.set_source(self)
		Character.add_allied_effect(context, user, user, counter_ignore)
	else:
		var mark = Effect.mark(-1, "Explosion will bypass Invulnerability.")
		mark.set_source(self)
		mark.cleansable = false
		Character.add_allied_effect(context, user, user, mark)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Explosion") and not user.has_effect("Waga wa Megumin!", EffectType.Type.IGNORE_COUNTER)
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
