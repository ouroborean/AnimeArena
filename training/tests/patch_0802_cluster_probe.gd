extends Node

# Patch 2026-08-02 — cluster probe for Itadori Yuji, Kaname Madoka, Miki Sayaka and Xanxus.
#
# WHAT NEEDS A PROBE RATHER THAN A COMPILE, per change:
#   YUJI   The Black Flash chance lives in TWO files (yuji5 stamps the mark's opening magnitude,
#          character/yuji.gd holds the reset floor). Either half alone compiles and renders; the
#          desync only shows the first time a proc resets. Consume Finger's "+15 to minimum AND
#          current" is the subtle one — the owner's ruling is that the net gain to current is
#          only ever 15, so the probe asserts it from BOTH a current sitting on the floor and a
#          current above it, which is exactly where the old "raise up to the floor" form was wrong.
#   MADOKA The new per-turn ticker is the first thing that ever calls gain_corruption on a schedule,
#          so the missing null guard would have crashed EVERY turn after a revive — and a GDScript
#          runtime error only logs and continues, so the failure mode is a silently dead passive.
#          Also asserts the owner's revive ruling: the gem MARK goes, the machinery stays.
#   SAYAKA Enraged Slash's second stack must be a SECOND single grant, so the death check runs
#          between them and she can never be left standing one stack past her limit.
#   XANXUS The free stacks are counted in his own ACTING turns and must not pause while he is dead.
#          Xanxus is deliberately seated on PLAYER 2 here: `waiting_for_turn` is the player/enemy
#          SIDE split, not "my team", so a naive gate is inverted for exactly this seat.
#
# ASSERTION ORDER: each block asserts the POSITIVE (the new behaviour happened) before any control.
#
#   godot --headless --path <repo> res://training/tests/patch_0802_cluster_probe.tscn

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

func _fill_energy(p):
	for colour in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		p.team.energy.pool[colour] = 20

func _flash(yuji):
	return yuji.has_effect("Black Flash", EffectType.Type.MARK)

func _gem(c, gem_name):
	return c.effects.has_effect(gem_name, EffectType.Type.MARK, c)

func _wrath_stacks(x):
	var mod = x.effects.has_effect("Scars of Wrath", EffectType.Type.DAMAGE_MOD, x)
	if not mod:
		return 0
	return mod.stack_count()

func _turn_counter(x):
	return x.effects.has_effect("Scars of Wrath", EffectType.Type.START_OF_TURN_TRIGGER, x)

# execute() is called directly here rather than through the turn loop, so used_ability has to be set
# by hand: Character.resolve_healing / resolve_damage read owner.used_ability for the damage and
# healing modifiers, and a null there raises inside the engine instead of failing the assertion.
func _use(c, ability):
	c.used_ability = ability
	ability.execute(c, c.battle)

# Simulate ONE turn boundary for the given side. start_new_turn / turn_over both set the side latch
# first and then fire every character's start-of-turn triggers, on BOTH teams — so this is the same
# shape the real loop uses, and it is what makes the acting-team gate observable.
func _turn_for_enemy_side(m, enemy_side: bool):
	m.waiting_for_turn = enemy_side
	for c in m.player.team.characters:
		c.check_start_of_turn_triggers(m)
	for c in m.enemy.team.characters:
		c.check_start_of_turn_triggers(m)


