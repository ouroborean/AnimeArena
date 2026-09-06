extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Koro-Sensei targets another ally for 1 turn. During this time, if they receive a new Harmful skill, they will have all enemy effects removed from them and heal 25 HP. The turn after this effect is triggered, Pitch Black has no cost."

func split_desc():
	return [
		"Protects another ally for 1 turn",
		["If they receive a new Harmful skill, all enemy effects are removed from them and they heal 25 HP", Color.CADET_BLUE],
		["The turn after this triggers, Pitch Black costs nothing", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trigger = Effect.trigger_effect(Trigger.always(shed_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 2, "If this character receives a new Harmful skill, they will have all enemy effects removed from them and heal 25 HP.")
		trigger.set_source(self)
		trigger.invisible = true
		trigger.wrapup_func = default_counter_timeout
		Character.add_allied_effect(context, user, target, trigger)


func shed_trigger(context):
	var koro = context['effect'].user
	var ally = context['effect'].target
	user.manually_advance_mission(9, 1)
	ally.effects.cleanse_all_enemy_effects(ally)
	Character.resolve_effect_healing(context, context['effect'], ally, 25)
	
	var cost_mod = Effect.cost_change_effect({}, 2, ["Pitch Black"])
	cost_mod.set_source(self)
	Character.add_allied_effect(context, koro, koro, cost_mod)
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_heal(context, 35, 1.3)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
