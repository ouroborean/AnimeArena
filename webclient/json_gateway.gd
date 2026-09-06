## JsonGateway
##
## A raw-WebSocket + JSON transport endpoint for the thin web client (Scope A).
## Runs ALONGSIDE the existing Godot high-level-multiplayer server (which stays on
## its own port for the legacy Godot client), so nothing about the current game
## breaks while the JS client is built.
##
## Responsibilities (transport only — no game logic here):
##   - listen() on a TCP port, accept browsers, complete the WS handshake
##   - parse inbound text frames as JSON objects -> emit message_received(peer_id, msg)
##   - send(peer_id, {...}) / broadcast({...}) as JSON text frames
##   - emit client_connected / client_disconnected
##
## peer_id here is a gateway-local id (1,2,3,...), distinct from Godot multiplayer
## peer ids. The routing layer (next step) maps these to ServerSession / Match the
## same way the RPC path keys on the multiplayer sender id.
##
## Drive it either by adding it to the scene tree (its _process calls poll()) or by
## calling poll() manually each frame (see webclient/gateway_runner.gd for headless).

extends Node
class_name JsonGateway

signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal message_received(peer_id: int, msg: Dictionary)

var _tcp := TCPServer.new()
var _peers: Dictionary = {}        # peer_id -> WebSocketPeer
var _announced: Dictionary = {}    # peer_id -> true once we've emitted client_connected
var _out_queues: Dictionary = {}   # peer_id -> Array[String]: frames waiting for socket headroom (send_queued)
var _next_id: int = 1
var port: int = 0
var listening: bool = false

# Backpressure budget for send_queued: stay under the WebSocketPeer default outbound_buffer_size
# (65535) with slack for the frame envelope. A frame only leaves the queue when the wslay outbound
# buffer has room for it — send_text NEVER gets called into a full buffer, so nothing is dropped.
const _OUT_HEADROOM := 60000


## Begin accepting connections on `p`. Returns OK or a Godot Error code.
func listen(p: int) -> int:
	port = p
	var err := _tcp.listen(p)
	listening = err == OK
	if listening:
		print("[JsonGateway] listening on ws://*:%d" % p)
	else:
		push_error("[JsonGateway] listen(%d) failed (err %d)" % [p, err])
	return err


func stop() -> void:
	for pid in _peers.keys():
		var ws: WebSocketPeer = _peers[pid]
		ws.close()
	_peers.clear()
	_announced.clear()
	_tcp.stop()
	listening = false


func _process(_delta: float) -> void:
	poll()


## Pump the server: accept new sockets, advance handshakes, drain inbound frames.
## Safe to call every frame whether or not this node is in the scene tree.
func poll() -> void:
	if not listening:
		return

	# 1. Accept pending TCP connections and wrap each in a WebSocketPeer.
	while _tcp.is_connection_available():
		var conn := _tcp.take_connection()
		var ws := WebSocketPeer.new()
		var err := ws.accept_stream(conn)
		if err != OK:
			push_warning("[JsonGateway] accept_stream failed (err %d)" % err)
			continue
		var pid := _next_id
		_next_id += 1
		_peers[pid] = ws

	# 2. Advance every peer; emit connect once OPEN, drain text frames, reap CLOSED.
	var dead: Array = []
	for pid in _peers.keys():
		var ws: WebSocketPeer = _peers[pid]
		ws.poll()
		var state := ws.get_ready_state()
		match state:
			WebSocketPeer.STATE_OPEN:
				if not _announced.has(pid):
					_announced[pid] = true
					client_connected.emit(pid)
				_drain_out_queue(pid)   # push queued frames as socket headroom frees up
				while ws.get_available_packet_count() > 0:
					var pkt := ws.get_packet()
					if not ws.was_string_packet():
						continue  # binary frames unused for now
					var text := pkt.get_string_from_utf8()
					var parsed: Variant = JSON.parse_string(text)
					if typeof(parsed) == TYPE_DICTIONARY:
						message_received.emit(pid, parsed)
					else:
						push_warning("[JsonGateway] peer %d sent non-object frame: %s" % [pid, text])
			WebSocketPeer.STATE_CLOSED:
				dead.append(pid)

	for pid in dead:
		_peers.erase(pid)
		_out_queues.erase(pid)
		var was_announced: bool = _announced.erase(pid)
		if was_announced:
			client_disconnected.emit(pid)


## Send one JSON object to a single peer.
func send(peer_id: int, msg: Dictionary) -> void:
	if not _peers.has(peer_id):
		return
	var ws: WebSocketPeer = _peers[peer_id]
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(msg))


## Send one JSON object to a single peer THROUGH the backpressure queue. Use this for bursts of
## large frames (e.g. chunked replay delivery): the plain send() calls WebSocketPeer.send_text
## directly, which silently DROPS the frame with ERR_OUT_OF_MEMORY once the peer's 64KB outbound
## buffer backs up (only reproducible over a real network — loopback drains synchronously).
## send_queued frames wait in a per-peer Array and are pushed by poll() as headroom frees up, in
## order, never dropped while the socket lives. The queue dies with the peer.
func send_queued(peer_id: int, msg: Dictionary) -> void:
	if not _peers.has(peer_id):
		return
	if not _out_queues.has(peer_id):
		_out_queues[peer_id] = []
	_out_queues[peer_id].append(JSON.stringify(msg))
	_drain_out_queue(peer_id)   # opportunistic immediate push (loopback / idle sockets)


func _drain_out_queue(peer_id: int) -> void:
	if not _out_queues.has(peer_id) or not _peers.has(peer_id):
		return
	var ws: WebSocketPeer = _peers[peer_id]
	var q: Array = _out_queues[peer_id]
	while q.size() > 0:
		if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			break
		var text: String = q[0]
		# Only hand wslay a frame it has room for; otherwise wait for the next poll().
		if ws.get_current_outbound_buffered_amount() + text.to_utf8_buffer().size() > _OUT_HEADROOM:
			break
		if ws.send_text(text) != OK:
			break
		q.pop_front()
	if q.is_empty():
		_out_queues.erase(peer_id)


## Send one JSON object to every connected peer.
func broadcast(msg: Dictionary) -> void:
	broadcast_except([], msg)


## Send to every connected peer EXCEPT the given peer ids. Used by the maintenance eject, which must
## not throw the admin running it out of the admin panel they need in order to cancel or follow up.
func broadcast_except(exclude: Array, msg: Dictionary) -> void:
	var text := JSON.stringify(msg)
	for pid in _peers.keys():
		if pid in exclude:
			continue
		var ws: WebSocketPeer = _peers[pid]
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send_text(text)


func peer_count() -> int:
	return _peers.size()
