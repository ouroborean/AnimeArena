extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 damage to one enemy. For 1 turn, Shiro's other damaging skills will make her ignore stun and silence effects for 2 turns and deal 10 additional damage."

func split_desc():
	return [
		"Deals 15 damage to one enemy",
		["For 1 turn, Shiro's other damaging skills make her ignore stun and silence effects for 2 turns and deal 10 additional damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var rampage_boosted = Condition.has_effect(user, "Shiro Rampage", EffectType.Type.MARK, user)
	var mascot_boosted = Condition.has_effect(user, "Mascot Rush", EffectType.Type.MARK, user)
	var kick_boosted = Condition.has_effect(user, "Shiro Kick", EffectType.Type.MARK, user)
	var eff_duration = 3
	if user.path_name == "shiro":
		eff_duration = user.moveset.base_abilities[4].get_fever_duration()
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		if kick_boosted.satisfied(context):
			var stun = Effect.stun_effect(2, [], ["Strategic"])
			stun.set_source(user.moveset.base_abilities[0])
			Character.add_hostile_effect(context, user, target, stun)
		if mascot_boosted.satisfied(context):
			var silence = Effect.silence_effect(2)
			silence.set_source(user.moveset.base_abilities[1])
			Character.add_hostile_effect(context, user, target, silence)
	
	var boost = Effect.damage_mod_effect(10, eff_duration, ["Shiro Kick", "Mascot Rush"])
	boost.set_source(self)
	var mark = Effect.mark(eff_duration, "Shiro Kick and Mascot Rush will make Shiro ignore stun and silence effects for 1 turn.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, boost)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var rampage_boosted = Condition.has_effect(user, "Shiro Rampage", EffectType.Type.MARK, user)
	if rampage_boosted:
		variations.append([0, [user, "PASS", []]])
	else:
		variations += behavior_single_target_damage(context, 35)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
