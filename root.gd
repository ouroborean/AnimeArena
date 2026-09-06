extends Control

# Entry point. This project is now SERVER-ONLY: the Godot desktop client (ui/,
# scenes/, game.tscn) was retired in favour of the web client in webclient/, and
# was deleted 2026-07-26. The only supported way to run this project is headless.

# Called when the node enters the scene tree for the first time.
func _ready():
	if DisplayServer.get_name() == "headless":
		print("Starting in headless")
		# Server scene ONLY — ServerConnection + BucketHandler. This used to load
		# game.tscn (the desktop client shell) and build its entire UI tree just to
		# reach the ServerConnection node inside it.
		var server_root = load("res://server_root.tscn").instantiate()
		add_child(server_root)
		server_root.get_node("ServerConnection").actually_start_server()
	else:
		# No client to show any more. Say so plainly rather than opening a blank window.
		push_warning("Anime Arena is server-only — run with --headless. The player-facing client is the web app in webclient/.")
		print("Anime Arena is server-only. Run with --headless; the client lives in webclient/ (served separately).")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
