extends Node

# PRIVATE-INVITE GUARD — REGRESSION PROBE.
#   godot --headless --path <repo> res://training/tests/private_invite_probe.tscn
#
# WHAT THIS FILE KEEPS DEAD.
# `private_queue` is an INVITE map keyed by the ORDERED PAIR (inviter -> target):
#     private_queue[_invite_key(inviter, target)] = [inviter_peer, inviter_display_package, chars]
# It was once keyed by TARGET ALONE, which meant two people inviting the same player silently
# overwrote each other and every cleanup path had to guess a username.
# and the pairing test in receive_private_match_queue is `player.username in private_queue`, i.e.
# "is somebody waiting for ME?". Inviting YOURSELF therefore filed an entry under your OWN name, and
# the very next self-invite matched it and handed start_private_match the SAME package twice. Both
# seats resolved to ONE Player object; Match.from_players cleared that single team twice, `players`
# ended up with a single dict entry, begin_match bailed on `len(players) < 2`, so `manager` stayed
# null forever, `cancelling` was never set and nothing freed the node — while session.current_match
# still pointed at that zombie. _already_in_match then saw the zombie on every later queue attempt:
# the ACCOUNT WAS PERMANENTLY UNABLE TO QUEUE FOR ANYTHING. A blank target was the quieter sibling —
# it filed the invite under the "" key, where nobody's username lookup can ever hit, so it simply
# leaked until the player disconnected.
#
# Match.from_players' `player1 == player2` guard now stops the zombie from ever being BUILT, which is
# why blocks [1]/[2] cannot lean on "no zombie match exists" as their evidence — that is true with or
# without the fix. The evidence that the EARLY guard is alive is (a) nothing is filed under the
# sender's own name in the first place, and (b) what comes back on the wire is EXACTLY ONE
# receive_queue_rejected naming the mistake — as opposed to silence (the invite was filed) or the two
# generic "Opponent is already in a match" rejections start_private_match emits when from_players
# refuses late. See _refused() for why the type and the count are both load-bearing.
#
# !! READ BEFORE "FIXING" A FAILURE HERE !!
# Blocks [4] and [5] are the COUNTERWEIGHT: a normal mutual invite must still build a real private
# match, and whitespace around a real target must be trimmed so " Bob " and "Bob" land on the SAME
# key. If those go red the guard has eaten the feature it was meant to protect — do not "fix" blocks
# [1]-[3] by widening the refusal.
#
# HOW IT RUNS. ServerConnection is instantiated but NEVER added to the tree (_ready boots a real game
# server, sockets and all). The only test double is the JSON gateway — a spy object standing in for
# the SOCKET, so the frames the server tries to send are observable. The function under test is the
# real one; peer_map/sessions are populated exactly the way _process_login populates them.
#
# EXPECTED STDERR NOISE: blocks [4]/[5] build real matches whose Match node hangs off the detached
# ServerConnection, so `Timer.start()` in start_turn_timer prints "Timer was not added to the scene
# tree". That is the harness being detached, not a failure.

var pass_n := 0
var fail_n := 0

# Stands in for the WebSocket gateway (send_to_peer's sink), so refusals are observable instead of
# vanishing. Nothing about receive_private_match_queue itself is stubbed.
class GatewaySpy extends RefCounted:
	var frames: Array = []
	func send(pid: int, frame: Dictionary) -> void:
		frames.append(frame)

var _spy: GatewaySpy
var _players: Array = []

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

# Seat a logged-in player the way _process_login does: peer_map[peer] -> username -> ServerSession.
func _seat(S, username: String, peer: int, names: Array) -> Dictionary:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.set_username(username)
	p.mission_reference = {}
	p.mission_data = {}
	# ServerSession is an inner class of ServerConnection; reach it through the script's constant map
	# rather than re-declaring a copy here, so a change to its _init breaks this probe loudly.
	var SessionClass = S.get_script().get_script_constant_map()["ServerSession"]
	S.peer_map[peer] = username
	S.sessions[username] = SessionClass.new(username, peer, p)
	_players.append(p)
	return {"player": p, "peer": peer, "pkg": p.display_package(), "chars": names}