func _ready():
	print("=== patch 2026-08-02 cluster probe (yuji / madoka / sayaka / xanxus) ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["yuji", "madoka", "sayaka"])
	var p2 = _build_player("BotEnemy", ["xanxus", "gon", "naruto"])
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	_fill_energy(p1)
	_fill_energy(p2)
	for c in p1.team.characters + p2.team.characters:
		c.refresh()

	var yuji = p1.team.characters[0]
	var madoka = p1.team.characters[1]
	var sayaka = p1.team.characters[2]
	var xanxus = p2.team.characters[0]
	var foe = p2.team.characters[1]

	# ---------------------------------------------------------------- YUJI
	print("-- Itadori Yuji: Black Flash --")
	var flash = _flash(yuji)
	_check(flash != null, "POSITIVE: the Black Flash mark exists after startup")
	_check(flash != null and flash.mag == 15, "POSITIVE: baseline chance is 15 (yuji5 stamps the mark)")
	_check(yuji.black_flash_minimum == 15, "POSITIVE: the reset floor in character/yuji.gd is the SAME 15")

	# A failed roll is forced by putting the chance at 0 (roll() returns 1..100, so nothing hits).
	flash.mag = 0
	yuji.call_unique("yuji", "check_black_flash", [foe])
	_check(_flash(yuji).mag == 20, "POSITIVE: a failed True-damage roll raises the chance by 20 (was 15)")

	# A successful roll is forced by putting the chance at 100.
	yuji.black_flash_minimum = 40
	_flash(yuji).mag = 100
	yuji.call_unique("yuji", "check_black_flash", [foe])
	_check(_flash(yuji).mag == 40, "POSITIVE: a successful proc resets to the CURRENT minimum, not to the 15 base")

	# Consume Finger from a current ABOVE the floor: both rise by exactly 15.
	yuji.black_flash_minimum = 20
	_flash(yuji).mag = 50
	_use(yuji, yuji.moveset.base_abilities[2])
	_check(yuji.black_flash_minimum == 35, "POSITIVE: Consume Finger raises the minimum by 15")
	_check(_flash(yuji).mag == 65, "POSITIVE: ...and the current by 15 as well (it used to gain nothing here)")

	# Consume Finger from a current sitting ON the floor: the gain is 15, never 30.
	yuji.black_flash_minimum = 20
	_flash(yuji).mag = 20
	_use(yuji, yuji.moveset.base_abilities[2])
	_check(yuji.black_flash_minimum == 35 and _flash(yuji).mag == 35, "POSITIVE: current == minimum -> BOTH become 35 (a 15 gain, not 30)")

	# The ceiling.
	yuji.black_flash_minimum = 20
	_flash(yuji).mag = 95
	_use(yuji, yuji.moveset.base_abilities[2])
	_check(_flash(yuji).mag == 100, "Consume Finger is clamped at 100 (this site never had a clamp)")

	# Combat Awakening.
	_flash(yuji).mag = 30
	_use(yuji, yuji.moveset.base_abilities[1])
	_check(_flash(yuji).mag == 55, "POSITIVE: Combat Awakening raises the current chance by 25 (was 20)")
	_flash(yuji).mag = 90
	_use(yuji, yuji.moveset.base_abilities[1])
	_check(_flash(yuji).mag == 100, "Combat Awakening is still clamped at 100")

	# ---------------------------------------------------------------- MADOKA
	print("-- Kaname Madoka: Soul Gem --")
	var tick = madoka.effects.has_effect("Soul Gem: Madoka", EffectType.Type.TICKING_TRIGGER, madoka)
	_check(tick != null, "POSITIVE: Madoka now carries a per-turn TICKING_TRIGGER")
	_check(tick != null and tick.duration == -1, "the ticker is permanent (dur -1), not a finite window")
	_check(tick != null and tick.system and not tick.remove_on_death, "the ticker survives the death cleanse (system + remove_on_death = false)")
	_check(tick != null and tick.display_system, "...and is still serialized to both players (display_system)")

	var gem = _gem(madoka, "Soul Gem: Madoka")
	_check(gem != null and gem.mag == 0, "the gem starts empty")
	m.execute_ticking_effect(tick)
	_check(_gem(madoka, "Soul Gem: Madoka").mag == 1, "POSITIVE: one tick = one stack")
	m.execute_ticking_effect(tick)
	_check(_gem(madoka, "Soul Gem: Madoka").mag == 2, "POSITIVE: and the next tick is the second stack")

	# The null guard: strip the gem and tick anyway. Before the guard this raised every turn — and a
	# GDScript runtime error only logs, so the observable symptom is the gem never coming back.
	madoka.effects.erase_effect(_gem(madoka, "Soul Gem: Madoka"))
	_check(_gem(madoka, "Soul Gem: Madoka") == null, "[setup] the gem is gone")
	m.execute_ticking_effect(tick)
	_check(_gem(madoka, "Soul Gem: Madoka") != null, "POSITIVE: a gemless tick re-seeds the gem instead of crashing")
	_check(_gem(madoka, "Soul Gem: Madoka").mag == 1, "...and the re-seeded gem starts counting from 1 again")

	# The death threshold, and the owner's revive ruling.
	_gem(madoka, "Soul Gem: Madoka").mag = 10
	madoka.gain_corruption()
	_check(not madoka.dead and _gem(madoka, "Soul Gem: Madoka").mag == 11, "[control] 11 stacks is survivable")
	madoka.gain_corruption()
	_check(madoka.dead, "POSITIVE: the 12th stack kills Madoka (was 15)")
	_check(madoka.effects.has_effect("Soul Gem: Madoka", EffectType.Type.TICKING_TRIGGER, madoka) != null, "POSITIVE: the passive machinery SURVIVES her death (owner ruling)")
	_check(_gem(madoka, "Soul Gem: Madoka") == null, "...while the gem MARK itself is removed, also per the ruling")
	madoka.dead = false
	madoka.health.set_health(50)
	m.execute_ticking_effect(madoka.effects.has_effect("Soul Gem: Madoka", EffectType.Type.TICKING_TRIGGER, madoka))
	_check(_gem(madoka, "Soul Gem: Madoka") != null and _gem(madoka, "Soul Gem: Madoka").mag == 1, "POSITIVE: a revived Madoka resumes ticking and tracking from zero")

	# ---------------------------------------------------------------- SAYAKA
	print("-- Miki Sayaka: Enraged Slash --")
	var s_gem = _gem(sayaka, "Soul Gem: Sayaka")
	_check(s_gem != null, "[setup] Sayaka's gem exists")
	s_gem.mag = 0
	sayaka.targeter.clear_targets()
	sayaka.targeter.targets.append(foe)
	_use(sayaka, sayaka.moveset.base_abilities[3])
	_check(_gem(sayaka, "Soul Gem: Sayaka").mag == 2, "POSITIVE: Enraged Slash grants 2 stacks (was 1)")

	# The death check must run BETWEEN the two grants: from 9, she dies on 10 and is never at 11.
	_gem(sayaka, "Soul Gem: Sayaka").mag = 9
	sayaka.targeter.clear_targets()
	sayaka.targeter.targets.append(foe)
	_use(sayaka, sayaka.moveset.base_abilities[3])
	_check(sayaka.dead, "POSITIVE: Enraged Slash from 9 stacks kills her on reaching 10")
	var strays = 0
	for eff in sayaka.effects._effects:
		if eff.effect_name() == "Soul Gem: Sayaka" and eff.effect_type == EffectType.Type.MARK and eff.mag > 10:
			strays += 1
	_check(strays == 0, "POSITIVE: she is never left standing PAST the limit (no 11-stack gem)")
	_check(sayaka.effects.has_effect("Soul Gem: Sayaka", EffectType.Type.TICKING_TRIGGER, sayaka) != null, "Sayaka's passive machinery also survives her death")

	# ---------------------------------------------------------------- XANXUS
	print("-- Xanxus: Scars of Wrath, 2nd and 4th turns --")
	var counter = _turn_counter(xanxus)
	_check(counter != null, "POSITIVE: Xanxus carries a START_OF_TURN turn counter")
	_check(counter != null and counter.system and not counter.remove_on_death, "the counter outlives his death, so the count does not pause (owner ruling)")
	_check(_wrath_stacks(xanxus) == 0, "[setup] no wrath stacks yet")

	# Xanxus is on PLAYER 2, so his turns are the ones where waiting_for_turn is TRUE. Feed one full
	# round at a time and assert the OFFSETS, not just the total.
	_turn_for_enemy_side(m, false)
	_check(counter.mag == 0, "[control] the opponent's turn does not advance his count")
	_turn_for_enemy_side(m, true)
	_check(counter.mag == 1 and _wrath_stacks(xanxus) == 0, "his 1st turn advances the count and grants nothing")
	_turn_for_enemy_side(m, false)
	_turn_for_enemy_side(m, true)
	_check(counter.mag == 2, "his 2nd turn is counted")
	_check(_wrath_stacks(xanxus) == 1, "POSITIVE: the 2nd turn grants a free stack")
	_turn_for_enemy_side(m, false)
	_turn_for_enemy_side(m, true)
	_check(counter.mag == 3 and _wrath_stacks(xanxus) == 1, "[control] the 3rd turn grants nothing")
	_turn_for_enemy_side(m, false)
	_turn_for_enemy_side(m, true)
	_check(_wrath_stacks(xanxus) == 2, "POSITIVE: the 4th turn grants the second free stack")
	_turn_for_enemy_side(m, false)
	_turn_for_enemy_side(m, true)
	_check(_wrath_stacks(xanxus) == 2, "[control] the 5th turn grants nothing more")

	# The free stacks must be the GENERIC bonuses, not one of the nine trigger categories.
	var storage = xanxus.effects.has_effect("Scars of Wrath", EffectType.Type.XANXUS_STORAGE, xanxus)
	var consumed = 0
	for key in storage.storage.keys():
		if storage.storage[key] != 0:
			consumed += 1
	_check(consumed == 0, "POSITIVE: the free stacks consumed none of the nine trigger categories")
	_check(xanxus.effects.has_effect("Scars of Wrath", EffectType.Type.COST_MOD, xanxus) != null, "the free stacks carry the cost reduction too")
	_check(xanxus.effects.has_effect("Scars of Wrath", EffectType.Type.COOLDOWN_MOD, xanxus) != null, "...and the cooldown reduction")

	# A real trigger still pays out on top, through the same helper.
	xanxus.wrath_check("normal")
	_check(_wrath_stacks(xanxus) == 3, "POSITIVE: wrath_check still grants through the extracted helper")
	_check(storage.storage["normal"] == 1, "...and it DOES consume its category")

	print("=== %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
