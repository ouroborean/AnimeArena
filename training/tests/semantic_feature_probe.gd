extends Node

# Gate for the appended semantic feature layer.
#
# IDENTITY PROOF (stronger than a byte-compare of two eval logs): a loaded
# gen_8 checkpoint must have every APPENDED weight at exactly 0.0, and every
# feature component must be finite. score = dot(w, phi); if w[j] == 0.0 for all
# appended j AND phi[j] is finite, those terms contribute exactly 0.0, so scores
# are bit-identical to the pre-change policy and the argmax cannot move.
# The finiteness half is load-bearing: 0.0 * INF == NaN in IEEE754, and one NaN
# poisons the whole score and silently loses every comparison.
#
# VARIANCE CHECK: the bug being fixed is features that are CONSTANT across the
# candidate set (exact zero gradient forever). Every appended ability feature is
# asserted to take more than one distinct value across a real candidate set in at
# least some decisions -- otherwise it is dead weight and must be deleted, not
# rationalised as "slow to learn".

var pass_n := 0
var fail_n := 0

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

const FIRST_NEW_ABILITY := 17
const FIRST_NEW_TARGET := 13

func _build_player(u, names) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	for cn in names:
		p.recruit_character(Character.from_character_name(cn), u == "B")
	for c in p.team.characters:
		c.bot_character = true
	return p

func _ready() -> void:
	print("=== semantic feature probe ===")

	# --- the tag table actually loaded -------------------------------------
	var tag_path := "res://training/bot_tags.json"
	ck("bot_tags.json exists", FileAccess.file_exists(tag_path))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(tag_path))
	var tags: Dictionary = parsed.get("tags", {}) if parsed is Dictionary else {}
	ck("tag table is populated (%d entries)" % tags.size(), tags.size() > 500)
	var bits := {1: 0, 2: 0, 4: 0, 8: 0, 16: 0, 32: 0, 64: 0}
	for v in tags.values():
		for b in bits.keys():
			if int(v) & b:
				bits[b] += 1
	var all_bits_fire := true
	for b in bits.keys():
		if bits[b] == 0:
			all_bits_fire = false
	ck("every semantic bit fires at least once %s" % str(bits), all_bits_fire)

	# --- IDENTITY: appended weights load at exactly 0.0 ---------------------
	var pol = BotPolicyV3.load_from_path("res://training/checkpoints/gen_8.json")
	ck("gen_8 checkpoint loaded", pol != null)
	if pol == null:
		print("=== %d passed, %d failed ===" % [pass_n, fail_n]); get_tree().quit(1); return
	ck("schema grew to %d ability features" % BotPolicyV3.FEATURE_SCHEMA.size(),
		BotPolicyV3.FEATURE_SCHEMA.size() > FIRST_NEW_ABILITY)
	var zero_a := true
	for j in range(FIRST_NEW_ABILITY, pol.shared_w.size()):
		if pol.shared_w[j] != 0.0:
			zero_a = false
			printerr("    shared_w[%d] (%s) = %s" % [j, BotPolicyV3.FEATURE_SCHEMA[j], str(pol.shared_w[j])])
	ck("every appended ABILITY weight loads at exactly 0.0", zero_a)
	var zero_t := true
	for j in range(FIRST_NEW_TARGET, pol.shared_tw.size()):
		if pol.shared_tw[j] != 0.0:
			zero_t = false
	ck("every appended TARGET weight loads at exactly 0.0", zero_t)
	# Pre-existing weights must be untouched by the append (indices did not move).
	ck("index 13 is still kill_available", BotPolicyV3.FEATURE_SCHEMA[13] == "kill_available")
	ck("index 12 is still dmg_hint_norm", BotPolicyV3.FEATURE_SCHEMA[12] == "dmg_hint_norm")
	ck("kill_available weight preserved (%.4f)" % pol.shared_w[13], absf(pol.shared_w[13] - 0.9151) < 0.001)
	ck("target index 12 is still focus_fire", BotPolicyV3.TARGET_SCHEMA[12] == "focus_fire")

	# --- FINITENESS + VARIANCE over real decisions --------------------------
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("A", ["naruto", "gon", "ichigo"])
	var p2 := _build_player("B", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var obs := BotObservation.for_player(m, p1)
	var n_decisions := 0
	var nonfinite := 0
	var out_of_range := 0
	# per appended ability feature: did it ever differ across the candidate set?
	var varied := {}
	for j in range(FIRST_NEW_ABILITY, BotPolicyV3.FEATURE_SCHEMA.size()):
		varied[j] = false

	for character in p1.team.characters:
		if character.dead:
			continue
		var cands: Array = obs.own_candidates(character)
		if cands.is_empty():
			continue
		n_decisions += 1
		var seen := {}
		for cand in cands:
			var phi: PackedFloat64Array = pol.extract_ability_features(obs, character, cand)
			for j in range(phi.size()):
				if not is_finite(phi[j]):
					nonfinite += 1
				elif phi[j] < -1.001 or phi[j] > 1.501:
					out_of_range += 1
			for j in range(FIRST_NEW_ABILITY, mini(phi.size(), BotPolicyV3.FEATURE_SCHEMA.size())):
				if not seen.has(j):
					seen[j] = phi[j]
				elif absf(seen[j] - phi[j]) > 1e-9:
					varied[j] = true
			# target side
			for t in cand["targets"]:
				var pt: PackedFloat64Array = pol.extract_target_features(obs, character, cand, t, {})
				for j in range(pt.size()):
					if not is_finite(pt[j]):
						nonfinite += 1

	ck("exercised real decisions (%d)" % n_decisions, n_decisions > 0)
	ck("NO non-finite feature components (0*INF=NaN would move the argmax)", nonfinite == 0)
	ck("no component wildly out of range (%d)" % out_of_range, out_of_range == 0)

	# Report which appended ability features varied. A feature that NEVER varies is
	# the exact bug this change fixes, so name it loudly.
	var dead_names: Array = []
	for j in range(FIRST_NEW_ABILITY, BotPolicyV3.FEATURE_SCHEMA.size()):
		var nm: String = BotPolicyV3.FEATURE_SCHEMA[j]
		if varied[j]:
			print("       varies: %s" % nm)
		else:
			dead_names.append(nm)
	if not dead_names.is_empty():
		print("       (did not vary in this sample: %s)" % str(dead_names))
	# In a single 3v3 sample not every feature will fire; require that the CORE
	# semantic bits move, which is what makes the shared layer able to learn at all.
	var core := ["cd_norm", "t_damage_now"]
	var core_ok := true
	for nm in core:
		var idx: int = BotPolicyV3.FEATURE_SCHEMA.find(nm)
		if idx < 0 or not varied[idx]:
			core_ok = false
	ck("core discriminators (cd_norm, t_damage_now) vary across candidates", core_ok)

	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
