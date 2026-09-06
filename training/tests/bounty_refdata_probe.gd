# Throwaway (backend port proof): dump the STATIC reference tables bounty generation reads, plus
# every character's universe, so a non-Godot generator can rebuild bounty_types / by_universe from
# JSON instead of from GDScript. Dictionary key ORDER is load-bearing (get_archetypes iterates
# `categories` in insertion order, and that order is the index space of every category draw), so
# this is dumped through JSON.stringify, which preserves it.
#   godot --headless --path . --script res://training/tests/bounty_refdata_probe.gd
extends SceneTree

func _init():
	var b = load("res://scripts/bounty.gd").new()

	# Per-character universe ordinal, in char_name_list() order — the exact order
	# CharacterDatabase.by_universe() appends in.
	var roster := []
	for n in CharacterDatabase.char_name_list():
		var c = Character.from_character_name(n)
		roster.append({"path_name": c.path_name, "universe": c.universe})
		c.free()

	# Which characters belong to NO archetype at all? Those hit the categories.keys() fallback in
	# generate_from_details, a different code path worth pinning in the fixture.
	var no_archetype := []
	for n in CharacterDatabase.char_name_list():
		if Bounty.flat_bounty_categories(n).is_empty():
			no_archetype.append(n)

	# Category members that are not roster characters at all (dead data that can still be DRAWN as
	# a mission target) and archetype-list entries that are not category keys (dead, undrawable).
	var roster_names = CharacterDatabase.char_name_list()
	var ghost_members := {}
	for key in b.categories:
		for m in b.categories[key]:
			if not (m in roster_names):
				if not ghost_members.has(key):
					ghost_members[key] = []
				ghost_members[key].append(m)
	var dead_archetypes := []
	for a in b.archetypes:
		if not b.categories.has(a):
			dead_archetypes.append(a)

	var universe_enum := {}
	for k in CharacterConcept.Universe:
		universe_enum[k] = CharacterConcept.Universe[k]

	# Explicit key order + the per-character ordered archetype list. get_archetypes() iterates the
	# `categories` Dictionary in INSERTION order and the result is indexed by randi_range, so this
	# order IS part of the RNG contract. Dumped as an Array as well as the Dictionary because
	# JSON object key order is not guaranteed to survive every consumer.
	var category_order := []
	for key in b.categories:
		category_order.append(key)
	var ordered_archetypes := {}
	for n in roster_names:
		ordered_archetypes[n] = b.get_archetypes(n)

	var out := {
		"category_order": category_order,
		"ordered_archetypes_per_character": ordered_archetypes,
		"mission_types": b.mission_types,
		"categories": b.categories,
		"archetypes": b.archetypes,
		"winning_patterns": b.winning_patterns,
		"mastery_suffix": Bounty.MASTERY_SUFFIX,
		"char_name_list": roster_names,
		"roster": roster,
		"universe_enum": universe_enum,
		"no_archetype_characters": no_archetype,
		"category_members_not_on_roster": ghost_members,
		"archetypes_with_no_category": dead_archetypes,
	}
	DirAccess.make_dir_recursive_absolute("res://backend_port/bounty")
	var f := FileAccess.open("res://backend_port/bounty/reference_data.json", FileAccess.WRITE)
	# sort_keys=FALSE. Godot's JSON.stringify sorts object keys by default, which would silently
	# alphabetise `categories` — and the insertion order of that dict is the index space every
	# category draw is taken from. (The shipped webclient/app/bounty_data.json was written with the
	# default and IS alphabetised: it is safe for the client's membership lookups but must never be
	# used as the generation source.)
	f.store_string(JSON.stringify(out, "  ", false))
	f.close()
	print("[REFDATA] categories=", b.categories.size(), " roster=", roster.size(),
		" universes=", universe_enum.size())
	print("  no_archetype_characters=", no_archetype)
	print("  archetypes_with_no_category=", dead_archetypes)
	print("  ghost category members=", ghost_members)
	b.free()
	quit()
