extends Ability
var base_power = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Applies 20 Nullify to one enemy. If Nullify from Psychokinetic Bind exists on a different enemy, Tatsumaki will slam them together. If there is an enemy between them, this deals damage to them equal to their total Nullify and stuns the enemy for 2 turns. If not, their total Nullify is split between affected enemies and they are both stunned for 1 turn. This removes all Nullify from affected targets and bypasses invulnerability."

func split_desc():
	return [
		["Applies 20 Nullify to one enemy", Color.ORANGE_RED],
		"If Psychokinetic Bind's Nullify exists on a different enemy, slams them together",
		"Enemy between them takes damage equal to their total Nullify",
		["That enemy is stunned for 2 turns", Color.ORANGE_RED],
		"Otherwise, total Nullify is split between both enemies as damage",
		["Both enemies are stunned for 1 turn", Color.ORANGE_RED],
		["Removes all Nullify from affected targets and bypasses invulnerability", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var barrier_eff = Effect.barrier_effect(20, -1)
		barrier_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, barrier_eff, true)
	var idx1 = -1
	var idx2 = -1
	var total_barrier = 0
	for i in range(3):
		var character = context['enemy_team'].characters[i]
		if character.has_effect("Psychokinetic Bind", EffectType.Type.BARRIER, user):
			if idx1 == -1:
				idx1 = i
				total_barrier += character.has_effect("Psychokinetic Bind", EffectType.Type.BARRIER, user).mag
			elif idx2 == -1:
				idx2 = i
				total_barrier += character.has_effect("Psychokinetic Bind", EffectType.Type.BARRIER, user).mag
				character.effects.full_remove_effect_by_name("Psychokinetic Bind")
				context['enemy_team'].characters[idx1].effects.full_remove_effect_by_name("Psychokinetic Bind")
	if idx1 == 0 and idx2 == 2 and not (context['enemy_team'].characters[1].dead or context['enemy_team'].characters[1].banished):
		Character.resolve_damage(context, context['enemy_team'].characters[1], total_barrier, DamageType.Type.NORMAL)
		var stun = Effect.stun_effect(4)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, context['enemy_team'].characters[1], stun, true)
	elif idx1 != -1 and idx2 != -1:
		var split_damage = total_barrier / 2
		Character.resolve_damage(context, context['enemy_team'].characters[idx1], split_damage, DamageType.Type.NORMAL)
		var stun = Effect.stun_effect(2)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, context['enemy_team'].characters[idx1], stun, true)
		Character.resolve_damage(context, context['enemy_team'].characters[idx2], split_damage, DamageType.Type.NORMAL)
		var stun2 = Effect.stun_effect(2)
		stun2.set_source(self)
		Character.add_hostile_effect(context, user, context['enemy_team'].characters[idx2], stun2, true)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_spread_out(context, "Psychokinetic Bind", EffectType.Type.BARRIER, 25, 1.2, true)
	
	return variations
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
