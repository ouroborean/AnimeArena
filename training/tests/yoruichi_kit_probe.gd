extends Node

# Yoruichi end-to-end kit probe. Her whole kit is reactive and timing-sensitive, so these checks
# drive REAL turn boundaries and REAL enemy skill uses rather than poking effects directly — the
# Gather watcher only fires from inside check_ability_use_triggers, and the Paralyze window is
# exactly where a duration off-by-one would hide.
#   godot --headless --path <repo> res://training/tests/yoruichi_kit_probe.tscn

var fails := 0

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _build_player(u, names):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	var is_enemy = (u == "BotEnemy")
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _cast(m, caster, idx, targets):
	var ab = caster.moveset.base_abilities[idx]
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	caster.used_ability = ab
	ab.execute(caster, m)
	return ab

# Drive an enemy through the REAL use pipeline: execute, then fire their own ACTION_USE_TRIGGERs.
# That second call is the only thing that runs Gather's watcher, and battle_manager does it right
# after execute() on every uncountered skill.
func _enemy_acts(m, enemy, idx, targets):
	var ab = _cast(m, enemy, idx, targets)
	enemy.check_ability_use_triggers(m, ab)
	return ab

# One full turn boundary. end_of_turn_effect_handling runs the acting side's end-of-turn triggers,
# advances that side's cooldowns, ticks every duration, then flips sides via turn_over().
func _pass_turn(m):
	m.end_of_turn_effect_handling()

func _to_yoruichi_turn(m):
	for _i in range(4):
		if not m.waiting_for_turn:
			return
		m.end_of_turn_effect_handling()

# Restore the enemy side between phases. Resetting hp alone is NOT enough: `dead` stays true, and
# every effect application (and the Gather trigger itself) bails on a dead character.
func _revive(p):
	for c in p.team.characters:
		c.dead = false
		c.banished = false
		c.health.hp = c.health.max_hp

func _stacks(y) -> int:
	var e = y.has_effect("Shunko: Gather", EffectType.Type.MARK, y)
	return e.stack_count() if e else 0

func _watchers(foe, y) -> int:
	var n := 0
	for eff in foe.effects.get_effects_by_type(EffectType.Type.ACTION_USE_TRIGGER):
		if eff.user == y:
			n += 1
	return n

func _slot(y, i) -> String:
	var a = y.moveset.get_active_abilities(y)
	return a[i].ability_name if i < a.size() and a[i] != null else "<none>"

