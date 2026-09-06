extends Ability
var base_damage = 45
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 45 Affliction damage to one enemy and caps their health."

func split_desc():
	return [
		"Deals 45 Affliction damage to target enemy",
		"Affected enemies have their max HP set to their current HP"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	if user.has_effect("Defensive Alchemy", EffectType.Type.COST_CHANGE, user) and not user.marked_by("Free Transmutation", user):
		var mark = Effect.mark(7, func (eff): return "Free Transmutation cannot grant Edward energy.")
		mark.set_source(user.moveset.base_abilities[4])
		Character.add_allied_effect(context, user, user, mark)
		user.gain_random_energy()
		user.manually_advance_mission(9, 1)
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
		target.cap_health(context, user, -1, self)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75, 0.9)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
