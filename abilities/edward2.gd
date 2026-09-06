extends Ability
var base_shield = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Grants target ally 20 Shield or target enemy 20 Nullify. For 1 turn, Destruction Alchemy costs 2 random energy, but deals 10 less damage."

func split_desc():
	return [
		"Gives target ally 20 Shield or target enemy 20 Nullify",
		"Destruction Alchemy costs 2 Random and -10 damage for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mod_shield = base_shield
	if user.marked_by("Battle Alchemy", user):
		mod_shield -= 10
		if not user.marked_by("Free Transmutation", user):
			var mark = Effect.mark(7, func (eff): return "Free Transmutation cannot grant Edward energy.")
			mark.set_source(user.moveset.base_abilities[4])
			Character.add_allied_effect(context, user, user, mark)
			user.gain_random_energy()
			user.manually_advance_mission(9, 1)
	
	for target in user.targeter.targets:
		if target in user.team.characters:
			var shield = Effect.shield_effect(mod_shield, -1)
			shield.set_source(self)
			Character.add_allied_effect(context, user, target, shield)
		else:
			var barrier = Effect.barrier_effect(mod_shield, -1)
			barrier.set_source(self)
			Character.add_hostile_effect(context, user, target, barrier)
	var cost_change = Effect.cost_change_effect({Energy.Type.RANDOM: 2}, 3, ["Destruction Alchemy"])
	cost_change.set_source(self)
	var damage_mod = Effect.damage_mod_effect(-10, 3, ["Destruction Alchemy"])
	damage_mod.set_source(self)
	Character.add_allied_effect(context, user, user, cost_change)
	Character.add_allied_effect(context, user, user, damage_mod)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context, 50)
	variations += behavior_single_target_hostile(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