# Fire the real handler with exactly the arguments the JSON gateway passes it (see _json_queue's
# "private" branch: display_package, characters, str(target_username)).
func _invite(S, seat: Dictionary, target: String) -> Array:
	var before: int = _spy.frames.size()
	S.receive_private_match_queue(seat["peer"], seat["pkg"], seat["chars"], target)
	return _spy.frames.slice(before)

# Fixture reset between INDEPENDENT blocks. Without it a block that fails and leaves an entry behind
# also fails every later block's "files nothing" / "exactly one invite" assertion, and the real
# failure drowns. Never called INSIDE a block — block [2]'s whole point is the state block [2]'s own
# first call left behind.
func _fresh_queue(S) -> void:
	S.private_queue.clear()

func _types(frames: Array) -> Array:
	var out: Array = []
	for f in frames:
		out.append(str(f.get("type", "")))
	return out

func _reason(frames: Array) -> String:
	if frames.is_empty():
		return "<no frame sent>"
	return str(frames[0].get("reason", ""))

# What a refusal from the EARLY guard must look like on the wire: exactly one frame, typed
# receive_queue_rejected, carrying an explanation that names the mistake.
#
# The type is load-bearing, not cosmetic. The client sets queued=true optimistically the instant it
# sends, and ONLY its receive_queue_rejected handler clears that; the "error" handler merely prints
# the reason. Ship this as "error" and a client without the matching JS guard (an older cached build,
# or any hand-sent frame) sits on "Waiting for … to invite you back" forever against a server holding
# no invite.
#
# The COUNT is what proves the early guard ran instead of start_private_match. start_private_match
# never emits exactly one frame for these inputs: a self-invite that reaches it makes from_players
# refuse, and the release loop then sends receive_queue_rejected once PER PACKAGE (two frames, reason
# "Opponent is already in a match"), while a successful pairing emits receive_private_match twice
# plus two apply_turn_result. And an invite that is silently FILED emits nothing at all. So
# "exactly one, and it says <needle>" separates the guard from every other outcome.
func _refused(frames: Array, needle: String) -> bool:
	return frames.size() == 1 \
		and _types(frames) == ["receive_queue_rejected"] \
		and _reason(frames).to_lower().contains(needle)

