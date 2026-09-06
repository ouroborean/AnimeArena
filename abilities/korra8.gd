extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 damage to one enemy and stuns their non-Mental skills for 2 turns. Cannot be used while active."

func split_desc():
	return [
		"Deals 15 damage to target enemy each turn for 2 turns",
		"Stuns their non-Mental skills for 2 turns",
		["Cannot be used while active", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var cancels = []
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 5)
		damage_eff.set_source(self)
		cancels.append(damage_eff)
		var stun = Effect.stun_effect(4, [], ["Mental"])
		stun.set_source(self)
		cancels.append(stun)
		Character.add_hostile_effect(context, user, target, damage_eff)
		Character.add_hostile_effect(context, user, target, stun)
	var cancel_eff = Effect.control_cancel(3, ability_name, cancels)
	cancel_eff.set_source(self)
	
	Character.add_allied_effect(context, user, user, cancel_eff)
		
func extra_usable(user):
	for character in user.battle.all_characters():
		if not character in user.team.characters and character.effects.has_effect("Water Arm Stun", EffectType.Type.DAMAGE, user) != null:
			return false
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_stun(context, 50)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
