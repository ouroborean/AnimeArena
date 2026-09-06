extends Node
class_name EnergyPool

var pool: Dictionary = {
	Energy.Type.GREEN: 0,
	Energy.Type.BLUE: 0,
	Energy.Type.WHITE: 0,
	Energy.Type.RED: 0
}

var promised_pool: Dictionary = {
	Energy.Type.GREEN: 0,
	Energy.Type.BLUE: 0,
	Energy.Type.WHITE: 0,
	Energy.Type.RED: 0,
	Energy.Type.RANDOM: 0
}
# NOTE: this pool used to own an `EnergyDisplay` UI node (res://ui/energy_display.tscn),
# instantiated as a child by energypool.tscn — meaning every team in every match built a
# UI subtree on the headless server. The desktop client is retired and the web client
# renders energy from the wire snapshot, so the display and its mirror calls are gone.

func reset_pool():
	pool = {
		Energy.Type.GREEN: 0,
		Energy.Type.BLUE: 0,
		Energy.Type.WHITE: 0,
		Energy.Type.RED: 0
	}
	promised_pool = {
		Energy.Type.GREEN: 0,
		Energy.Type.BLUE: 0,
		Energy.Type.WHITE: 0,
		Energy.Type.RED: 0,
		Energy.Type.RANDOM: 0
	}


func total_available():
	var count = 0
	for key in pool:
		count += pool[key]
		count -= promised_pool[key]
	count -= promised_pool[Energy.Type.RANDOM]
	return count

func can_exchange():
	for key in pool:
		var key_count = 0
		key_count += pool[key]
		key_count -= promised_pool[key]
		if key_count >= 2 and total_available() >= 2:
			return true
	return false

func true_pool():
	var output = {}
	for key in pool:
		output[key] = pool[key] - promised_pool[key]
	return output

func can_afford(cost):
	return _can_afford_from(cost, true_pool(), total_available())

# Affordability as if a pending 2-for-1 exchange (give `offer`, get 1 `request`) were applied
# first — mirrors accept_exchange's pool delta on a COPY of the pool (nothing is mutated).
# Used by Match.validate_input for web clients that bundle the exchange in submit_turn_input
# (the real exchange is applied later, in apply_input), so an exchange-to-fund turn validates.
func can_afford_after_exchange(cost, offer, request):
	var current_pool = true_pool()
	var total = total_available()
	for et in offer:
		var color = int(et)
		var amount = int(offer[et])
		current_pool[color] = int(current_pool.get(color, 0)) - amount
		total -= amount
	var req = int(request)
	current_pool[req] = int(current_pool.get(req, 0)) + 1
	total += 1
	return _can_afford_from(cost, current_pool, total)

func _can_afford_from(cost, current_pool, total):
	for energy_type in cost:
		var amount = cost[energy_type]
		if total < amount:
			return false
		if not energy_type == Energy.Type.RANDOM:
			if current_pool[energy_type] < amount:
				return false
			else:
				total -= amount
	return true

func clear_promised_pool():
	promised_pool = {
		Energy.Type.GREEN: 0,
		Energy.Type.BLUE: 0,
		Energy.Type.WHITE: 0,
		Energy.Type.RED: 0,
		Energy.Type.RANDOM: 0
	}



func receive_generic_allocation_offer(offer, replaying=false):
	if not replaying:
		for energy_type in pool:
			offer.append([energy_type, promised_pool[energy_type]])
	clear_promised_pool()
	for offer_set in offer:
		# int() coercion: web clients send energy_allocation over JSON, where numbers
		# arrive as float; without this the pool drifts to float values. (change_energy
		# already int()s element; count was the gap.) Godot RPC path is unchanged.
		var element = int(offer_set[0])
		var count = int(offer_set[1])
		change_energy(element, -count)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func change_energy(element, val):
	element = int(element)
	# `pool` is keyed on GREEN/BLUE/WHITE/RED only — RANDOM is a cost token, not
	# a storable color. If something tries to add or drain RANDOM directly we
	# want to fail loudly instead of auto-vivifying `pool[4]` into a fake
	# negative bucket. Callers that need to spend RANDOM should go through
	# receive_generic_allocation_offer (which the random panel resolves into
	# specific colors) or change_promised_energy.
	if element == Energy.Type.RANDOM:
		push_error("EnergyPool.change_energy called with RANDOM type — route through receive_generic_allocation_offer instead")
		return
	if val > 0:
		gain_energy(element, val)
	else:
		lose_energy(element, val)

func change_promised_energy(element, val):
	if val > 0:
		gain_promised_energy(element, val)
	else:
		lose_promised_energy(element, val)

func gain_promised_energy(element, val):
	promised_pool[element] += val
	
func lose_promised_energy(element, val):
	promised_pool[element] += val

func gain_energy(element, val):
	pool[element] += val

func lose_energy(element, val):
	element = int(element)
	
	pool[element] += val
	
func promise_energy(element, val):
	promised_pool[element] += val

func open_energy_exchange():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
