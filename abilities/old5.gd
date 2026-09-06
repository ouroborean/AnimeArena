extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Once Sayaka has received 80 damage, her Strategic skills are permanently stunned and Hero Slash is replaced by Enraged Slash."

func split_desc():
	return [
		"Once Sayaka receives 80 total damage, her Strategic skills are permanently Stunned",
		["Replaces Hero Slash with Enraged Slash", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger_desc = func (eff):
		var total_eff = eff.user.effects.has_effect("Berserk", EffectType.Type.DAMAGE_RECEIVE_TRIGGER, user)
		return "Sayaka has received " + str(total_eff.mag) + " damage."
	
	var trigger_eff = Effect.trigger_effect(Trigger.always(berserk_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, trigger_desc)
	trigger_eff.set_source(self)
	
	var mark_desc = func (eff):
		return "Once Sayaka has received 80 damage, her Strategic skills are permanently stunned and Hero Slash is replaced by Enraged Slash."
	var mark_eff = Effect.mark(-1, mark_desc)
	mark_eff.set_source(self)
	
	Character.add_allied_effect(context, user, user, mark_eff)
	Character.add_allied_effect(context, user, user, trigger_eff)

func berserk_trigger(context):
	context['effect'].mag += context['value']
	if context['effect'].mag >= 80:
		context['effect'].target.effects.full_remove_effect_by_name("Berserk")
		var strat_stun = Effect.stun_effect(-1, ["Strategic"])
		strat_stun.set_source(self)
		var abi_swap = Effect.ability_swap_effect(5, 0, user, -1)
		abi_swap.set_source(self)
		Character.add_allied_effect(context, user, user, strat_stun)
		Character.add_allied_effect(context, user, user, abi_swap)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	pass
