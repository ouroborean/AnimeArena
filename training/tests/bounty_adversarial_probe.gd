# ADVERSARIAL REVIEW probe (read-only). Independent of bounty_generation_probe.gd: this one exists
# to attack the non-Godot port with input shapes the original fixture never covered --
# very long usernames, large / multi-digit / negative reroll tokens, and usernames built from
# characters that break naive hashing (backslash, quote, newline, tab, NBSP, combining marks,
# ZWJ emoji sequences, the highest legal code point).
#
# It only re-derives cards from inputs; it never reads or writes ausers/ or any live state.
#   godot --headless --path . --script res://training/tests/bounty_adversarial_probe.gd
extends SceneTree

func _init():
	var cases := []

	# Built with String.chr() where the code point matters, so nothing depends on how this
	# source file happens to be encoded on disk.
	var ZWJ := String.chr(0x200D)
	var usernames := [
		"A".repeat(200),                                    # DJB2 over 200 chars, u32 wraps repeatedly
		"a".repeat(1000) + "Z",                             # very long
		"back\\slash",                                      # backslash (escape hazard)
		"quote\"inside",                                    # double quote
		"tab\there",                                        # literal tab
		"new\nline",                                        # literal newline
		"nb" + String.chr(0x00A0) + "space",                # non-breaking space
		"e" + String.chr(0x0301) + "combining",             # e + COMBINING ACUTE (NFD)
		String.chr(0x00E9) + "precomposed",                 # precomposed e-acute (NFC)
		"fam" + String.chr(0x1F468) + ZWJ + String.chr(0x1F469) + ZWJ + String.chr(0x1F466),
		String.chr(0x10FFFF),                               # highest legal code point
		"0",                                                # numeric-looking
		"   ",                                              # whitespace only
	]
	# Paths chosen to hit branch shapes: many-archetype, single-archetype, solo-universe,
	# and the category holding the non-roster ghost string.
	var paths := ["naruto", "goku", "jinwoo", "lizandpatty", "toji"]
	# Reroll tokens the original probe never used (it used only "0".."3").
	var rerolls := ["4", "10", "17", "99", "100", "1000", "999999", "-1", "-42"]

	for u in usernames:
		for p in paths:
			cases.append({"player": u, "path": p, "rerolls": "0", "type": "unlock", "group": "adv_user"})
			cases.append({"player": u, "path": p, "rerolls": "0", "type": "mastery", "group": "adv_user"})
	for rr in rerolls:
		for p in paths:
			cases.append({"player": "Cheshire", "path": p, "rerolls": rr, "type": "unlock", "group": "adv_reroll"})
			cases.append({"player": "Cheshire", "path": p, "rerolls": rr, "type": "mastery", "group": "adv_reroll"})
	# Every roster character at a HIGH reroll count + mastery, which the roster fixture never swept.
	for p in CharacterDatabase.char_name_list():
		cases.append({"player": "Zz", "path": p, "rerolls": "7", "type": "mastery", "group": "adv_roster_mastery"})

	var rows := []
	for c in cases:
		var seed_input: String = c.player + c.path + str(c.rerolls)
		if c.type == "mastery":
			seed_input += Bounty.MASTERY_SUFFIX
		var b = Bounty.get_bounty(c.player, c.path, c.rerolls, c.type)
		rows.append({
			"group": c.group,
			"player": c.player,
			"path": c.path,
			"rerolls": c.rerolls,
			"type": c.type,
			"seed_input": seed_input,
			"seed_hash": hash(seed_input),
			"requires_bounty_target": b.requires_bounty_target,
			"bounty_target_path": b.bounty_target_path,
			"bounty_path": b.bounty_path,
			"missions": b.missions,
		})
		b.free()

	var f := FileAccess.open("res://backend_port/bounty/adversarial_fixture.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"cases": rows}, "  ", false))
	f.close()
	print("[ADVERSARIAL] cases=", rows.size())
	quit()
