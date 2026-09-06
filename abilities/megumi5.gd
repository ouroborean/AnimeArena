extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Each turn, Bottomless Well, Great Serpent, and Rabbit Escape select a random class of skill to refer to",
		["Classes are: Physical, Energy, Affliction, or Mental", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var ticking = Effect.trigger_effect(Trigger.always(ticking_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Megumi's skills now interact with Physical skills.")
	ticking.set_source(self)
	ticking.mag = "Physical"
	Character.add_allied_effect(context, user, user, ticking)

func ticking_trigger(context):
	var source = context.effect
	var roll = context.battle.roll(1, 4)
	var skill_class = ""
	match roll:
		1:
			skill_class = "Physical"
		2:
			skill_class = "Energy"
		3:
			skill_class = "Mental"
		4:
			skill_class = "Affliction"
	source.description = func (eff): return "Megumi's skills now interact with " + skill_class + " skills."
	source.mag = skill_class
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