func _ready():
	print("=== yoruichi kit probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["yoruichi", "naruto", "gon"])
	var p2 = _build_player("BotEnemy", ["killua", "misaka", "gray"])
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	var y = p1.team.characters[0]
	var foe = p2.team.characters[0]
	var foe2 = p2.team.characters[1]
	var foe3 = p2.team.characters[2]

	# ---- registration ----
	_check(y.character_name == "Yoruichi Shihouin", "character builds (%s)" % y.character_name)
	_check(y.health.max_hp == 100, "max HP is 100 (got %d)" % y.health.max_hp)
	var names: Array = []
	for a in y.moveset.base_abilities:
		names.append(a.ability_name)
	_check(names == ["Shunko: Gather", "Shunko: Raijin Senkei", "Black Cat Warrior Princess", "Yoruichi Dodge", "Fickle Flash"],
		"5 abilities in order: %s" % [names])
	var display: Array = []
	for a in y.moveset.display_abilities():
		display.append(a.ability_name)
	_check(display.size() == 4 and not "Fickle Flash" in display,
		"4 display slots, Fickle Flash hidden (%s)" % [display])
	_check(y.effects.get_effects_by_type(EffectType.Type.ON_DEATH_TRIGGER).is_empty(),
		"no passive machinery is installed at battle start (she has no passive)")

	# ---- Gather: first cast installs the reactive AND counts as stack 1 ----
	_cast(m, y, 0, [y])
	_check(_stacks(y) == 1, "first cast of Gather = 1 stack (got %d)" % _stacks(y))
	_check(_watchers(foe, y) == 1 and _watchers(foe2, y) == 1 and _watchers(foe3, y) == 1,
		"exactly one watcher planted on each of the 3 enemies (%d/%d/%d)" % [_watchers(foe, y), _watchers(foe2, y), _watchers(foe3, y)])

	# Re-casting must stack, NOT re-plant (a duplicate watcher would double every trigger).
	_cast(m, y, 0, [y])
	_check(_stacks(y) == 2, "second cast = 2 stacks (got %d)" % _stacks(y))
	_check(_watchers(foe, y) == 1, "re-cast did NOT plant a duplicate watcher (got %d)" % _watchers(foe, y))

	# ---- the reactive: damage scales with stacks, and paralyzes ----
	_pass_turn(m)   # over to the enemy
	_check(m.waiting_for_turn, "it is the enemy's turn")
	_revive(p2)
	var hp0 = foe.health.hp
	_enemy_acts(m, foe, 0, [y])
	_check(hp0 - foe.health.hp == 10, "an enemy acting takes 5 x 2 stacks = 10 Piercing (dealt %d)" % (hp0 - foe.health.hp))
	_check(foe.paralyzed(), "that enemy's cooldowns are Paralyzed")
	# The client clusters a character's effects by (name, unique_render_id), and EVERYTHING this
	# ability applies is named "Shunko: Gather". Without a distinct id the Paralyze would render
	# inside the same panel as the permanent watcher that fired it, so the enemy would get no visible
	# signal that the reactive had gone off.
	var g_watcher = null
	for e in foe.effects.get_effects_by_type(EffectType.Type.ACTION_USE_TRIGGER):
		if e.source == y.moveset.base_abilities[0]:
			g_watcher = e
	var g_para = foe.effects.get_effects_by_type(EffectType.Type.PARALYZE)[0]
	_check(g_watcher != null, "the standing Gather watcher is still on that enemy")
	_check(g_watcher != null and String(g_watcher.effect_name()) == String(g_para.effect_name()),
		"the watcher and the Paralyze really do share a name (so the id is what separates them)")
	_check(int(g_para.unique_render_id) != int(g_watcher.unique_render_id) if g_watcher != null else false,
		"the triggered Paralyze renders in its OWN cluster (watcher id %d vs paralyze id %d)"
			% [int(g_watcher.unique_render_id) if g_watcher != null else -99, int(g_para.unique_render_id)])
	_check(not foe2.paralyzed(), "an enemy who did NOT act is untouched")

	# One fire per enemy per turn.
	hp0 = foe.health.hp
	_enemy_acts(m, foe, 1, [y])
	_check(foe.health.hp == hp0, "the same enemy acting twice in one turn only triggers once")
	# ...but a DIFFERENT enemy still gets hit the same turn (the owner's ruling).
	var hp2 = foe2.health.hp
	_enemy_acts(m, foe2, 0, [y])
	_check(hp2 - foe2.health.hp == 10, "a second enemy acting the same turn IS hit (dealt %d)" % (hp2 - foe2.health.hp))
	_check(foe2.paralyzed(), "...and is Paralyzed too")

	# ---- Paralyze actually costs them a cooldown tick ----
	# Applied DURING the enemy's turn, so duration 2 spans two boundaries: it blocks that turn's
	# advance_cooldowns, ticks to 1, then expires at the end of Yoruichi's turn. Net: exactly one
	# lost tick, which is what "Paralyze their cooldowns for 1 turn" means.
	var probe_ability = foe.moveset.base_abilities[1]
	probe_ability.cooldown_remaining = 3
	_pass_turn(m)   # end of the ENEMY's turn: their advance_cooldowns runs, but they are paralyzed
	_check(probe_ability.cooldown_remaining == 3,
		"a Paralyzed enemy's cooldown did NOT tick down (still %d)" % probe_ability.cooldown_remaining)
	_pass_turn(m)   # end of Yoruichi's turn: the Paralyze ticks out
	_check(not foe.paralyzed(), "the Paralyze is gone by Yoruichi's turn end (one tick eaten)")
	_pass_turn(m)   # end of the enemy's next turn -- now it should tick
	_check(probe_ability.cooldown_remaining == 2,
		"once un-Paralyzed the cooldown resumes ticking (now %d)" % probe_ability.cooldown_remaining)

	# ---- Raijin Senkei: 25 + 10/stack, and it NEVER consumes (owner ruling) ----
	_to_yoruichi_turn(m)
	_revive(p2)
	var st := _stacks(y)
	_check(st == 2, "2 stacks going into Raijin Senkei (got %d)" % st)
	hp0 = foe3.health.hp
	_cast(m, y, 1, [foe3])
	_check(hp0 - foe3.health.hp == 25 + 10 * st, "Raijin Senkei dealt 25+10*%d (dealt %d)" % [st, hp0 - foe3.health.hp])
	_check(_stacks(y) == st, "the stack counter is UNTOUCHED (still %d)" % _stacks(y))
	_check(_watchers(foe, y) == 1 and _watchers(foe2, y) == 1 and _watchers(foe3, y) == 1,
		"every watcher is still installed (%d/%d/%d)" % [_watchers(foe, y), _watchers(foe2, y), _watchers(foe3, y)])

	# Firing it again is just as strong -- the battery is a standing multiplier, not a resource.
	hp0 = foe2.health.hp
	_cast(m, y, 1, [foe2])
	_check(hp0 - foe2.health.hp == 25 + 10 * st,
		"a second Raijin Senkei hits for the same 25+10*%d (dealt %d)" % [st, hp0 - foe2.health.hp])
	_check(_stacks(y) == st, "...and the counter is still %d" % _stacks(y))

	# The reactive keeps punishing after the cash-out.
	_pass_turn(m)
	_revive(p2)
	hp0 = foe.health.hp
	_enemy_acts(m, foe, 0, [y])
	_check(hp0 - foe.health.hp == 5 * st, "the reactive still fires after Raijin Senkei (dealt %d)" % (hp0 - foe.health.hp))
	_check(foe.paralyzed(), "...and still Paralyzes")

	# ---- the 6-stack cap ----
	_to_yoruichi_turn(m)
	for i in range(10):
		_cast(m, y, 0, [y])
	_check(_stacks(y) == 6, "stacks cap at 6 (got %d)" % _stacks(y))
	_check(not y.moveset.base_abilities[0].extra_usable(y), "Gather is unusable at max stacks")

	# ---- Black Cat Warrior Princess ----
	_to_yoruichi_turn(m)
	_check(_slot(y, 2) == "Black Cat Warrior Princess", "slot 2 starts as Black Cat (%s)" % _slot(y, 2))
	_cast(m, y, 2, [y])
	_check(_slot(y, 2) == "Fickle Flash", "Black Cat swapped slot 2 to Fickle Flash (got %s)" % _slot(y, 2))

	# +10 damage and a Shatter rider while it is up.
	_pass_turn(m)
	_revive(p2)
	y.health.hp = y.health.max_hp
	_check(y.moveset.base_abilities[0].black_cat_active(y), "Black Cat reads as active before the trigger")
	hp0 = foe.health.hp
	_enemy_acts(m, foe, 0, [y])
	_check(hp0 - foe.health.hp == 6 * 5 + 10, "empowered trigger deals 6 stacks x5 +10 = 40 (dealt %d)" % (hp0 - foe.health.hp))
	_check(foe.def_broken(), "the triggering enemy is Shattered")
	# ...and the Shatter joins the Paralyze in the "it fired" cluster, not the watcher's.
	var g_shat = foe.effects.get_effects_by_type(EffectType.Type.DEF_NEGATE)[0]
	var g_w2 = null
	for e in foe.effects.get_effects_by_type(EffectType.Type.ACTION_USE_TRIGGER):
		if e.source == y.moveset.base_abilities[0]:
			g_w2 = e
	_check(g_w2 != null and int(g_shat.unique_render_id) != int(g_w2.unique_render_id),
		"the Shatter also renders apart from the watcher (id %d vs %d)"
			% [int(g_shat.unique_render_id), int(g_w2.unique_render_id) if g_w2 != null else -99])

	# Raijin Senkei still does not consume under Black Cat either (it never consumes at all now).
	_to_yoruichi_turn(m)
	_revive(p2)
	_check(y.moveset.base_abilities[0].black_cat_active(y),
		"Black Cat is still up on this turn (slot 2 = %s)" % _slot(y, 2))
	_cast(m, y, 1, [foe3])
	_check(_stacks(y) == 6, "Raijin Senkei did NOT consume the stacks under Black Cat (got %d)" % _stacks(y))
	_check(_watchers(foe, y) == 1, "...and the watchers are still installed")

	# ---- Fickle Flash ----
	var flash = y.moveset.base_abilities[4]
	_check(flash.ability_name == "Fickle Flash", "index 4 is Fickle Flash")
	_check(flash.classes["Harmful"], "Fickle Flash is classed Harmful (so Taunt and receive-triggers see it)")
	_check(flash.classes["Damaging"], "...and Damaging (so Silence does not lock a pure damage skill out)")
	_check(flash.classes["Bypassing"], "...and still Bypassing")
	_check(not flash.classes["Physical"], "...and is NOT Physical")
	# is_silenced_out(user) is `user.is_silenced() and not classes["Damaging"]`, so with no Silence
	# on her the left operand is false and the call answers false whatever Fickle Flash is classed.
	# Silence her for real, or this asserts nothing about the design decision it names.
	var y_sil = Effect.silence_effect(6)
	y_sil.set_source(y.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(y, m), y, y, y_sil)
	_check(y.is_silenced(), "(setup) Yoruichi is really silenced")
	var dodge = y.moveset.base_abilities[3]
	_check(not dodge.classes["Damaging"] and dodge.is_silenced_out(y),
		"...and the SAME silence DOES lock out a non-Damaging skill of hers (%s)" % dodge.ability_name)
	_check(not flash.is_silenced_out(y), "a silenced Yoruichi can still use Fickle Flash (it is Damaging)")
	for e in y.effects.get_effects_by_type(EffectType.Type.SILENCE):
		e.end_effect()
	_check(not y.is_silenced(), "(teardown) the silence is gone")
	_revive(p2)
	for c in p2.team.characters:
		for e in c.effects.get_effects_by_type(EffectType.Type.PARALYZE):
			e.end_effect()
	hp0 = foe2.health.hp
	_cast(m, y, 4, [foe2])
	_check(hp0 - foe2.health.hp == 20, "Fickle Flash deals 20 Piercing (dealt %d)" % (hp0 - foe2.health.hp))

	# The cooldown rider only fires against a Paralyzed target.
	var before: Array = []
	for a in foe2.moveset.get_active_abilities(foe2):
		before.append(a.cooldown_remaining)
	_cast(m, y, 4, [foe2])
	var after: Array = []
	for a in foe2.moveset.get_active_abilities(foe2):
		after.append(a.cooldown_remaining)
	_check(before == after, "no cooldown bump on an un-Paralyzed target (%s -> %s)" % [before, after])

	var para = Effect.paralyze_effect(4)
	para.set_source(y.moveset.base_abilities[0])
	Character.add_hostile_effect(QueryContext.from_game_state(y, m), y, foe2, para)
	_check(foe2.paralyzed(), "target is Paralyzed for the rider test")
	before = []
	for a in foe2.moveset.get_active_abilities(foe2):
		before.append(a.cooldown_remaining)
	_cast(m, y, 4, [foe2])
	var total_before := 0
	var total_after := 0
	for v in before:
		total_before += v
	for a in foe2.moveset.get_active_abilities(foe2):
		total_after += a.cooldown_remaining
	_check(total_after == total_before + 1,
		"exactly one skill's remaining cooldown went up by 1 (%d -> %d)" % [total_before, total_after])

	# Bypassing: an Invulnerable enemy is still a legal target.
	var inv = Effect.invuln_effect(6)
	inv.set_source(y.moveset.base_abilities[3])
	Character.add_allied_effect(QueryContext.from_game_state(foe3, m), foe3, foe3, inv)
	_check(foe3.is_invuln(null), "foe3 is Invulnerable")
	for c in m.all_characters():
		c.set_untargeted()
	flash.target(y, m)
	_check(foe3.targeted, "Fickle Flash can still target through Invulnerability (Bypassing)")
	for c in m.all_characters():
		c.set_untargeted()
	y.moveset.base_abilities[1].target(y, m)
	_check(not foe3.targeted, "...while non-bypassing Raijin Senkei cannot")

	# ---- Yoruichi Dodge ----
	_to_yoruichi_turn(m)
	y.dead = false
	y.health.hp = y.health.max_hp
	_cast(m, y, 3, [y])
	_check(y.is_invuln(null), "Yoruichi Dodge made her Invulnerable")

	# =====================================================================================
	# Regressions for the defects the adversarial review confirmed. Both FAILED before the fix.
	# =====================================================================================
	_to_yoruichi_turn(m)
	_revive(p2)
	y.dead = false
	y.health.hp = y.health.max_hp
	# Tear everything down by hand so this starts from a clean install. Nothing in the kit does this
	# any more (Raijin Senkei no longer consumes), so the probe has to do it itself.
	y.effects.full_remove_effect_by_name("Shunko: Gather", y)
	for c in p2.team.characters:
		for eff in c.effects.get_effects_by_type(EffectType.Type.ACTION_USE_TRIGGER):
			if eff.user == y:
				c.effects.erase_effect(eff)
	_check(_stacks(y) == 0 and _watchers(foe, y) == 0, "reset: no counter, no watchers")

	# (1) An enemy who is BANISHED when Gather is first cast must not be exempt forever. The
	# bypassing flag only waives the invulnerability check — can_apply_hostile_effect ALWAYS
	# includes is_alive, which is `not (dead or banished)` — so the install silently skips them.
	foe3.banished = true
	_cast(m, y, 0, [y])
	_check(_watchers(foe, y) == 1 and _watchers(foe2, y) == 1, "present enemies were branded")
	_check(_watchers(foe3, y) == 0, "the banished enemy could NOT be branded at install time")
	foe3.banished = false
	_cast(m, y, 0, [y])   # a later cast must repair them
	_check(_watchers(foe3, y) == 1, "a later Gather cast brands the returned enemy (got %d)" % _watchers(foe3, y))
	_check(_watchers(foe, y) == 1, "...without duplicating the watcher on anyone else (got %d)" % _watchers(foe, y))
	_check(_stacks(y) == 2, "the repair cast still counts as a normal stack-up (got %d)" % _stacks(y))

	# ...and the repair must stay reachable once the battery is full.
	for i in range(8):
		_cast(m, y, 0, [y])
	_check(_stacks(y) == 6, "battery full")
	_check(not y.moveset.base_abilities[0].extra_usable(y), "at 6 stacks with everyone branded, Gather is unusable")
	foe2.effects.erase_effect(foe2.effects.get_effects_by_type(EffectType.Type.ACTION_USE_TRIGGER)[0])
	_check(_watchers(foe2, y) == 0, "simulated a lost brand on one enemy")
	_check(y.moveset.base_abilities[0].extra_usable(y),
		"...Gather becomes usable again at max stacks so the brand can be repaired")
	_cast(m, y, 0, [y])
	_check(_watchers(foe2, y) == 1, "the repair cast restored it")

	# (2) The once-per-turn latch must not go stale across a banishment. tick_all_effects_durations
	# is skipped entirely for a banished character, so an engine `triggered` flag set just before a
	# banish would still be set on return and eat that enemy's next trigger.
	_pass_turn(m)
	_revive(p2)
	y.health.hp = y.health.max_hp
	# Black Cat may or may not still be up here depending on how many boundaries the earlier
	# phases burned, so derive the expected number rather than hard-coding it.
	var expect: int = 6 * 5 + (10 if y.moveset.base_abilities[0].black_cat_active(y) else 0)
	var hp_a = foe.health.hp
	_enemy_acts(m, foe, 0, [y])
	_check(hp_a - foe.health.hp == expect,
		"trigger fired at 6 stacks (dealt %d, expected %d)" % [hp_a - foe.health.hp, expect])
	foe.banished = true                    # banished right after triggering
	_pass_turn(m)                          # this boundary skips their effect ticks entirely
	_pass_turn(m)
	foe.banished = false
	_revive(p2)
	y.health.hp = y.health.max_hp
	_to_yoruichi_turn(m)
	_pass_turn(m)                          # back to the enemy's turn
	expect = 6 * 5 + (10 if y.moveset.base_abilities[0].black_cat_active(y) else 0)
	hp_a = foe.health.hp
	_enemy_acts(m, foe, 0, [y])
	_check(hp_a - foe.health.hp == expect,
		"a returning enemy does NOT get a free skill from a stale latch (dealt %d, expected %d)" % [hp_a - foe.health.hp, expect])

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
