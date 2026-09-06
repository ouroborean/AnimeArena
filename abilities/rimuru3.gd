extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Rimuru deals 25 damage to the enemy team and 5 Affliction damage permanently"

func split_desc():
	return [
		"Deals 25 damage to the enemy team",
		["Affected enemies take 5 Affliction damage each turn for the rest of the game", Color.ORANGE_RED],
		["Permanently enhances Rimuru's Harmful skills and can only be used once", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 25, DamageType.Type.NORMAL)
		var damage = Effect.damage_effect(5, DamageType.Type.AFFLICTION, -1)
		damage.set_source(self)
		damage.remove_on_death = false
		damage.cleansable = false
		Character.add_hostile_effect(context, user, target, damage)
	var mark = Effect.mark(-1, "Gluttony will counter instead of Paralyzing.")
	mark.set_source(self)
	mark.cleansable = false
	Character.add_allied_effect(context, user, user, mark)
	var cost_increase = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM, ["Black Flame"])
	cost_increase.set_source(self)
	Character.add_allied_effect(context, user, user, cost_increase)
	var target_change = Effect.target_change_effect(TargetType.Type.ALL, -1, ["Black Flame"])
	target_change.set_source(self)
	Character.add_allied_effect(context, user, user, target_change)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Megiddo")

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 20, 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
