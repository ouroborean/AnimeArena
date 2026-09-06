extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "At the start of the game, Omnimon marks a random enemy as his Nemesis. If Omnimon kills his Nemesis, he will heal 25 HP, and his damaging skills permanently trigger their bonus effects."

func split_desc():
	return [
		["At the start of the game, Omnimon marks a random enemy as his Nemesis", Color.CADET_BLUE],
		["If Omnimon kills his Nemesis, he heals 25 HP and his damaging skills permanently trigger their bonus effects", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var roll = battle.roll(0, 2)
	var nemesis = context['enemy_team'].characters[roll]
	
	var mark = Effect.mark(-1, "This character is Omnimon's Nemesis. Omnimon's skills will Bypass Invulnerability and have bonus effects if targeting them.")
	mark.set_source(self)
	mark.cleansable = false
	Character.add_hostile_effect(context, user, nemesis, mark)
	var trigger = Effect.trigger_effect(Trigger.always(on_death_trigger), EffectType.Type.ON_DEATH_TRIGGER, -1, "If Omnimon kills this character, his skills will permanently gain their bonus effects and he will heal 25 HP.")
	trigger.set_source(self)
	Character.add_hostile_effect(context, user, nemesis, trigger)


func on_death_trigger(context):
	var killer = context['owner']
	if killer.path_name != "omnimon":
		return
	user.manually_advance_mission(6, 1)
	Character.resolve_healing(context, killer, 25)
	var mark = Effect.mark(-1, "Omnimon has slain his Nemesis. His skills will permanently activate their bonus effects.")
	mark.set_source(self)
	mark.cleansable = false
	Character.add_allied_effect(context, killer, killer, mark)


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
