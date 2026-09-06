extends Ability
var base_healing = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "One ally permanently heals 10 health per turn. Once active, Saber can reactivate this skill to reflect all new harmful effects received by that ally to herself for one turn."

func split_desc():
	return [
		["One ally permanently heals 10 health per turn", Color.CADET_BLUE],
		["While active, reactivate to reflect new harmful effects on that ally to Saber for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target.has_effect("Avalon", EffectType.Type.HEALING, user):
			var reflect = Effect.reflect_effect(Trigger.always(reflect_trigger), EffectType.Type.REFLECT_RECEIVE, user, 2, "Harmful skills will be reflected to Saber", ["Harmful"])
			reflect.set_source(self)
			Character.add_allied_effect(context, user, target, reflect)
		else:
			Character.resolve_healing(context, target, base_healing)
			var healing = Effect.healing_effect(base_healing, -1)
			healing.set_source(self)
			Character.add_allied_effect(context, user, target, healing)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var user = context['owner']
	var allies = context['owner'].team.characters
	for ally in allies:
		if ally.has_effect("Avalon", EffectType.Type.HEALING, user):
			variations.append([135, [user, self, [ally]]])
	if len(variations) == 0:
		variations += behavior_single_target_helpful(context, 70)
	
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for ally in user.team.characters:
		if ally.has_effect("Avalon", EffectType.Type.HEALING, user):
			check_allied_target(user, ally, context)
			return
	default_allied_target_function(user, battle)
