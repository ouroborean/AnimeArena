extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 4 turns, Tokito gives his team 20% dodge chance, doubled if the attacking enemy is Blinded",
		["This effect increases by 10% each turn", Color.DIM_GRAY],
		["Swaps to Fifth Form: Sea of Clouds and Haze and ends if Tokito dies", Color.AQUAMARINE]
	]
func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# Durations here are already correct and deliberately untouched:
		# dodge 8 == 4 turns, ticker 7 == the 3 increases inside that window.
		var dodge = Effect.dodge_effect(20, 8)
		dodge.display_mag = true
		dodge.set_source(self)
		# Effect.dodge_effect's stock description closes over the CONSTRUCTOR
		# magnitude, so a mutated dodge would advertise 20% forever. Read eff.mag
		# instead so the tooltip tracks the per-turn increase.
		dodge.description = func (eff):
			return "This character has a " + str(eff.mag) + "% chance to fully dodge new harmful skills."

		var ticking = Effect.trigger_effect(Trigger.always(ticking_trigger), EffectType.Type.TICKING_TRIGGER, 7, "This dodge chance increases by 10% each turn.")
		ticking.set_source(self)
		Character.add_allied_effect(context, user, target, dodge)
		Character.add_allied_effect(context, user, target, ticking)
		
	var swap = Effect.ability_swap_effect(4, 2, user, 7)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)


func ticking_trigger(context):
	var dodge_owner = context['target']
	
	var effect = dodge_owner.has_effect("Seventh Form: Obscuring Clouds", EffectType.Type.DODGE_CHANCE)
	if effect:
		effect.mag += 10
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_helpful_aoe_aid(context, 60)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here

	default_allied_target_function(user, battle)
