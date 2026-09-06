extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For one turn, Ganta receives 5 additional damage from non-Affliction sources. During this time, Ganta cannot die and if an enemy deals new damage to Ganta, Ganta's skills will Bypass Invulnerability and deal 10 additional damage against them for 1 turn."

func split_desc():
	return [
		"Ganta takes +5 non-Affliction damage for 1 turn. During this time, he is Immortal",
		["Ganta will Bypass and gets +10 damage against enemies that damage while active", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var vuln_eff = Effect.vulnerability_effect(5, 2, [], [], [DamageType.Type.AFFLICTION])
	vuln_eff.set_source(self)
	
	var trigger_eff = Effect.trigger_effect(Trigger.always(reckless_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, 2, "If Ganta is damaged by an enemy, his skills will deal 10 more damage and Bypass against them for 1 turn.")
	trigger_eff.set_source(self)
	trigger_eff.ability_only = true
	var immortal = Effect.immortality_effect(2)
	immortal.set_source(self)
	
	Character.add_allied_effect(context, user, user, trigger_eff)
	Character.add_allied_effect(context, user, user, vuln_eff)
	Character.add_allied_effect(context, user, user, immortal)

func reckless_trigger(context):
	var attacker = context['owner']
	var user = context['effect'].user
	
	var vuln_eff = Effect.vulnerability_effect(10, 2, ["Ganta Gun", "Supersonic Ganta Gun", "Ganbare Gun"])
	vuln_eff.description = func (eff):
		return "Ganta's skills will deal " + str(eff.mag) + " more damage to this character."
	vuln_eff.set_source(self)
	
	var bypass_mark = Effect.mark(2, "Ganta's skills will Bypass Invulnerability when targeting this character.")
	bypass_mark.set_source(self)
	
	Character.add_hostile_effect(context, user, attacker, vuln_eff)
	Character.add_hostile_effect(context, user, attacker, bypass_mark)
	

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 15, 1.5)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
