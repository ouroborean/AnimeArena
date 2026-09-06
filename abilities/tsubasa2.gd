extends Ability

# One Thousand Tears. AoE burst + a NORMAL DoT ("One Thousand Tears" — Azure Slash keys on it)
# plus a DAMAGE_DEALT_TRIGGER watcher on each enemy: if that enemy damages one of Tsubasa's
# allies (not Tsubasa herself), Tsubasa taunts them for 1 turn.
#
# DoT duration: 5. Matches ban3 (Courechouse Assault), the shipped "immediate hit + damage_effect
# for 3 turns" pattern — immediate resolve_damage is the first tick, the dur-5 DAMAGE effect
# supplies the remaining player-turn ticks. The watcher shares that duration so the taunt window
# lines up with the DoT.

func describe(user):
	return "Deals 10 damage to all enemies and deals 10 more damage to them each turn for 3 turns. While affected, any enemy that damages one of Tsubasa's allies is Taunted for 1 turn."

func split_desc():
	return [
		"Deals 10 damage to all enemies, then 10 damage each turn for 3 turns",
		["While affected, an enemy that damages one of Tsubasa's allies is Taunted for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
		var dot = Effect.damage_effect(10, DamageType.Type.NORMAL, 5)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)
		var watch = Effect.trigger_effect(Trigger.always(tears_watch), EffectType.Type.DAMAGE_DEALT_TRIGGER, 5, "If this enemy damages one of Tsubasa's allies, Tsubasa Taunts them for 1 turn.")
		watch.set_source(self)
		Character.add_hostile_effect(context, user, target, watch)

func tears_watch(context):
	var enemy = context['owner']
	if enemy == null or enemy.dead or enemy.banished:
		return
	var tsubasa = context['effect'].user
	if tsubasa.dead or tsubasa.banished:
		return
	var victim = context['target']
	if victim == null:
		return
	if victim in tsubasa.team.characters and victim != tsubasa:
		var new_context = QueryContext.from_game_state(tsubasa, tsubasa.battle)
		var taunt = Effect.taunt_effect(2, tsubasa)
		taunt.set_source(self)
		Character.add_hostile_effect(new_context, tsubasa, enemy, taunt)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
