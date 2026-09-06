extends Ability

var initial_damage = 30
var tick_damage = 15

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "One enemy takes 30 piercing damage and then takes 15 piercing damage per turn. During this time, their skills cost one more random energy, Witch Hunter is replaced by Figure-6 Hunter, and if the targeted enemy uses a new harmful skill, this effect will end. Channeled."

func split_desc():
	return [
		"Deals 30 piercing damage to target enemy",
		["They take 15 piercing damage per turn", Color.ORANGE_RED],
		["Their skills cost 1 more random energy", Color.ORANGE_RED],
		["Witch Hunter is replaced by Figure-6 Hunter", Color.AQUA],
		["Channeled", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var cancels = []

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, initial_damage, DamageType.Type.PIERCING)
		var cost_mod = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM)
		cost_mod.set_source(self)
		cost_mod.channel = true
		cancels.append(cost_mod)
		var damage_eff = Effect.damage_effect(tick_damage, DamageType.Type.PIERCING, -1)
		damage_eff.set_source(self)
		damage_eff.channel = true
		cancels.append(damage_eff)
		# No HARMFUL_USE_TRIGGER any more: Witch Hunter no longer ends when its target uses a
		# new Harmful skill, and gets no replacement enemy-side exit (owner ruling Q35) - the
		# channel cancel below is now the only way out. Figure-6 Hunter (maka5) used that
		# trigger as its victim lookup and is re-keyed onto this DAMAGE effect in the same
		# change; shipping half of it greys Figure-6 Hunter out forever with no error.
		Character.add_hostile_effect(context, user, target, damage_eff)
		Character.add_hostile_effect(context, user, target, cost_mod)
	
	var swap = Effect.ability_swap_effect(4, 2, user, -1)
	swap.set_source(self)
	swap.channel = true
	cancels.append(swap)
	var cancel_eff = Effect.channel_cancel(-1, ability_name, cancels)
	cancel_eff.set_source(self)
	
	Character.add_allied_effect(context, user, user, swap)
	Character.add_allied_effect(context, user, user, cancel_eff)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 50, 1.1)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
