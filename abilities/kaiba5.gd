extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 2 turns, all enemies have their damage capped to 15 and their invisible effects become visible (Invisible)",
		["When this effect expires, all enemies take damage equal to the amount of damage reduced by this effect (Bypasses)", Color.DIM_GRAY],
		["Swaps to Enemy Controller", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var damage_cap = Effect.damage_cap(15, 4)
		damage_cap.set_source(self)
		damage_cap.invisible = true
		Character.add_hostile_effect(context, user, target, damage_cap)
		var mark = Effect.mark(4, "This character's invisible effects will become visible.")
		mark.set_source(self)
		mark.invisible = true
		Character.add_hostile_effect(context, user, target, mark)
	var sub_mark = Effect.mark(5, "Enemies will take damage equal to the total damage absorbed by Crush Card Virus.")
	sub_mark.invisible = true
	sub_mark.wrapup_func = crush_card_timeout
	sub_mark.display_mag = true
	sub_mark.set_source(self)
	Character.add_allied_effect(context, user, user, sub_mark)
	if user.has_effect("Enemy Controller", EffectType.Type.ABILITY_SWAP):
		user.effects.remove_effect("Enemy Controller", EffectType.Type.ABILITY_SWAP)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func crush_card_timeout(context):
	for character in user.battle.all_characters():
		if not (character in user.team.characters) and not character.dead and not character.banished:
			var damage = context.effect.mag
			if damage > 0:
				Character.resolve_effect_damage(context, context.effect, character, damage, DamageType.Type.NORMAL)
				

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 20)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
