extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Stuns all enemies' Strategic skills for 1 turn. For 1 turn this swaps to Hauser Impact."

func split_desc():
	return [
		"Stuns all enemies' Strategic skills for 1 turn",
		["Swaps to Hauser Impact for 1 turn", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun_eff = Effect.stun_effect(2, ["Strategic"])
		stun_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, stun_eff)
	
	var swap_eff = Effect.ability_swap_effect(4, 2, user, 3)
	swap_eff.set_source(self)
	Character.add_allied_effect(context, user, user, swap_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var bakugo = context['owner']
	var targets = []
	var mod = 0
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished):
			targets.append(character)
			if not character.ignoring_effect_type(EffectType.Type.STUN):
				mod += 50
	if len(targets) == 0:
		variations.append([0, [user, "PASS", []]])
	else:
		variations.append([150 + mod, [bakugo, self, targets]])
	
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
