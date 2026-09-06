extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Every turn, Boruto's 3rd skill swaps to a new random Rasengan skill.",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var tick = Effect.trigger_effect(Trigger.always(ticking_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Boruto will swap to a new random Rasengan.")
	tick.set_source(self)
	Character.add_allied_effect(context, user, user, tick)

func ticking_trigger(context):
	var abilities = user.moveset.get_active_abilities(user)
	var rasengans = ["Vanishing Rasengan", "Compression Rasengan", "Wind Release: Rasengan"]
	rasengans.erase(abilities[2].ability_name)
	var chosen_index = user.battle.roll(0, 1)
	var chosen_rasengan = rasengans[chosen_index]
	
	match chosen_rasengan:
		"Vanishing Rasengan":
			pass
		"Compression Rasengan":
			var swap = Effect.ability_swap_effect(6, 2, user, 3)
			swap.set_source(self)
			Character.add_allied_effect(context, user, user, swap)
		"Wind Release: Rasengan":
			var swap = Effect.ability_swap_effect(5, 2, user, 3)
			swap.set_source(self)
			Character.add_allied_effect(context, user, user, swap)
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
