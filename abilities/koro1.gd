extends Ability
 
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the next 4 turns, Koro-sensei will make all characters Invulnerable to one of the following classes of skills for 1 turn, chosen at random: Physical, Mental, Energy, Affliction. Each turn the chosen class will change to a random choice of the classes that haven't been chosen yet."

func split_desc():
	return [
		["For 4 turns, all characters become invulnerable to one random skill class each turn (Physical, Mental, Energy, or Affliction)", Color.CADET_BLUE],
		["Each turn picks a new class from those not yet chosen", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var ticking_trigger = Effect.trigger_effect(Trigger.always(lesson_trigger), EffectType.Type.TICKING_TRIGGER, 7, "Koro-sensei will make all characters Invulnerable to a random class of skill.")
	ticking_trigger.set_source(self)
	var invuln_type = ""
	var list = ["Physical", "Mental", "Energy", "Affliction"]
	var roll = battle.roll(0, 3)
	if list[roll] != null:
		invuln_type = list[roll]
		list[roll] = null
	for character in battle.all_characters():
		if not character.dead and not character.banished:
			var invuln = Effect.invuln_effect(3, [invuln_type])
			invuln.set_source(self)
			
			Character.add_allied_effect(context, user, character, invuln, true)
	
	ticking_trigger.mag = list
	Character.add_allied_effect(context, user, user, ticking_trigger)
	
	
	


func lesson_trigger(context):
	var koro = context['owner']
	var battle = context['battle']
	var lessons = context['effect']
	var invuln_type = ""
	while true:
		var roll = battle.roll(0, 3)
		if lessons.mag[roll] != null:
			invuln_type = lessons.mag[roll]
			lessons.mag[roll] = null
			break
	
	for character in battle.all_characters():
		if not character.dead and not character.banished:
			var invuln = Effect.invuln_effect(3, [invuln_type])
			invuln.set_source(self)
			
			Character.add_allied_effect(context, user, character, invuln, true)

		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 100)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here

	default_self_target_function(user, battle)
