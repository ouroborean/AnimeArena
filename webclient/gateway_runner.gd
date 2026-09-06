## gateway_runner.gd — standalone headless harness for the JsonGateway.
##
## Run WITHOUT touching the real game:
##   godot --headless --path . --script res://webclient/gateway_runner.gd
##
## Then open webclient/test_client.html in a browser (or point any WS client at
## ws://localhost:5696). Proves the raw-WS + JSON transport end to end before we
## wire it into ServerConnection's real login / matchmaking / battle handlers.
##
## Messages handled here are STUBS — just enough to validate the round-trip:
##   {"type":"ping","payload":X}            -> {"type":"pong","echo":X}
##   {"type":"login","username":U,"password":P} -> {"type":"login_response","ok":bool,...}
## Anything else -> {"type":"error","reason":...}

extends SceneTree

const PORT := 5696

var _gateway


func _initialize() -> void:
	_gateway = load("res://webclient/json_gateway.gd").new()
	_gateway.client_connected.connect(_on_connected)
	_gateway.client_disconnected.connect(_on_disconnected)
	_gateway.message_received.connect(_on_message)
	var err: int = _gateway.listen(PORT)
	if err != OK:
		print("[runner] could not listen on %d — aborting" % PORT)
		quit(1)
		return
	print("[runner] gateway up on ws://localhost:%d — Ctrl+C to stop" % PORT)


# SceneTree main-loop tick. Return true to quit; we drive the gateway and keep running.
func _process(_delta: float) -> bool:
	_gateway.poll()
	return false


func _finalize() -> void:
	if _gateway:
		_gateway.stop()


func _on_connected(pid: int) -> void:
	print("[runner] + client %d connected (total %d)" % [pid, _gateway.peer_count()])


func _on_disconnected(pid: int) -> void:
	print("[runner] - client %d disconnected (total %d)" % [pid, _gateway.peer_count()])


func _on_message(pid: int, msg: Dictionary) -> void:
	var t: String = str(msg.get("type", ""))
	print("[runner] <- %d: %s" % [pid, JSON.stringify(msg)])
	match t:
		"ping":
			_gateway.send(pid, {"type": "pong", "echo": msg.get("payload", null)})
		"login":
			# STUB. Real impl will call into ServerConnection (load_player + password
			# check) and ship the player blob (MATCH_PROTOCOL.md §4.1). For now just
			# prove the request/response shape and the transport.
			var user: String = str(msg.get("username", ""))
			var pword: String = str(msg.get("password", ""))
			var ok := user != "" and pword != ""
			_gateway.send(pid, {
				"type": "login_response",
				"ok": ok,
				"username": user,
				"player": {
					"_stub": true,
					"note": "wire to ServerConnection.load_player next",
				},
			})
		_:
			_gateway.send(pid, {"type": "error", "reason": "unknown type: " + t})
