extends Node

# Probe for the authored-asset kill-switch EXEMPTION (#73). The Character Creator kill switch gates
# NEW authoring, but approved content is LIVE content: while the switch is OFF, a plain (non-admin)
# player facing an admin who fielded an approved authored character must still be able to STREAM that
# character's portrait. So authored_asset_fetch is routed OUTSIDE the `authored_*` gate in
# ServerConnection._on_json_message, while every other authored_* frame is still blocked.
#
# We drive the REAL _on_json_message with a stub gateway (capturing sent frames) and a real, non-admin
# session, so the assertion has teeth: it fails if the one-line exemption is removed OR widened to let
# another authoring frame through. Uses a ZZ_-prefixed throwaway author + an auth_zz id, and cleans up.

var pass_n := 0
var fail_n := 0

# Records every frame the server tries to send, so the probe can inspect the routing decision.
class GatewayStub:
	var sent: Array = []
	func send(_pid: int, frame: Dictionary) -> void: sent.append(frame)
	func send_queued(_pid: int, frame: Dictionary) -> void: sent.append(frame)
	func clear() -> void: sent.clear()
	func types() -> Array:
		var out: Array = []
		for f in sent: out.append(str(f.get("type", "")))
		return out
	func first_of(t: String) -> Dictionary:
		for f in sent:
			if str(f.get("type", "")) == t: return f
		return {}

# True iff any streamed authored_asset_data frame actually carried portrait bytes (a `data`
# payload) — a {missing} frame has no `data`, so this distinguishes "served" from "refused".
func _streamed_bytes(gw) -> bool:
	for f in gw.sent:
		if str(f.get("type", "")) == "authored_asset_data" and f.has("data") and str(f.get("data", "")) != "":
			return true
	return false

# Minimal live-match stub tree for the ITEM 3 CARVE-OUT test. _char_in_live_match walks
# session.current_match -> manager -> {player,enemy}.team.characters[].path_name, so the stub only
# needs those fields. Inner classes default to RefCounted, so is_instance_valid() holds while a local
# reference is alive.
class MatchStub:
	var manager
class MgrStub:
	var player
	var enemy
class SideStub:
	var team
class TeamStub:
	var characters: Array = []
class CharStub:
	var path_name: String = ""

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

func _mk_spec(id: String, author: String) -> Dictionary:
	# Same minimal 4-active shape the icon probe saves cleanly; status=approved so can_use is public.
	var ability := {
		"name": "A", "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Instant", "Harmful", "Damaging"],
		"blocks": [{"op": "damage", "amount": 10, "damage_type": "NORMAL"}],
		"requires": [],
	}
	var abilities: Array = []
	for nm in ["A", "B", "C", "D"]:
		var a := ability.duplicate(true)
		a["name"] = nm
		abilities.append(a)
	return {
		"id": id, "name": "Asset Probe", "author": author, "status": "approved",
		"colors": [0], "description": "probe", "abilities": abilities,
	}

