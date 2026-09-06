extends Ability

# X-Slash — the swapped-in replacement for Inverted Spear of Heaven. It can only target an enemy
# that Toji has damaged with 3 of his different skills (tracked in the character's `xslash_hits`,
# installed by character/toji.gd's startup). Using it plants an END_OF_TURN_TRIGGER on that enemy:
# at the end of their next turn, if Toji is still alive, they are executed. Firing at the enemy's
# own turn-end gives them one turn to try to kill Toji first.

func describe(user):
	return ""

func split_desc():
	return [
		"Marks an enemy that Toji has damaged with 3 unique skills",
		"At the end of that enemy's next turn, if Toji is still alive, they are executed",
		["X-Slash replaces Inverted Spear of Heaven once an enemy can be targeted with it", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var doom = Effect.trigger_effect(Trigger.always(xslash_execute), EffectType.Type.END_OF_TURN_TRIGGER, -1, "X-Slash will execute this character at the end of their turn unless Toji has fallen.")
		doom.set_source(self)
		doom.cleansable = true
		Character.add_hostile_effect(context, user, target, doom)

func xslash_execute(context):
	var eff = context['effect']
	var toji = context['owner']
	var enemy = context['target']
	# One-shot: remove ourselves so we can never fire twice.
	enemy.effects.erase_effect(eff)
	if toji == null or toji.dead or toji.banished:
		return
	if enemy == null or enemy.dead or enemy.banished:
		return
	enemy.instant_kill(toji, self)

# A living enemy Toji has damaged with 3 distinct skills (read from the character's tracker).
func _xslash_targetable(user, enemy, hits):
	return user.is_hostile(enemy) and not enemy.dead and not enemy.banished and hits.has(enemy) and hits[enemy].size() >= 3

func extra_usable(user):
	var hits = user.get("xslash_hits")
	if hits == null:
		return false
	for enemy in user.battle.all_characters():
		if _xslash_targetable(user, enemy, hits):
			return true
	return false

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 200)
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var hits = user.get("xslash_hits")
	if hits == null:
		return
	for character in battle.all_characters():
		if _xslash_targetable(user, character, hits):
			check_hostile_target(user, character, context)
