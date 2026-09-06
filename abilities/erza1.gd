extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy for 3 turns and activates Clear Heart Clothing",
		["If Clear Heart Clothing is already active, deals 25 Piercing damage to target enemy (Bypassing)", Color.CADET_BLUE],
		["Clear Heart Clothing: Erza ignores stuns and counter effects and Titania's Rampage costs 1 Random", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var equipped = user.call_unique("erza", "wearing_armor", ["Clear Heart Clothing"])
	if user.call_unique("erza", "wearing_armor", ["Nakagami's Armor"]):
		var cooldown_mod = Effect.cooldown_mod(-1, -1, ["Titania's Rampage"])
		cooldown_mod.set_source(self)
		cooldown_mod.stackable = true
		cooldown_mod.stack_mag = true
		cooldown_mod.display_stacks = true
		cooldown_mod.unique_render_id = 5
		Character.add_allied_effect(context, user, user, cooldown_mod)
	if not equipped:
		user.call_unique("erza", "requip_armor", ["clear_heart"])
	for target in user.targeter.targets:
		if not equipped:
			Character.resolve_damage(context, target, 15, DamageType.Type.PIERCING)
			var damage = Effect.damage_effect(15, DamageType.Type.PIERCING, 5)
			damage.set_source(self)
			Character.add_hostile_effect(context, user, target, damage)
		else:
			Character.resolve_damage(context, target, 25, DamageType.Type.PIERCING)
	
		
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
	if user.call_unique("erza", "wearing_armor", ["Clear Heart Clothing"]):
		bypassing = true
	default_hostile_target_function(user, battle, bypassing)
