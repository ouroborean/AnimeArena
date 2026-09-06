extends Node

# ============================================================================
# ADVERSARIAL REVIEW — Creator Roulette 10 damage_boost routing.
#   godot --headless --path <repo> res://training/tests/advrev_weaken_routing_probe.tscn
#
# REGRESSION GUARD (was a bug-repro). Claim under test: a block `damage_boost {amount:-10,
# exclude_types:[AFFLICTION]}` is a FAITHFUL equivalent of the hand-written ladydevimon3 weaken:
#       var weaken = Effect.damage_mod_effect(-10, 2, [], [], [DamageType.Type.AFFLICTION])
#       Character.add_hostile_effect(context, user, target, weaken)
# The hand-written kit lands the weaken through add_HOSTILE_effect, so an INVULNERABLE enemy
# REFUSES it (can_apply_hostile_effect fails). The block runner picks the apply path from
# _is_hostile_effect(spec). ORIGINALLY it read HOSTILE_BY_SIGN as `amount > 0`, so a NEGATIVE weaken
# read not-hostile and routed through add_ALLIED_effect, bypassing the invuln / shrug_off /
# is_ignoring_skill gates — the authored weaken landed on an invulnerable enemy the real kit cannot
# touch. FIXED: damage_boost is in SIGN_HOSTILE_WHEN_NEGATIVE, so a negative weaken now routes
# hostile and is refused identically. This probe pins that parity so the polarity cannot regress.
# ============================================================================

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _build_player(u, names, is_enemy):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	return p

func _runner(ab, m, who):
	return load("res://blocks/block_runner.gd").new(ab, m, who)

func _carrier(nm, owner):
	var a := ScriptedAbility.new()
	a.configure({"name": nm, "target": "enemy", "blocks": []})
	a.ability_name = nm
	a.classes = Ability.default_classes()
	a.classes["Harmful"] = true
	a.classes["Instant"] = true
	a.user = owner
	owner.moveset.add_ability(a)
	return a

func _dmg_mods(ch) -> Array:
	return ch.effects.get_effects_by_type(EffectType.Type.DAMAGE_MOD)

func _ready():
	print("=== adversarial: damage_boost weaken routing vs invulnerable enemy ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("ZZ_Caster", ["naruto", "sasuke", "sakura"], false)
	var p2 = _build_player("ZZ_Enemy", ["gon", "killua", "gray"], true)
	m.start_battle(p1, p2, true, 11, BattleManager.MatchType.BOT)
	for c in p1.team.characters:
		c.bot_character = false
	var me = p1.team.characters[0]
	var foe = p2.team.characters[0]
	var carrier = _carrier("Darkness Spear", me)
	var context = carrier.make_context(m)

	# --- make the enemy INVULNERABLE (the exact gate the hand-written add_hostile_effect respects) ---
	var inv = Effect.invuln_effect(20)
	inv.set_source(foe.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(foe, m), foe, foe, inv, true)
	_check(foe.is_invulnerable() if foe.has_method("is_invulnerable") else true,
		"(setup) the enemy is invulnerable")

	# --- 1) HAND-WRITTEN reference: add_hostile_effect on the invuln enemy -> REFUSED ---
	var hand = Effect.damage_mod_effect(-10, 2, [], [], [DamageType.Type.AFFLICTION])
	hand.set_source(carrier)
	Character.add_hostile_effect(context, me, foe, hand)
	var hand_landed := _dmg_mods(foe).size() > 0
	_check(not hand_landed,
		"HAND-WRITTEN ladydevimon3 weaken is REFUSED by the invulnerable enemy (add_hostile_effect)")

	# clear any stray mod so the two paths are measured independently
	for e in _dmg_mods(foe):
		foe.effects.erase_effect(e)

	# --- 2) BLOCK-AUTHORED: the shipped ladydevimon3 damage_boost through _op_apply ---
	me.targeter.targets = [foe]
	me.targeter.main_target = foe
	_runner(carrier, m, me).run([{
		"op": "apply", "to": "target",
		"effect": {"kind": "damage_boost", "amount": -10, "turns": 1, "exclude_types": ["AFFLICTION"]}
	}])
	me.targeter.targets = []
	var block_landed := _dmg_mods(foe).size() > 0

	# THE DIVERGENCE: if the block weaken LANDS while the hand weaken was refused, the authored
	# LadyDevimon debuffs a target the real kit cannot. Faithful behaviour = block also refused.
	_check(not block_landed,
		"BLOCK damage_boost{-10} is ALSO refused by the invulnerable enemy (faithful to add_hostile_effect)")
	if block_landed:
		print("  >>> DIVERGENCE CONFIRMED: the authored weaken landed on an INVULNERABLE enemy that")
		print("      the hand-written add_hostile_effect refused. _is_hostile_effect returns amount>0,")
		print("      so a NEGATIVE (hostile) damage_boost is routed through add_ALLIED_effect, bypassing")
		print("      the invuln / shrug_off / is_ignoring_skill gates the real kit passes through.")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit()
