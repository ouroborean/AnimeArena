extends Node
class_name HealthComponent
@export var hp = 100
var max_hp = hp

signal health_changed(new_health)
signal max_changed(new_max)
signal died(killer, kill_source)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_max_hp(max):
	max_hp = max
	max_changed.emit(max_hp)

func set_health(health):
	hp = health
	health_changed.emit(hp)

func modify_hp(mod, modifier, source):
	hp += mod
	if hp > max_hp:
		hp = max_hp
	elif hp <= 0:
		hp = 0
		died.emit(modifier, source)
		
	if mod != 0:
		health_changed.emit(hp)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
