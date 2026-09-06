extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Noelle targets all enemies for 2 turns, increasing the costs of their skills by one random. This effect is removed on the next skill used by each affected target."

func split_desc():
	return [
		["For 2 turns, all enemies' skills cost 1 more random energy", Color.ORANGE_RED],
		["The effect is removed by the next skill each affected enemy uses", Color.DIM_GRAY],
		["During Valkyrie Dress it lasts twice as long and is not removed by their skills", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var effect_duration = 4
	if user.marked_by("Saint Valkyrie Dress", user):
		effect_duration += 4
	
	for target in user.targeter.targets:
		var cost_mod = Effect.cost_mod_effect(1, effect_duration, Energy.Type.RANDOM)
		cost_mod.set_source(self)
		var trigger_eff = Effect.trigger_effect(Trigger.always(remove_trigger), EffectType.Type.ACTION_USE_TRIGGER, effect_duration, "If this character uses a new skill, this effect will end.")
		trigger_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, trigger_eff)
		Character.add_hostile_effect(context, user, target, cost_mod)
		

func remove_trigger(context):
	var enemy = context['owner']
	var noelle = context['effect'].user
	noelle.manually_advance_mission(10, 1)
	# Valkyrie Dress gates the trigger's BODY, never its application: noelle1:20 and
	# noelle5:20 both find the Cradle by probing for this very ACTION_USE_TRIGGER, so
	# skipping the apply would leave their consume branches unable to see the Cradle at all.
	# Bailing here leaves the trigger in place, and it re-fires on the target's next skill.
	if noelle.marked_by("Saint Valkyrie Dress", noelle):
		return
	enemy.effects.full_remove_effect_by_name("Sea Dragon's Cradle", noelle)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 125)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
