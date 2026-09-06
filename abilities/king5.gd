extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 damage to all enemies for 2 turns. For 1 turn, if any character deals damage to affected enemies, they will heal all their living allies for 5 health."

func split_desc():
	return [
		"Heals King's allies 15 HP and makes them Invulnerable for 1 turn",
		["If they do not use a new skill on the following turn, this effect triggers again.", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_healing(context, target, 15)
		var invuln = Effect.invuln_effect(2)
		invuln.set_source(self)
		Character.add_allied_effect(context, user, target, invuln)
		var trigger = Effect.trigger_effect(Trigger.always(ticking), EffectType.Type.TICKING_TRIGGER, 3, "If this character does not use a skill, they will become Invulnerable for 1 turn and heal 15 HP.")
		trigger.set_source(self)
		Character.add_allied_effect(context, user, target, trigger)

func ticking(context):
	var ally = context.target
	if not ally.acted:
		var invuln = Effect.invuln_effect(2)
		invuln.set_source(self)
		Character.add_allied_effect(context, user, ally, invuln)
		Character.resolve_effect_healing(context, context.effect, ally, 15)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_helpful_aoe_aid(context)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
