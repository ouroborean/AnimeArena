extends Node
# DIAGNOSTIC: is "who goes first" fair? Replicates the exact live code path:
#   start_ranked_match: var rng = RandomNumberGenerator.new(); var seed = rng.randi_range(1, 6900000)
#   Match.from_players: coin_rng.set_seed(seed); var p1_first = coin_rng.randi_range(0, 1) == 1
#   godot --headless --path <repo> res://training/tests/coinflip_diag_probe.tscn

func _ready():
	print("=== coin-flip diagnostic ===")

	# 1. Is a FRESH RandomNumberGenerator auto-randomized, or does it start from a fixed seed?
	var seeds := []
	for i in range(8):
		var rng := RandomNumberGenerator.new()
		seeds.append(rng.randi_range(1, 6900000))
	var all_same: bool = seeds.all(func(x): return x == seeds[0])
	print("[1] 8 fresh-RNG seeds (the live seed source): ", seeds)
	print("    ALL IDENTICAL: ", all_same, "  <-- if true, every match uses the SAME seed")

	var N := 20000
	# 2. EXACT live path: fresh RNG for the seed, fresh RNG for the coin.
	var p1first := 0
	var seed_vals := {}
	for i in range(N):
		var rng := RandomNumberGenerator.new()
		var s: int = rng.randi_range(1, 6900000)
		seed_vals[s] = true
		var coin := RandomNumberGenerator.new()
		coin.set_seed(s)
		if coin.randi_range(0, 1) == 1:
			p1first += 1
	print("[2] LIVE PATH p1_first over %d matches: %d (%.1f%%) | distinct seeds seen: %d" % [N, p1first, 100.0 * p1first / N, seed_vals.size()])

	# 3. If the seed WERE randomized properly, is the coin itself fair?
	var p1f2 := 0
	for i in range(N):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var s: int = rng.randi_range(1, 6900000)
		var coin := RandomNumberGenerator.new()
		coin.set_seed(s)
		if coin.randi_range(0, 1) == 1:
			p1f2 += 1
	print("[3] with randomize()d seeds, p1_first: %d (%.1f%%)  <-- what a proper fix would give" % [p1f2, 100.0 * p1f2 / N])

	# 4. Is set_seed()+randi_range(0,1) biased across SEQUENTIAL seeds (counter-like sources)?
	var seqp1 := 0
	for s in range(1, N + 1):
		var coin := RandomNumberGenerator.new()
		coin.set_seed(s)
		if coin.randi_range(0, 1) == 1:
			seqp1 += 1
	print("[4] coin over sequential seeds 1..%d: %d (%.1f%%)" % [N, seqp1, 100.0 * seqp1 / N])

	# 5. The HARDENED live helper (_fresh_match_seed = randomize() + randi_range): entropy + coin fairness.
	var S = load("res://components/server_connection.gd").new()
	var hseeds := {}
	var hp1 := 0
	for i in range(N):
		var s: int = S._fresh_match_seed()
		hseeds[s] = true
		var coin := RandomNumberGenerator.new()
		coin.set_seed(s)
		if coin.randi_range(0, 1) == 1:
			hp1 += 1
	print("[5] HARDENED _fresh_match_seed over %d: %d distinct seeds (was ~16334 unhardened) | coin p1_first %.1f%%" % [N, hseeds.size(), 100.0 * hp1 / N])

	print("=== done ===")
	get_tree().quit()
