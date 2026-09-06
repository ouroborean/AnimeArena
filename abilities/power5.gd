extends Ability

func describe(user):
	return "Whenever an enemy receives Bleed damage, Power heals for half that amount."

func split_desc():
	return [
		["Whenever an enemy takes Bleed damage, Power heals for half that amount", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Seed a persistent receive-trigger on every enemy. It survives Power's death (system) and each
	# enemy's death/revive (cleansable is false because dur == -1), so it re-activates on revive.
	for enemy in context['enemy_team'].characters:
		var trig = Effect.trigger_effect(Trigger.always(fiend_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "When this character takes Bleed damage, Power heals for half.")
		trig.set_source(self)
		trig.invisible = true
		trig.ability_only = false   # must stay false so DoT (effect) Bleed ticks fire it
		trig.system = true
		trig.remove_on_death = false
		Character.add_hostile_effect(context, user, enemy, trig)

func fiend_trigger(context):
	if context.damage_type != DamageType.Type.BLEED:
		return
	var power = context['effect'].user
	Character.resolve_effect_healing(context, context['effect'], power, int(context['value'] / 2.0))

func extra_usable(user):
	return false

func custom_behavior(context):
	return []

func target(user, battle):
	pass
