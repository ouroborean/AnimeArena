extends Node

# Probe for authored SKILL ICONS: the icon<->slot binding must survive the one
# mutation the editor actually forces (remove a skill, then add one, because
# `actives != 4` is a hard save error), and no client-supplied string may ever
# reach AuthoredAssets.asset_path.

var pass_n := 0
var fail_n := 0

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

func _mk_ability(nm: String, passive := false) -> Dictionary:
	var a := {
		"name": nm, "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Passive"] if passive else ["Instant", "Harmful", "Damaging"],
		"blocks": [{"op": "damage", "amount": 10, "damage_type": "NORMAL"}],
		"requires": [],
	}
	if passive:
		a["target"] = "self"
		a["blocks"] = [{"op": "apply", "to": "user", "effect": {"kind": "heal_over_time", "amount": 5, "turns": -1}}]
	return a

func _mk_spec(id: String) -> Dictionary:
	return {
		"id": id, "name": "Icon Probe", "author": "ZZ_PROBE", "status": "draft",
		"colors": [0], "description": "probe",
		"abilities": [_mk_ability("A"), _mk_ability("B"), _mk_ability("C"), _mk_ability("D")],
	}

func _ready() -> void:
	print("=== authored icon probe ===")

	# --- slot allocation -----------------------------------------------------
	var spec := _mk_spec("auth_zzprobe1")
	ck("first upload for skill 0 gets ability1", AuthoredRegistry.allocate_icon_slot(spec, 0) == "ability1")
	spec["abilities"][0]["icon"] = "ability1"
	ck("first upload for skill 1 gets ability2", AuthoredRegistry.allocate_icon_slot(spec, 1) == "ability2")
	spec["abilities"][1]["icon"] = "ability2"
	ck("re-upload for skill 0 REUSES ability1 (overwrite, no leak)", AuthoredRegistry.allocate_icon_slot(spec, 0) == "ability1")
	ck("out-of-range index allocates nothing", AuthoredRegistry.allocate_icon_slot(spec, 9) == "")

	# --- THE forced flow: remove a skill, then add one -----------------------
	# [A(ab1) B(ab2) C D] -> remove B -> [A(ab1) C D] -> add E -> [A(ab1) C D E]
	# Positional binding would now show A's picture on nobody and hand C the
	# "ability2" file that belonged to B. The binding must travel with the object.
	spec["abilities"][2]["icon"] = "ability3"
	spec["abilities"].remove_at(1)                       # drop B
	spec["abilities"].append(_mk_ability("E"))
	# Asserted through allocate_icon_slot — the function that actually decides which file a
	# re-upload overwrites. Reading the dicts straight back would only assert Array.remove_at:
	# no project code runs between the assignment and the read, so a positional binding scheme
	# would sail through it. Routed through the allocator, a positional scheme fails here (it
	# would hand index 1 "ability2", which is B's dead file, instead of C's own "ability3").
	ck("after remove+add, a re-upload for A still resolves to A's own file",
		AuthoredRegistry.allocate_icon_slot(spec, 0) == "ability1")
	ck("after remove+add, C keeps ability3 (it did not inherit B's ability2)",
		AuthoredRegistry.allocate_icon_slot(spec, 1) == "ability3")
	var freed := AuthoredRegistry.allocate_icon_slot(spec, 3)
	ck("new skill E inherits nothing and reuses B's now-unreferenced slot (%s)" % freed, freed == "ability2")
	spec["abilities"][3]["icon"] = freed                 # E's upload lands and is bound
	var d_slot := AuthoredRegistry.allocate_icon_slot(spec, 2)
	ck("D, still unbound, is handed a DIFFERENT free slot (%s) — no two skills share a picture" % d_slot,
		d_slot == "ability4")

	# --- stale-index guard: driven through the REAL server handler -----------
	# The client indexes its UNSAVED working copy; the server resolves against the
	# SAVED spec. Removing a skill is the forced flow (actives != 4 blocks saving),
	# so the two diverge routinely. Uploading then must NOT resolve to another skill
	# and overwrite its art — the name is what proves both sides mean the same skill.
	#
	# The guard is ServerConnection._authored_upload (the `uabs[aidx].name != uname` bail), so
	# CALL IT. Comparing two strings the probe wrote itself left that guard deletable.
	var sc = load("res://components/server_connection.gd").new()
	var author := "ZZ_ICON_PROBE"
	var saved := _mk_spec("auth_zzprobe5")
	saved["author"] = author
	saved["abilities"][0]["icon"] = "ability1"
	saved["abilities"][3]["icon"] = "ability4"
	var save_errs := AuthoredRegistry.save_spec(saved)
	ck("(setup) the saved spec stored cleanly %s" % [save_errs], save_errs.is_empty())
	ck("saved index 3 is D, not the client's E (the desync is real)",
		str(saved["abilities"][3].get("name", "")) == "D")
	ck("without the guard the upload would have opened onto D's slot",
		AuthoredRegistry.allocate_icon_slot(saved, 3) == "ability4")
	# Working copy after "remove B, add E" is [A, C, D, E], so uploading for E sends index 3
	# with name "E" — while saved index 3 is still D.
	var stale = sc._authored_upload(author, {"type": "authored_upload_begin", "id": "auth_zzprobe5",
		"ability_index": 3, "ability_name": "E", "bytes": 1024, "chunks": 1})
	ck("name check REJECTS the stale index (%s)" % [stale.get("reason", stale.get("type", "?"))],
		str(stale.get("type", "")) == "error" and str(stale.get("reason", "")).begins_with("Save your changes"))
	ck("...so no upload was opened — D's ability4 art was never at risk",
		AuthoredAssets.peek(author).is_empty())
	# The SAME index is accepted once the two sides agree on the name.
	var good = sc._authored_upload(author, {"type": "authored_upload_begin", "id": "auth_zzprobe5",
		"ability_index": 3, "ability_name": "D", "bytes": 1024, "chunks": 1})
	ck("name check ACCEPTS a matching index (%s)" % [good.get("reason", good.get("type", "?"))],
		str(good.get("type", "")) == "authored_upload_ready")
	ck("...and it opened onto D's OWN slot (%s)" % str(AuthoredAssets.peek(author).get("slot", "")),
		str(AuthoredAssets.peek(author).get("slot", "")) == "ability4")
	AuthoredAssets.finish(author)
	AuthoredRegistry.delete_spec("auth_zzprobe5", author, false)
	sc.free()

	# --- sanitization: the security boundary ---------------------------------
	var evil := _mk_spec("auth_zzprobe2")
	evil["abilities"][0]["icon"] = "../../../../etc/passwd"
	evil["abilities"][1]["icon"] = "portrait"             # must not be stealable by a skill
	evil["abilities"][2]["icon"] = "ability2"
	evil["abilities"][3]["icon"] = "ability2"             # duplicate
	AuthoredRegistry._sanitize_icons(evil)
	ck("path-traversal icon scrubbed", str(evil["abilities"][0]["icon"]) == "")
	ck("'portrait' rejected as a skill icon", str(evil["abilities"][1]["icon"]) == "")
	ck("first claimant of a slot keeps it", str(evil["abilities"][2]["icon"]) == "ability2")
	ck("duplicate slot scrubbed (no two skills share a picture)", str(evil["abilities"][3]["icon"]) == "")
	var nonstr := _mk_spec("auth_zzprobe3")
	nonstr["abilities"][0]["icon"] = 7
	AuthoredRegistry._sanitize_icons(nonstr)
	ck("non-string icon scrubbed", str(nonstr["abilities"][0]["icon"]) == "")

	# --- ability slots exclude the portrait ----------------------------------
	# The count TRACKS the ability ceiling rather than being hard-coded: a hidden skill
	# is swapped onto the board mid-match, so it is seen and needs its own art, and a
	# character may now carry up to LIMITS.max_abilities of them. What this asserts is
	# the invariant that has teeth — the portrait is not an ability slot, and every
	# ability index has exactly one slot.
	var slots := AuthoredAssets.ability_slots()
	var want_slots: Array = []
	for i in range(BlockSchema.LIMITS["max_abilities"]):
		want_slots.append("ability%d" % (i + 1))
	ck("ability_slots() is one slot per ability, portrait excluded (%d)" % slots.size(), slots == want_slots)
	ck("...and 'portrait' is not among them", not ("portrait" in slots))
	ck("asset_path stays inside the character's dir", AuthoredAssets.asset_path("auth_x", "ability1").ends_with("auth_x/ability1.png"))

	# --- Passive must not steal a display slot -------------------------------
	# display_abilities() is a blind [0..3] slice, so a Passive authored FIRST
	# would take a board slot and push a real skill off the wire entirely.
	var pspec := _mk_spec("auth_zzprobe4")
	pspec["abilities"].insert(0, _mk_ability("P", true))   # passive at index 0
	var ch := AuthoredCharacter.new()
	ch.spec = pspec
	var built: Array = ch._build_moveset()
	ck("moveset keeps all 5 abilities", built.size() == 5)
	var first4_names := []
	for i in range(4):
		first4_names.append(built[i].ability_name)
	ck("the 4 display slots are the ACTIVE skills, in order", first4_names == ["A", "B", "C", "D"])
	ck("the Passive is sorted last", built[4].ability_name == "P")
	ck("passive is still flagged Passive after reorder", built[4].classes["Passive"])
	for a in built:
		a.free()
	ch.free()

	# --- icon_slot reaches the ability object --------------------------------
	var sa := ScriptedAbility.new()
	sa.configure({"blocks": [], "target": "enemy", "icon": "ability3"})
	ck("ScriptedAbility.configure picks up icon_slot", sa.icon_slot == "ability3")
	var sb := ScriptedAbility.new()
	sb.configure({"blocks": [], "target": "enemy"})
	ck("missing icon -> empty icon_slot (wire ships nothing)", sb.icon_slot == "")
	sa.free()
	sb.free()

	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
