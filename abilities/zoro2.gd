extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, Zoro will ignore enemy stun effects and his skills will deal 5 additional damage permanently (stacks)."

func split_desc():
	return [
		"Zoro permanently deals 5 more damage (stacks)",
		["For 1 turn, Zoro ignores Harmful Stun effects", Color.CADET_BLUE],
		["Swaps with One-Sword Style: Lion Strike for 1 turn", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var ign_eff = Effect.ignore_effect_effect(3, EffectType.Type.STUN)
	ign_eff.set_source(self)
	var buff_eff = Effect.damage_mod_effect(5, -1)
	buff_eff.set_source(self)
	buff_eff.stackable = true
	buff_eff.stack_mag = true
	buff_eff.display_stacks = true
	var portrait = Effect.portrait_change_effect(0, 3)
	portrait.set_source(self)
	Character.add_allied_effect(context, user, user, portrait)
	Character.add_allied_effect(context, user, user, ign_eff)
	Character.add_allied_effect(context, user, user, buff_eff)
	
	var swap = Effect.ability_swap_effect(4, 1, user, 3)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations.append([250, [user, self, []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
	
