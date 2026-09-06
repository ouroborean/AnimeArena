extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Whenever Natsu is targeted by a new harmful Strategic skill or deals new Affliction damage, he heals 5 HP and deals 5 more Affliction damage with all his skills for 3 turns. This effect stacks."

func split_desc():
	return [
		"Whenever Natsu receives a Harmful Strategic skill or deals Affliction damage, he heals 5 HP and deals +5 Affliction damage for 3 turns (Stacks)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var receive_trigger = Effect.trigger_effect(Trigger.always(receive_fire_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, -1, "If Natsu is targeted by a new harmful Strategic Skill, he heals 5 HP and deals 5 more Affliction damage with all his skills for 3 turns.")
	receive_trigger.set_source(self)
	var deal_trigger = Effect.trigger_effect(Trigger.always(dealt_fire_trigger), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, "If Natsu deals new Affliction damage, he heals 5 HP and deals 5 more Affliction damage with his skills for 3 turns.")
	deal_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, receive_trigger)
	Character.add_allied_effect(context, user, user, deal_trigger)


func receive_fire_trigger(context):
	if not context['source'].classes["Strategic"]:
		return
	Character.resolve_effect_healing(context, context['effect'], context['target'], 5)
	var damage_mod_effect = Effect.damage_mod_effect(5, 5, [], [DamageType.Type.AFFLICTION])
	damage_mod_effect.set_source(self)
	damage_mod_effect.unique_render_id = int(Time.get_ticks_msec())
	Character.add_allied_effect(context, context['target'], context['target'], damage_mod_effect)

func dealt_fire_trigger(context):
	if not (context['source'] is Ability) or not context['damage_type'] == DamageType.Type.AFFLICTION:
		return
	Character.resolve_effect_healing(context, context['effect'], context['owner'], 5)
	var damage_mod_effect = Effect.damage_mod_effect(5, 5, [], [DamageType.Type.AFFLICTION])
	damage_mod_effect.set_source(self)
	damage_mod_effect.unique_render_id = int(Time.get_ticks_msec())
	Character.add_allied_effect(context, context['owner'], context['owner'], damage_mod_effect)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
