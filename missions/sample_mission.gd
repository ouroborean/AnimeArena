extends Mission

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func get_objectives():
	
	var sakura_wins = Objective.win_objective(10, false, ["Sakura Haruno"])
	var sasuke_wins = Objective.win_objective(10, false, ["Sasuke Uchiha"])
	var kirishima_wins = Objective.win_objective(10, false, ["Touka Kirishima"])
	
	var new_obj = [
		sakura_wins,
		sasuke_wins,
		kirishima_wins
	]
	for obj in new_obj:
		assign_objective(obj)

func get_rewards():
	rewards = ["Kakashi Hatake", load("res://assets/images/Kakashi Hatake/kakashiprof.png")]

func get_valid_characters():
	valid_characters = ["Touka Kirishima", "Sasuke Uchiha", "Sakura Haruno"]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