func _ready() -> void:
	print("=== authored asset kill-switch probe ===")
	var author := "ZZ_ASSET_PROBE"
	var cid := "auth_zzassetprobe1"

	# --- an approved authored character with a portrait on disk -----------------
	var save_errs := AuthoredRegistry.save_spec(_mk_spec(cid, author))
	ck("(setup) approved spec saved %s" % [save_errs], save_errs.is_empty())
	# is_approved (not can_use) is the approval proxy here: since the owner ruling made can_use ADMIN-ONLY,
	# can_use(cid, "SomeoneElse", ...) is now false for any status. The asset carve-out this probe covers
	# keys on APPROVAL (is_approved) + author + live-match membership, not on can_use, so this is the honest check.
	ck("(setup) it reads back as approved", AuthoredRegistry.is_approved(cid))
	AuthoredAssets._ensure_dir(cid)
	var pf := FileAccess.open(AuthoredAssets.asset_path(cid, "portrait"), FileAccess.WRITE)
	pf.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]))   # fetch reads raw bytes; it does not re-validate PNG
	pf.close()
	ck("(setup) portrait asset exists", AuthoredAssets.has_asset(cid, "portrait"))

	# --- a real, NON-admin session on a web (JSON) peer -------------------------
	var sc = load("res://components/server_connection.gd").new()
	var gw := GatewayStub.new()
	sc.json_gateway = gw
	var player := Player.new()
	player.username = author
	var pid := 42
	var lpid: int = ServerConnection.JSON_PEER_BASE + pid
	sc.peer_map[lpid] = author
	sc.sessions[author] = ServerConnection.ServerSession.new(author, lpid, player)

	sc.creator_enabled = false   # the switch is OFF
	ck("author is a normal (non-admin) player", sc._creator_blocked(author))

	# --- every OTHER authored_* frame is still blocked while OFF ----------------
	gw.clear()
	sc._on_json_message(pid, {"type": "authored_list"})
	var listed := gw.first_of("error")
	ck("authored_list is BLOCKED by the kill switch (%s)" % str(listed.get("reason", gw.types())),
		not listed.is_empty() and str(listed.get("reason", "")).contains("Character Creator"))
	ck("...and it did NOT leak an authored_list frame", not ("authored_list" in gw.types()))

	# --- authored_asset_fetch is EXEMPT: it serves the live portrait ------------
	gw.clear()
	sc._on_json_message(pid, {"type": "authored_asset_fetch", "id": cid, "slot": "portrait"})
	ck("asset fetch is NOT blocked by the kill switch", gw.first_of("error").is_empty())
	var data := gw.first_of("authored_asset_data")
	ck("asset fetch streamed the portrait while the Creator is OFF (%s)" % gw.types(),
		not data.is_empty() and not bool(data.get("missing", false)) and str(data.get("id", "")) == cid)

	# --- a logged-out peer still gets nothing (the handler's own guard) ---------
	gw.clear()
	sc._on_json_message(99, {"type": "authored_asset_fetch", "id": cid, "slot": "portrait"})
	ck("asset fetch from an unknown peer errors (not logged in)",
		str(gw.first_of("error").get("reason", "")) == "not logged in")

	# --- ITEM 3: the APPROVAL GATE on the PUBLIC opponent-facing fetch -----------
	# ABUSE: a logged-in player who GUESSES another author's id could pull their UNAPPROVED
	# work-in-progress art. The fetch must serve APPROVED content only — except the author's OWN,
	# which rides the editor-preview path through this same frame.
	# HAND-REVERSAL: in the authored_asset_fetch handler, drop `fauthorised and` from the fbytes
	# condition => the unapproved-id-to-a-stranger fetch below streams instead of {missing} (the two
	# NEGATIVE asserts go red), while the approved (section above) and own-author cases stay green.
	var other_author := "ZZ_OTHER_AUTHOR"
	var uid := "auth_zzunapproved1"
	var wip := _mk_spec(uid, other_author)
	wip["status"] = "submitted"                       # authored, on disk, but NOT approved
	var wip_errs := AuthoredRegistry.save_spec(wip)
	ck("(setup) unapproved spec saved %s" % [wip_errs], wip_errs.is_empty())
	ck("(setup) it is authored but NOT approved",
		AuthoredRegistry.is_authored(uid) and not AuthoredRegistry.is_approved(uid))
	AuthoredAssets._ensure_dir(uid)
	var wf := FileAccess.open(AuthoredAssets.asset_path(uid, "portrait"), FileAccess.WRITE)
	wf.store_buffer(PackedByteArray([9, 8, 7, 6, 5, 4, 3, 2]))
	wf.close()
	ck("(setup) unapproved portrait exists on disk", AuthoredAssets.has_asset(uid, "portrait"))

	# NEGATIVE: the ZZ_ASSET_PROBE session (a logged-in player who is NOT the author) asks for the
	# UNAPPROVED id and gets {missing} — even though the spec and the asset both exist on disk.
	gw.clear()
	sc._on_json_message(pid, {"type": "authored_asset_fetch", "id": uid, "slot": "portrait"})
	var wdata := gw.first_of("authored_asset_data")
	ck("a stranger fetching an UNAPPROVED id gets missing (the approval gate) (%s)" % gw.types(),
		not wdata.is_empty() and bool(wdata.get("missing", false)))
	ck("...and no portrait bytes leaked for the unapproved id",
		gw.first_of("error").is_empty() and not _streamed_bytes(gw))

	# {missing} is IDENTICAL to a truly-absent id, so the response never reveals the id exists.
	gw.clear()
	sc._on_json_message(pid, {"type": "authored_asset_fetch", "id": "auth_doesnotexist9", "slot": "portrait"})
	var ndata := gw.first_of("authored_asset_data")
	ck("a truly-absent id answers the SAME {missing} (existence is not leaked)",
		not ndata.is_empty() and bool(ndata.get("missing", false)))

	# POSITIVE CONTROL: the author's OWN session streams the unapproved art (the editor preview path).
	# A second real, non-admin session owned by ZZ_OTHER_AUTHOR on the same server-connection.
	var other_player := Player.new()
	other_player.username = other_author
	var opid := 43
	var olpid: int = ServerConnection.JSON_PEER_BASE + opid
	sc.peer_map[olpid] = other_author
	sc.sessions[other_author] = ServerConnection.ServerSession.new(other_author, olpid, other_player)
	gw.clear()
	sc._on_json_message(opid, {"type": "authored_asset_fetch", "id": uid, "slot": "portrait"})
	var odata := gw.first_of("authored_asset_data")
	ck("the AUTHOR fetching their OWN unapproved art still streams it (editor preview) (%s)" % gw.types(),
		not odata.is_empty() and not bool(odata.get("missing", false)) and _streamed_bytes(gw))

	# --- ITEM 3 CARVE-OUT: the OPPONENT in a live match renders the author's OWN fielded unapproved
	# character. can_use() lets an author FIELD their unapproved character in a Bot/Private match; in a
	# Private match vs a human, the opponent (NOT the author, NOT an approver) must still stream that
	# character's portrait, or their board paints a broken portrait for a character sitting right there.
	# The `uid` stranger-fetch above already proved a match-LESS stranger gets {missing}; here the SAME
	# kind of stranger, but with `uid` fielded in their current match, streams it — the only difference
	# is match membership, so this isolates the carve-out.
	# HAND-REVERSAL: drop the `or _char_in_live_match(...)` arm from the gate => this first assert goes red
	# while the stranger-without-a-match assert above stays green.
	var viewer := Player.new()
	viewer.username = "ZZ_MATCH_VIEWER"
	var vpid := 45
	var vlpid: int = ServerConnection.JSON_PEER_BASE + vpid
	sc.peer_map[vlpid] = "ZZ_MATCH_VIEWER"
	var vsess = ServerConnection.ServerSession.new("ZZ_MATCH_VIEWER", vlpid, viewer)
	sc.sessions["ZZ_MATCH_VIEWER"] = vsess
	var fielded := CharStub.new(); fielded.path_name = uid
	var vteam := TeamStub.new(); vteam.characters = [fielded]
	var enemy_side := SideStub.new(); enemy_side.team = vteam
	var own_side := SideStub.new(); own_side.team = TeamStub.new()   # the viewer's own side, no authored char
	var vmgr := MgrStub.new(); vmgr.player = own_side; vmgr.enemy = enemy_side
	var vmatch := MatchStub.new(); vmatch.manager = vmgr
	vsess.current_match = vmatch
	gw.clear()
	sc._on_json_message(vpid, {"type": "authored_asset_fetch", "id": uid, "slot": "portrait"})
	var vdata := gw.first_of("authored_asset_data")
	ck("the OPPONENT fielding the author's unapproved char in their live match streams it (%s)" % gw.types(),
		not vdata.is_empty() and not bool(vdata.get("missing", false)) and _streamed_bytes(gw))
	# SCOPING GUARD: emptying that team flips the SAME viewer+id back to {missing} — proving the carve-out
	# keys on ACTUAL membership (path_name match), not merely "the requester happens to be in a match".
	vteam.characters = []
	gw.clear()
	sc._on_json_message(vpid, {"type": "authored_asset_fetch", "id": uid, "slot": "portrait"})
	var vgone := gw.first_of("authored_asset_data")
	ck("...emptying the fielded team flips the SAME fetch back to missing (keyed on membership)",
		not vgone.is_empty() and bool(vgone.get("missing", false)))

	# --- cleanup ---------------------------------------------------------------
	viewer.free()
	other_player.free()
	player.free()
	sc.free()
	AuthoredAssets.delete_all(cid)
	AuthoredRegistry.delete_spec(cid, author, true)
	AuthoredAssets.delete_all(uid)
	AuthoredRegistry.delete_spec(uid, other_author, true)
	ck("(cleanup) spec removed", not AuthoredRegistry.is_authored(cid))
	ck("(cleanup) portrait removed", not AuthoredAssets.has_asset(cid, "portrait"))
	ck("(cleanup) unapproved spec removed", not AuthoredRegistry.is_authored(uid))

	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