func _ready() -> void:
	print("=== private invite guard probe ===")
	var S = load("res://components/server_connection.gd").new()
	_spy = GatewaySpy.new()
	S.json_gateway = _spy
	var BASE: int = S.JSON_PEER_BASE

	# =====================================================================================
	# [1] A SELF-INVITE IS REFUSED AND FILES NOTHING.
	# =====================================================================================
	var solo := _seat(S, "ZZ_Solo", BASE + 11, ["naruto", "sasuke", "gray"])
	var f1 := _invite(S, solo, "ZZ_Solo")
	ck("[1] self-invite leaves private_queue EMPTY (nothing filed under the sender)",
		S.private_queue.is_empty())
	ck("[1] ...specifically no entry keyed on the sender's own name",
		not ("ZZ_Solo" in S.private_queue))
	ck("[1] the sender is TOLD why — ONE receive_queue_rejected, not silence: %s" % str(_types(f1)),
		_refused(f1, "yourself"))
	ck("[1] ...and the reason names the mistake: \"%s\"" % _reason(f1),
		_reason(f1).to_lower().contains("yourself"))

	# =====================================================================================
	# [2] TWO CONSECUTIVE SELF-INVITES — the exact sequence that used to brick the account.
	#     The second one is the dangerous one: unguarded, it MATCHES the entry the first one
	#     filed and hands start_private_match one package for both seats.
	# =====================================================================================
	var f2 := _invite(S, solo, "ZZ_Solo")
	# HONEST NOTE: this one line does NOT prove the guard. Verified by reversal — with the guard
	# commented out it stays GREEN, because the unguarded second call reaches start_private_match,
	# from_players refuses, and _erase_private_invite drains the queue on the way out. It is here to
	# state the required end state; the two assertions below are what actually bite.
	ck("[2] private_queue is STILL empty after a second self-invite",
		S.private_queue.is_empty())
	ck("[2] the second self-invite is refused the SAME way, not paired: %s" % str(_types(f2)),
		_refused(f2, "yourself"))
	# start_private_match's fingerprints, per the count/wording argument on _refused(): a pairing emits
	# receive_private_match (+apply_turn_result); a late from_players refusal emits one
	# receive_queue_rejected PER PACKAGE, reason "Opponent is already in a match". Neither may appear.
	var all_solo := _types(f1 + f2)
	var late_refusal := false
	for f in f1 + f2:
		if str(f.get("reason", "")).to_lower().contains("already in a match"):
			late_refusal = true
	ck("[2] start_private_match was NEVER reached (2 frames total, no pairing, no late refusal): %s" % str(all_solo),
		all_solo.size() == 2
		and not ("receive_private_match" in all_solo)
		and not ("apply_turn_result" in all_solo)
		and not late_refusal)
	ck("[2] no private match was created", S.private_matches.is_empty())
	ck("[2] no match node was parented onto the server", S.get_child_count() == 0)
	ck("[2] the sender's session holds NO match (this is what used to lock the account out)",
		S.get_session(solo["peer"]).current_match == null)
	ck("[2] the sender can still be queued afterwards (_already_in_match stays false)",
		not S._already_in_match(solo["peer"]))

	# A padded self-invite is the same brick wearing a hat: the guard must compare the TRIMMED
	# target, or " ZZ_Solo " sails past it and is filed under the sender's own key anyway.
	var f2b := _invite(S, solo, "  ZZ_Solo  ")
	ck("[2] a WHITESPACE-PADDED self-invite is refused too (guard compares the trimmed target)",
		S.private_queue.is_empty() and _refused(f2b, "yourself"))

	# =====================================================================================
	# [3] BLANK / WHITESPACE-ONLY TARGET files nothing (it used to leak under the "" key).
	# =====================================================================================
	_fresh_queue(S)
	var blank := _seat(S, "ZZ_Blank", BASE + 12, ["naruto", "sasuke", "gray"])
	for bad in ["", "   ", "\t", "\n  "]:
		var fb := _invite(S, blank, bad)
		ck("[3] target %s is refused and files nothing (no \"\" key)" % JSON.stringify(bad),
			S.private_queue.is_empty() and not ("" in S.private_queue))
		ck("[3] ...and the sender is told what to do: \"%s\"" % _reason(fb),
			_refused(fb, "username"))

	# =====================================================================================
	# [4] COUNTERWEIGHT — A NORMAL INVITE STILL WORKS.
	# =====================================================================================
	_fresh_queue(S)
	var alpha := _seat(S, "ZZ_Alpha", BASE + 21, ["naruto", "sasuke", "gray"])
	var beta := _seat(S, "ZZ_Beta", BASE + 22, ["inuyasha", "ryohei", "kitara"])
	var f4a := _invite(S, alpha, "ZZ_Beta")
	ck("[4] A->B files EXACTLY ONE invite", S.private_queue.size() == 1)
	ck("[4] ...keyed on the ORDERED PAIR (inviter -> target)", S._invite_key("ZZ_Alpha", "ZZ_Beta") in S.private_queue)
	ck("[4] ...carrying the inviter's peer, package and team",
		S.private_queue.get(S._invite_key("ZZ_Alpha", "ZZ_Beta"), [null])[0] == alpha["peer"]
		and str(S.private_queue.get(S._invite_key("ZZ_Alpha", "ZZ_Beta"), [null, {}])[1].get("username", "")) == "ZZ_Alpha"
		and S.private_queue.get(S._invite_key("ZZ_Alpha", "ZZ_Beta"), [null, null, []])[2] == alpha["chars"])
	ck("[4] a pending invite sends the inviter no refusal: %s" % str(_types(f4a)), f4a.is_empty())

	var f4b := _invite(S, beta, "ZZ_Alpha")
	ck("[4] B->A CONSUMES the invite (private_queue drained)", S.private_queue.is_empty())
	var m4 = S.get_session(alpha["peer"]).current_match
	ck("[4] a real private match was built and seated on BOTH sessions",
		m4 != null and is_instance_valid(m4) and S.get_session(beta["peer"]).current_match == m4)
	ck("[4] ...it is tracked in private_matches", S.private_matches.size() == 1 and S.private_matches[0] == m4)
	ck("[4] ...with both seats present and DISTINCT (the zombie had one)",
		m4 != null and m4.players.size() == 2
		and m4.players.values()[0] != m4.players.values()[1])
	ck("[4] ...and its BattleManager actually started (manager non-null, not the bailed-out zombie)",
		m4 != null and m4.manager != null and is_instance_valid(m4.manager))
	ck("[4] both clients were told the match started: %s" % str(_types(f4b)),
		_types(f4b).count("receive_private_match") == 2)

	# =====================================================================================
	# [5] COUNTERWEIGHT — WHITESPACE AROUND A REAL TARGET IS TRIMMED.
	#     Filed raw, " ZZ_Delta " is a key ZZ_Delta's own `username in private_queue` lookup can
	#     never hit: a permanently unmatchable invite. The client trims too; the server may not
	#     depend on that.
	# =====================================================================================
	_fresh_queue(S)
	var gamma := _seat(S, "ZZ_Gamma", BASE + 31, ["naruto", "sasuke", "gray"])
	var delta := _seat(S, "ZZ_Delta", BASE + 32, ["inuyasha", "ryohei", "kitara"])
	_invite(S, gamma, "  ZZ_Delta  ")
	ck("[5] a padded target is filed under the TRIMMED key",
		S.private_queue.size() == 1 and S._invite_key("ZZ_Gamma", "ZZ_Delta") in S.private_queue)
	ck("[5] ...and NOT under the padded string",
		not (S._invite_key("ZZ_Gamma", "  ZZ_Delta  ") in S.private_queue))
	var f5b := _invite(S, delta, " ZZ_Gamma ")
	ck("[5] the padded invite still PAIRS (trimming did not orphan it)",
		S.private_queue.is_empty() and _types(f5b).count("receive_private_match") == 2)
	var m5 = S.get_session(delta["peer"]).current_match
	ck("[5] ...into a real second match, distinct from [4]'s",
		m5 != null and is_instance_valid(m5) and m5 != m4
		and S.get_session(gamma["peer"]).current_match == m5)

	# Players seated but never matched are parentless; matched ones belong to their BattleManager
	# and go down with S.free().
	for p in _players:
		if is_instance_valid(p) and p.get_parent() == null:
			p.free()
	S.free()
	# NOT COVERED HERE, recorded so the gap is visible rather than assumed:
	#   * two people inviting the SAME target now coexist instead of the second evicting the first
	#     (the pair key makes eviction impossible by construction);
	#   * starting a match no longer collaterally erases an unrelated third party's invite
	#     (start_private_match cleans up by PEER ID via _erase_private_invite, not by username).
	# A block exercising both was written and dropped: seating a third player and building a THIRD
	# real match on a detached ServerConnection hangs the probe (two live shadow managers with turn
	# timers are already running by this point). Both behaviours follow directly from the key shape
	# and the peer-id cleanup, which blocks [4] and [5] do exercise.

	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
