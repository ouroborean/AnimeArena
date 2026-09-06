extends Ability

var base_damage = 15

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Lucy deals 15 damage to all enemies and grants her team 10 points of damage reduction for one turn."

func split_desc():
	return [
		"Deals 15 damage to all enemies",
		["Lucy's team gains 10 Damage Reduction for 2 turns", Color.CADET_BLUE],
		["During Gemini, it lasts 3 turns instead and the damage repeats each turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Never re-derive "is this the Gemini cast?" from `duration`. The old code
	# tested `duration == 4` for it; now that the BASE is 4, that test would be
	# true for every cast and hand the Gemini damage repeat out for free.
	var geminied = user.marked_by("Gemini", user)
	# 2 turns == duration 4, 3 turns == duration 6 (durations tick at the end of
	# every player's turn).
	var duration = 6 if geminied else 4

	for target in user.targeter.targets:
		if not target in context['enemy_team'].characters:
			var dr = Effect.damage_reduction_effect(10, duration)
			dr.set_source(self)
			Character.add_allied_effect(context, user, target, dr)
		else:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
			if geminied:
				# 3 turns of damage counting the cast turn: the hit above is
				# instance 1, so the ticker runs 2N-1 == 5 for the other two.
				var dmg_eff = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 5)
				dmg_eff.set_source(self)
				Character.add_hostile_effect(context, user, target, dmg_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 50)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
