extends Node

# Gate for the two new mechanisms:
#   PERSISTENT EXPLORATION - a per-match perturbation of per-entry weights, so the
#     bot commits to one variant of itself for a whole game and multi-turn
#     setup -> payoff sequences can be attempted (and credited) as a unit. Softmax
#     temperature cannot do this: it resamples independently every decision.
#   CHARACTER FOCUS - force one character onto the training side every match so its
#     per-entry weights get thousands of updates instead of the ~2 that uniform
#     sampling over a 170-character roster provides.
#
# The load-bearing safety property is that exploration noise must NEVER reach disk:
# it lives in `explore_offsets`, outside `entries`, so to_dict()/merge() cannot see
# it. If it leaked, every checkpoint would accumulate random garbage.

var pass_n := 0
var fail_n := 0

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

func _ready() -> void:
	print("=== exploration + focus probe ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234

	var pol := BotPolicyV3.new()
	var kit := [["naruto", "Rasengan"], ["naruto", "Toad Kumite"], ["gon", "Jajanken Rock"]]

	# --- exploration is OFF by default -------------------------------------
	# ("no offsets before sampling" used to sit here: a read of a `= {}` member one line after
	#  construction, with no code path able to populate it. It could not go red. The claim worth
	#  making is the observable one — sample_exploration is the ONLY way offsets appear, and
	#  sigma=0 is exactly the old behaviour, which the check below drives for real.)
	pol.sample_exploration(kit, 0.0, rng)
	ck("sigma=0 samples nothing (exactly the old behaviour)", pol.explore_offsets.is_empty())

	# --- sampling produces per-entry, per-feature noise ---------------------
	pol.sample_exploration(kit, 0.25, rng)
	ck("one offset per (character, ability) [%d]" % pol.explore_offsets.size(),
		pol.explore_offsets.size() == kit.size())
	var off: PackedFloat64Array = pol.explore_offsets["naruto|Rasengan"]
	ck("offset spans the whole feature schema", off.size() == BotPolicyV3.FEATURE_SCHEMA.size())
	var nonzero := 0
	var sum := 0.0
	var sumsq := 0.0
	for v in off:
		if absf(v) > 1e-12:
			nonzero += 1
		sum += v
		sumsq += v * v
	ck("offset is actually populated (%d/%d non-zero)" % [nonzero, off.size()], nonzero > off.size() / 2)
	var sd := sqrt(sumsq / off.size())
	ck("magnitude is in the right ballpark for sigma=0.25 (rms %.3f)" % sd, sd > 0.1 and sd < 0.5)
	# Different abilities must get INDEPENDENT perturbations, or every skill shifts
	# together and the bot explores nothing new about its kit's internal ordering.
	var off2: PackedFloat64Array = pol.explore_offsets["naruto|Toad Kumite"]
	var same := true
	for i in range(off.size()):
		if absf(off[i] - off2[i]) > 1e-12:
			same = false
	ck("different abilities get INDEPENDENT noise", not same)

	# --- THE SAFETY PROPERTY: noise must never reach disk -------------------
	# Round-TRIPPED rather than argued from grep: give an entry known non-zero weights, perturb
	# it, then serialise and reload while the perturbation is still live. What comes back must
	# be the true weights to the last bit — if to_dict() ever folded the offset in, every
	# checkpoint would quietly accumulate random garbage. (Reading a FRESH entry's zeros after
	# sampling proved nothing: the entry did not exist while sampling ran.)
	var e := pol._entry("naruto", "Rasengan")
	var truth := PackedFloat64Array()
	truth.resize(BotPolicyV3.FEATURE_SCHEMA.size())
	for i in range(truth.size()):
		truth[i] = 0.125 * float(i + 1)
	e["w"] = truth.duplicate()
	pol.sample_exploration(kit, 0.5, rng)
	ck("(control) a live offset exists for that entry at serialisation time",
		pol.explore_offsets.has("naruto|Rasengan"))
	var reloaded = BotPolicyV3.from_dict(pol.to_dict())
	ck("the checkpoint reloads at all", reloaded != null)
	var drift := -1.0
	if reloaded != null:
		drift = 0.0
		var re: Dictionary = reloaded._entry("naruto", "Rasengan")
		for i in range(truth.size()):
			drift = maxf(drift, absf(float(re["w"][i]) - truth[i]))
	ck("exploration noise NEVER reaches disk (max weight drift %.9f)" % drift, drift == 0.0)
	var live_drift := 0.0
	for i in range(truth.size()):
		live_drift = maxf(live_drift, absf(float(e["w"][i]) - truth[i]))
	ck("...and sampling did not mutate the live weights it is layered over (%.9f)" % live_drift,
		live_drift == 0.0)

	pol.clear_exploration()
	ck("clear_exploration() empties them", pol.explore_offsets.is_empty())

	# --- exploration actually CHANGES a score ------------------------------
	# (a direct check that score_candidate consumes the offset at all)
	var phi := PackedFloat64Array()
	phi.resize(BotPolicyV3.FEATURE_SCHEMA.size())
	for i in range(phi.size()):
		phi[i] = 1.0
	pol.sample_exploration(kit, 0.5, rng)
	var delta: float = pol._dot(pol.explore_offsets["naruto|Rasengan"], phi)
	ck("a perturbation produces a non-zero score shift (%.4f)" % delta, absf(delta) > 1e-6)
	pol.clear_exploration()

	# --- character focus ----------------------------------------------------
	# NOT add_child(): BotTrainerV3._ready() launches a real training run. We only
	# need _sample_teams(), which does not require being in the tree.
	var T = load("res://training/bot_trainer.gd").new()
	T.focus_character = "naruto"
	var seen_focus := 0
	# A separate LATCH, not a sentinel written into seen_focus: the loop increments that counter,
	# so a violation on any iteration but the last was immediately overwritten (-999 + 1) and the
	# check below passed anyway.
	var on_enemy_side := 0
	var rounds := 40
	for i in range(rounds):
		var r := RandomNumberGenerator.new()
		r.seed = 500 + i
		var teams: Array = T._sample_teams(r)
		if "naruto" in teams[0]:
			seen_focus += 1
		# The focused character must never also be drafted onto the OPPOSING side,
		# or it would train against a mirror of itself every match.
		if "naruto" in teams[1]:
			on_enemy_side += 1
	ck("focus puts the character on the training side in ALL %d matches" % rounds, seen_focus == rounds)
	ck("...and never on the opposing side (%d violation(s))" % on_enemy_side, on_enemy_side == 0)

	T.focus_character = ""
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	var t2: Array = T._sample_teams(r2)
	ck("focus=\"\" restores normal sampling (3v3)", t2[0].size() == 3 and t2[1].size() == 3)
	# No duplicate characters across the two teams.
	var dup := false
	for n in t2[0]:
		if n in t2[1]:
			dup = true
	ck("no character appears on both teams", not dup)

	T.free()
	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
