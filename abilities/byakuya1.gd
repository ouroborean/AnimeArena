extends Ability
var base_damage = 10
var tick_damage = 10
var modded_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Byakuya deals 10 Piercing damage to target enemy each turn for the rest of the game. While active, this skill costs 1 Red energy and can be used to change its target or deal 20 Piercing damage to the currently affected target. Bypasses Invulnerability."

func split_desc():
	return [
		"Permanently deals 10 Piercing damage to target enemy each turn (Bypasses)",
		"While active, can be used for 1 Red to change targets or deal 20 Piercing damage to the current target"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var used_mark = user.effects.has_effect("Scatter, Senbonzakura", EffectType.Type.COST_CHANGE, user)
	
	#If Byakuya is currently controlling Scatter
	if used_mark:
		for target in user.targeter.targets:
			#If the target currently has Scatter
			if target.has_effect("Scatter, Senbonzakura", EffectType.Type.DAMAGE, user):
				#Deal the instant hit
				Character.resolve_damage(context, target, modded_damage, DamageType.Type.PIERCING)
			#If the target does not have Scatter
			else:
				#Find the character with Scatter and remove it
				for character in context['enemy_team'].characters:
					if character.has_effect("Scatter, Senbonzakura", EffectType.Type.DAMAGE, user):
						character.effects.remove_effect("Scatter, Senbonzakura", EffectType.Type.DAMAGE, user)
				#Apply Scatter to the new target
				Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
				var scatter_eff = Effect.damage_effect(tick_damage, DamageType.Type.PIERCING, -1)
				scatter_eff.set_source(self)
				Character.add_hostile_effect(context, user, target, scatter_eff)
	#If he is not
	else:
		for target in user.targeter.targets:
			#Add the effect to the target
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
			var scatter_eff = Effect.damage_effect(tick_damage, DamageType.Type.PIERCING, -1)
			scatter_eff.set_source(self)
			Character.add_hostile_effect(context, user, target, scatter_eff)
	#And a permanent cost change effect that we can check for to see if Byakuya is controlling scatter
	var cost_change = Effect.cost_change_effect({Energy.Type.RED: 1}, -1, ["Scatter, Senbonzakura"])
	cost_change.set_source(self)
	Character.add_allied_effect(context, user, user, cost_change)
			

		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	if target_type() == TargetType.Type.SINGLE:
		variations += behavior_single_target_damage(context, 10, 1.0, true)
	else:
		variations += behavior_hostile_aoe_damage(context, 25, 1.0, true)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
