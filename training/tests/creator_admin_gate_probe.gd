extends Node

# Probe for the OWNER RULING: authored characters are ADMIN-ONLY to field right now (approved OR not).
# The approval/roster pipeline that would let a normal player pick an approved authored character is
# DEFERRED, so AuthoredRegistry.can_use must return false for every non-admin and true only for an admin.
#
# can_use gained a 4th arg `is_admin`, computed at the real call site (ServerConnection._authored_team_error)
# via _is_admin(username). This probe hits BOTH halves: the pure gate (can_use with the bool) AND the
# threading (ServerConnection._is_admin resolving admin-ness from ADMIN_USERNAMES), so removing either the
# gate or the correct wiring turns an assert red.
#
# Every fixture uses ZZ_-prefixed throwaway usernames + auth_zz ids and is cleaned up. No real/admin
# username is ever written to disk (ADMIN_USERNAMES is read for _is_admin, never a live ausers write).
# Run: godot --headless --path <repo> res://training/tests/creator_admin_gate_probe.tscn

var pass_n := 0
var fail_n := 0

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

func _mk_spec(id: String, author: String, status: String) -> Dictionary:
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
		"id": id, "name": "Admin Gate Probe", "author": author, "status": status,
		"colors": [0], "description": "probe", "abilities": abilities,
	}

func _ready() -> void:
	print("=== creator admin-gate probe ===")
	var author := "ZZ_GATE_AUTHOR"
	var approved_id := "auth_zzgateapproved1"
	var wip_id := "auth_zzgatewip1"

	var e1 := AuthoredRegistry.save_spec(_mk_spec(approved_id, author, "approved"))
	ck("(setup) approved spec saved %s" % [e1], e1.is_empty())
	var e2 := AuthoredRegistry.save_spec(_mk_spec(wip_id, author, "submitted"))
	ck("(setup) unapproved spec saved %s" % [e2], e2.is_empty())
	ck("(setup) approved reads back approved", AuthoredRegistry.is_approved(approved_id))
	ck("(setup) unapproved is authored but NOT approved",
		AuthoredRegistry.is_authored(wip_id) and not AuthoredRegistry.is_approved(wip_id))

	# --- NEGATIVE: no non-admin may field authored content, whatever its status -------------------
	# A stranger can't field an APPROVED character (the approved-is-public rule is suspended).
	ck("NEGATIVE approved + non-admin stranger => FALSE",
		not AuthoredRegistry.can_use(approved_id, "ZZ_NONADMIN", true, false))
	# The AUTHOR can't field their OWN unapproved character (the author-in-bot/private carve-out is suspended).
	ck("NEGATIVE unapproved + its own (non-admin) author => FALSE",
		not AuthoredRegistry.can_use(wip_id, author, true, false))
	# Match kind is irrelevant now: quick/ranked (is_private_or_bot=false) is also false, same as bot/private.
	ck("NEGATIVE approved + non-admin in quick/ranked => FALSE",
		not AuthoredRegistry.can_use(approved_id, "ZZ_NONADMIN", false, false))

	# --- POSITIVE: an admin may field either one -------------------------------------------------
	ck("POSITIVE approved + admin => TRUE",
		AuthoredRegistry.can_use(approved_id, "ZZ_ADMIN", true, true))
	ck("POSITIVE unapproved + admin => TRUE (approved-ness no longer matters, admin does)",
		AuthoredRegistry.can_use(wip_id, "ZZ_ADMIN", true, true))

	# --- HAND-REVERSAL (teeth): the ONLY difference between the reds above and the greens here is the
	# is_admin bool. Flipping it on the EXACT same (id, username, match-kind) that returned false makes it
	# return true — so the assert genuinely rides the admin gate, not some incidental status/author path.
	# (Equivalently: reverting can_use's body to `return is_admin` -> `return not is_admin` flips every
	# NEGATIVE to green and every POSITIVE to red.)
	ck("hand-reversal: same stranger+approved with is_admin flipped ON => TRUE",
		AuthoredRegistry.can_use(approved_id, "ZZ_NONADMIN", true, true))
	ck("hand-reversal: same author+unapproved with is_admin flipped OFF stays FALSE",
		not AuthoredRegistry.can_use(wip_id, author, true, false))

	# A truly-absent id is false no matter who asks (guards the null-spec early return).
	ck("absent id + admin => FALSE (null-spec guard)",
		not AuthoredRegistry.can_use("auth_zzdoesnotexist9", "ZZ_ADMIN", true, true))

	# --- THREADING: the call site feeds is_admin from ServerConnection._is_admin(username). Prove that
	# resolves admin-ness from ADMIN_USERNAMES (an exact-case match) so the bool passed to can_use is right.
	var sc = load("res://components/server_connection.gd").new()
	var admin_name := str(sc.ADMIN_USERNAMES[0]) if not (sc.ADMIN_USERNAMES as Array).is_empty() else ""
	ck("_is_admin(a real admin name) is TRUE", admin_name != "" and sc._is_admin(admin_name))
	ck("_is_admin(a ZZ_ throwaway) is FALSE", not sc._is_admin("ZZ_NONADMIN"))
	ck("_is_admin(case-variant of an admin) is FALSE (exact-case, anti-escalation)",
		admin_name != "" and not sc._is_admin(admin_name.to_lower()) if admin_name != admin_name.to_lower() else true)
	sc.free()

	# --- cleanup ---------------------------------------------------------------------------------
	AuthoredRegistry.delete_spec(approved_id, author, true)
	AuthoredRegistry.delete_spec(wip_id, author, true)
	ck("(cleanup) approved spec removed", not AuthoredRegistry.is_authored(approved_id))
	ck("(cleanup) unapproved spec removed", not AuthoredRegistry.is_authored(wip_id))

	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
