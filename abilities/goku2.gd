extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Goku gains 10 points of damage reduction and takes 5 affliction damage every turn for 3 turns. While active, this swaps to Kaioken Rush and Kamehameha deals 10 additional damage, becomes piercing, and deals 5 affliction damage to Goku."

func split_desc():
	return [
		"Goku gains 10 Damage Reduction and takes 5 Affliction damage for 3 turns",
		"While active, Kamehameha gets +10 damage, becomes Piercing, and deals 5 Affliction damage to Goku",
		["Swaps to Kaioken Rush", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dr = Effect.damage_reduction_effect(10, 6)
	dr.set_source(self)
	
	var damage_eff = Effect.damage_effect(5, DamageType.Type.AFFLICTION, 5, false)
	damage_eff.set_source(self)
	Character.add_allied_effect(context, user, user, damage_eff)
	Character.resolve_effect_damage(context, damage_eff, user, 5, DamageType.Type.AFFLICTION)
	
	var swap = Effect.ability_swap_effect(4, 1, user, 5)
	swap.set_source(self)
	var damage_mod = Effect.damage_mod_effect(10, 5, ["Kamehameha"])
	damage_mod.set_source(self)
	var mark = Effect.mark(5, func (eff): return "Kamehameha deals Piercing damage and deals 5 Affliction damage to Goku on use.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, damage_mod)
	Character.add_allied_effect(context, user, user, swap)
	Character.add_allied_effect(context, user, user, dr)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 75, 0.7)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
