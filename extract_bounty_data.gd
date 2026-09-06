# One-off: dump the bounty static data the web client needs (archetype categories,
# the 5x5 winning patterns, the archetype list, and the starter squads for eligibility).
#   Run:  godot --headless --path . --script res://extract_bounty_data.gd
extends SceneTree

func _init():
	var b = load("res://scripts/bounty.gd").new()
	var out = {
		"categories": b.categories,            # archetype -> [path_name]
		"winning_patterns": b.winning_patterns, # 12 index-arrays over the 25-cell grid
		"archetypes": b.archetypes,            # ordered archetype names (membership test)
		"starters": CharacterDatabase.starter_squads(),  # starter (always-owned) path_names
	}
	var f = FileAccess.open("res://webclient/app/bounty_data.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("[BOUNTY] categories=", b.categories.size(), " patterns=", b.winning_patterns.size(), " archetypes=", b.archetypes.size(), " starters=", CharacterDatabase.starter_squads().size())
	quit()
