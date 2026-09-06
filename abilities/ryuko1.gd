extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ryuko deals 20 damage to one enemy and caps their damage at 20 for one turn. If this skill kills an enemy, Ryuko will heal 10 health and permanently deal 10 additional damage."

func split_desc():
	return [
		"Deals 20 damage to one enemy",
		["Caps target's damage at 10 for 1 turn", Color.ORANGE_RED],
		["On kill: Ryuko heals 10 health and permanently deals 10 additional damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		#dur 2 == 1 turn and is already correct; only the cap literal moves 20 -> 10.
		var damage_cap = Effect.damage_cap(10, 2)
		damage_cap.set_source(self)
		Character.add_hostile_effect(context, user, target, damage_cap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func on_kill(target):
	var context = QueryContext.from_game_state(user, user.battle)
	Character.resolve_healing(context, user, 10)
	var boost = Effect.damage_mod_effect(10, -1)
	boost.set_source(self)
	Character.add_allied_effect(context, user, user, boost)

func custom_behavior(context):
	var variations = []
	if target_type() == TargetType.Type.SINGLE:
		variations += behavior_single_target_damage(context, 35)
	else:
		variations += behavior_hostile_aoe_damage(context, 15)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
