extends Ability
var base_damage = 20
var stack_threshold = 4

const PILE := "Death Beam"

# Last Emperor. Frieza's parting shot: killing him is not free if he spent the match tagging you.
#
# The trigger is installed on Frieza at battle start, permanent, `system` so the death-cleanse cannot
# strip it and `remove_on_death = false` so dying does not remove the very effect that dying is
# supposed to fire. check_death_triggers runs BEFORE cleanse_death_effects, so the Death Beam stacks
# — which ARE cleansable and belong to Frieza — are still readable here (minene5 precedent).
#
# Note that context['owner'] on a death trigger is the KILLER, not the holder; Frieza is eff.user.

func describe(user):
	return "When Frieza dies, he deals 20 damage to any enemy with 4 or more stacks of Death Beam."

func split_desc():
	return [
		["When Frieza dies, he deals 20 damage to every enemy with 4 or more stacks of Death Beam", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var death_trigger = Effect.trigger_effect(Trigger.always(on_frieza_death), EffectType.Type.ON_DEATH_TRIGGER, -1,
		"When Frieza dies, he deals 20 damage to any enemy with 4 or more stacks of Death Beam.")
	death_trigger.set_source(self)
	# system + remove_on_death = false is what lets this outlive the death that fires it (the death
	# cleanse spares a system effect only when both hold). display_system puts it back on screen:
	# "do not take the kill carelessly at 4+ stacks" is a read the opponent is entitled to, and the
	# passive's text is public anyway. See Effect.display_system.
	death_trigger.system = true
	death_trigger.remove_on_death = false
	death_trigger.display_system = true
	Character.add_allied_effect(context, user, user, death_trigger)

func on_frieza_death(context):
	var eff = context['effect']
	var frieza = eff.user
	# Not gated on frieza.dead — it is already true by the time a death trigger runs.
	if frieza == null or not is_instance_valid(frieza):
		return
	var battle = frieza.battle
	if battle == null or not is_instance_valid(battle):
		return
	var death_context = QueryContext.from_game_state(frieza, battle)
	for enemy in battle.all_characters():
		if enemy in frieza.team.characters:
			continue
		if enemy.dead or enemy.banished:
			continue
		var mark = enemy.has_effect(PILE, EffectType.Type.MARK, frieza)
		if mark == null or mark.stack_count() < stack_threshold:
			continue
		Character.resolve_effect_damage(death_context, eff, enemy, base_damage, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func target(user, battle):
	default_self_target_function(user, battle)
