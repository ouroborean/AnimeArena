extends Ability
var base_damage = 40
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Misaka deals 40 damage to target enemy. This ability Bypasses Invulnerability and cannot be countered or reflected. For the rest of the game, Iron Sand and Railgun cost one additional random energy and have their base effects doubled. Using this ability will reset all her abilities to their original forms and prevent her from switching for the rest of the game."

func split_desc():
	return [
		"Deals 40 damage to target enemy, Bypassing Invulnerability",
		["Cannot be countered or reflected", Color.DIM_GRAY],
		["For the rest of the game, Iron Sand and Railgun have their base effects doubled but cost 1 more random energy", Color.CADET_BLUE],
		["Resets all her abilities to their original forms and locks switching for the rest of the game", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
	for swap in user.effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP):
		if swap.user == user:
			user.effects.erase_effect(swap)
	var lockout_mark = Effect.mark(-1, "Iron Sand and Railgun cannot swap to their alternate effects.")
	lockout_mark.set_source(self)
	var doubler = Effect.mark(-1, "Iron Sand and Railgun have double their base effect.")
	doubler.set_source(self)
	var cost_increase = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM, ["Iron Sand", "Railgun"])
	cost_increase.set_source(self)
	
	Character.add_allied_effect(context, user, user, lockout_mark)
	Character.add_allied_effect(context, user, user, doubler)
	Character.add_allied_effect(context, user, user, cost_increase)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 100, 1.0, true)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
