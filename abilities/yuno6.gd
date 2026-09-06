extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 2 turns, all enemies will be Shattered and take 10 piercing damage per turn. While this is active, Spirit of Zephyr has its cost reduced by 2 blue energy"

func split_desc():
	return [
		"Deals 10 Piercing damage to all enemies per turn for 2 turns",
		["All enemies are Shattered for 2 turns", Color.ORANGE_RED],
		["While active, Spirit of Zephyr costs 2 less blue energy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var shatter = Effect.def_negate(3)
		shatter.set_source(self)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.PIERCING, 3)
		damage_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, shatter)
		Character.add_hostile_effect(context, user, target, damage_eff)
	var cost_mod = Effect.cost_mod_effect(-2, 3, Energy.Type.BLUE, ["Spirit of Zephyr"])
	cost_mod.set_source(self)
	Character.add_allied_effect(context, user, user, cost_mod)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 25, 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
