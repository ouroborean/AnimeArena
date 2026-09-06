extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 30 Piercing damage and removes 1 energy from target enemy, activating Nakagami's Armor",
		["If Nakagami's Armor is already active, steals 15 HP from target enemy (Bypassing)", Color.CADET_BLUE],
		["Nakagami's Armor: Erza's next skill has its Cooldown permanently reduced by 1 and Nakagami's Starlight costs 1 Random", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var equipped = user.call_unique("erza", "wearing_armor", ["Nakagami's Armor"])
	if not equipped:
		user.call_unique("erza", "requip_armor", ["nakagamis"])
	else:
		var cooldown_mod = Effect.cooldown_mod(-1, -1, ["Nakagami's Starlight"])
		cooldown_mod.set_source(self)
		cooldown_mod.stackable = true
		cooldown_mod.display_stacks = true
		cooldown_mod.stack_mag = true
		cooldown_mod.unique_render_id = 5
		Character.add_allied_effect(context, user, user, cooldown_mod)
	for target in user.targeter.targets:
		if not equipped:
			health_drain = false
			Character.resolve_damage(context, target, 30, DamageType.Type.PIERCING)
			target.lose_energy(user)
		else:
			health_drain = true
			Character.resolve_damage(context, target, 15, DamageType.Type.AFFLICTION)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var bypassing = false
	if user.call_unique("erza", "wearing_armor", ["Nakagami's Armor"]):
		bypassing = true
	default_hostile_target_function(user, battle, bypassing)
