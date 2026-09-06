extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 damage to one enemy. After two turns have passed, the damaged enemy will die. This skill can only target an enemy marked by Red-Eyed Killer."

func split_desc():
	return [
		"Deals 15 damage to target enemy. After 2 turns, the damaged enemy dies",
		"Can only target enemies marked by Red-Eyed Killer"
	]


func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		
		if target.marked_by("Red-Eyed Killer", user):
			user.manually_advance_mission(7, 1)
		if user.marked_by("Little War Horn", user):
			user.manually_advance_mission(10, 1)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var death_trigger = Effect.trigger_effect(Trigger.always(one_cut_trigger), EffectType.Type.TICKING_TRIGGER, 5, "This character will die.")
		death_trigger.set_source(self)
		death_trigger.bypassing = true
		death_trigger.remove_on_death = false
		Character.add_hostile_effect(context, user, target, death_trigger)

func one_cut_trigger(context):
	if context['effect'].duration == 1:
		context['target'].instant_kill(context['owner'], self)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	if user.marked_by("Little War Horn", user):
		variations += behavior_single_target_hostile(context, 150)
	else:
		variations += behavior_hostile_single_require_mark(context, "Red-Eyed Killer", EffectType.Type.MARK, 150)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	if user.has_effect("Little War Horn", EffectType.Type.MARK, user):
		default_hostile_target_function(user, battle)
	else:
		default_hostile_target_function(user, battle, false, "Red-Eyed Killer")
