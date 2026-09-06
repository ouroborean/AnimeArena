extends Ability
var base_damage = 35
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 35 affliction damage to an enemy and reduces their non-Affliction damage by 15 for 1 turn. For 1 turn, this skill will deal 15 affliction damage and cost a single random, but it can only be used on the previous target of this skill."

func split_desc():
	return [
		"Deals 35 Affliction damage to target enemy and reduces their non-Affliction damage by 15 for 1 turn",
		["The following turn, this skill deals 15 Affliction damage and costs 1 Random energy, but can only affect the previous target", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mod_damage = base_damage
	if user.marked_by("Fire Dragon's Roar", user):
		mod_damage = 15
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, mod_damage, DamageType.Type.AFFLICTION)
		var damage_mod = Effect.damage_mod_effect(-15, 2, [], [], [DamageType.Type.AFFLICTION])
		damage_mod.set_source(self)
		var enemy_mark = Effect.mark(3, "This character can be targeted by Fire Dragon's Roar.")
		enemy_mark.set_source(self)
		Character.add_hostile_effect(context, user, target, damage_mod)
		Character.add_hostile_effect(context, user, target, enemy_mark)
	var cost_mod_eff = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, 3, ["Fire Dragon's Roar"])
	cost_mod_eff.set_source(self)
	var mark = Effect.mark(3, "Fire Dragon's Roar will deal 15 affliction damage and can only target characters marked by it.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, cost_mod_eff)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 85)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	if user.marked_by("Fire Dragon's Roar", user):
		for character in battle.all_characters():
			if character.marked_by("Fire Dragon's Roar", user):
				check_hostile_target(user, character, context)
	else:
		default_hostile_target_function(user, battle)
