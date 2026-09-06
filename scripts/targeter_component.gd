extends Node
class_name TargeterComponent

var targets: Array
var main_target = null
var targeting = false
var targeting_ability = null

func start_targeting(ability):
	reset()
	targeting = true
	targeting_ability = ability

func remove_target(target):
	targets.erase(target)
	if main_target == target:
		if len(targets) > 0:
			main_target = targets[0]
		else:
			main_target = null

func clear_targets():
	targets.clear()
	main_target = null

func add_target(target):
	if main_target == null:
		main_target = target
	targets.append(target)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func end_targeting():
	targeting = false
	targeting_ability = null

func reset():
	targets.clear()
	targeting = false
	main_target = null
	targeting_ability = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
