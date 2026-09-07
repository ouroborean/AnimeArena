extends Node
class_name ServerConnection

# --- NETWORK CONFIGURATION ---
# Toggle NETWORK_MODE to switch between local Windows testing and the production
# websocket. LOCAL connects to a headless server running on this same machine at
# 127.0.0.1:5695 (launch the headless instance first, then start the client in a
# second window). REMOTE connects to the production wss server. The server bind
# port is the same in both modes; only the client-side URL changes.
enum NetworkMode { LOCAL, REMOTE }
const NETWORK_MODE = NetworkMode.REMOTE

const LOCAL_CLIENT_URL = "ws://127.0.0.1:5695"
const REMOTE_CLIENT_URL = "wss://server.animaslashanimearenaserver.org"

# Resolved at parse time from NETWORK_MODE. Used by both this script and game.gd.
const TARGET_IP = LOCAL_CLIENT_URL if NETWORK_MODE == NetworkMode.LOCAL else REMOTE_CLIENT_URL
const TARGET_PORT = 5696  # legacy WebSocketMultiplayerPeer server (now idle — desktop client retired)
const RECONNECT_TIMEOUT = 120.0 # Time in seconds to wait for a player to return

# --- ranked bot fallback ----------------------------------------------------
# Ranked can now seat a bot, like Quick. Unlike Quick — which waits the player's own bot_queue_delay
# setting — the ranked wait is FIXED, so nobody can tune their way to a faster bot on the ladder.
const RANKED_BOT_DELAY := 30.0
# A ranked game against a bot is a real win/loss on the record, but its ladder movement is bounded:
# both a bot win and a bot loss are capped at RANKED_BOT_RATING_CAP (and floored at the ±10 ladder
# minimum), so a bot game moves the ladder by at most this much in either direction — you never lose
# more to a bot than a bot win could gain (fixing the old asymmetry where a bot loss was uncapped and,
# at low rating, exceeded the capped win). The bot LOSS additionally keeps its x0.5 scale, so it's
# generally gentler than the win; the cap is the ceiling both share.
const RANKED_BOT_RATING_CAP := 25.0
const RANKED_BOT_LOSS_RATING_SCALE := 0.5
# peer_id -> queue-session counter, so a fallback coroutine from a cancelled queue can tell it has
# been superseded (GDScript timers can't be cancelled once awaited).
var _ranked_fallback_gen := {}

# --- ranked pairing ----------------------------------------------------------
# RANK-MATCHING RESTRICTION LIFTED 2026-08-14 (owner: the player base is too small to separate players
# by rank). Every queued player may pair with every other, IMMEDIATELY — so the old rating-distance gate
# collapses to a single catch-all band with a ZERO wait. ranked_required_wait() returns 0 for any gap, so
# every pair is eligible the instant both are queued; _best_gated_ranked_pair still pairs the CLOSEST-rated
# two first (a quality nicety, not a restriction) and a bot is seated only when nobody else is queued.
#
# The band structure + ranked_required_wait() are kept (not ripped out) so the sweep, the manifest, and its
# parity test stay intact — to change the pairing wait, edit the band and regenerate
# data/server/matchmaking.json via tools/reference_data.py.
const GATE_BANDS := [
	[-1, 0.0],   # any rating gap -> 0s wait: pair immediately (closest-rated pair first)
]
const MM_TICK := 1.0                 # seconds between gate sweeps
# Seconds between Nexus disk re-scans. The bucket roster is now driven by the <path>.dat files in
# `bucket data/` (see BucketHandler.initialize_buckets), so this poll lets files added / removed / edited
# on disk by an external tool surface to clients without a server restart. Only broadcasts on a real change.
const NEXUS_POLL_INTERVAL := 30.0
var _last_poll_open := true           # last-seen bucket data/poll.dat state, so an external toggle rebroadcasts too
var _ranked_wait_start := {}         # peer_id -> Time.get_ticks_msec() at enqueue
var _gate_tick_running := false      # re-entrancy guard for the sweep

## Does this ladder result move clan records? Any match between two HUMANS who are not in the same
## clan counts — the opponent no longer has to be in a clan themselves, so a clan-vs-Clanless game
## moves the one record that exists. Two Clanless players compare equal and move nothing.
## Pure: no member state, so a probe can call it on a bare instance.
static func clan_record_counts(winner_clan: String, loser_clan: String, winner_is_throwaway: bool, loser_is_throwaway: bool) -> bool:
	# The throwaway flag is is_EPHEMERAL, not is_bot: a persistent ULTRA bot is Clanless (never in a real
	# clan) so it is filtered by the winner_clan != loser_clan test below, letting the HUMAN's clan record
	# still move in an ultra-bot game — that parity is deliberate (owner 2026-08-15), so players can't spot
	# an ultra bot by their clan record standing still. Only the EPHEMERAL 30s-fallback seat is a throwaway.
	if winner_is_throwaway or loser_is_throwaway:
		return false          # an ephemeral bot seat has no clan and never moves a record
	return winner_clan != loser_clan


# How long BOTH players must have waited before a pair this far apart may be seated.
# Pure: no member state, no tree access, so a probe can call it on a bare instance.
func ranked_required_wait(delta_rating: int) -> float:
	for band in GATE_BANDS:
		if int(band[0]) < 0 or delta_rating < int(band[0]):
			return float(band[1]) * RANKED_BOT_DELAY
	return float(GATE_BANDS[GATE_BANDS.size() - 1][1]) * RANKED_BOT_DELAY

# --- SESSION CLASS (NEW) ---
# Holds all data for a connected user to allow for stateful reconnections
class ServerSession:
	var username: String
	var peer_id: int
	var player_data: Player # Your Player object
	var status: int = ConnectionState.ONLINE
	var current_match = null
	var disconnect_timer: Timer = null
	var rate_buckets: Dictionary = {}   # key -> Array[int] of recent Time.get_ticks_msec() stamps

	enum ConnectionState { ONLINE, DISCONNECTED, IN_GAME }

	func _init(_username, _peer_id, _player_data):
		username = _username
		peer_id = _peer_id
		player_data = _player_data

# --- DATA STRUCTURES ---
var sessions: Dictionary = {} # Username -> ServerSession
var peer_map: Dictionary = {} # PeerID -> Username (Fast lookup)

# --- JSON GATEWAY (web client transport, Scope A; see webclient/ + MATCH_PROTOCOL.md) ---
const JSON_GATEWAY_PORT := 5695  # the web client's gateway now owns the production port (behind nginx)
const JSON_PEER_BASE := 1000000000  # web peers get logical ids above this so they never collide with Godot peer ids
var json_gateway = null

# --- EXISTING VARIABLES ---
var multiplayer_peer = WebSocketMultiplayerPeer.new()
var delta_timer = 30.0
var ranked_queue = {
	Rank.Type.IRON: {},
	Rank.Type.BRONZE: {},
	Rank.Type.SILVER: {},
	Rank.Type.GOLD: {},
	Rank.Type.PLATINUM: {},
	Rank.Type.DIAMOND: {},
	Rank.Type.MASTER: {},
	Rank.Type.GRANDMASTER: {},
	Rank.Type.CHALLENGER: {},
}
var match_waiting = false

# Kept for compatibility with your enums, though Session class handles state now
enum Connection {
	OFFLINE,
	ONLINE,
	DISCONNECTED,
	IN_GAME
}

var ladder = {}
var clan_ladder = {}
var private_queue = {}
var private_matches: Array[Match]
var queued_players = {}
var player_check = {}
var quick_matches: Array[Match]
var ranked_matches: Array[Match]
var bot_matches: Array[Match]
# Synthetic peer ids for server-side bot seats. Always <= BOT_PEER_BASE (negative)
# so they never collide with real Godot peers (positive) or JSON gateway logical
# peers (JSON_PEER_BASE = 1e9+). _is_bot_peer() tests this range.
const BOT_PEER_BASE := -1000
var _bot_peer_counter := BOT_PEER_BASE
var _player
var _version = "1.6.0"
var needed_versions = []
var missions
var clans = {}
var players = {}
var stats_manager: StatsManager = StatsManager.new()
var mastery_db: MasteryDB = null
var stats_db: StatsDB = null
# Site-usage telemetry (visits / registrations / matches / concurrency) — the source for the
# admin "Metrics" dashboard. Null when SQLite failed to open, and every call site is guarded,
# so losing the DB costs the dashboard and nothing else.
var metrics_db: MetricsDB = null
# How often online sessions are sampled into the presence table. Concurrency is the one figure
# that cannot be reconstructed after the fact from visit rows without an interval scan per point,
# so it has to be sampled as it happens. 5 minutes ≈ 288 rows/day: fine grained enough for a
# daily peak, small enough to keep forever.
const PRESENCE_SAMPLE_INTERVAL := 300.0
@export var is_server = false
@export var bucket_handler: BucketHandler
@export var heartbeat_timer: Timer
@export var ladder_timer: Timer

# --- CHAT (Phase 2) ---
# RAM-only ring buffers — no durable history (decision D5). Global chat defaults ON with an
# admin kill switch (D7). Channels: global (server-wide), match (derived from the sender's
# session.current_match — the client NEVER supplies a match id, anti-spoof), dm (any player,
# ignore-enforced). Spectators are NOT chat members (D6).
const CHAT_GLOBAL_CAP := 100
const CHAT_DM_CAP := 50
const CHAT_MATCH_CAP := 50
const CHAT_MAX_LEN := 300
const MAX_DM_BUFFERS := 2000          # cap the NUMBER of dm-pair buffers, not just each one's length
var chat_global: Array = []          # ring buffer of {from, text, ts}, cap CHAT_GLOBAL_CAP
var chat_dm: Dictionary = {}         # "<a>|<b>" (usernames sorted, joined by "|") -> Array of {from, to, text, ts}, cap CHAT_DM_CAP
var chat_dm_lru: Array = []          # dm keys, least-recently-used first -> bounds chat_dm's key count (RAM, D5)
var chat_match: Dictionary = {}      # match_uid -> Array of {from, text, ts}, cap CHAT_MATCH_CAP
var global_chat_enabled: bool = true
# Character Creator kill switch. Defaults OFF so the feature stays hidden until it is deliberately
# turned on, and unlike global_chat_enabled it PERSISTS — an admin's decision must survive a restart
# rather than silently reverting on the next deploy. Admins always retain access so they can test a
# disabled feature. Enforced server-side (see _creator_blocked); the hidden button is only cosmetic.
const SERVER_FLAGS_PATH := "res://server_flags.json"
var creator_enabled: bool = false

# --- REPLAYS (P3) ---
# Server-side replay persistence. One file per finished PvP match (Quick/Ranked/Private;
# BOT and CAMPAIGN are skipped): replays/<match_uid>.replay, one line of JSON from
# MatchReplayLog.to_dict(). Fetch is participants-only (D3) and CHUNKED (the gateway's WS
# buffers are the Godot-default 64KB — a full replay can exceed 1MB and cannot ship as one
# frame). Retention (D4): 30 days / 5000 files, swept at boot + daily.
const REPLAY_DIR := "replays/"
const REPLAY_RETENTION_DAYS := 30
const REPLAY_MAX_FILES := 5000
const REPLAY_CHUNK := 24000

# --- SIGNALS (PRESERVED) ---
signal server_start()
signal char_select(player)
signal quick_match_received(opponent, opponent_team, first, seed, canonical_role)
signal ranked_match_received(opponent, opponent_team, first, seed, canonical_role)
signal private_match_received(opponent, opponent_team, first, seed, canonical_role)
signal opponent_ban_received(character)
signal opponent_pick_received(character)
signal opponent_surrendered()
signal player_connected(peer_id)
signal set_login_message(message)
signal return_texture(texture)
signal prompt_restart()
signal inform_updating()
signal connection_ready()
signal connection_complete()
signal end_queue()
signal request_game_refresh()
signal character_bucket_info_broadcast(max, info_sets)
signal bucket_update(path_name, amount, max)
signal reconnection_package_received(package)
signal ladder_info_received(ladder_info)
signal character_mastery_received(character_path, data)
signal clan_creation_response_received(data)
signal clan_info_received(info, connection)
signal clan_search_info_received(clan_info, connection)
signal send_player_application_invite_info(info, connection)
signal send_clan_application_invite_info(info, connection)
signal player_search_info_received(player_info, connection)
signal player_update_received(player)
signal force_login_return()
signal opponent_disconnect_received()
signal opponent_reconnect_received()
# Phase 2 shadow validation: server has asked us to compute and report our
# current state hash for the given match/turn. The BattleScene listens.
signal state_hash_requested(match_id, turn_number)
# Phase 6: emitted when the server's apply_turn_result RPC arrives. Routed
# by game.tscn into BattleScene.apply_turn_result, which delegates to the
# live BattleManager. The manager's apply_turn_result is itself gated on
# `passive`, so during Phase 6 the call chain is wired but inert.
signal apply_turn_result_received(events, snapshot)
signal spectate_init_received(package)
signal spectate_denied(reason)
signal replay_saved()
# Emitted on the client when the WebSocket drops while the player is logged in.
signal connection_lost()
# Emitted on the client when the server validates a tab-away reconnect and
# the player was in a match — carries the reconnection package JSON.
signal session_reconnect_received(package)
# Emitted when a tab-away reconnect resolves without a match (session valid
# but no active game) or when the auto-login fallback completes. The overlay
# can be safely dismissed.
signal connection_lost_resolved()

var game_loaded = false
var pending_pongs: Dictionary = {} # username -> true, tracks who we're waiting on
# Client-side: tracks whether we're in the middle of an automatic reconnection
# after a tab-away disconnect (as opposed to a fresh client start).
var _is_reconnecting: bool = false
# Client-side: stored login credentials for auto-login during reconnection.
var _stored_username: String = ""
var _stored_password: String = ""
# Holds serialized replay data (Dictionary) keyed by username after a match ends.
# Players can request their replay via RPC; unclaimed replays are discarded on
# session wipe or when the player starts a new match.
var pending_replays: Dictionary = {} # username -> replay dict

# --- INITIALIZATION ---

func _ready():
	if DisplayServer.get_name() != "headless":
		multiplayer.connected_to_server.connect(notify_connection_complete)
		multiplayer.server_disconnected.connect(heartbeat_check)
		connection_ready.emit()
		heartbeat_timer.start()
	else:
		initialize_players()
		initialize_clans()
		# Ultra Bot rotation scheduler (P5). The whole system is gated behind a persistent DEPLOY switch: the
		# bots stay dormant (no seeding, no online, no queue, no play) until an admin presses Deploy, and the
		# choice survives restarts (a re-deployed fleet comes back automatically). The Timer always runs so a
		# live Deploy takes effect without a restart, but the tick is a no-op until deployed.
		_load_ultra_bot_deployed()
		_ultra_bot_timer = Timer.new()
		_ultra_bot_timer.wait_time = ULTRA_BOT_TICK
		_ultra_bot_timer.timeout.connect(_on_ultra_bot_tick)
		add_child(_ultra_bot_timer)
		_ultra_bot_timer.start()
		if _ultra_bot_deployed:
			_seed_ultra_bots()           # persistent accounts — created/healed after the cache is loaded
			_ultra_bot_rotation_tick()   # populate immediately at boot rather than waiting one tick
		mastery_db = MasteryDB.new()
		if mastery_db.open_db():
			mastery_db.backfill_from_players(players)
			stats_manager.mastery_db = mastery_db
		else:
			mastery_db = null
			print("[SERVER] Mastery DB unavailable — ladder writes/reads disabled")
		stats_db = StatsDB.new()
		if stats_db.open_db():
			# On a brand-new DB, seed it losslessly from the historical match
			# logs so no usage history is thrown away. Guarded so reboots with
			# an already-populated DB never re-add the same games.
			if stats_db.is_empty():
				stats_db.backfill_from_match_records()
			elif stats_db.character_match_is_empty():
				# The aggregate predates the dated per-appearance table. Seed the new table
				# from the same historical logs so date filtering has history to work with
				# from the first boot, instead of looking broken until new matches pile up.
				stats_db.backfill_appearances()
		else:
			stats_db = null
			print("[SERVER] Stats DB unavailable — character usage tracking disabled")
		# Site-usage metrics. On a fresh DB, seed the MATCH history from the archive so the
		# dashboard opens with real engagement data; visits/sessions can only start from now
		# (a match record says nothing about when anyone logged in), which the UI states.
		metrics_db = MetricsDB.new()
		if metrics_db.open_db():
			if metrics_db.count_kind("match") == 0:
				metrics_db.backfill_matches()
			var presence_timer := Timer.new()
			presence_timer.wait_time = PRESENCE_SAMPLE_INTERVAL
			presence_timer.one_shot = false
			presence_timer.autostart = true
			presence_timer.timeout.connect(_sample_presence)
			add_child(presence_timer)
		else:
			metrics_db = null
			print("[SERVER] Metrics DB unavailable — site usage tracking disabled")
		# Replay persistence (P3): ensure the folder exists, sweep expired files now, then
		# re-sweep daily via a code-built timer (this node lives for the whole process).
		if not DirAccess.dir_exists_absolute(REPLAY_DIR.trim_suffix("/")):
			DirAccess.make_dir_absolute(REPLAY_DIR.trim_suffix("/"))
		_sweep_replays()
		var replay_sweep_timer := Timer.new()
		replay_sweep_timer.wait_time = 86400.0
		replay_sweep_timer.one_shot = false
		replay_sweep_timer.autostart = true
		replay_sweep_timer.timeout.connect(_sweep_replays)
		add_child(replay_sweep_timer)
		missions = Mission.all_missions()
		for rank in ranked_queue:
			for i in range(5):
				ranked_queue[rank][i + 1] = []
		# Ranked pairing is now TIME-GATED, so it can no longer be driven only by the
		# enqueue handler: two players who are not yet eligible when the second one joins
		# would never be looked at again. This sweep is what re-evaluates them.
		var gate_timer := Timer.new()
		gate_timer.wait_time = MM_TICK
		gate_timer.autostart = true
		gate_timer.timeout.connect(_gate_tick)
		add_child(gate_timer)
		# Nexus disk poll: re-scan bucket data/ every NEXUS_POLL_INTERVAL so .dat files added / removed /
		# edited on disk (by an external service or a manual edit) reach clients without a server restart.
		_last_poll_open = _poll_open()
		var nexus_poll_timer := Timer.new()
		nexus_poll_timer.wait_time = NEXUS_POLL_INTERVAL
		nexus_poll_timer.autostart = true
		nexus_poll_timer.timeout.connect(_nexus_poll_tick)
		add_child(nexus_poll_timer)

# --- HELPER: GET PLAYER SAFE ---
# Replaces 'connected_peers[peer_id]' to safely get data via the new Session system
func get_player(peer_id):
	if peer_id in peer_map:
		var username = peer_map[peer_id]
		if username in sessions:
			return sessions[username].player_data
	return null

func get_session(peer_id) -> ServerSession:
	if peer_id in peer_map:
		return sessions[peer_map[peer_id]]
	return null

# Is `cid` the path_name of a character actually fielded in `sess`'s current live battle (either team)?
# ABUSE-CASE CARVE-OUT for the authored-art approval gate: can_use() (now admin-only) lets an ADMIN
# FIELD an authored character — including an unapproved one — in a match. In a Private match against a
# human, the OPPONENT's client must still render that character's portrait/ability art — but the
# opponent is neither the author nor an approver, so the bare approval gate would wrongly starve them
# and paint a broken portrait for a character sitting right there on the board. This leaks nothing the
# requester cannot already see: the character is on their own screen. Draft phase has no manager yet,
# so this is strictly the in-battle window.
func _char_in_live_match(sess: ServerSession, cid: String) -> bool:
	if sess == null or sess.current_match == null or not is_instance_valid(sess.current_match):
		return false
	var mgr = sess.current_match.manager
	if mgr == null or not is_instance_valid(mgr):
		return false
	for team in [mgr.player.team, mgr.enemy.team]:
		if team == null:
			continue
		for character in team.characters:
			if character.path_name == cid:
				return true
	return false

# Usernames with server-admin privileges. Admins can broadcast a scrolling announcement
# to every connected client, so keep this list small and vetted. (Currently test-only.)
const ADMIN_USERNAMES: Array = ["Cheshire", "IsaacTheEmperor"]

# ---------------------------------------------------------------------------
# UPDATE / MAINTENANCE MODE
# ---------------------------------------------------------------------------
# Three admin-driven steps: warn everyone, eject everyone to the login screen with logins locked,
# then the operator stops the process and starts the new build.
#
# The whole thing is IN-MEMORY on purpose. The restart is the reset: a freshly booted server has an
# empty `maintenance` and a brand-new boot_id, which is exactly the state an ejected client is
# polling for. Nothing to remember to switch off afterwards.
#
# Sockets are deliberately NOT force-closed on eject. The client puts ITSELF on the login screen, so
# the real disconnect is the operator stopping the server — which is the `_close` the waiting client
# is listening for anyway. Force-closing would also cut the admin's own socket mid-operation.
const MAINTENANCE_DEFAULT := "Anime Arena is going down for an update."
# Changes on every process start; an ejected client reloads when it sees a boot_id different from
# the one that ejected it. Time alone is enough (restarts are seconds apart at minimum) but the
# random suffix makes a same-second restart safe too.
var boot_id: String = str(int(Time.get_unix_time_from_system())) + "_" + str(randi())
var maintenance: Dictionary = {}

## True once logins are locked. A bare warning does NOT lock — players keep playing until the eject.
func _maintenance_locked() -> bool:
	return bool(maintenance.get("locked", false))


## GATEWAY peer ids of every logged-in admin. The eject skips them: an admin thrown to the login
## screen loses the admin panel (it is hidden there), and with it the Cancel button — so ejecting
## yourself would make the step you just took unreversible.
##
## Note the id namespaces. sessions[*].peer_id is a LOGICAL id (JSON_PEER_BASE + gateway id), while
## json_gateway keys its peers by the raw gateway id. Excluding the logical id would match nothing
## and quietly eject the admin anyway — which is exactly what it did before _json_local was applied.
func _admin_peer_ids() -> Array:
	var out := []
	for uname in sessions:
		if not _is_admin(uname):
			continue
		var sess = sessions[uname]
		if _is_json_peer(sess.peer_id):
			out.append(_json_local(sess.peer_id))
	return out


## Wind the server down to a state where stopping the process costs nobody anything:
##   * every live match is CANCELLED as a no-contest (Match.cancel_match) — no W/L, no rating, no AP.
##     Without this an ejected player simply stops taking turns and the AFK timer forfeits them a
##     real ranked loss, and anyone inside their 120s reconnect grace is surrendered by wipe_session
##     when the login lock refuses their re-login.
##   * every queue is emptied, so the matchmaker (and the ranked bot fallback) cannot seat somebody
##     into a brand-new match seconds before the process dies.
## Returns [matches_cancelled, players_dequeued] for the admin's confirmation line.
func _maintenance_stand_down() -> Array:
	var doomed := []
	for uname in sessions:
		var m = sessions[uname].current_match
		if m != null and is_instance_valid(m) and not doomed.has(m):
			doomed.append(m)
	var dequeued: int = queued_players.size() + private_queue.size()
	for rank in ranked_queue:
		for tier in ranked_queue[rank]:
			dequeued += ranked_queue[rank][tier].size()
	for pid in peer_map.keys():
		_release_queues(pid)
	for m in doomed:
		m.cancel_match()
	return [doomed.size(), dequeued]

func _is_admin(username) -> bool:
	# EXACT-case match, deliberately. The account namespace (ausers/<name>.dat) is case-sensitive on
	# the Linux production host, so a case-insensitive check here would be a privilege-escalation hole:
	# anyone could register a case-variant of an admin name ("cheshire" vs "Cheshire") — a distinct
	# account with their own password — and inherit admin. Registration additionally rejects
	# case-variants of admin names (see _process_register) as defense in depth.
	return username != null and str(username) in ADMIN_USERNAMES

# True if `username` case-insensitively collides with any reserved admin name. Used to stop a
# non-admin from registering/squatting a case-variant of an admin account on a case-sensitive host.
func _collides_with_admin_name(username) -> bool:
	if username == null:
		return false
	var lower := str(username).strip_edges().to_lower()
	for admin_name in ADMIN_USERNAMES:
		if str(admin_name).to_lower() == lower:
			return true
	return false

# --- Admin tools: resolve / summarize a target player (online session OR offline account) ---
func _admin_get_target(uname: String):
	# Guard the account-file path: the username flows into ausers/<name>.dat, so reject anything
	# that could traverse out of the accounts directory (admin-only, but defensive nonetheless).
	if uname == "" or uname.contains("/") or uname.contains("\\") or uname.contains(".."):
		return null
	# Prefer the live session object so edits reflect immediately mid-session; fall back to the
	# in-memory account cache, then to a disk load for accounts not yet cached.
	if uname in sessions:
		return sessions[uname].player_data
	if uname in players:
		return players[uname]
	if FileAccess.file_exists("ausers/" + uname + ".dat"):
		var data = load_player(uname)
		if data != null:
			var p = Player.load_player(data)
			players[uname] = p
			return p
	return null

# Sliding-window rate limit. Returns true and records the hit if under the cap; false if over.
# Uses monotonic ticks (immune to wall-clock changes). session may be a ServerSession.
# CALLERS: `key` must come from a BOUNDED set (a channel/action TYPE like "chat" or "dm", NOT a
# per-recipient value). A bucket entry persists for the life of the session, so keying by unbounded
# user input (e.g. every whisper target) would grow session.rate_buckets without bound.
func _rate_ok(session, key: String, max_n: int, window_ms: int) -> bool:
	if session == null:
		return true
	var now := Time.get_ticks_msec()
	var stamps: Array = session.rate_buckets.get(key, [])
	var kept := []
	for t in stamps:
		if now - int(t) < window_ms:
			kept.append(t)
	if kept.size() >= max_n:
		session.rate_buckets[key] = kept
		return false
	kept.append(now)
	session.rate_buckets[key] = kept
	return true

# Sanitize user-entered single-line text: strip control chars, collapse whitespace, trim, cap length.
func _clean_text(s, maxlen: int) -> String:
	var text := str(s)
	# Bound the work of the O(n) sanitize loop below against an oversized input before it runs. The
	# whitespace collapse can only SHRINK the string, so a generous pre-cap (4x) never drops a char
	# that would have survived to the final maxlen cap.
	if text.length() > maxlen * 4:
		text = text.substr(0, maxlen * 4)
	var out := ""
	for i in text.length():
		var c := text[i]
		var code := c.unicode_at(0)
		if code < 32 or code == 127:
			out += " "   # control chars (incl. newlines/tabs) -> space
		else:
			out += c
	# collapse runs of spaces
	while out.find("  ") != -1:
		out = out.replace("  ", " ")
	out = out.strip_edges()
	if out.length() > maxlen:
		out = out.substr(0, maxlen)
	return out

func _player_status(uname) -> String:
	# Live presence: offline / online / in match / disconnected. Shared by the admin panel
	# (_admin_summarize) and the public profile (_build_profile_body).
	if not (uname in sessions):
		return "offline"
	var sess = sessions[uname]
	if sess.current_match != null and is_instance_valid(sess.current_match):
		return "in match"
	if sess.status == ServerSession.ConnectionState.DISCONNECTED:
		return "disconnected"
	return "online"

func _admin_summarize(uname: String, p) -> Dictionary:
	var status_str := _player_status(uname)
	var d := {"username": uname, "status": status_str, "ap": 0, "wins": 0, "losses": 0, "rating": 0, "unlocks": 0}
	if p != null:
		d["ap"] = int(p.ap)
		d["unlocks"] = p.unlocks.size()
		if p.rank != null:
			d["wins"] = p.rank.wins
			d["losses"] = p.rank.losses
			d["rating"] = p.rank.get_rating()
	return d

# Sanitized public profile body for get_player_profile — a whitelist built off the Player object
# (modeled on display_package/_admin_summarize; NEVER the raw save, which carries pass_hash). Adds
# top-5 mastery (from the sparse xp map) + the server-only match_history ring buffer.
func _reset_player_record(target) -> void:
	# Zero the win/loss record + streak and drop back to Iron 1 / 0 RP. Touches ONLY the Rank
	# object — AP, unlocks, character mastery (character_progress), bounties, and match_history are
	# left untouched. Shared by the admin "reset_record" op and the self-service "reset_own_record".
	target.rank.wins = 0
	target.rank.losses = 0
	target.rank.streak = 0
	target.rank._ranked_streak = 0
	target.rank._rp = 0
	# rank/rank_tier are derived from rating (Rank.tier_for_rating), so zeroing the rating IS the
	# demotion back to Iron 1 — there is no stored tier to reset.
	target.rank.set_values(0, 0, 0, 0)


# ---------------------------------------------------------------------------
# SEASON RESET
# ---------------------------------------------------------------------------
# Wipes the ladder for EVERY account: win/loss, streaks, RP and rating back to zero, via the same
# _reset_player_record the per-player admin op uses. AP, unlocks, mastery, bounties, campaign
# progress and match_history are deliberately untouched.
#
# WHY THIS LIVES IN THE SERVER AND NOT IN A SCRIPT OVER ausers/*.dat: initialize_players() loads
# every account into the `players` cache at boot, and that cache is what fresh-login session creation
# reads from (see resave_player). Editing the .dat files under a running server is therefore silently
# reverted the moment an edited player logs in or is resaved for any other reason. Doing it here
# mutates the live objects AND the files in one pass, so there is no window where the two disagree.
const SEASON_RESET_CONFIRM := "RESET SEASON"

# Snapshot every account file before touching them. Returns the backup directory, or "" on failure —
# and a failed backup ABORTS the reset, because this is otherwise unrecoverable.
func _backup_accounts() -> String:
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "_")
	var dir_name := "ausers_backup_" + stamp
	var da := DirAccess.open(".")
	if da == null:
		return ""
	if not da.dir_exists(dir_name) and da.make_dir(dir_name) != OK:
		return ""
	for file in DirAccess.get_files_at("ausers"):
		if not file.ends_with(".dat"):
			continue
		var src := FileAccess.open("ausers/" + file, FileAccess.READ)
		if src == null:
			return ""
		var body := src.get_as_text()
		src.close()
		var dst := FileAccess.open(dir_name + "/" + file, FileAccess.WRITE)
		if dst == null:
			return ""
		dst.store_string(body)
		dst.close()
	return dir_name


## dry_run reports what WOULD happen and writes nothing. A real run needs the exact confirm phrase.
func _season_reset(dry_run: bool, confirm: String) -> Dictionary:
	var names := []
	for file in DirAccess.get_files_at("ausers"):
		if file.ends_with(".dat"):
			names.append(file.get_slice(".dat", 0))
	var with_record := 0
	for uname in names:
		var p = _admin_get_target(uname)
		if p != null and p.rank != null and (p.rank.wins > 0 or p.rank.losses > 0 or p.rank.get_rating() != 0):
			with_record += 1
	if dry_run:
		return {"ok": true, "dry_run": true, "accounts": names.size(), "with_record": with_record,
			"note": "Would reset %d account(s); %d currently carry a record. Re-send with confirm=\"%s\" to apply." % [names.size(), with_record, SEASON_RESET_CONFIRM]}
	if confirm != SEASON_RESET_CONFIRM:
		return {"ok": false, "note": "Confirmation phrase required: send confirm=\"%s\"." % SEASON_RESET_CONFIRM}
	var backup := _backup_accounts()
	if backup == "":
		return {"ok": false, "note": "Backup failed — nothing was reset."}
	var done := 0
	var failed := []
	for uname in names:
		var target = _admin_get_target(uname)
		if target == null:
			failed.append(uname)
			continue
		_reset_player_record(target)
		resave_player(target)
		# Push the zeroed record to anyone online so their profile does not sit stale until relog.
		if uname in sessions and sessions[uname].peer_id in peer_map:
			send_player_update(sessions[uname].peer_id)
		done += 1
	print("[ADMIN] SEASON RESET: ", done, "/", names.size(), " account(s) reset, backup in ", backup)
	return {"ok": true, "dry_run": false, "accounts": names.size(), "reset": done,
		"failed": failed, "backup": backup,
		"note": "Reset %d of %d account(s). Backup: %s" % [done, names.size(), backup]}

func _build_profile_body(p) -> Dictionary:
	var body := {
		"username": p.username,
		"wins": p.rank.wins,
		"losses": p.rank.losses,
		"rating": p.rank.get_rating(),
		"streak": p.rank.streak,
		"rank": p.rank.rank,
		"tier": p.rank.rank_tier,
		"clan": p.clan,
		"title": p.title,
		"avatar_url": p.avatar_url,
		"player_card": p.equipped_player_card,
	}
	body["clan_banner"] = clans[p.clan].banner_url if (p.clan != "Clanless" and p.clan in clans) else ""
	body["status"] = _player_status(p.username)   # offline / online / in match / disconnected
	var mastery := []
	var xp_map = p.character_progress.xp_data
	for path in xp_map:
		var xp := int(xp_map[path])
		mastery.append({"path": path, "xp": xp, "level": MasteryConfig.xp_to_level(xp)})
	mastery.sort_custom(func(a, b): return a["xp"] > b["xp"])
	body["top_mastery"] = mastery.slice(0, 5)
	body["match_history"] = _prune_match_history(p.match_history)   # last 7 days, max 100
	return body

# Admin tools: per-character usage/win aggregates, bucketed PvP (Quick+Ranked)
# vs Bot. Reads the StatsDB (authoritative); falls back to the legacy flat
# stats/<char>.stats files (PvP-only, since they merge Quick+Ranked) if the DB
# is unavailable, so the view is never blank just because SQLite failed to open.
## from_ts/to_ts are unix seconds bounding the window; 0/0 means ALL TIME, which reads the
## running aggregate exactly as before (so the default view is unchanged and still cheap).
## Any window at all switches to the dated per-appearance table.
func _admin_character_stats(from_ts := 0, to_ts := 0) -> Array:
	var by_path := {}
	var windowed: bool = from_ts > 0 or to_ts > 0
	if stats_db != null:
		var rows: Array = stats_db.get_usage_rows_between(from_ts, to_ts) if windowed else stats_db.get_usage_rows()
		for row in rows:
			var path := str(row.get("character_path", ""))
			if path == "":
				continue
			var mt := int(row.get("match_type", -1))
			var bucket := ""
			if mt == BattleManager.MatchType.QUICK or mt == BattleManager.MatchType.RANKED:
				bucket = "pvp"
			elif mt == BattleManager.MatchType.BOT:
				bucket = "bot"
			else:
				continue  # PRIVATE (or unknown) is excluded
			if not path in by_path:
				by_path[path] = {"path": path, "pvp": {"picks": 0, "wins": 0, "losses": 0}, "bot": {"picks": 0, "wins": 0, "losses": 0}}
			by_path[path][bucket]["picks"] += int(row.get("picks", 0))
			by_path[path][bucket]["wins"] += int(row.get("wins", 0))
			by_path[path][bucket]["losses"] += int(row.get("losses", 0))
	elif DirAccess.dir_exists_absolute(StatsManager.STATS_DIR):
		# Fallback: the legacy flat aggregates merge Quick+Ranked, so treat as PvP.
		for file_name in DirAccess.get_files_at(StatsManager.STATS_DIR):
			if not file_name.ends_with(".stats"):
				continue
			var path := file_name.get_slice(".stats", 0)
			var stats = stats_manager.get_character_stats(path)
			by_path[path] = {
				"path": path,
				"pvp": {"picks": int(stats.get("picks", 0)), "wins": int(stats.get("wins", 0)), "losses": int(stats.get("losses", 0))},
				"bot": {"picks": 0, "wins": 0, "losses": 0},
			}
	var out := []
	for path in by_path:
		out.append(by_path[path])
	return out


# --- SITE USAGE METRICS ---------------------------------------------------------------
# Feeds the admin "Metrics" dashboard: who is here now, and what the traffic has looked like
# over a window. Writes live in MetricsDB; the functions here are the bridge between live
# server state (sessions/queues/matches) and that store.

## Who is on the site RIGHT NOW: {online, in_match, queued, matches}. Humans only — Ultra Bots
## hold real sessions and sit in the ranked queue, so counting them would report an empty
## server as a populated one. This is both the presence sample and the dashboard's live row,
## deliberately the same function so the chart and the header can never disagree.
func _live_usage_counts() -> Dictionary:
	var online := 0
	var in_match := 0
	for uname in sessions:
		var sess = sessions[uname]
		if sess == null or _is_bot_peer(sess.peer_id):
			continue
		if sess.player_data != null and sess.player_data.is_ultra_bot:
			continue
		if sess.status != ServerSession.ConnectionState.ONLINE:
			continue   # held (disconnected, awaiting reconnect) — not currently present
		online += 1
		if sess.current_match != null and is_instance_valid(sess.current_match):
			in_match += 1
	# Queues live in THREE separate containers — quick in queued_players, ladder in the
	# per-rank/per-tier ranked_queue buckets, private invites in private_queue. Counting only
	# the first (the obvious one) would report an empty queue while the whole ladder sits in it.
	# Deduped by peer id: a player can be in the quick and ranked queues at the same time.
	var queued_peers := {}
	for peer_id in queued_players:
		if not _is_bot_peer(peer_id):
			queued_peers[peer_id] = true
	for rank in ranked_queue:
		for tier in ranked_queue[rank]:
			for entry in ranked_queue[rank][tier]:
				if entry.size() > 0 and not _is_bot_peer(entry[0]):
					queued_peers[entry[0]] = true
	for key in private_queue:
		if private_queue[key].size() > 0 and not _is_bot_peer(private_queue[key][0]):
			queued_peers[private_queue[key][0]] = true
	var queued := queued_peers.size()
	var live_matches := 0
	for m in (ranked_matches + quick_matches + private_matches + bot_matches):
		if is_instance_valid(m):
			live_matches += 1
	return {"online": online, "in_match": in_match, "queued": queued, "matches": live_matches}


## Periodic concurrency sample + heartbeat for every open visit (see MetricsDB.touch_open_visits:
## this is what keeps a session's recorded length honest if the process dies without a clean
## disconnect). Both run off one timer so a sample and its heartbeat always share a timestamp.
func _sample_presence() -> void:
	if metrics_db == null:
		return
	var now := int(Time.get_unix_time_from_system())
	var live := _live_usage_counts()
	metrics_db.record_presence(now, int(live["online"]), int(live["in_match"]), int(live["queued"]))
	var names := []
	for uname in sessions:
		var sess = sessions[uname]
		if sess == null or _is_bot_peer(sess.peer_id):
			continue
		if sess.player_data != null and sess.player_data.is_ultra_bot:
			continue
		if sess.status == ServerSession.ConnectionState.ONLINE:
			names.append(uname)
	metrics_db.touch_open_visits(names, now)


## The whole dashboard payload for one window, assembled server-side. Built in one place (rather
## than as a dozen client round-trips) so every figure on screen describes the SAME window — a
## dashboard whose tiles were fetched at different moments is how a "drop in traffic" turns out
## to be two queries a minute apart.
func _site_metrics(days: int) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var day: int = MetricsDB.DAY
	# Windows are whole UTC days ending with today, matching how the series is bucketed —
	# a window ending mid-day would make the newest bar a partial day next to full ones
	# without saying so.
	var today: int = (now / day) * day
	var from_ts: int = today - (maxi(days, 1) - 1) * day
	var live := _live_usage_counts()
	var out := {
		"now": now,
		"days": days,
		"from_ts": from_ts,
		"to_ts": now,
		"live": live,
		"total_accounts": players.size(),
	}
	if metrics_db == null:
		out["unavailable"] = true
		return out
	# Rolling active-user counts. These are the standard D/W/M actives, each measured back
	# from NOW rather than from the window, so they mean the same thing whatever range is
	# selected on screen.
	out["dau"] = metrics_db.active_users(today, now)
	out["wau"] = metrics_db.active_users(now - 7 * day, now)
	out["mau"] = metrics_db.active_users(now - 30 * day, now)
	out["active"] = metrics_db.active_users(from_ts, now)
	out["sessions"] = metrics_db.session_lengths(from_ts, now)
	out["mix"] = metrics_db.new_vs_returning(from_ts, now)
	out["registrations"] = metrics_db.event_totals("register", from_ts, now)
	out["matches"] = metrics_db.event_totals("match", from_ts, now)
	out["matches_by_mode"] = metrics_db.matches_by_mode(from_ts, now)
	out["peak"] = metrics_db.peak_presence(from_ts, now)
	out["hours"] = metrics_db.hour_histogram(from_ts, now)
	out["retention"] = metrics_db.retention(from_ts - 7 * day, now, now)
	out["visit_span"] = metrics_db.visit_span()
	out["data_span"] = metrics_db.span()
	# One row per UTC day, gap-filled, so the client renders a calendar rather than a list of
	# whatever days happened to have traffic. A missing day IS the signal on a usage chart.
	var visits := {}
	for r in metrics_db.daily_visits(from_ts, now):
		visits[int(r["day"])] = r
	var matches := {}
	for r in metrics_db.daily_events("match", from_ts, now):
		matches[int(r["day"])] = r
	var regs := {}
	for r in metrics_db.daily_events("register", from_ts, now):
		regs[int(r["day"])] = r
	var pres := {}
	for r in metrics_db.daily_presence(from_ts, now):
		pres[int(r["day"])] = r
	var series := []
	var d: int = from_ts
	while d <= today:
		var v = visits.get(d, null)
		var m = matches.get(d, null)
		var g = regs.get(d, null)
		var p = pres.get(d, null)
		series.append({
			"day": d,
			"players": 0 if v == null else int(v["players"]),
			"sessions": 0 if v == null else int(v["sessions"]),
			"seconds": 0 if v == null else int(v["seconds"] if v["seconds"] != null else 0),
			"matches": 0 if m == null else int(m["refs"]),
			"match_players": 0 if m == null else int(m["players"]),
			"registrations": 0 if g == null else int(g["count"]),
			"peak_online": 0 if p == null else int(p["peak"]),
		})
		d += day
	out["series"] = series
	var per_user := metrics_db.matches_per_user(from_ts, now)
	var top := []
	for r in metrics_db.top_players(from_ts, now, 20):
		var uname := str(r["username"])
		top.append({
			"username": uname,
			"sessions": int(r["sessions"]),
			"seconds": int(r["seconds"] if r["seconds"] != null else 0),
			"last_seen": int(r["last_seen"]),
			"matches": int(per_user.get(uname, 0)),
			"online": uname in sessions,
		})
	out["top_players"] = top
	return out

# Character unlocks are stored as "<path>_unlock" gate strings; accept either form from the admin.
func _normalize_unlock(raw: String) -> String:
	var u := raw.strip_edges()
	if u == "":
		return ""
	if not u.ends_with("_unlock"):
		u += "_unlock"
	return u

# --- CORE CONNECTION LOGIC ---

func actually_start_server():
	is_server = true
	# The legacy WebSocketMultiplayerPeer server (port 5696, retired desktop client) is GONE.
	# It carried ~80 unauthenticated @rpc handlers reachable by anyone who could open a socket;
	# the web client has never used it. The JSON gateway below (port 5695) is the only transport.
	print("[SERVER] Loaded ", players.size(), " players, ", clans.size(), " clans")
	_load_server_flags()
	_start_json_gateway()
	server_start.emit()

# --- JSON GATEWAY (web client) -------------------------------------------------
func _start_json_gateway():
	json_gateway = load("res://webclient/json_gateway.gd").new()
	add_child(json_gateway)
	json_gateway.message_received.connect(_on_json_message)
	json_gateway.client_disconnected.connect(_on_json_disconnected)
	json_gateway.listen(JSON_GATEWAY_PORT)
	print("[SERVER] JSON gateway listening on port ", JSON_GATEWAY_PORT)

func _is_json_peer(peer_id: int) -> bool:
	return peer_id >= JSON_PEER_BASE

func _json_local(peer_id: int) -> int:
	return peer_id - JSON_PEER_BASE

# Outbound: route a server->client message to a web peer over the JSON gateway.
# Every peer is a JSON peer now that the legacy Godot-RPC transport is gone, so the
# old _rpc_to_godot positional-arg bridge has been deleted along with it.
func send_to_peer(peer_id: int, method: String, payload: Dictionary) -> void:
	if _is_bot_peer(peer_id):
		return   # Ultra Bot / fallback-bot seat: no socket, so every outbound frame is a silent no-op.
	if not _is_json_peer(peer_id):
		push_error("[send_to_peer] non-JSON peer %d for '%s' — legacy RPC transport is removed" % [peer_id, method])
		return
	if json_gateway:
		var frame := {"type": method}
		frame.merge(payload)
		json_gateway.send(_json_local(peer_id), frame)

# A web client's frames arrive here (gateway peer id is gateway-local). We lift it
# into the shared logical id space (JSON_PEER_BASE + id) so sessions/peer_map work
# exactly as on the RPC path, then reuse the same handlers.
func _on_json_message(json_pid: int, msg: Dictionary) -> void:
	var logical_peer: int = JSON_PEER_BASE + json_pid
	var t := str(msg.get("type", ""))
	# Character Creator kill switch, applied to the WHOLE authored_* surface in one place rather
	# than per-handler — hiding the button does nothing on its own, since these frames can be sent
	# by hand. Admins pass through so they can build and test while the feature is dark.
	# EXCEPTION: authored_asset_fetch serves already-uploaded art (portraits / ability icons) for
	# characters that are live in matches. The kill switch gates NEW authoring, not the serving of
	# APPROVED content — approved content is live content. An opponent (who may be a plain player
	# while the Creator is dark, e.g. facing an admin fielding an approved authored character) must
	# still be able to stream that character's portrait mid-match, so the art frame sits OUTSIDE the
	# gate. The handler still requires a logged-in player and an existing authored asset, so it can
	# only ever return art that already passed upload — it opens no authoring capability.
	if t.begins_with("authored_") and t != "authored_asset_fetch":
		var cp = get_player(logical_peer)
		if cp == null or _creator_blocked(cp.username):
			json_gateway.send(json_pid, {"type": "error", "reason": "The Character Creator isn't available yet"})
			return
	match t:
		"ping":
			json_gateway.send(json_pid, {"type": "pong", "echo": msg.get("payload", null)})
		"server_status":
			# PRE-AUTH on purpose: this is what an ejected client polls while it waits for the
			# relaunched server. boot_id changes on every process start, which is the only reliable
			# "this is a different server than the one that ejected me" signal — a reconnect alone
			# cannot tell a relaunched server from the old one that has not died yet.
			json_gateway.send(json_pid, {"type": "server_status", "boot_id": boot_id,
				"maintenance": _maintenance_locked(), "message": str(maintenance.get("message", ""))})
		"login", "register":
			# Refuse new sessions once the update lock is on, so a player who refreshes during the
			# window cannot slip back in ahead of the restart.
			if _maintenance_locked():
				json_gateway.send(json_pid, {"type": "maintenance_locked",
					"message": str(maintenance.get("message", MAINTENANCE_DEFAULT)), "boot_id": boot_id})
			elif t == "login":
				_process_login(logical_peer, str(msg.get("username", "")), str(msg.get("password", "")))
			else:
				_process_register(logical_peer, str(msg.get("username", "")), str(msg.get("password", "")))
		"change_password":
			_process_change_password(logical_peer, str(msg.get("current", "")), str(msg.get("new", "")))
		"queue_quick", "queue_ranked", "queue_private":
			_json_enqueue(logical_peer, t.trim_prefix("queue_"), msg)
		"queue_bot":
			# Immediate bot game — the player explicitly wants a bot, no queue / fallback timer.
			start_immediate_bot_match(logical_peer, msg.get("characters", []))
		"cancel_queue":
			cancel_queue(logical_peer)
		"campaign_start_battle":
			# Single-player PvE campaign encounter. Logged-in only; teams validated in start_campaign_battle.
			if get_player(logical_peer):
				start_campaign_battle(logical_peer, msg)
			else:
				json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
		"campaign_enter":
			_campaign_enter(logical_peer, json_pid)
		"campaign_travel":
			_campaign_travel(logical_peer, json_pid, str(msg.get("to", "")))
		"campaign_activation_complete":
			_campaign_complete(logical_peer, json_pid, str(msg.get("node", "")), str(msg.get("activation", "")))
		"campaign_choice":
			_campaign_choice(logical_peer, json_pid, str(msg.get("scene", "")), int(msg.get("line", -1)), int(msg.get("choice", -1)))
		"campaign_arrive":
			_campaign_arrive(logical_peer, json_pid, str(msg.get("node", "")))
		"campaign_abandon":
			_campaign_abandon(logical_peer, json_pid, str(msg.get("node", "")), str(msg.get("activation", "")))
		"campaign_set_party":
			_campaign_set_party(logical_peer, json_pid, msg.get("party", []))
		"campaign_set_vessel_skills":
			_campaign_set_vessel_skills(logical_peer, json_pid, msg.get("skills", []))
		"submit_ban":
			_json_draft_action(logical_peer, "ban", msg)
		"submit_pick":
			_json_draft_action(logical_peer, "pick", msg)
		"lock_bans":
			_json_draft_action(logical_peer, "lock", msg)
		"draft_hover":
			var hsess = get_session(logical_peer)
			if hsess and hsess.current_match and is_instance_valid(hsess.current_match):
				hsess.current_match.set_draft_hover(logical_peer, str(msg.get("character", "")))
		"submit_turn_input":
			# On a silent validation rejection, reply with an error so the web client re-enables
			# its turn UI immediately instead of waiting on its recovery watchdog.
			if not _process_turn_input(logical_peer, msg.get("match_id", 0), msg.get("input", {}), true):
				json_gateway.send(json_pid, {"type": "error", "reason": "Turn rejected — not a legal play (check energy, cooldowns, and targets)"})
		"surrender":
			# Routes to the same core as the Godot send_surrender->process_surrender path.
			# The match-end broadcast (apply_turn_result + MATCH_ENDED) is already bridged,
			# so both players get the win/loss; receive_surrender stays a redundant ping.
			process_surrender(logical_peer)
		"save_cosmetics":
			# Mirrors update_player_cosmetics core (absorb_cosmetic_update + resave_player).
			# The client omits mastery_xp, so server mastery progress is left untouched.
			var cp = get_player(logical_peer)
			if cp:
				cp.absorb_cosmetic_update(msg.get("update", {}))
				resave_player(cp)
		"nexus_state":
			# All character buckets + the current leader max + poll state. The web client groups
			# by universe (via roster.json) and computes the leaderboard itself.
			var ns = bucket_handler.get_all_bucket_sets()  # [current_max, [[path_name, ap], ...]]
			json_gateway.send(json_pid, {"type": "nexus_state", "max": ns[0], "sets": ns[1], "poll_open": _poll_open()})
		"donate":
			# Contribute AP to a character bucket. Unlike the client-trusted Godot path
			# (receive_player_contribution never debits AP), we debit + validate server-side,
			# then echo receive_player_update so the browser AP stays authoritative.
			var dp = get_player(logical_peer)
			var dpath := str(msg.get("path_name", ""))
			var damount := int(msg.get("amount", 0))  # int() coerces the JSON float
			if dp == null or damount <= 0 or not bucket_handler.has_character_bucket(dpath):
				json_gateway.send(json_pid, {"type": "error", "reason": "bad donate"})
			elif not _poll_open():
				json_gateway.send(json_pid, {"type": "error", "reason": "nexus closed"})
			elif dp.ap < damount:
				json_gateway.send(json_pid, {"type": "error", "reason": "insufficient AP"})
			else:
				dp.contribute_ap(damount)  # ap -= amount
				resave_player(dp)          # persist the lowered AP (mirrors save_cosmetics)
				var upd = bucket_handler.process_bucket_update(dpath, damount)  # [name, new_ap, current_max]
				send_player_update(logical_peer)  # client refreshes S.player (authoritative AP)
				# The Godot-RPC fan-out that used to follow was removed with the desktop client: there
				# is no @rpc "update_buckets" left anywhere and the server never opens a Godot peer,
				# so it only logged "Unable to get the RPC configuration" on every donation.
				json_gateway.send(json_pid, {"type": "update_buckets", "path_name": upd[0], "amount": upd[1], "current_max": upd[2]})
		"ladder":
			# Ranked ladder (by_rating/by_wins/by_streak + clans), top-50 with a "me" row if below cut.
			var lp = get_player(logical_peer)
			json_gateway.send(json_pid, {"type": "ladder", "ladder": _build_ladder_info(lp.username if lp else "")})
		"bounty_missions":
			# Read-only: generate a bounty's 25 missions server-side (avoids porting Godot hash()+PCG32).
			# Rerolls are derived server-side so the missions match the server-computed progress.
			var bp = get_player(logical_peer)
			if bp:
				var bpath := str(msg.get("path", ""))
				var btype := str(msg.get("btype", "unlock"))
				var bkey := bpath + Bounty.MASTERY_SUFFIX if btype == "mastery" else bpath
				var brr = bp.get_bounty_rerolls(bkey)
				var bb = Bounty.get_bounty(bp.username, bpath, str(brr), btype)
				json_gateway.send(json_pid, {"type": "bounty_missions", "path": bpath, "btype": btype, "key": bkey, "rerolls": brr, "missions": bb.missions})
		"complete_bounty":
			# Server-authoritative reward: validate the bingo completion, grant AP / mastery-XP / unlock,
			# erase the bounty, and echo receive_player_update. (save_cosmetics omits mastery_xp, so the
			# mastery reward must be granted here, not client-side.)
			var ccp = get_player(logical_peer)
			var ckey := str(msg.get("bounty_path", ""))
			if ccp and ckey in ccp.active_bounties:
				var c_mastery := ckey.ends_with(Bounty.MASTERY_SUFFIX)
				var c_raw := ckey.trim_suffix(Bounty.MASTERY_SUFFIX) if c_mastery else ckey
				var c_type := "mastery" if c_mastery else "unlock"
				var cb = Bounty.get_bounty(ccp.username, c_raw, str(ccp.get_bounty_rerolls(ckey)), c_type)
				if cb.bounty_completed(ccp.active_bounties[ckey]):
					if c_mastery:
						ccp.ap += 5000
						ccp.character_progress.award_xp(c_raw, 1000)
					else:
						ccp.unlocks.append(c_raw + "_unlock")
					ccp.active_bounties.erase(ckey)
					ccp.bounty_rerolls.erase(ckey)
					resave_player(ccp)
					send_player_update(logical_peer)
				else:
					json_gateway.send(json_pid, {"type": "error", "reason": "bounty not complete"})
		"admin_announce":
			# Admin-only server-wide announcement. Authority is re-checked HERE server-side —
			# the client's UI gating is convenience only and must never be trusted. On success,
			# fan the message out to every connected client as a scrolling marquee.
			var ap = get_player(logical_peer)
			if ap == null or not _is_admin(ap.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized to send announcements"})
			else:
				var announce_text := str(msg.get("text", "")).strip_edges()
				if announce_text == "":
					json_gateway.send(json_pid, {"type": "error", "reason": "Announcement text is empty"})
				else:
					if announce_text.length() > 500:
						announce_text = announce_text.substr(0, 500)
					print("[ANNOUNCE] '", ap.username, "' broadcast: ", announce_text)
					json_gateway.broadcast({"type": "announcement", "text": announce_text, "from": ap.username})
		"admin_close_nexus_round":
			# Admin-only: close a Nexus voting round. Removes the top `count` characters (they leave
			# the Nexus permanently + stop accepting/tracking AP, persisted to removed_list.dat) and
			# halves every remaining bucket so order is kept but the field is easier to catch. Authority
			# re-checked HERE; UI gating is convenience only. Broadcasts a fresh nexus_state to everyone.
			var nca = get_player(logical_peer)
			if nca == null or not _is_admin(nca.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				var nc_count = int(msg.get("count", 0))
				var nc_result = bucket_handler.close_nexus_round(nc_count)
				broadcast_nexus_state()
				print("[ADMIN] '", nca.username, "' closed nexus round (count=", nc_count, "): removed ", nc_result.removed)
				json_gateway.send(json_pid, {"type": "nexus_round_closed", "removed": nc_result.removed, "remaining": nc_result.remaining, "current_max": nc_result.current_max})
		"admin_scale_nexus_ap":
			# Admin-only: multiply every Nexus character's AP by `multiplier` (a decimal below 1 divides;
			# result rounded to nearest int). Authority re-checked HERE; UI gating is convenience only.
			# Broadcasts a fresh nexus_state so every client's standings update.
			var nsa = get_player(logical_peer)
			if nsa == null or not _is_admin(nsa.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				var ns_mult = float(msg.get("multiplier", 1.0))
				if ns_mult <= 0 or not is_finite(ns_mult):
					json_gateway.send(json_pid, {"type": "error", "reason": "Multiplier must be greater than 0"})
				else:
					var ns_result = bucket_handler.scale_all_buckets(ns_mult)
					broadcast_nexus_state()
					print("[ADMIN] '", nsa.username, "' scaled nexus AP by ", ns_mult, " (", ns_result.scaled, " buckets)")
					json_gateway.send(json_pid, {"type": "nexus_scaled", "multiplier": ns_mult, "count": ns_result.scaled})
		"admin_ultra_bot":
			# Admin-only: manually drive an Ultra Bot's presence for SMOKE-TESTING before the P5 rotation
			# scheduler exists. action in {online, queue, offline, status}. Authority re-checked HERE.
			var uba = get_player(logical_peer)
			if uba == null or not _is_admin(uba.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				var ub_action := str(msg.get("action", "status"))
				var ub_name := str(msg.get("username", "")).strip_edges()
				match ub_action:
					"online":
						var ub_pid := _ultra_bot_online(ub_name)
						if ub_pid != 0:
							_ultra_bot_pinned[ub_name] = true   # PIN: stay online despite the schedule (smoke-test)
						print("[ADMIN] '", uba.username, "' Ultra Bot online: ", ub_name, " -> peer ", ub_pid)
						json_gateway.send(json_pid, {"type": "ultra_bot_result", "action": "online", "username": ub_name, "ok": ub_pid != 0})
					"queue":
						var ub_pid2 := _ultra_bot_online(ub_name)   # ensure online first
						if ub_pid2 == 0:
							json_gateway.send(json_pid, {"type": "ultra_bot_result", "action": "queue", "username": ub_name, "ok": false})
						else:
							_ultra_bot_pinned[ub_name] = true   # PIN: stay online + queued despite the schedule
							_ultra_bot_enqueue_ranked(ub_name)
							print("[ADMIN] '", uba.username, "' Ultra Bot queued (ranked): ", ub_name)
							json_gateway.send(json_pid, {"type": "ultra_bot_result", "action": "queue", "username": ub_name, "ok": true})
					"offline":
						_ultra_bot_offline(ub_name)
						print("[ADMIN] '", uba.username, "' Ultra Bot offline: ", ub_name)
						json_gateway.send(json_pid, {"type": "ultra_bot_result", "action": "offline", "username": ub_name, "ok": true})
					"deploy":
						# Master persistent switch: launch (seed + activate) or stand down the whole fleet.
						_ultra_bot_deploy(bool(msg.get("on", true)))
						print("[ADMIN] '", uba.username, "' Ultra Bots DEPLOY -> ", _ultra_bot_deployed)
						json_gateway.send(json_pid, {"type": "ultra_bot_result", "action": "deploy", "ok": true})
					"rotation":
						# Live kill-switch for the automatic daily rotation scheduler.
						_ultra_bot_rotation_enabled = bool(msg.get("on", true))
						if _ultra_bot_rotation_enabled and _ultra_bot_deployed:
							_ultra_bot_rotation_tick()   # apply the current hour's roster right away
						print("[ADMIN] '", uba.username, "' Ultra Bot rotation -> ", _ultra_bot_rotation_enabled)
						json_gateway.send(json_pid, {"type": "ultra_bot_result", "action": "rotation", "ok": true})
					_:
						var ub_list := []
						for uname in players:
							var pl = players[uname]
							if pl != null and pl.is_ultra_bot:
								var ub_online: bool = uname in _ultra_bot_peers
								ub_list.append({
									"username": uname,
									"rating": pl.rank.get_rating(),
									"online": ub_online,
									"pinned": uname in _ultra_bot_pinned,
									"queued": ub_online and not _find_ranked_entry(_ultra_bot_peers[uname]).is_empty(),
									"in_match": (uname in sessions) and sessions[uname].current_match != null,
								})
						json_gateway.send(json_pid, {"type": "ultra_bot_status", "bots": ub_list, "rotation_enabled": _ultra_bot_rotation_enabled, "deployed": _ultra_bot_deployed})
		"admin_maintenance":
			var mta = get_player(logical_peer)
			if mta == null or not _is_admin(mta.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				var mt_action := str(msg.get("action", ""))
				# Sanitized like any other admin-authored text that lands on every client's screen.
				var mt_msg := _clean_text(str(msg.get("message", "")), 200)
				if mt_msg == "":
					mt_msg = MAINTENANCE_DEFAULT
				match mt_action:
					"warn":
						var mt_secs: int = clampi(int(msg.get("seconds", 300)), 0, 7200)
						maintenance = {"message": mt_msg, "locked": false, "seconds": mt_secs}
						json_gateway.broadcast({"type": "maintenance_notice", "message": mt_msg,
							"seconds": mt_secs, "boot_id": boot_id})
						print("[ADMIN] '", mta.username, "' announced maintenance in ", mt_secs, "s: ", mt_msg)
						json_gateway.send(json_pid, {"type": "maintenance_state", "phase": "warn", "message": mt_msg, "seconds": mt_secs})
					"eject":
						maintenance = {"message": mt_msg, "locked": true}
						# Cancel live matches + empty the queues BEFORE the broadcast, so no match can
						# resolve against a player who is already on their way to the login screen.
						var stood_down = _maintenance_stand_down()
						# Everyone EXCEPT the admins lands on the login screen and waits for a new boot_id.
						json_gateway.broadcast_except(_admin_peer_ids(),
							{"type": "maintenance_eject", "message": mt_msg, "boot_id": boot_id})
						print("[ADMIN] '", mta.username, "' EJECTED all clients for maintenance: ", mt_msg,
							" (", stood_down[0], " match(es) cancelled, ", stood_down[1], " dequeued)")
						json_gateway.send(json_pid, {"type": "maintenance_state", "phase": "ejected",
							"message": mt_msg, "matches_cancelled": stood_down[0], "dequeued": stood_down[1]})
					"cancel":
						maintenance = {}
						json_gateway.broadcast({"type": "maintenance_cleared", "boot_id": boot_id})
						print("[ADMIN] '", mta.username, "' cancelled maintenance")
						json_gateway.send(json_pid, {"type": "maintenance_state", "phase": "off"})
					_:
						json_gateway.send(json_pid, {"type": "error", "reason": "Unknown maintenance action: " + mt_action})
		"admin_season_reset":
			# Admin-only, and separate from admin_modify_player because it has no single target.
			# Defaults to a DRY RUN: a caller who sends nothing but the message type gets a preview,
			# never a wipe. Applying requires dry_run=false AND the exact confirm phrase.
			var sra = get_player(logical_peer)
			if sra == null or not _is_admin(sra.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				var sr_dry := bool(msg.get("dry_run", true))
				var sr_res := _season_reset(sr_dry, str(msg.get("confirm", "")))
				if not sr_dry and sr_res.get("ok", false):
					print("[ADMIN] '", sra.username, "' ran the SEASON RESET")
				sr_res["type"] = "admin_season_reset_result"
				json_gateway.send(json_pid, sr_res)
		"admin_list_players":
			# Admin-only: snapshot of every connected session + its status/stats.
			var la = get_player(logical_peer)
			if la == null or not _is_admin(la.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				var rows := []
				for uname in sessions:
					rows.append(_admin_summarize(uname, sessions[uname].player_data))
				json_gateway.send(json_pid, {"type": "admin_players", "players": rows, "total_accounts": players.size()})
		"admin_training_status":
			# Admin-only: v3 bot-training dashboard snapshot — the trainer's status
			# file, the Elo ledger, the live policy generation, and the available
			# training replays. All read fresh from disk so a running orchestrator
			# shows live numbers.
			var ta = get_player(logical_peer)
			if ta == null or not _is_admin(ta.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				var live_gen := -1
				var lp = BattleManager._get_live_bot_policy()
				if lp != null:
					live_gen = lp.generation
				var replay_names := []
				var rdir := DirAccess.open("res://training/replays")
				if rdir != null:
					for fname in rdir.get_files():
						if fname.ends_with(".replay"):
							replay_names.append(fname)
				replay_names.sort()
				# Cap the payload (long runs accumulate hundreds of replays and
				# elo rows) and send_queued: a plain send() silently DROPS the
				# frame once the peer's 64KB WS buffer backs up.
				if replay_names.size() > 24:
					replay_names = replay_names.slice(replay_names.size() - 24)
				var elo_dict := _read_json_dict("res://training/elo.json")
				if elo_dict.has("history") and elo_dict["history"] is Array and elo_dict["history"].size() > 40:
					elo_dict = elo_dict.duplicate()
					elo_dict["history"] = elo_dict["history"].slice(elo_dict["history"].size() - 40)
				json_gateway.send_queued(json_pid, {"type": "admin_training_status",
					"status": _read_json_dict("res://training/training_status.json"),
					"elo": elo_dict,
					"live_generation": live_gen, "replays": replay_names})
		"admin_get_bot_tuning":
			var ga = get_player(logical_peer)
			if ga == null or not _is_admin(ga.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				json_gateway.send(json_pid, {"type": "admin_bot_tuning", "tuning": _read_json_dict("res://bot_tuning.json")})
		"admin_set_bot_tuning":
			# Admin-only: overwrite bot_tuning.json (the v3 hand-tuning overlay).
			# Validated to be a dict carrying the right format tag; live bots
			# hot-reload it by mtime, no restart needed.
			var sa = get_player(logical_peer)
			if sa == null or not _is_admin(sa.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				var tuning = msg.get("tuning")
				if tuning is String:
					tuning = JSON.parse_string(tuning)
				var tuning_problem := _validate_bot_tuning(tuning)
				if tuning_problem != "":
					json_gateway.send(json_pid, {"type": "error", "reason": "Invalid tuning: " + tuning_problem})
				else:
					var tf := FileAccess.open("res://bot_tuning.json", FileAccess.WRITE)
					if tf == null:
						json_gateway.send(json_pid, {"type": "error", "reason": "Could not write bot_tuning.json"})
					else:
						tf.store_string(JSON.stringify(tuning, "\t"))
						tf.close()
						# Invalidate the in-process mtime cache so a second save
						# within the same wall-clock second still hot-reloads.
						BattleManager._live_tuning_mtime = -1
						print("[ADMIN] '", sa.username, "' updated bot_tuning.json")
						json_gateway.send(json_pid, {"type": "admin_bot_tuning_saved"})
		# --- AUTHORED CHARACTERS (block editor) ------------------------------
		# Ownership and status are decided here, never by the client: the author
		# is always the authenticated session, and only an admin can approve.
		"authored_list":
			var alp = get_player(logical_peer)
			if alp == null:
				json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
			else:
				var mine := []
				for s in AuthoredRegistry.specs_for_author(alp.username):
					mine.append(_authored_summary(s))
				var pub := []
				for s in AuthoredRegistry.approved_specs():
					pub.append(_authored_summary(s))
				var review := []
				if _is_admin(alp.username):
					for s in AuthoredRegistry.all_specs():
						if str(s.get("status", "")) == "submitted":
							review.append(_authored_summary(s))
				json_gateway.send_queued(json_pid, {"type": "authored_list",
					"mine": mine, "approved": pub, "review": review,
					"palette": _authored_palette()})
		"authored_get":
			var agp = get_player(logical_peer)
			var aspec = AuthoredRegistry.get_spec(str(msg.get("id", "")))
			if agp == null or aspec == null:
				json_gateway.send(json_pid, {"type": "error", "reason": "no such character"})
			elif str(aspec.get("author", "")) != agp.username and str(aspec.get("status","")) != "approved" and not _is_admin(agp.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "not yours"})
			else:
				json_gateway.send_queued(json_pid, {"type": "authored_spec", "spec": aspec})
		"authored_save":
			var asp = get_player(logical_peer)
			if asp == null:
				json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
			else:
				var incoming = msg.get("spec", null)
				if incoming is String:
					incoming = JSON.parse_string(incoming)
				json_gateway.send_queued(json_pid, _authored_save(asp.username, incoming))
		"authored_submit", "authored_unsubmit":
			var aup = get_player(logical_peer)
			var uspec = AuthoredRegistry.get_spec(str(msg.get("id", "")))
			if aup == null or uspec == null or str(uspec.get("author", "")) != aup.username:
				json_gateway.send(json_pid, {"type": "error", "reason": "not your character"})
			else:
				uspec = uspec.duplicate(true)
				uspec["status"] = "submitted" if str(msg.get("type", "")) == "authored_submit" else "testing"
				var serrs := AuthoredRegistry.save_spec(uspec)
				if serrs.is_empty():
					json_gateway.send(json_pid, {"type": "authored_saved", "id": uspec["id"], "status": uspec["status"]})
				else:
					json_gateway.send(json_pid, {"type": "error", "reason": "; ".join(serrs)})
		"authored_delete":
			var adp = get_player(logical_peer)
			if adp == null:
				json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
			else:
				var did := str(msg.get("id", ""))
				var derrs := AuthoredRegistry.delete_spec(did, adp.username, _is_admin(adp.username))
				if derrs.is_empty():
					AuthoredAssets.delete_all(did)
					json_gateway.send(json_pid, {"type": "authored_deleted", "id": did})
				else:
					json_gateway.send(json_pid, {"type": "error", "reason": "; ".join(derrs)})
		"authored_review":
			# Admin-only: approve or reject a submitted character.
			var arp = get_player(logical_peer)
			if arp == null or not _is_admin(arp.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				var rspec = AuthoredRegistry.get_spec(str(msg.get("id", "")))
				var verdict := str(msg.get("verdict", ""))
				if rspec == null or not verdict in ["approved", "rejected"]:
					json_gateway.send(json_pid, {"type": "error", "reason": "bad review request"})
				else:
					rspec = rspec.duplicate(true)
					rspec["status"] = verdict
					rspec["review_note"] = str(msg.get("note", "")).substr(0, 300)
					var rerrs := AuthoredRegistry.save_spec(rspec)
					if rerrs.is_empty():
						print("[AUTHORED] '", arp.username, "' ", verdict, " ", rspec["id"])
						json_gateway.send(json_pid, {"type": "authored_reviewed", "id": rspec["id"], "status": verdict})
					else:
						json_gateway.send(json_pid, {"type": "error", "reason": "; ".join(rerrs)})
		"authored_validate":
			# Live editor feedback: validate WITHOUT persisting and return the
			# generated descriptions. The editor renders these rather than
			# reimplementing the generator in JS, so preview and battle text can
			# never drift.
			var avp = get_player(logical_peer)
			if avp == null:
				json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
			else:
				var cand = msg.get("spec", null)
				if cand is String:
					cand = JSON.parse_string(cand)
				json_gateway.send_queued(json_pid, _authored_validate(cand))
		"authored_asset_fetch":
			# Uploaded art lives on the GAME server, not the static asset host, so
			# the client pulls it over the socket and caches a blob URL. Chunked
			# with the same {part,total} shape the replay stream uses.
			var afp = get_player(logical_peer)
			if afp == null:
				json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
			else:
				var fid := str(msg.get("id", ""))
				var fslot := str(msg.get("slot", "portrait"))
				var okslot := fslot in AuthoredAssets.SLOTS
				# APPROVAL GATE. ABUSE CASE: this handler answers for any authored id whose spec+asset
				# exist, so a logged-in player who GUESSES another author's id could pull their
				# UNAPPROVED, work-in-progress art. The kill-switch exemption's own justification is
				# "approved content is live content", so the public fetch serves ONLY approved content —
				# the same gate char-select and fielding already use. The one authenticated exception is
				# the author fetching their OWN art (the editor preview goes through this same frame), so
				# it stays served regardless of approval. A blocked id answers {missing:true}, identical
				# to a truly-absent id, so the response never reveals whether the id exists.
				# The third arm covers the opponent in a Private match: they must render an author's own
				# unapproved character while it is fielded against them (see _char_in_live_match).
				var fauthorised: bool = AuthoredRegistry.is_approved(fid) or AuthoredRegistry.author_of(fid) == afp.username or _char_in_live_match(get_session(logical_peer), fid)
				var fbytes := FileAccess.get_file_as_bytes(AuthoredAssets.asset_path(fid, fslot)) if (okslot and fauthorised and AuthoredRegistry.is_authored(fid) and AuthoredAssets.has_asset(fid, fslot)) else PackedByteArray()
				if fbytes.size() == 0:
					json_gateway.send(json_pid, {"type": "authored_asset_data", "id": fid, "slot": fslot, "missing": true})
				else:
					var b64 := Marshalls.raw_to_base64(fbytes)
					var atotal := int(ceil(float(b64.length()) / float(REPLAY_CHUNK)))
					for apart in range(atotal):
						json_gateway.send_queued(json_pid, {"type": "authored_asset_data",
							"id": fid, "slot": fslot, "part": apart, "total": atotal,
							"data": b64.substr(apart * REPLAY_CHUNK, REPLAY_CHUNK)})
		"authored_upload_begin", "authored_upload_chunk", "authored_upload_end":
			var aip = get_player(logical_peer)
			if aip == null:
				json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
			else:
				json_gateway.send(json_pid, _authored_upload(aip.username, msg))
		"admin_fetch_training_replay":
			# Admin-only: stream a training .replay through the same chunk protocol
			# the client's replay_data handler already reassembles (match_id keys
			# the buffer, so the filename-derived id coexists with PvP fetches).
			var ra = get_player(logical_peer)
			if ra == null or not _is_admin(ra.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				var rname := str(msg.get("name", ""))
				var name_ok := rname.ends_with(".replay") and not rname.contains("/") and not rname.contains("\\") and not rname.contains("..")
				var rf = FileAccess.open("res://training/replays/" + rname, FileAccess.READ) if name_ok else null
				if rf == null:
					json_gateway.send(json_pid, {"type": "replay_result", "ok": false, "note": "Training replay not available"})
				else:
					var rline := rf.get_line()
					var rtotal := int(ceil(float(rline.length()) / float(REPLAY_CHUNK)))
					if rtotal < 1:
						rtotal = 1
					for rpart in rtotal:
						json_gateway.send_queued(json_pid, {"type": "replay_data", "match_id": "train_" + rname, "part": rpart, "total": rtotal, "data": rline.substr(rpart * REPLAY_CHUNK, REPLAY_CHUNK)})
					print("[ADMIN] Queued training replay ", rname, " to ", ra.username, " in ", rtotal, " chunk(s)")
		"admin_modify_player":
			# Admin-only: mutate a target account (online or offline). Authority is re-checked HERE;
			# the client UI gating is convenience only. Persists + pushes a live update if online.
			var ma = get_player(logical_peer)
			if ma == null or not _is_admin(ma.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				var target_name := str(msg.get("target", "")).strip_edges()
				var op := str(msg.get("op", ""))
				var target = _admin_get_target(target_name)
				if target_name == "" or target == null:
					json_gateway.send(json_pid, {"type": "error", "reason": "No such account: " + target_name})
				else:
					var ok := true
					var note := ""
					match op:
						"grant_ap":
							var amt := int(msg.get("value", 0))
							target.ap = maxi(0, int(target.ap) + amt)
							note = str(amt) + " AP applied (now " + str(int(target.ap)) + ")"
						"reset_record":
							_reset_player_record(target)
							note = "Win/loss record reset"
						"add_unlock":
							var uid := _normalize_unlock(str(msg.get("value", "")))
							if uid == "":
								ok = false
								note = "Empty unlock id"
							elif uid in target.unlocks:
								note = uid + " already unlocked"
							else:
								target.unlocks.append(uid)
								note = "Granted " + uid
						"remove_unlock":
							var uid2 := _normalize_unlock(str(msg.get("value", "")))
							if uid2 in target.unlocks:
								target.unlocks.erase(uid2)
								note = "Removed " + uid2
							else:
								note = uid2 + " was not unlocked"
						"mute":
							# Chat mute (Phase 2): a muted sender's chat_send is dropped server-side.
							target.muted = true
							note = target_name + " muted"
						"unmute":
							target.muted = false
							note = target_name + " unmuted"
						_:
							ok = false
							note = "Unknown op: " + op
					if ok:
						resave_player(target)
						print("[ADMIN] '", ma.username, "' ", op, " -> '", target_name, "': ", note)
						if target_name in sessions:
							send_player_update(sessions[target_name].peer_id)
						json_gateway.send(json_pid, {"type": "admin_modify_result", "ok": true, "target": target_name, "note": note, "player": _admin_summarize(target_name, target)})
					else:
						json_gateway.send(json_pid, {"type": "error", "reason": note})
		"admin_character_stats":
			# Admin-only: aggregated per-character usage/win data, bucketed PvP
			# (Quick+Ranked) vs Bot. Authority is re-checked HERE server-side —
			# the client's UI gating is convenience only and must never be trusted.
			var ca = get_player(logical_peer)
			if ca == null or not _is_admin(ca.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				# Optional date window (unix seconds). Absent/0 = all time.
				var cs_from := int(msg.get("from_ts", 0))
				var cs_to := int(msg.get("to_ts", 0))
				var cs_span: Array = stats_db.character_match_span() if stats_db != null else [0, 0]
				json_gateway.send(json_pid, {"type": "admin_character_stats",
					"stats": _admin_character_stats(cs_from, cs_to),
					"from_ts": cs_from, "to_ts": cs_to,
					# So the UI can show the true extent of the data instead of offering a
					# range that contains nothing.
					"data_from": cs_span[0], "data_to": cs_span[1]})
		"admin_site_metrics":
			# Admin-only: the site-usage dashboard payload (visits, sessions, sign-ups, matches,
			# concurrency) for a trailing window of whole UTC days. Authority is re-checked HERE
			# server-side — this exposes per-player activity, so the client's UI gating is
			# convenience only and must never be trusted.
			var ma = get_player(logical_peer)
			if ma == null or not _is_admin(ma.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				# Clamped: the window drives a handful of grouped scans, and an unbounded value
				# from a hand-crafted message would turn the dashboard into a full-table sort.
				var sm_days := clampi(int(msg.get("days", 30)), 1, 365)
				var sm_body := _site_metrics(sm_days)
				sm_body["type"] = "admin_site_metrics"
				json_gateway.send(json_pid, sm_body)
		"clan_state":
			var csp = get_player(logical_peer)
			if csp != null:
				var body := _clan_state_body(csp.username)
				body["type"] = "clan_state"
				json_gateway.send(json_pid, body)
		"create_clan":
			_json_clan_create(logical_peer, json_pid, msg)
		"clan_search":
			_json_clan_search(logical_peer, json_pid, msg)
		"clan_apply":
			_json_clan_apply(logical_peer, json_pid, msg)
		"clan_cancel_application":
			_json_clan_cancel_application(logical_peer, json_pid, msg)
		"clan_invite":
			_json_clan_invite(logical_peer, json_pid, msg)
		"clan_cancel_invite":
			_json_clan_cancel_invite(logical_peer, json_pid, msg)
		"clan_accept_invite":
			_json_clan_accept_invite(logical_peer, json_pid, msg)
		"clan_decline_invite":
			_json_clan_decline_invite(logical_peer, json_pid, msg)
		"clan_approve_application":
			_json_clan_approve_application(logical_peer, json_pid, msg)
		"clan_deny_application":
			_json_clan_deny_application(logical_peer, json_pid, msg)
		"clan_kick":
			_json_clan_kick(logical_peer, json_pid, msg)
		"clan_promote":
			_json_clan_promote(logical_peer, json_pid, msg)
		"clan_demote":
			_json_clan_demote(logical_peer, json_pid, msg)
		"clan_leave":
			_json_clan_leave(logical_peer, json_pid, msg)
		"clan_disband":
			_json_clan_disband(logical_peer, json_pid, msg)
		"clan_reset_record":
			_json_clan_reset_record(logical_peer, json_pid, msg)
		"clan_set_banner":
			_json_clan_set_banner(logical_peer, json_pid, msg)
		"social_state":
			_json_social_state(logical_peer, json_pid, msg)
		"friend_request":
			_json_friend_request(logical_peer, json_pid, msg)
		"friend_accept":
			_json_friend_accept(logical_peer, json_pid, msg)
		"friend_decline":
			_json_friend_decline(logical_peer, json_pid, msg)
		"friend_cancel":
			_json_friend_cancel(logical_peer, json_pid, msg)
		"friend_remove":
			_json_friend_remove(logical_peer, json_pid, msg)
		"ignore_add":
			_json_ignore_add(logical_peer, json_pid, msg)
		"ignore_remove":
			_json_ignore_remove(logical_peer, json_pid, msg)
		"chat_send":
			_json_chat_send(logical_peer, json_pid, msg)
		"chat_history":
			_json_chat_history(logical_peer, json_pid, msg)
		"admin_toggle_global_chat":
			# Admin-only global-chat kill switch (D7). Authority re-checked HERE server-side —
			# the client's UI gating is convenience only and must never be trusted. On success,
			# push the new state to every online session as global_chat_state.
			var tga = get_player(logical_peer)
			if tga == null or not _is_admin(tga.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				global_chat_enabled = bool(msg.get("enabled", true))
				print("[ADMIN] '", tga.username, "' set global_chat_enabled=", global_chat_enabled)
				for tg_uname in sessions:
					var tg_sess = sessions[tg_uname]
					if tg_sess.status == ServerSession.ConnectionState.ONLINE:
						send_to_peer(tg_sess.peer_id, "global_chat_state", {"enabled": global_chat_enabled})
		"admin_toggle_creator":
			# Character Creator kill switch. Same shape as admin_toggle_global_chat, but the flag is
			# PERSISTED so the decision survives a restart, and it gates real server behaviour rather
			# than just a button (see _creator_blocked).
			var tcr = get_player(logical_peer)
			if tcr == null or not _is_admin(tcr.username):
				json_gateway.send(json_pid, {"type": "error", "reason": "Not authorized"})
			else:
				creator_enabled = bool(msg.get("enabled", false))
				_save_server_flags()
				print("[ADMIN] '", tcr.username, "' set creator_enabled=", creator_enabled)
				for cr_uname in sessions:
					var cr_sess = sessions[cr_uname]
					if cr_sess.status == ServerSession.ConnectionState.ONLINE:
						send_to_peer(cr_sess.peer_id, "creator_state", {"enabled": creator_enabled})
		"get_player_profile":
			# Public showcase: any logged-in player may view any player's profile. The body is a
			# whitelist (never the raw save, which holds pass_hash). No admin gate.
			var pp_requester = get_player(logical_peer)
			if pp_requester == null:
				json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
			else:
				var pp_name = str(msg.get("username", "")).strip_edges()
				var pp_target = _admin_get_target(pp_name)   # live session / cache / disk; path-traversal-safe
				if pp_target == null:
					json_gateway.send(json_pid, {"type": "error", "reason": "No such player: " + pp_name})
				else:
					var pp_body := _build_profile_body(pp_target)
					# Admin-only tell: staff can always see that an account is an Ultra Bot; the public
					# whitelist body never carries it, so normal players stay unaware (the disguise).
					if _is_admin(pp_requester.username):
						pp_body["is_ultra_bot"] = pp_target.is_ultra_bot
					json_gateway.send(json_pid, {"type": "player_profile", "profile": pp_body})
		"reset_own_record":
			# Self-service: a logged-in player wipes THEIR OWN win/loss record + streak (mirrors the
			# admin reset_record op, but scoped to the caller — no target field, so it can never be
			# pointed at another account). No effect on AP, unlocks, mastery, bounties, or history.
			var rr_p = get_player(logical_peer)
			if rr_p == null:
				json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
			else:
				_reset_player_record(rr_p)
				resave_player(rr_p)
				send_player_update(logical_peer)   # refresh S.player (rating / W-L shown outside the profile)
				print("[PROFILE] '", rr_p.username, "' reset their own win/loss record")
				json_gateway.send(json_pid, {"type": "record_reset", "ok": true, "profile": _build_profile_body(rr_p)})
		"replay_fetch":
			_json_replay_fetch(logical_peer, json_pid, msg)
		"spectate":
			_json_spectate(logical_peer, json_pid, msg)
		"spectate_leave":
			_json_spectate_leave(logical_peer, json_pid, msg)
		"social_setting":
			_json_social_setting(logical_peer, json_pid, msg)
		_:
			json_gateway.send(json_pid, {"type": "error", "reason": "unhandled type: " + t})

# Web clients send only their team (characters[]) + optional target_username; the
# authoritative display package is derived server-side from the logged-in Player so
# the browser never supplies its own rank/profile. Then we call the existing queue
# handlers directly — they already take the sender id as their first argument.
func _json_enqueue(logical_peer: int, mode: String, msg: Dictionary) -> void:
	var p = get_player(logical_peer)
	if not p:
		return
	var pkg = p.display_package()
	var characters = msg.get("characters", [])
	# Authored-character gate. Unapproved creations are author-only and confined
	# to bot/private matches, so an untested or unbalanced one can never reach
	# Quick or Ranked. Enforced here because this is the single funnel every
	# queued team passes through.
	var gate := _authored_team_error(characters, p.username, mode == "private")
	if gate != "":
		send_to_peer(logical_peer, "error", {"reason": gate})
		return
	match mode:
		"quick":
			receive_quick_match_queue(logical_peer, pkg, characters)
		"ranked":
			receive_ranked_match_queue(logical_peer, pkg, characters)
		"private":
			receive_private_match_queue(logical_peer, pkg, characters, str(msg.get("target_username", "")))

# Route a web client's draft action to its live Match; reply with an error frame on rejection.
func _json_draft_action(peer_id, action, msg):
	var session = get_session(peer_id)
	if not session or not session.current_match or not is_instance_valid(session.current_match):
		send_to_peer(peer_id, "error", {"reason": "No active draft"})
		return
	var m = session.current_match
	var character = str(msg.get("character", ""))
	var err := ""
	match action:
		"ban":
			err = m.submit_draft_ban(peer_id, character, bool(msg.get("confirm", false)))
		"pick":
			err = m.submit_draft_pick(peer_id, character)
		"lock":
			err = m.lock_draft_bans(peer_id)
	if err != "":
		send_to_peer(peer_id, "error", {"reason": err})

func _on_json_disconnected(json_pid: int) -> void:
	var logical_peer: int = JSON_PEER_BASE + json_pid
	if logical_peer in peer_map:
		print("[SERVER] JSON peer disconnected: '", peer_map[logical_peer], "'")
		# Reuse the full disconnect path (queue cleanup, in-match session hold,
		# peer_map erase) while peer_map[logical_peer] still resolves.
		handle_disconnect(logical_peer)

func handle_disconnect(peer_id):
	# An Ultra Bot / bot seat has no socket and never "disconnects" — it is brought down explicitly via
	# _ultra_bot_offline. Guard so a stray call (e.g. a forced ping-cycle disconnect) can't tear down a
	# live bot session mid-day and orphan its match.
	if _is_bot_peer(peer_id):
		return
	var dc_username = peer_map[peer_id] if peer_id in peer_map else "unknown"
	print("[SERVER] Peer disconnected: ", peer_id, " (", dc_username, ")")
	# 1. Remove from Queue (Always happens on DC)
	# Was nested inside `if peer_id in queued_players`, so a RANKED-ONLY queuer's entry
	# survived their disconnect forever — the ghost that find_nearest_ranked_player's
	# "check if online" guard was added to work around. It also searched the player's
	# CURRENT rating bucket rather than the one the entry was filed under, so a rating
	# change while queued stranded the entry in the old bucket. _release_queues scans
	# every bucket and drains duplicates, and runs unconditionally.
	_release_queues(peer_id)

	# Remove from any match's spectator list
	var all_matches = ranked_matches + quick_matches + private_matches
	for ongoing_match in all_matches:
		if is_instance_valid(ongoing_match) and peer_id in ongoing_match.spectators:
			ongoing_match.remove_spectator(peer_id)

	# 2. Session Management
	var session = get_session(peer_id)
	if session:
		# Clear pending pong tracking
		pending_pongs.erase(session.username)

		# SPECTATOR LIFECYCLE (P4): a spectator also carries current_match, which would
		# otherwise route them into the in-match HOLD branch below — check_out_player on a
		# match they aren't playing, then 120s later wipe_session -> finalize_surrender
		# auto-surrendering a game they were only WATCHING. Detach here so a disconnecting
		# spectator takes the immediate lobby-wipe path. Remove from the match's spectators
		# dict directly too — the sweep above only covers the ranked/quick/private ARRAYS,
		# so this stays correct for any match not registered there (e.g. bot matches).
		if session.current_match != null and is_instance_valid(session.current_match) \
				and not (session.username in session.current_match.get_player_usernames()):
			session.current_match.remove_spectator(peer_id)
			session.current_match = null

		# If in a match -> HOLD session
		if session.current_match != null:
			session.status = ServerSession.ConnectionState.DISCONNECTED
			# Presence: flip this user's online friends to see them as disconnected.
			_push_presence_to_friends(session.username, "disconnected")
			var current_match = session.current_match
			current_match.check_out_player(peer_id)

			# Notify the opponent that this player disconnected
			var opponent_id = current_match.get_opponent(peer_id)
			if opponent_id != null and opponent_id in peer_map:
				var expected_username = current_match.get_expected_username(opponent_id)
				if expected_username != null and peer_map[opponent_id] == expected_username:
					send_to_peer(opponent_id, "receive_opponent_disconnect_notification", {})

			# Start wipe timer
			var timer = Timer.new()
			timer.wait_time = RECONNECT_TIMEOUT
			timer.one_shot = true
			timer.timeout.connect(func(): wipe_session(session.username))
			add_child(timer)
			timer.start()
			session.disconnect_timer = timer

		# If just in lobby -> WIPE immediately (or short delay)
		else:
			wipe_session(session.username)

	# Always remove the ID mapping immediately so Godot can reuse the ID
	peer_map.erase(peer_id)

func wipe_session(username):
	if not username in sessions: return
	var session = sessions[username]
	pending_pongs.erase(username)
	pending_replays.erase(username)
	print("[SESSION] Wiping session for '", username, "'")

	# --- AUTO-SURRENDER ON TIMEOUT ---
	# Only a real PARTICIPANT gets surrendered. A spectator session also holds current_match
	# (defense in depth — handle_disconnect already detaches watchers before the hold branch);
	# forfeiting on their behalf would end a game they were only watching.
	if session.current_match != null and is_instance_valid(session.current_match):
		if session.username in session.current_match.get_player_usernames():
			print("[SESSION] ", username, " had active match — auto-surrendering")
			finalize_surrender(session)
		else:
			session.current_match.remove_spectator(session.peer_id)
			session.current_match = null
	else:
		session.current_match = null
	# ---------------------------------

	if session.disconnect_timer:
		session.disconnect_timer.queue_free()
		session.disconnect_timer = null

	# Presence: OFFLINE — read friends off the still-valid player_data BEFORE erase.
	_push_presence_to_friends(username, "offline")

	# Usage metrics: the visit ends HERE, not in handle_disconnect. A player who drops mid-match
	# holds their session (and their seat) for RECONNECT_TIMEOUT and usually comes back, so
	# closing the visit on the socket drop would chop every match with a blip in it into two
	# short sessions. wipe_session is the point where they are genuinely gone.
	if metrics_db != null:
		metrics_db.end_visit(username, int(Time.get_unix_time_from_system()))

	sessions.erase(username)
	print("[SESSION] Active sessions: ", sessions.size())

func start_client(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		var err = multiplayer_peer.create_client(TARGET_IP)
		if err != OK:
			return
		multiplayer.multiplayer_peer = multiplayer_peer
		# Client side player loading happens after login response now

# --- LOGIN & RECONNECT LOGIC ---

func attempt_login(username, password):
	_stored_username = username
	_stored_password = password
	rpc_id(1, "receive_login_attempt", multiplayer.get_unique_id(), username, password)
	
func _process_login(peer_id, username, password):
	print("[LOGIN] Attempt from peer ", peer_id, ": '", username, "'")
	var login_response
	var player_json_string = null
	var response_id = 0
	var message = ""
	var pending_reconnect = null   # set in Case A when re-linking a live match
	if FileAccess.file_exists("ausers/" + username + ".dat"):
		var player_data = load_player(username)
		# Legacy password hash check
		if not "pass_hash" in player_data:
			player_data["pass_hash"] = password
			var temp_player = Player.load_player(player_data)
			save_player(temp_player, password)

		if player_data["pass_hash"] == password:
			# --- NEW SESSION LOGIC ---

			# Case A: Reconnecting to an existing session
			if username in sessions and sessions[username].status == ServerSession.ConnectionState.DISCONNECTED:
				var session = sessions[username]

				# Stop the wipe timer
				if session.disconnect_timer:
					session.disconnect_timer.queue_free()
					session.disconnect_timer = null

				# Update ID
				session.peer_id = peer_id
				session.status = ServerSession.ConnectionState.ONLINE
				peer_map[peer_id] = username

				# Presence: back ONLINE — notify this user's online friends.
				_push_presence_to_friends(username, "online")

				# Chat (Phase 2): seed the client with the current global-chat kill-switch state.
				send_to_peer(peer_id, "global_chat_state", {"enabled": global_chat_enabled})
				# Same for the Character Creator switch, so the client knows whether to show its button.
				send_to_peer(peer_id, "creator_state", {"enabled": creator_enabled})

				# Re-link the live match. The Godot client reaches this via
				# validate_session_response (peer_connected-triggered), which web peers
				# never fire — so do the same check-in here. check_in_player fixes the
				# seat/acting_player/turn-timer; get_reconnection_info is the snapshot-based
				# resume package, sent after the login response below (via send_to_peer so
				# it reaches web and Godot peers alike).
				if session.current_match != null and is_instance_valid(session.current_match):
					var current_match = session.current_match
					current_match.check_in_player(peer_id, session.player_data)
					pending_reconnect = current_match.get_reconnection_info(peer_id)
					var opponent_id = current_match.get_opponent(peer_id)
					if opponent_id != null and opponent_id in peer_map:
						var expected = current_match.get_expected_username(opponent_id)
						if expected != null and peer_map[opponent_id] == expected:
							send_to_peer(opponent_id, "receive_opponent_reconnect_notification", {})

				player_json_string = load_player(username, true)
				response_id = 2 # Reconnect ID
				# Usage metrics: a reconnect opens a NEW visit row flagged resumed, because the
				# original one was closed when they dropped. Counting the gap as presence would
				# credit the site with time a disconnected player spent elsewhere.
				if metrics_db != null:
					metrics_db.begin_visit(username, int(Time.get_unix_time_from_system()), true)
				print("[LOGIN] Reconnect: '", username, "' resumed session")

			# Case B: Already logged in elsewhere
			elif username in sessions and sessions[username].status != ServerSession.ConnectionState.DISCONNECTED:
				message = "Account already logged in."
				print("[LOGIN] Rejected: '", username, "' already logged in")

			# Case C: Fresh Login
			else:
				player_json_string = load_player(username, true)
				response_id = 1

				# Reload from disk so the session never starts with stale data
				# (the cached players[username] may predate cosmetic/rank/unlock saves).
				var fresh_player = Player.load_player(load_player(username))
				players[username] = fresh_player
				var new_session = ServerSession.new(username, peer_id, fresh_player)
				sessions[username] = new_session
				peer_map[peer_id] = username
				# Presence: now ONLINE (new_session defaults to ONLINE) — notify friends.
				_push_presence_to_friends(username, "online")
				# Chat (Phase 2): seed the client with the current global-chat kill-switch state.
				send_to_peer(peer_id, "global_chat_state", {"enabled": global_chat_enabled})
				# Same for the Character Creator switch, so the client knows whether to show its button.
				send_to_peer(peer_id, "creator_state", {"enabled": creator_enabled})
				# Usage metrics: this is the visit. Ultra Bots never reach _process_login (they are
				# seated directly by _ultra_bot_online), so no bot filter is needed here.
				if metrics_db != null:
					metrics_db.begin_visit(username, int(Time.get_unix_time_from_system()), false)
				print("[LOGIN] Fresh login: '", username, "' (peer ", peer_id, ") — sessions: ", sessions.size())

		else:
			message = "Incorrect password."
			print("[LOGIN] Rejected: '", username, "' wrong password")
	else:
		message = "No player with that username exists."
		
	login_response = get_login_response(response_id, player_json_string, message, response_id != 0 and _is_admin(username))
	send_to_peer(peer_id, "receive_login_response", {"json_string": login_response})
	# Current maintenance state, every login. Without this a player who joins DURING the warning
	# window never hears about it, and — worse — a client still carrying a stale warning from before
	# a restart has no way to learn the new process has none (the phase is otherwise only cleared by
	# an explicit admin cancel). Sent unconditionally so it can clear as well as set.
	if response_id != 0:
		if maintenance.is_empty():
			send_to_peer(peer_id, "maintenance_cleared", {"boot_id": boot_id})
		elif not _maintenance_locked():
			send_to_peer(peer_id, "maintenance_notice", {"message": str(maintenance.get("message", MAINTENANCE_DEFAULT)),
				"seconds": int(maintenance.get("seconds", 0)), "boot_id": boot_id})
	# Reconnect resume: ship the snapshot-based package right after the login response
	# so the client can rebuild the in-progress board (see Match.get_reconnection_info).
	if pending_reconnect != null:
		send_to_peer(peer_id, "receive_session_reconnect", {"info": pending_reconnect})

# --- REPLACED HELPERS & GAME LOGIC ---

func initialize_players():
	for file in DirAccess.get_files_at("ausers"):
		var player_name = file.get_slice(".dat", 0)
		players[player_name] = Player.load_player(load_player(player_name))

func initialize_clans():
	for file in DirAccess.get_files_at("clans"):
		var clan_name = file.get_slice(".dat", 0)
		clans[clan_name] = Clan.load_clan(load_clan(clan_name))

func notify_connection_complete():
	if _is_reconnecting:
		# Tab-away reconnect: the server's request_session_validation handles
		# everything, so suppress connection_complete (which would trigger
		# auto_login_check and race with the session validation path).
		return
	connection_complete.emit()
	
func _process(delta):
	delta_timer -= delta
	if delta_timer <= 0.0:
		_on_ladder_timer_timeout()
		delta_timer = 30.0
	# Server-initiated ping to detect frozen browser tabs
	if is_server:
		server_ping_timer_elapsed += delta
		if server_ping_timer_elapsed >= SERVER_PING_INTERVAL:
			server_ping_timer_elapsed = 0.0
			server_ping_cycle()

func heartbeat_check():
	if multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		if _player != null and not _is_reconnecting:
			_is_reconnecting = true
			connection_lost.emit()
		multiplayer_peer = WebSocketMultiplayerPeer.new()
		multiplayer_peer.create_client(TARGET_IP)
		multiplayer.multiplayer_peer = multiplayer_peer
		await get_tree().create_timer(1.0).timeout
	else:
		rpc_id(1, "receive_heartbeat", multiplayer.get_unique_id())



# --- SERVER-INITIATED PING/PONG ---
# Detects frozen browser tabs that maintain the TCP connection but can't
# process messages. The server pings every online session; if a pong isn't
# received by the next cycle, the player is treated as disconnected.

const SERVER_PING_INTERVAL = 15.0
var server_ping_timer_elapsed = 0.0

func server_ping_cycle():
	# Check for missing pongs from the previous cycle
	for username in pending_pongs.keys():
		if username in sessions:
			var session = sessions[username]
			if session.status == ServerSession.ConnectionState.ONLINE and session.peer_id in peer_map:
				# Player didn't respond — treat as disconnected
				print("[PING] No pong from '", username, "' — forcing disconnect")
				var stale_peer_id = session.peer_id
				handle_disconnect(stale_peer_id)
				# Godot won't fire peer_disconnected for a frozen WebSocket,
				# so we manually disconnect them
				if multiplayer_peer.has_method("disconnect_peer"):
					multiplayer_peer.disconnect_peer(stale_peer_id)
	pending_pongs.clear()

	# Send new pings to all online sessions. Web peers are skipped: they can't
	# receive a Godot rpc, and the JSON gateway already detects dead sockets in
	# poll() (-> _on_json_disconnected), so pinging them would force-disconnect
	# every cycle.
	for username in sessions:
		var session = sessions[username]
		# Skip Ultra Bot / bot sessions: they have no socket, so a Godot rpc_id ping can't reach them and
		# the missing pong would force-disconnect the bot every cycle.
		if session.status == ServerSession.ConnectionState.ONLINE and session.peer_id in peer_map and not _is_json_peer(session.peer_id) and not _is_bot_peer(session.peer_id):
			pending_pongs[username] = true
			rpc_id(session.peer_id, "receive_server_ping")



# --- OPPONENT DISCONNECT / RECONNECT NOTIFICATIONS ---



func start_server(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		actually_start_server()

func load_player(username, str=false):
	var player_save = FileAccess.open("ausers/" + username + ".dat", FileAccess.READ)
	var json = JSON.new()
	var json_string = player_save.get_line()
	var parse_result = json.parse(json_string)
	
	if not parse_result == OK:
		return
	var player_data = json.get_data()
	player_data.missions = {}
	json_string = JSON.stringify(player_data)
	if not str:
		return player_data
	else:
		return json_string

func load_clan(clan_name, str=false):
	var clan_save = FileAccess.open("clans/" + clan_name + ".dat", FileAccess.READ)
	var json = JSON.new()
	var json_string = clan_save.get_line()
	var parse_result = json.parse(json_string)
	if not parse_result == OK:
			return
	var clan_data = json.get_data()
	if not str:
		return clan_data
	else:
		return json_string

func request_character_buckets(universe):
	rpc_id(1, "receive_character_bucket_request", multiplayer.get_unique_id(), universe)

	

func send_player_contribution(bucket_path_name, amount):
	rpc_id(1, "receive_player_contribution", multiplayer.get_unique_id(), bucket_path_name, amount)



func save_player(player, pass_hash=""):
	var player_save = FileAccess.open("ausers/" + player.username + ".dat", FileAccess.WRITE)
	var player_data = player.save()
	if pass_hash != "":
		player_data['pass_hash'] = pass_hash
	var json_string = JSON.stringify(player_data)
	player_save.store_line(json_string)
	player_save.close()

func save_clan(clan):
	# The clans/ runtime dir isn't committed/guaranteed to exist; without this, FileAccess.open
	# returns null and the write silently no-ops, so clans would never persist across restarts.
	if not DirAccess.dir_exists_absolute("clans"):
		DirAccess.make_dir_absolute("clans")
	var clan_save = FileAccess.open("clans/" + clan.clan_name + ".dat", FileAccess.WRITE)
	if clan_save == null:
		push_error("[CLAN] Could not open clans/" + clan.clan_name + ".dat for write")
		return
	var clan_data = clan.save()
	var json_string = JSON.stringify(clan_data)
	clan_save.store_line(json_string)

func resave_player(player):
	var player_data = load_player(player.username)
	# .get() so an account whose .dat predates the pass_hash field can't crash the save; save_player
	# only writes pass_hash when non-empty, so "" leaves the on-disk hash untouched.
	var pass_hash_store = player_data.get("pass_hash", "") if player_data != null else ""
	save_player(player, pass_hash_store)
	# Keep the global players cache in sync so leaderboards, clan ops,
	# and fresh-login session creation never use stale data.
	players[player.username] = player

func send_player_update(peer_id):
	var player = get_player(peer_id)
	if player:
		var username = player.username
		var json_string = load_player(username, true)
		send_to_peer(peer_id, "receive_player_update", {"json_string": json_string})

# AP is a FLAT payout per queue — no streak scaling anywhere (streaks stopped feeding AP when Quick
# stopped recording wins/losses, so scaling by one would have been dead weight that only Ranked moved).
# The client mirrors this table in matchApGain(); change both together.
#
#   Bot Match (practice)   50 /  0
#   Quick (incl. its bot fallback)  100 / 50
#   Ranked vs a human     500 / 50
#   Ranked vs a bot       250 / 50   <- reduced, since a ranked bot is a 30s wait away
#   Private                 0 /  0
func _calculate_ap_gain(match_type, won: bool, practice := false, vs_bot := false) -> int:
	if practice:
		return 50 if won else 0
	if match_type == BattleManager.MatchType.PRIVATE:
		return 0
	if match_type == BattleManager.MatchType.RANKED:
		if vs_bot:
			return 250 if won else 50
		return 500 if won else 50
	# QUICK, and BOT-typed quick-queue fallbacks (presented to the player as a Quick Match).
	return 100 if won else 50

func _send_post_match_player_updates(match_obj):
	for peer_id in match_obj.players:
		var match_player = match_obj.players[peer_id]
		# Only send if the player is still connected with the correct identity
		if peer_id in peer_map:
			var expected_username = match_obj.get_expected_username(peer_id)
			if expected_username != null and peer_map[peer_id] == expected_username:
				send_player_update(peer_id)


# (_handle_bot_match_ending was removed here: dead legacy from the old client-reported bot path.
#  It recorded BOT wins/losses on the rank — the exact opposite of the current rule — and ran
#  check_all_bounties over a CLIENT-SUPPLIED team list. Zero call sites; it survived only as a trap.)



	

func get_login_response(login_response_id, player=null, message="", is_admin=false):
	var json_dict = {
		"id": login_response_id,
		"player": player,
		"message": message,
		"version": _version,
		"is_admin": is_admin
	}
	return JSON.stringify(json_dict)

func attempt_register(username, password):
	rpc_id(1, "receive_register_attempt", multiplayer.get_unique_id(), username, password)

	
func _process_register(peer_id, username, password):
	username = username.strip_edges()
	var message
	if username == "" or password == "":
		message = "Enter a username and password to register."
	elif FileAccess.file_exists("ausers/" + username + ".dat"):
		message = "Registration failed! An account with that name already exists."
	elif _collides_with_admin_name(username):
		# Block case-variant squats of a reserved admin name on the case-sensitive prod filesystem.
		message = "Registration failed! That username is reserved."
	else:
		var player = Player.new_gen(username, password, missions)
		player.set_username(username)
		players[username] = player
		save_player(player, password)
		# Usage metrics: sign-ups are the growth half of the dashboard. Recorded at REGISTRATION,
		# not at the first login that follows, so "new accounts" stays a count of accounts created.
		if metrics_db != null:
			metrics_db.record_event("register", username, int(Time.get_unix_time_from_system()), "web", username)
		print("[REGISTER] New account created (web): '", username, "'")
		message = "Registration successful! Logging you in…"
	send_to_peer(peer_id, "receive_register_response", {"message": message})

# Change the password of the logged-in web peer. Verifies the current password against the stored
# pass_hash (plaintext, mirroring _process_login), then rewrites it via save_player.
func _process_change_password(peer_id, current_password, new_password):
	var player = get_player(peer_id)
	var ok = false
	var message
	if player == null:
		message = "You must be logged in to change your password."
	elif new_password.strip_edges() == "":
		message = "New password can't be empty."
	else:
		var player_data = load_player(player.username)
		if player_data == null or not ("pass_hash" in player_data) or str(player_data["pass_hash"]) != current_password:
			message = "Current password is incorrect."
		else:
			save_player(player, new_password)   # rewrites pass_hash on disk
			print("[PASSWORD] Changed for '", player.username, "'")
			message = "Password updated."
			ok = true
	send_to_peer(peer_id, "receive_change_password_response", {"ok": ok, "message": message})

# Server tells the client its queue request was refused (e.g., short character
# list). Client cancels its queueing UI so the user can fix their team and retry.

func queue_quick_match(player):
	var character_names = []
	for character in player.team.characters:
		character_names.append(character.path_name)
	if player.equipped_disguise != "" and player.equipped_disguise != "toga":
		character_names.append(player.equipped_disguise)
		
	rpc_id(1, "receive_quick_match_queue", multiplayer.get_unique_id(), player.display_package(), character_names)

func queue_ranked_match(player):
	var character_names = []
	for character in player.team.characters:
		character_names.append(character.path_name)
	if player.equipped_disguise != "" and player.equipped_disguise != "toga":
		character_names.append(player.equipped_disguise)
	rpc_id(1, "receive_ranked_match_queue", multiplayer.get_unique_id(), player.display_package(), character_names)

func _already_in_match(peer_id) -> bool:
	var sess = get_session(peer_id)
	if sess and sess.current_match != null and is_instance_valid(sess.current_match):
		send_to_peer(peer_id, "error", {"reason": "Already in a match"})
		return true
	return false


func receive_quick_match_queue(peer_id, player, character_names):
	# SECURITY CHECK: Ensure sender is logged in
	if not get_player(peer_id):
		return
	if _already_in_match(peer_id):
		return

	var qp = get_player(peer_id)
	# Match.from_players rebuilds the team SOLELY from this list, so a short
	# payload would dump the player into a match with < 3 characters. The
	# client's queue button gates on len(team.characters) == 3, so reaching
	# here means the client got into a bad state — reject and let it recover.
	if character_names.size() < 3:
		print("[QUEUE] REJECTED ", qp.username, " — short quick queue payload (", character_names.size(), "): ", character_names)
		send_to_peer(peer_id, "receive_queue_rejected", {})
		return
	print("[QUEUE] ", qp.username, " joined quick queue (", character_names, ") — queue size: ", len(queued_players) + 1)
	queued_players[peer_id] = [player, character_names]

	if len(queued_players.values()) > 1:
		var player1_id = queued_players.keys()[0]

		# Prevent matching with yourself (just in case)
		if player1_id == peer_id:
			return

		start_quick_match(player1_id, peer_id)
	else:
		# No human waiting — arm a bot fallback after this player's bot_queue_delay setting. If a human
		# joins first, start_quick_match removes this peer from queued_players and the timer no-ops; same
		# for cancel_queue.
		_start_bot_fallback(peer_id)

func receive_ranked_match_queue(peer_id, player, character_names):
	# SECURITY CHECK: Ensure sender is logged in
	if not get_player(peer_id):
		return
	if _already_in_match(peer_id):
		return

	# Ranked now uses BLIND TEAM PICKS like Quick Match (no draft) — require a full 3-character team,
	# mirroring receive_quick_match_queue's guard.
	if character_names.size() < 3:
		var rqp = get_player(peer_id)
		print("[QUEUE] REJECTED ", rqp.username, " — short ranked queue payload (", character_names.size(), ")")
		send_to_peer(peer_id, "receive_queue_rejected", {})
		return

	# IDEMPOTENT: nothing upstream rate-limits queue_ranked, and a duplicate entry would let
	# one sweep pair the same peer with two different opponents — the second seat wipes the
	# live board out from under the first.
	_release_queues(peer_id)
	ranked_queue[player.rank][player.tier].append([peer_id, player, character_names])
	_ranked_wait_start[peer_id] = Time.get_ticks_msec()

	# Arm the bot fallback UNCONDITIONALLY, not just when nobody else is waiting. Pairing is
	# now gated on rating distance, so "someone is here but we are not eligible yet" is a
	# normal state — under the old if/else that player got no fallback and no pair, i.e.
	# stranded forever. The coroutine is generation-guarded and _in_live_match-guarded, so an
	# extra arm is a no-op once a match starts. Worst case for a gated player is a bot at
	# RANKED_BOT_DELAY, which is precisely the intended outcome for a far-apart queuer.
	_start_ranked_bot_fallback(peer_id)
	# Sweep immediately so a close pair still feels instant rather than waiting for the tick.
	_gate_tick()

func queue_private_match(player, target_username):
	var character_names = []
	for character in player.team.characters:
		character_names.append(character.path_name)
	if player.equipped_disguise != "" and player.equipped_disguise != "toga":
		character_names.append(player.equipped_disguise)
	rpc_id(1, "receive_private_match_queue", multiplayer.get_unique_id(), player.display_package(), character_names, target_username)


func receive_private_match_queue(peer_id, player, character_names, target_username):
	# SECURITY CHECK: Ensure sender is logged in
	if not get_player(peer_id):
		return
	if _already_in_match(peer_id):
		return

	if character_names.size() < 3:
		var qp = get_player(peer_id)
		print("[QUEUE] REJECTED ", qp.username, " — short private queue payload (", character_names.size(), "): ", character_names)
		send_to_peer(peer_id, "receive_queue_rejected", {})
		return
	# SELF-INVITE. An invite is keyed (inviter -> target), so inviting YOURSELF files (me -> me) — and
	# the pairing lookup for a self-invite asks for exactly that same key, so the very next self-invite
	# matches it and hands start_private_match the same package twice. Both
	# seats then resolve to ONE Player object. Match.from_players now refuses that outright (its
	# player1 == player2 guard), so this is no longer a zombie-match/lockout, but the refusal reaches
	# the player as a generic rejection with no idea what they did wrong. Reject it here, where we can
	# say why. An empty target is refused for the same reason: it would file the invite under the ""
	# key, where it can never be matched and simply leaks until the player disconnects.
	# Both refusals ship as receive_queue_rejected, NOT "error". The client sets queued=true
	# optimistically the moment it sends, and only the receive_queue_rejected handler clears it —
	# the "error" handler just prints the reason. A client without the matching JS guard (an older
	# cached build, or any hand-sent frame) would otherwise sit on "Waiting for … to invite you
	# back" forever against a server that holds no invite. The pre-guard behaviour reached the
	# player through start_private_match's receive_queue_rejected, so this keeps that contract.
	var invite_target := str(target_username).strip_edges()
	if invite_target == "":
		send_to_peer(peer_id, "receive_queue_rejected", {"reason": "Enter the username of the player you want to challenge"})
		return
	if invite_target == player.username:
		send_to_peer(peer_id, "receive_queue_rejected", {"reason": "You can't challenge yourself — enter another player's username"})
		return
	# Pair only on MUTUAL agreement, which the PAIR KEY now expresses directly: an invite exists under
	# (inviter -> target), so "has the person I named already invited me?" is a single exact lookup.
	# The old target-only key could not ask that — it only asked "is ANYONE waiting for me?", so C
	# inviting A followed by A inviting B seated A against C and told B nothing.
	# Filing uses the TRIMMED target for the same reason it always did: " Bob " must land on the key
	# the real Bob's lookup will hit. The client trims too, but the server must not depend on it.
	var waiting = private_queue.get(_invite_key(invite_target, player.username), null)
	if waiting != null:
		start_private_match(waiting, [peer_id, player, character_names])
	else:
		private_queue[_invite_key(player.username, invite_target)] = [peer_id, player, character_names]

func start_private_match(player1_package, player2_package):
	var p1 = get_player(player1_package[0])
	var p2 = get_player(player2_package[0])
	
	# --- SAFETY CHECK ---
	if not p1 or not p2:
		
		# Clean up the specific invalid entries so they don't block future invites. By PEER ID: entries
		# are keyed (inviter -> target), so erasing by a participant's own username missed the real
		# entry entirely and could take an unrelated one with it.
		if not p1:
			_erase_private_invite(player1_package[0])
		if not p2:
			_erase_private_invite(player2_package[0])
		return
	# --------------------

	var seed = _fresh_match_seed()

	var new_match = Match.from_players(player1_package[0], p1, player1_package[2], player2_package[0], p2, player2_package[2], seed, BattleManager.MatchType.PRIVATE)
	# from_players REFUSES to rebuild a player who still holds a live match (it would clear that live
	# board). The usual cause here is a STALE invite: nothing reaps private_queue when its owner starts
	# a quick/ranked/bot match, so the invite outlives them.
	if new_match == null:
		# Purge the consumed invite by PEER, not by username — it is filed under the target's name.
		# Left in place it re-fires this exact bad pairing on the invitee's next attempt.
		_erase_private_invite(player1_package[0])
		_erase_private_invite(player2_package[0])
		# Whoever is NOT the busy seat is sitting in a queued client state and must be released;
		# the busy one is mid-battle and gets nothing (an error toast would just alarm them).
		for pkg in [player1_package, player2_package]:
			if not _in_live_match(pkg[0]):
				send_to_peer(pkg[0], "receive_queue_rejected", {"reason": "Opponent is already in a match"})
		print("[MATCH] Private match ABORTED — from_players refused (a seat already holds a live match): ", p1.username, " vs ", p2.username)
		return
	new_match.timeout_current_player.connect(handle_timeout)
	new_match.server_match_ended.connect(handle_server_match_ended)
	new_match.match_over.connect(match_ended)
	add_child(new_match)
	new_match.begin_match()
	new_match.start_turn_timer()

	# ASSIGN MATCH TO SESSIONS
	get_session(player1_package[0]).current_match = new_match
	get_session(player2_package[0]).current_match = new_match

	var p1_first = new_match.player_goes_first(player1_package[0])
	# Canonical role is decided by seat order in Match.from_players: peer_id1
	# is always p1, peer_id2 is always p2. The shadow uses these as p1/p2
	# directly so the wire's "p1 vs p2" coordinates match the server's view.
	send_to_peer(player1_package[0], "receive_private_match", {"opponent": player2_package[1], "opponent_team": player2_package[2], "first_turn": p1_first, "seed": seed, "canonical_role": 0})
	send_to_peer(player2_package[0], "receive_private_match", {"opponent": player1_package[1], "opponent_team": player1_package[2], "first_turn": not p1_first, "seed": seed, "canonical_role": 1})
	# Drain the shadow's initial events (TURN_STARTED + first-turn ENERGY_GAINED
	# and, on p2-first matches, the p2 wait_for_turn pre-gen) so the acting
	# client sees their starting energy on turn 1 instead of after their first
	# submission. RPC ordering guarantees the receive_private_match handler runs
	# (and the client's manager.start_battle completes) before apply_turn_result
	# arrives on the same channel.
	_broadcast_turn_result(new_match)
	private_matches.append(new_match)

	# Standard cleanup for successful match. By PEER ID, not username: with target-keyed entries the old
	# erase deleted whatever invite happened to sit under p1's NAME, which was never p1's own invite but
	# a THIRD PARTY's invite aimed at p1 — a bystander silently lost their pending challenge every time
	# someone else's private match started. Clearing both peers' outstanding invites here is also what
	# stops a just-seated player from being pulled into a second private match by a leftover invite.
	_erase_private_invite(player1_package[0])
	_erase_private_invite(player2_package[0])
	# Also drop them from the QUICK queue. Every other match-start path does this (start_quick_match,
	# _start_bot_fallback, start_immediate_bot_match); without it a player who was sitting in the quick
	# queue when they accepted a private invite stays queued and gets started into a SECOND concurrent
	# match — and Match.from_players clears the persistent Player's team, wiping this match's live board.
	queued_players.erase(player1_package[0])
	queued_players.erase(player2_package[0])
	print("[MATCH] Private match started: ", p1.username, " vs ", p2.username, " (seed=", seed, ")")


func attempt_match_reconnect():
	rpc_id(1, "receive_match_reconnect_request", multiplayer.get_unique_id())



func find_nearest_ranked_player(peer_id):
	var player = get_player(peer_id)
	if not player: return null
	
	# Same-tier fast path. The `in peer_map` check matches the widening scans below: without it a
	# GHOST entry (a ranked-only queuer who disconnected — handle_disconnect only cleans ranked_queue
	# for peers that were ALSO in the quick queue) is returned, start_ranked_match aborts on the dead
	# player, and the live queuer is left seated with no match and no fallback armed.
	if len(ranked_queue[player.rank.rank][player.rank.rank_tier]) > 1:
		for queue_package in ranked_queue[player.rank.rank][player.rank.rank_tier]:
			if queue_package[0] != peer_id and queue_package[0] in peer_map:
				return queue_package
	var lowest_search = [player.rank.rank, player.rank.rank_tier]
	var low_search = lowest_search
	var highest_search = [player.rank.rank, player.rank.rank_tier]
	var high_search = highest_search
	while true:
		if not lowest_search == [Rank.Type.IRON, 1]:
			low_search = get_new_rank_search(low_search[0], low_search[1], false)
			lowest_search = low_search
			if len(ranked_queue[low_search[0]][low_search[1]]) > 0:
				for queue_package in ranked_queue[low_search[0]][low_search[1]]:
					if queue_package[0] in peer_map: # Check if online
						return queue_package
		if not highest_search == [Rank.Type.GRANDMASTER, 5]:
			high_search = get_new_rank_search(high_search[0], high_search[1], true)
			highest_search = high_search
			if len(ranked_queue[high_search[0]][high_search[1]]) > 0:
				for queue_package in ranked_queue[high_search[0]][high_search[1]]:
					if queue_package[0] in peer_map: # Check if online
						return queue_package
		if highest_search == [Rank.Type.GRANDMASTER, 5] and lowest_search == [Rank.Type.IRON, 1]:
			return null
			

func get_new_rank_search(current_rank, current_tier, searching_high):
	if searching_high:
		current_tier += 1
		if current_tier == 6:
			current_tier = 1
			current_rank = current_rank + 1
			if current_rank > 7:
				current_rank = 7
				current_tier = 5
	else:
		current_tier -= 1
		if current_tier == 0:
			current_tier = 5
			current_rank = current_rank - 1
			if current_rank < 0:
				current_rank = 0
				current_tier = 1
	return [current_rank, current_tier]
			

func match_ended(ended_match):
	if not is_instance_valid(ended_match):
		print("[MATCH] match_ended called on invalid match — ignoring")
		return

	var usernames = ended_match.get_player_usernames()
	print("[MATCH] Match ended. Players: ", usernames)

	# Update session states
	for username in usernames:
		if username in sessions:
			# IDENTITY CHECK — only clear the pointer if it actually points at THIS match. Without it, a
			# late teardown of a STALE match steals the player's pointer to the LIVE match they have since
			# moved on to; from that moment _process_turn_input bails on the null current_match and returns
			# true, so every turn they submit is dropped SILENTLY (no error frame reaches the client) while
			# the live match's AFK timer runs them down to a force-forfeit for a game they were never
			# allowed to play. Same reason the DISCONNECTED wipe is nested here: wiping a session that is
			# bound to a different, live match would lock that account out of it entirely.
			if sessions[username].current_match == ended_match:
				sessions[username].current_match = null
				if sessions[username].status == ServerSession.ConnectionState.DISCONNECTED:
					print("[MATCH] ", username, " was disconnected — wiping session")
					wipe_session(username)

	for spectator_peer in ended_match.spectators.keys():
		if spectator_peer in peer_map:
			var spec_username = peer_map[spectator_peer]
			if spec_username in sessions:
				sessions[spec_username].current_match = null
	ended_match.spectators.clear()

	# Chat (Phase 2): free this match's chat ring buffer — RAM only, no durable history (D5).
	chat_match.erase(str(ended_match.match_uid))

	# Detach Player objects from the BattleManager before the match scene
	# tree cascade-frees, since Players are owned by the global session map.
	ended_match.release_player_objects()

	# Server controls match lifecycle — remove from arrays and free the node
	remove_match(ended_match)
	ended_match.queue_free()


func start_quick_match(peer_id1, peer_id2):
	var p1 = get_player(peer_id1)
	var p2 = get_player(peer_id2)
	
	# SAFETY CHECK: If either player is missing (disconnected/unauth), abort
	if not p1 or not p2:
		# Clean up the bad entries so queue doesn't get stuck
		if not p1: queued_players.erase(peer_id1)
		if not p2: queued_players.erase(peer_id2)
		# The SURVIVOR stays queued but just lost the pairing that would have started their game, and
		# receive_quick_match_queue only arms a bot fallback on its empty-queue branch — so re-arm it
		# here or they wait forever (there is no periodic sweep for the quick queue).
		if p1 and not p2: _start_bot_fallback(peer_id1)
		if p2 and not p1: _start_bot_fallback(peer_id2)
		return

	var seed = _fresh_match_seed()

	var new_match = Match.from_players(peer_id1, p1, queued_players[peer_id1][1], peer_id2, p2, queued_players[peer_id2][1], seed, BattleManager.MatchType.QUICK)
	# from_players REFUSED (a seat already holds a live match, or both seats are the same account:
	# receive_quick_match_queue only compares PEER IDS). The joiner passed _already_in_match one
	# statement before we were called, so in practice the offender is the incumbent at the head of the
	# queue — and queued_players.keys()[0] is insertion-ordered, so leaving it in place would re-fire
	# this rejection for every future joiner.
	if new_match == null:
		var busy1 := _in_live_match(peer_id1)
		var busy2 := _in_live_match(peer_id2)
		if p1 == p2 or (not busy1 and not busy2):
			# Same account on both seats, or a refusal we cannot attribute: drop BOTH entries rather
			# than leave a pairing that repeats on every subsequent queue event.
			busy1 = true
			busy2 = true
		if busy1:
			queued_players.erase(peer_id1)
		if busy2:
			queued_players.erase(peer_id2)
		# The innocent one keeps their queue entry (so do NOT send receive_queue_rejected — that would
		# flip their client's queued flag against a live server-side entry) but needs the fallback.
		if not busy1:
			_start_bot_fallback(peer_id1)
		if not busy2:
			_start_bot_fallback(peer_id2)
		print("[MATCH] Quick match ABORTED — from_players refused: ", p1.username, "(busy=", busy1, ") vs ", p2.username, "(busy=", busy2, ")")
		return
	new_match.timeout_current_player.connect(handle_timeout)
	new_match.server_match_ended.connect(handle_server_match_ended)
	new_match.match_over.connect(match_ended)
	add_child(new_match)
	new_match.begin_match()
	new_match.start_turn_timer()

	get_session(peer_id1).current_match = new_match
	get_session(peer_id2).current_match = new_match

	var p1_first = new_match.player_goes_first(peer_id1)
	send_to_peer(peer_id1, "receive_quick_match", {"opponent": queued_players[peer_id2][0], "opponent_team": queued_players[peer_id2][1], "first_turn": p1_first, "seed": seed, "canonical_role": 0})
	send_to_peer(peer_id2, "receive_quick_match", {"opponent": queued_players[peer_id1][0], "opponent_team": queued_players[peer_id1][1], "first_turn": not p1_first, "seed": seed, "canonical_role": 1})
	# Drain the shadow's initial events so the acting client sees turn-1 energy
	# before submitting. See start_private_match for details.
	_broadcast_turn_result(new_match)
	quick_matches.append(new_match)
	queued_players.erase(peer_id1)
	queued_players.erase(peer_id2)
	print("[MATCH] Quick match started: ", p1.username, " vs ", p2.username, " (seed=", seed, ")")

# ===========================================================================
# SERVER-SIDE BOT MATCHES
# ===========================================================================
# A bot match is an ordinary server-authoritative Match whose p2 seat is a
# synthetic, peer-less bot Player. The human plays through the normal gateway
# turn-input path; the server drives the bot's turns by running the same trained
# contextual AI the old client-side bot used, executing it directly on the
# authoritative shadow BattleManager and broadcasting the resulting events.
# Players reach a bot match by waiting 5-15s in the quick queue with no human
# opponent (see receive_quick_match_queue → _start_bot_fallback).

func _start_bot_fallback(peer_id) -> void:
	# Fire-and-forget coroutine. Wait the QUEUING PLAYER'S configured bot_queue_delay (their setting, not
	# a random timer); if they're still waiting in the quick queue (no human arrived, not cancelled, still
	# connected), pull them out and start a bot match instead.
	var p = get_player(peer_id)
	if not p:
		return
	var wait: float = clampf(float(p.bot_queue_delay), 15.0, 9999.0)
	await get_tree().create_timer(wait).timeout
	if not (peer_id in queued_players) or not get_player(peer_id):
		return
	# Still listed in the quick queue isn't proof they're free: nothing removes a peer from
	# queued_players when a RANKED or private match starts, so without this a player who queued
	# Quick, then queued Ranked, then got a ranked game would have this timer seat them into a
	# SECOND match — overwriting session.current_match and clearing their team mid-game.
	if _in_live_match(peer_id):
		queued_players.erase(peer_id)
		return
	# Ladder opt-out is honored ACROSS queues. A player can sit in both queues (receive_ranked clears the
	# quick queue, but receive_quick does NOT clear the ranked queue). If this player is also waiting in
	# ranked AND has opted out of ladder bots, seating a quick bot here would pull them out of the ranked
	# queue (via start_bot_match) and end their Ladder search against a bot — exactly what the opt-out
	# forbids. Drop only the quick entry and bail; their gated ranked wait for a human is left intact.
	if not get_player(peer_id).ranked_allow_bots and not _find_ranked_entry(peer_id).is_empty():
		print("[QUEUE] ", get_player(peer_id).username, " — quick bot suppressed (ladder opt-out + still ranked-queued)")
		queued_players.erase(peer_id)
		return
	var entry = queued_players[peer_id]
	queued_players.erase(peer_id)
	print("[QUEUE] ", get_player(peer_id).username, " — no human opponent in ", wait, "s, matching with a bot")
	start_bot_match(peer_id, entry[1])


# Ranked equivalent of _start_bot_fallback. The wait is a FIXED 30s rather than the player's own
# bot_queue_delay — that setting is a convenience for the casual queue, and letting it shorten the
# path to a ladder opponent would be a tuning knob on rating gain.
func _start_ranked_bot_fallback(peer_id) -> void:
	var p = get_player(peer_id)
	if not p:
		return
	# Stamp this wait so a timer left over from an earlier queue session can't seat the player.
	# Without it, cancel-then-requeue leaves the first coroutine running: it wakes on the NEW queue
	# entry and hands out a bot early, so the "fixed 30s" promise silently shortens.
	_ranked_fallback_gen[peer_id] = int(_ranked_fallback_gen.get(peer_id, 0)) + 1
	var my_gen: int = _ranked_fallback_gen[peer_id]
	var _fb_tree := get_tree()
	if _fb_tree == null:
		return   # off-tree (headless test harness): the delay timer can't run; the arm above is observable.
	await _fb_tree.create_timer(RANKED_BOT_DELAY).timeout
	if int(_ranked_fallback_gen.get(peer_id, 0)) != my_gen:
		return                                   # superseded by a newer queue session
	var rp = get_player(peer_id)
	if not rp or _in_live_match(peer_id):
		_erase_from_ranked_queue(peer_id)
		return
	# Opted out of ladder bots: LEAVE them queued rather than seating a bot, so they wait for a human.
	if not rp.ranked_allow_bots:
		# BUT clear the no-back-to-back block first. Waiting the full bot-fallback delay is the same
		# "you've moved on" signal that actually playing a bot would give — without it, two opted-out
		# players who just faced each other and are the only two in the (small) ranked queue would
		# deadlock forever: the no-rematch skip never lets them pair and no bot is ever seated to clear
		# the block. Clearing here lets them re-pair after the wait instead of hanging at "Searching".
		rp.last_ranked_opponent = ""
		print("[QUEUE] ", rp.username, " — ranked bots opted out, staying in queue")
		return
	# The ranked queue is nested buckets of [peer_id, player, character_names], not a peer-keyed
	# dict, so pull the entry out by hand — and treat "not found" as "already matched or cancelled".
	var entry = _erase_from_ranked_queue(peer_id)
	if entry.is_empty():
		return
	# Playing a bot counts as "played someone else", so it clears any back-to-back block with a human.
	rp.last_ranked_opponent = ""
	print("[QUEUE] ", rp.username, " — no ranked opponent in ", RANKED_BOT_DELAY, "s, matching with a bot")
	start_bot_match(peer_id, entry[2], false, BattleManager.MatchType.RANKED)


# Remove a peer from ranked_queue wherever it sits and return its [peer_id, player, chars] entry
# ([] when absent). Scans every bucket rather than trusting the player's CURRENT rank/tier, because
# a rank change between queueing and dequeuing would otherwise strand the entry forever.
func _erase_from_ranked_queue(peer_id) -> Array:
	for rank_key in ranked_queue:
		for tier_key in ranked_queue[rank_key]:
			for entry in ranked_queue[rank_key][tier_key]:
				if entry[0] == peer_id:
					ranked_queue[rank_key][tier_key].erase(entry)
					return entry
	return []


# True when this peer already holds a live match. The single source of truth for "is this player
# busy" — _already_in_match wraps it with a client-facing error.
func _in_live_match(peer_id) -> bool:
	var sess = get_session(peer_id)
	return sess != null and sess.current_match != null and is_instance_valid(sess.current_match)


# Return the ACTUAL queued entry array for a peer without removing it. Identity matters:
# start_ranked_match cleans up with Array.erase(), which is VALUE equality — handing it a
# copy would silently no-op and leave the just-seated player pairable on the next sweep.
func _find_ranked_entry(peer_id) -> Array:
	for rank_key in ranked_queue:
		for tier_key in ranked_queue[rank_key]:
			for entry in ranked_queue[rank_key][tier_key]:
				if entry[0] == peer_id:
					return entry
	return []


# An invite's identity is the ORDERED PAIR (inviter -> target), not the target alone. Keying on the
# target meant two people inviting the SAME player silently overwrote each other — the second invite
# evicted the first, and that player could then never be reached by the person they were waiting on.
# It also forced every cleanup path to guess a username. Nothing here constrains the characters in a
# username, so the two halves are LENGTH-PREFIXED rather than joined by a separator: any separator
# could itself occur in a name and make ("A B" -> "C") collide with ("A" -> "B C").
static func _invite_key(inviter: String, target: String) -> String:
	return str(inviter.length()) + ":" + inviter + target


# Drop every OUTSTANDING private invite belonging to this peer. Always erase by PEER ID: entries are
# keyed (inviter -> target), so erasing by a username both misses the real entry AND can delete a
# bystander's unrelated invite that merely mentions that name. Scanning values is immune to the key
# shape. .keys() returns a copy, so erasing inside the loop is safe; drain every match rather than the
# first, since one player may legitimately have several invites outstanding.
func _erase_private_invite(peer_id) -> void:
	for key in private_queue.keys():
		if private_queue[key][0] == peer_id:
			private_queue.erase(key)


# The single dequeue primitive. Every path that takes a player out of matchmaking goes
# through here so no queue can retain a stale entry.
func _release_queues(peer_id) -> void:
	queued_players.erase(peer_id)
	# _erase_from_ranked_queue returns after the FIRST hit, so one call cannot clear
	# duplicates. Drain until nothing is left.
	while not _erase_from_ranked_queue(peer_id).is_empty():
		pass
	_erase_private_invite(peer_id)
	_ranked_wait_start.erase(peer_id)
	# Supersede any pending fallback coroutine for this queue session.
	_ranked_fallback_gen[peer_id] = int(_ranked_fallback_gen.get(peer_id, 0)) + 1


enum QVerdict { OK, REAP }

# Is this queued peer still a legitimate pairing candidate? ORDER IS LOAD-BEARING.
# REAP means DELETE the entry, never merely skip it.
func _ranked_entry_verdict(peer_id) -> int:
	# (a) Ghost filter FIRST. On a dead peer get_session returns null, which makes
	#     _in_live_match report false ("free") — so checking liveness first would
	#     wave a corpse through.
	if get_player(peer_id) == null:
		return QVerdict.REAP
	# (b) A reconnect rebinds the held session to a BRAND NEW peer id while this entry
	#     still holds the old one; a DISCONNECTED session also lingers for the whole
	#     reconnect window and keeps its current_match.
	var s = get_session(peer_id)
	if s == null or s.peer_id != peer_id or s.status != ServerSession.ConnectionState.ONLINE:
		return QVerdict.REAP
	# (c) _in_live_match, NEVER _already_in_match — the latter sends an error frame, and
	#     a 1 Hz sweep calling it would spam a red toast at everyone currently in a game.
	#     REAPING rather than skipping is what closes the match_ended window: match_ended
	#     nulls current_match, and a leftover entry would yank a player who is standing in
	#     the lobby into a ranked game they never queued for.
	if _in_live_match(peer_id):
		return QVerdict.REAP
	return QVerdict.OK


# PASS 1 of a sweep: prune dead entries and collect what remains.
# Flattens to peer ids FIRST — never erase while iterating the bucket triple-loop.
func _collect_ranked_candidates(now_ms: int) -> Array:
	var peers: Array = []
	for rank_key in ranked_queue:
		for tier_key in ranked_queue[rank_key]:
			for entry in ranked_queue[rank_key][tier_key]:
				peers.append(entry[0])
	var out: Array = []
	var seen := {}
	for peer in peers:
		if seen.has(peer):
			continue                      # first-seen-wins: never pair one peer twice in a pass
		seen[peer] = true
		if _ranked_entry_verdict(peer) != QVerdict.OK:
			_release_queues(peer)
			continue
		# Read the LIVE rating, not the display package snapshot taken at enqueue —
		# a record reset can move a rating out from under a queued entry.
		var p = get_player(peer)
		out.append({
			"peer": peer,
			"rating": int(p.rank.get_rating()),
			"enqueued_ms": int(_ranked_wait_start.get(peer, now_ms)),
			"username": str(p.username),
			"last_opp": str(p.last_ranked_opponent),   # for the ULTRA-bot no-rematch rule in _best_gated_ranked_pair
			"is_ultra": bool(p.is_ultra_bot),           # only Ultra bots avoid facing their immediate-last opponent
			# Master/Grandmaster (rank derived from the live rating, so never stale): two top-rank
			# queuers pair instantly regardless of rating gap — see _best_gated_ranked_pair.
			"top": p.rank.rank >= Rank.Type.MASTER,
		})
	return out


# Pure: pick the best legal pair, or [] if none is eligible yet.
# Closest rating first; ties break toward the longest total wait so a newcomer with a
# marginally better delta cannot repeatedly jump a starving veteran.
func _best_gated_ranked_pair(cands: Array, now_ms: int) -> Array:
	var best: Array = []
	var best_d := -1
	var best_wait := -1.0
	var best_bots := 99   # bot-count of the best pair so far; prefer FEWER bots (see the tier rule below)
	for i in range(cands.size()):
		for j in range(i + 1, cands.size()):     # i+1 structurally guarantees a != b
			var a: Dictionary = cands[i]
			var b: Dictionary = cands[j]
			# Bot-vs-bot IS allowed now (the acting-team generalization drives both seats): two idle bots
			# play an exhibition when no human needs them. The tier rule below still keeps humans first.
			# Back-to-back rematches stay ALLOWED between HUMANS (owner request 2026-08-15). But an ULTRA bot
			# avoids facing its immediate-last opponent (owner request 2026-08-16) — skip a pair when either
			# side is an ultra bot whose last ladder opponent is the other. This can never deadlock a lone
			# ultra bot: playing an ephemeral fallback bot clears its last_ranked_opponent (see
			# _start_ranked_bot_fallback), so it becomes free to re-face anyone next time.
			if (bool(a.get("is_ultra", false)) and str(a.get("last_opp", "")) != "" and str(a.get("last_opp", "")) == str(b.get("username", ""))) \
					or (bool(b.get("is_ultra", false)) and str(b.get("last_opp", "")) != "" and str(b.get("last_opp", "")) == str(a.get("username", ""))):
				continue
			var d: int = absi(int(a["rating"]) - int(b["rating"]))
			# / 1000.0 not / 1000: integer division would truncate every wait to whole
			# seconds and quietly turn the 10s band into an 11s band.
			var wa: float = maxf(0.0, float(now_ms - int(a["enqueued_ms"])) / 1000.0)
			var wb: float = maxf(0.0, float(now_ms - int(b["enqueued_ms"])) / 1000.0)
			# Two Master/Grandmaster players pair INSTANTLY regardless of rating gap: the top of the
			# ladder is a thin, wide-spread population (a 2400 and a 6000 are both "GM" yet 3600 apart),
			# so the distance gate would push almost every top-rank pair past the bot timer and hand them
			# a bot instead of each other. Everyone below Master keeps the normal gated wait.
			var required: float = 0.0 if (a["top"] and b["top"]) else ranked_required_wait(d)
			# minf, NEVER maxf: "the veteran waited 60s so anyone will do" is exactly the
			# stomping this feature exists to prevent. BOTH clocks must clear the bar.
			if required > minf(wa, wb):
				continue
			var tot := wa + wb
			# Bots fill GAPS, they don't steal human opponents. Rank pairs by BOT COUNT first (fewer bots
			# wins): human-human (0) > human-bot (1) > bot-bot (2). THEN closest rating, THEN longest wait.
			# So two queued humans always pair each other; a lone human instantly gets a bot; and two idle
			# bots only play each other when no human is in the pair — nobody ever waits behind a bot game.
			var pair_bots: int = int(_is_bot_peer(a["peer"])) + int(_is_bot_peer(b["peer"]))
			var better: bool
			if best.is_empty():
				better = true
			elif pair_bots != best_bots:
				better = pair_bots < best_bots     # fewer bots in the pair wins
			elif d != best_d:
				better = d < best_d
			else:
				better = tot > best_wait
			if better:
				best = [a, b]
				best_d = d
				best_wait = tot
				best_bots = pair_bots
	return best


# One sweep. NO `await` anywhere in here or in anything it calls — that is the entire
# safety argument for why a pair cannot be seated twice.
func _gate_tick() -> void:
	if _gate_tick_running:
		return
	_gate_tick_running = true
	var now_ms := Time.get_ticks_msec()     # monotonic; wall clock would jump under NTP
	var cands := _collect_ranked_candidates(now_ms)
	while cands.size() >= 2:
		var pair := _best_gated_ranked_pair(cands, now_ms)
		if pair.is_empty():
			break
		var ea := _find_ranked_entry(int(pair[0]["peer"]))
		var eb := _find_ranked_entry(int(pair[1]["peer"]))
		if ea.is_empty() or eb.is_empty():
			break
		_ranked_wait_start.erase(int(pair[0]["peer"]))
		_ranked_wait_start.erase(int(pair[1]["peer"]))
		start_ranked_match(ea, eb)
		# Drop both from the working set and look for another eligible pair this pass.
		var newc: Array = []
		for c in cands:
			if int(c["peer"]) != int(pair[0]["peer"]) and int(c["peer"]) != int(pair[1]["peer"]):
				newc.append(c)
		cands = newc
	_gate_tick_running = false


func start_bot_match(human_peer, human_chars, practice := false, match_type := BattleManager.MatchType.BOT) -> void:
	# practice=true only for the explicit "Bot Match" queue (start_immediate_bot_match): flat 50/0 AP.
	# A quick-queue bot FALLBACK passes practice=false and stays MatchType.BOT — it is presented and
	# scored as a Quick Match (no W/L, 100/50 AP).
	# match_type=RANKED is the ranked-queue fallback: a real ranked game whose opponent happens to be a
	# bot, so it DOES record a win/loss and move rating (scaled — see handle_server_match_ended).
	var p1 = get_player(human_peer)
	if not p1:
		return
	# Pull them out of BOTH queues. Nothing stops a client sitting in the quick and ranked queues at
	# once, and a leftover quick entry would let the next quick queuer pair with an already-seated
	# player — overwriting their current_match and clearing the live board out from under them.
	queued_players.erase(human_peer)
	_erase_from_ranked_queue(human_peer)

	var seed = _fresh_match_seed()

	# Synthetic, peer-less opponent. With no session and no peer_map entry, every
	# peer-guarded broadcast/save (_broadcast_turn_result,
	# _send_post_match_player_updates) skips it automatically.
	# Only the LADDER seats a trained-pool bot. Quick-queue fallbacks and the explicit Bot Match
	# button keep the old colour-balanced random draft, so casual play still shows the whole roster
	# while a ranked game that happens to pair you with a bot is a real test.
	var bot = _make_server_bot(match_type == BattleManager.MatchType.RANKED)
	var bot_chars = bot.team.characters.map(func(c): return c.path_name)
	_bot_peer_counter -= 1
	var bot_peer = _bot_peer_counter

	var new_match = Match.from_players(human_peer, p1, human_chars, bot_peer, bot, bot_chars, seed, match_type)
	# Only the human seat can be refused — the bot Player was built fresh two statements ago and can
	# never hold a match. Their queue entries are already gone (erased above), so there is nothing
	# stale to reap and no fallback to re-arm: they are IN a game. But the synthetic opponent is
	# unparented and owned by nobody until begin_match adopts it, so free it or its Player + 3
	# Character subtrees orphan permanently.
	if new_match == null:
		bot.queue_free()
		print("[MATCH] Bot match ABORTED — from_players refused: ", p1.username, " already holds a live match")
		return
	new_match.practice_match = practice
	# from_players rebuilt the bot's team from names, dropping the per-character bot
	# flag — re-apply it. ability_component.usable() refuses to let a non-bot
	# character act while battle.waiting_for_turn is true (the bot's seat is always
	# the "waiting" opponent on the shadow), so without this the bot can never act.
	for character in bot.team.characters:
		character.bot_character = true
	new_match.timeout_current_player.connect(handle_timeout)
	new_match.server_match_ended.connect(handle_server_match_ended)
	new_match.match_over.connect(match_ended)
	add_child(new_match)
	new_match.begin_match()
	new_match.start_turn_timer()

	get_session(human_peer).current_match = new_match   # only the human has a session

	var human_first = new_match.player_goes_first(human_peer)
	# Announced on the channel matching the QUEUE the player is actually in, so the board, the label
	# and the game-over modal all read correctly. The web client renders both identically and can't
	# tell the opponent is a bot beyond its package.
	#   - practice   -> "Bot Match" label + flat 50/0 AP
	#   - quick fallback -> stays a Quick Match (100/50, no W/L)
	#   - ranked fallback -> a real Ranked match; `vs_bot` tells the client to show 250/50 instead
	#     of 500/50 (see matchApGain), since nothing else on the wire reveals a bot opponent.
	var ranked_bot: bool = match_type == BattleManager.MatchType.RANKED
	var announce := "receive_ranked_match" if ranked_bot else "receive_quick_match"
	send_to_peer(human_peer, announce, {"opponent": bot.display_package(), "opponent_team": bot_chars, "first_turn": human_first, "seed": seed, "canonical_role": 0, "practice": practice, "vs_bot": true})
	_broadcast_turn_result(new_match)
	if ranked_bot:
		ranked_matches.append(new_match)
	else:
		bot_matches.append(new_match)
	print("[MATCH] Bot match started (", "ranked" if ranked_bot else ("practice" if practice else "quick"), "): ", p1.username, " vs ", bot.username, " (seed=", seed, ")")
	# If the coin flip put the bot first, drive its opening turn now.
	_drive_bot_if_acting(new_match)


# Player explicitly requested a bot game (the "Bot Match" button): start one RIGHT AWAY, bypassing the
# quick queue + its bot_queue_delay fallback timer.
func start_immediate_bot_match(peer_id, character_names) -> void:
	var p = get_player(peer_id)
	if not p:
		send_to_peer(peer_id, "error", {"reason": "not logged in"})
		return
	var sess = get_session(peer_id)
	if sess and sess.current_match != null and is_instance_valid(sess.current_match):
		send_to_peer(peer_id, "error", {"reason": "Already in a match"})
		return
	# from_players rebuilds the team SOLELY from this list; a short payload would start a <3-char match.
	if not (character_names is Array) or character_names.size() < 3:
		send_to_peer(peer_id, "receive_queue_rejected", {})
		return
	# Bot matches are a permitted venue for the author's own unapproved work, but
	# still not for anyone else's.
	var bot_gate := _authored_team_error(character_names, p.username, true)
	if bot_gate != "":
		send_to_peer(peer_id, "error", {"reason": bot_gate})
		return
	# If they were sitting in the quick queue, pull them out (their pending bot-fallback timer then no-ops).
	if peer_id in queued_players:
		queued_players.erase(peer_id)
	print("[MATCH] ", p.username, " requested an immediate bot match")
	start_bot_match(peer_id, character_names, true)   # practice: no win/loss record, small AP


const BOT_TEAM_POOL_PATH := "res://training/team_pool.json"
# Characters a server bot never fields. tsubaki/toga are long-standing exclusions; Fern is excluded
# because her kit scales off the energy left AFTER the turn is paid for, and the bot drivers execute
# BEFORE they pay (scripts/player_component.gd) — a bot Fern would read her own unspent cost and hit
# harder than a human one from the same board.
const BOT_EXCLUDED_CHARS := ["tsubaki", "toga", "fern"]

# Parsed, validated contents of team_pool.json. Cached for the process lifetime — the pool is only
# rewritten by an offline tournament run (training/team_tournament.ps1), so a server restart is the
# intended way to adopt a new one.
var _bot_team_pool: Array = []
var _bot_team_pool_loaded := false


## The high-performing 3-character teams discovered by team-tournament training. Entries naming a
## character that no longer exists, or one on the exclusion list, are dropped rather than silently
## producing a broken bot.
func _load_bot_team_pool() -> Array:
	if _bot_team_pool_loaded:
		return _bot_team_pool
	_bot_team_pool_loaded = true
	_bot_team_pool = []
	# _read_json_dict returns {} for missing OR unparseable, which is exactly the fallback case.
	var parsed := _read_json_dict(BOT_TEAM_POOL_PATH)
	if typeof(parsed.get("teams", null)) != TYPE_ARRAY:
		push_warning("[BOT] no usable team pool at " + BOT_TEAM_POOL_PATH + " — falling back to a random draft")
		return _bot_team_pool
	var roster: Array = CharacterDatabase.char_name_list()
	var skipped := 0
	for entry in parsed["teams"]:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("chars", null)) != TYPE_ARRAY:
			skipped += 1
			continue
		var chars: Array = entry["chars"]
		if chars.size() != 3:
			skipped += 1
			continue
		var team := []
		for c in chars:
			var char_name := str(c)
			# A team is only usable if every seat is a real, allowed, distinct character — the pool
			# outlives roster changes, so it can name someone who has since been removed.
			if char_name in BOT_EXCLUDED_CHARS or not char_name in roster or char_name in team:
				team = []
				break
			team.append(char_name)
		if team.size() == 3:
			_bot_team_pool.append(team)
		else:
			skipped += 1
	print("[BOT] team pool loaded: ", _bot_team_pool.size(), " usable team(s), ", skipped, " skipped")
	return _bot_team_pool


## A 3-character team for a server bot.
##
## LADDER (from_trained_pool = true) draws a whole team from the trained high-performance pool, so a
## ranked game against a bot is a genuine test. Everything else — the quick-queue fallback and the
## explicit Bot Match button — keeps the colour-balanced random draft, which shows the whole roster
## and stays beatable.
##
## A missing or unusable pool falls through to the random draft too, so a bad file degrades bot
## quality instead of breaking ladder matches.
func _pick_bot_team(from_trained_pool: bool) -> Array:
	if from_trained_pool:
		var pool := _load_bot_team_pool()
		if not pool.is_empty():
			var team: Array = pool[randi_range(0, pool.size() - 1)].duplicate()
			# _load_bot_team_pool already drops any team naming a BOT_EXCLUDED_CHARS member at load, so this
			# never fails today — but re-checking here keeps the "no banned character is ever fielded"
			# guarantee local to the draw, so a future change to how the pool is populated can't leak one.
			# On a miss (impossible today) fall through to the always-filtered random draft below.
			var banned := false
			for c in team:
				if c in BOT_EXCLUDED_CHARS:
					banned = true
					break
			if not banned:
				return team
	return _random_bot_team()


## The original colour-balanced random draft over the full roster.
func _random_bot_team() -> Array:
	var roster: Array = CharacterDatabase.char_name_list()
	var team := []
	while team.size() < 3:
		var pick = ColorBalancedDraft.pick_next(team, roster, BOT_EXCLUDED_CHARS)
		if pick == "":
			var fallback = roster[randi_range(0, roster.size() - 1)]
			if fallback in team or fallback in BOT_EXCLUDED_CHARS:
				continue
			pick = fallback
		team.append(pick)
	return team


# Bundled cosmetic pools for bot opponents, enumerated ONCE from the shipped assets rather than
# hardcoded. The old code guessed `randi_range(1, 72)` at a folder that actually holds 89 avatars
# under mixed numeric and named files, so it could never pick two thirds of them and would have
# silently started 404-ing the moment a numbered file was renamed. Reading the directory keeps the
# pool honest as art is added or removed.
const AVATAR_DIR := "res://assets/avatars"
const PLAYERCARD_DIR := "res://assets/cosmetics/playercards"
const DEFAULT_BOT_AVATAR := "res://assets/avatars/toko_toda.png"
const DEFAULT_BOT_CARD := "playercard_color_default"
var _avatar_pool: Array = []
var _playercard_pool: Array = []
var _cosmetic_pools_loaded := false

# List the .png basenames in a res:// directory. In an EXPORTED build the source .png is replaced by
# an imported .ctex inside .godot/, so list both and de-duplicate on the stem — otherwise this
# returns everything in the editor and nothing in the shipped server.
func _list_asset_stems(dir_path: String) -> Array:
	var out := {}
	var d := DirAccess.open(dir_path)
	if d == null:
		return []
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir():
			var stem := ""
			if f.ends_with(".png"):
				stem = f.get_basename()
			elif f.ends_with(".png.import"):
				stem = f.trim_suffix(".import").get_basename()
			if stem != "":
				out[stem] = true
		f = d.get_next()
	d.list_dir_end()
	var keys: Array = out.keys()
	keys.sort()   # stable order so a seeded pick is reproducible
	return keys

func _load_cosmetic_pools() -> void:
	if _cosmetic_pools_loaded:
		return
	_cosmetic_pools_loaded = true
	_avatar_pool = _list_asset_stems(AVATAR_DIR)
	_playercard_pool = _list_asset_stems(PLAYERCARD_DIR)
	print("[bot-cosmetics] ", _avatar_pool.size(), " avatar(s), ", _playercard_pool.size(), " playercard(s)")

# Give a bot Player a random look. `stable_key` (optional) makes the choice DETERMINISTIC for that
# key instead of random — campaign enemies use their name so a scripted opponent looks the same on
# every retry, while queue bots pass nothing and are freshly random each match.
#
# Deliberately uses the GLOBAL rng, never battle.roll: cosmetics must not consume the seeded
# gameplay stream, or picking an avatar would shift every subsequent dice roll in the match.
func _apply_bot_cosmetics(bot, stable_key := "") -> void:
	_load_cosmetic_pools()
	var av_i := 0
	var card_i := 0
	if stable_key == "":
		if _avatar_pool.size() > 0:
			av_i = randi_range(0, _avatar_pool.size() - 1)
		if _playercard_pool.size() > 0:
			card_i = randi_range(0, _playercard_pool.size() - 1)
	else:
		var h: int = abs(stable_key.hash())
		if _avatar_pool.size() > 0:
			av_i = h % _avatar_pool.size()
		if _playercard_pool.size() > 0:
			card_i = (h / 7) % _playercard_pool.size()
	# avatar_url is what display_package() actually ships; the old avatar_texture assignment was a
	# leftover from the deleted Godot desktop client and reached no one.
	if _avatar_pool.size() > 0:
		bot.avatar_url = AVATAR_DIR + "/" + str(_avatar_pool[av_i]) + ".png"
	else:
		bot.avatar_url = DEFAULT_BOT_AVATAR
	if _playercard_pool.size() > 0:
		bot.equipped_player_card = str(_playercard_pool[card_i])
	else:
		bot.equipped_player_card = DEFAULT_BOT_CARD


func _make_server_bot(from_trained_pool := false):
	# Mirrors the live client-side make_crazy_bot (char_select_scene.gd): a random username/avatar,
	# a 3-character team, and plausible random rank stats so it reads like a real opponent.
	# `from_trained_pool` is true only for the LADDER bot fallback (see _pick_bot_team).
	# Single-use per match; freed in Match.release_player_objects.
	var bot = load("res://components/player_component.tscn").instantiate()
	var usernames := ["cr4zy 1ns4n0", "ragingp0tato", "v3lvet_v0id", "7thGhost", "neon.drip_99", "static.cl1ng", "blurryfacex", "quantum_leap", "wild_cardx", "xfactor99", "zephyrbreeze", "gamma_ray9", "deltaForce", "kappaKing", "pi_rate314", "sigma_six", "spaceCadet", "time_travlr", "megaMind", "alphaw0lf", "Bankai 0r Bust", "Chidori Spark", "Gum Gum Pist0l", "sukuna_fingerz", "Levi Ackermn", "Zoro 3 Sword"]
	bot.set_username(usernames[randi_range(0, usernames.size() - 1)])
	bot.bot_player = true
	_apply_bot_cosmetics(bot)

	for char_name in _pick_bot_team(from_trained_pool):
		bot.recruit_character(Character.from_character_name(char_name), true)
	for character in bot.team.characters:
		character.bot_character = true
	# Plausible record so the opponent card looks like a real player.
	bot.rank.wins = randi_range(0, 50)
	bot.rank.losses = int((randf_range(0.2, 1.6) + randi_range(0, 1)) * bot.rank.wins)
	return bot


# ===========================================================================
# ULTRA BOTS — persistent, player-like bot accounts (see Anime Arena/Proposals/Ultra Bots).
#
# Unlike the ephemeral _make_server_bot above (a single-use, peer-less opponent conjured per match and
# freed after), an Ultra Bot is a DURABLE account: it lives in ausers/*.dat + the players cache like a
# human, is marked by the unforgeable Player.is_ultra_bot flag, moves REAL rating, and is visible on
# ladders/search. This section (Phase 1) is only the IDENTITY layer — the roster, the account builder,
# and the boot seeder. Self-queuing, the virtual session, turn-driving on the normal seat path, the
# rotation scheduler, and the enhanced-energy / think-time / surrender behaviours are later phases.
# ===========================================================================
const ULTRA_BOTS_CONFIG := "res://ultra_bots.json"

# Test seam: when non-null, this array is returned verbatim instead of reading ultra_bots.json — so
# scheduler/queue probes can drive the rotation against a FIXED roster and never break when the shipped
# roster is re-generated. Production leaves it null.
var _ultra_bot_roster_override = null

func _load_ultra_bot_roster() -> Array:
	if _ultra_bot_roster_override != null:
		return _ultra_bot_roster_override
	if not FileAccess.file_exists(ULTRA_BOTS_CONFIG):
		return []
	var f := FileAccess.open(ULTRA_BOTS_CONFIG, FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed.get("bots", null) is Array):
		push_warning("[ULTRABOT] ultra_bots.json missing or malformed 'bots' array")
		return []
	return parsed["bots"]

# The FAVORED characters an Ultra bot always fields: the valid, distinct, non-excluded subset of a
# preferred list, capped at 3. Unknown/removed/excluded/duplicate names are dropped (a roster typo
# degrades gracefully). May return fewer than 3 — that shortfall is filled per-match by _ultra_bot_team.
func _ultra_bot_favored_sanitized(preferred) -> Array:
	var out := []
	if preferred is Array:
		var roster: Array = CharacterDatabase.char_name_list()
		for c in preferred:
			var cname := str(c)
			if cname in roster and not cname in BOT_EXCLUDED_CHARS and not cname in out:
				out.append(cname)
			if out.size() == 3:
				break
	return out

# A full 3-character team seeded with the bot's FAVORED characters (always fielded), the remaining seats
# filled by a colour-balanced RANDOM draft. 3 favored -> exactly that trio; fewer -> the fill varies, which
# is what lets a bot "occasionally switch the team it's trying to use" while always keeping its favorites.
func _ultra_bot_team(preferred) -> Array:
	var out: Array = _ultra_bot_favored_sanitized(preferred)
	var roster: Array = CharacterDatabase.char_name_list()
	while out.size() < 3:
		var pick = ColorBalancedDraft.pick_next(out, roster, BOT_EXCLUDED_CHARS)
		if pick == "" or pick in out:
			pick = roster[randi_range(0, roster.size() - 1)]
		if not pick in out and not pick in BOT_EXCLUDED_CHARS:
			out.append(pick)
	return out

# A stored, unguessable password for a reserved bot account so the name can never be logged into.
# (Passwords are plaintext in this codebase; a long random token is enough — no human knows it, and the
# reserved .dat blocks re-registration. Generated once at account creation and preserved by resave.)
func _ultra_bot_pass_hash() -> String:
	return "ultrabot!" + str(randi()) + "-" + str(randi()) + "-" + str(int(Time.get_unix_time_from_system()))

# Pure builder: a fully-formed persistent bot Player from one roster entry. NO disk I/O and does not
# touch the players cache — safe to unit-test on a bare ServerConnection instance.
func _build_ultra_bot_player(entry: Dictionary) -> Player:
	var uname := str(entry.get("username", "")).strip_edges()
	if uname == "":
		return null
	var bot: Player = Player.new_gen(uname, "", missions)   # new_gen is untyped -> explicit type, not :=
	bot.set_username(uname)
	bot.is_ultra_bot = true          # DURABLE marker (persisted, unforgeable). bot_player is set at SEAT time.
	bot.ap = 0
	bot.rank.set_values(0, 0, 0, int(entry.get("rating", 1000)))
	# Record the FAVORED core (1-3), then field a full team = favored + colour-matched fill. The favored
	# list drives per-match re-rolls (_ultra_bot_pick_match_team); equipped_characters is just the current
	# fielded snapshot shown on the profile.
	var favored: Array = _ultra_bot_favored_sanitized(entry.get("preferred_team", []))
	_ultra_bot_favored[uname] = favored
	bot.equipped_characters = _ultra_bot_team(favored)
	_ultra_bot_current_team[uname] = bot.equipped_characters.duplicate()
	# Deterministic face by name first (stable_key), then explicit roster overrides win.
	_apply_bot_cosmetics(bot, uname)
	# A non-empty roster avatar_url wins; a blank placeholder keeps the auto-assigned cosmetic avatar
	# (so an empty "avatar_url": "" in the JSON is a safe no-op — see _ultra_bot_roster_avatar).
	var roster_avatar := _ultra_bot_roster_avatar(entry)
	if roster_avatar != "":
		bot.avatar_url = roster_avatar
	# Coherent, EARNED playercard + its backing mastery: replaces the stable-random card
	# _apply_bot_cosmetics just set with a mastery card for one of the bot's own team characters (unless a
	# roster player_card overrides), and floors that character's mastery at the level-3 unlock. See helper.
	_ultra_bot_apply_card_and_mastery(bot, entry)
	if entry.has("title"):
		bot.title = str(entry["title"])
	if entry.get("hats", null) is Array:
		bot.equipped_hats = entry["hats"]
	if entry.has("clan"):
		bot.clan = str(entry["clan"])
	return bot

# The roster's explicit avatar URL for a bot, trimmed — or "" when the field is absent or left blank.
# Blank means "keep the auto-assigned cosmetic avatar", so an empty "avatar_url": "" placeholder in
# ultra_bots.json is a safe no-op and the owner only has to paste a URL to give a bot a custom face.
func _ultra_bot_roster_avatar(entry: Dictionary) -> String:
	return str(entry.get("avatar_url", "")).strip_edges()

# The character a mastery playercard belongs to ("playercard_mastery_naruto" -> "naruto"), or "" if the
# card is not a per-character mastery card (a color card, the default, etc.) or names an unknown character.
func _mastery_card_character(card: String) -> String:
	var prefix := "playercard_mastery_"
	if not card.begins_with(prefix):
		return ""
	var ch := card.substr(prefix.length())
	if ch in CharacterDatabase.char_name_list():
		return ch
	return ""

# A deterministic, plausible multiple-of-20 mastery XP inside the [min_level, min_level+1) band — the kind of
# value organic +100/-40 play actually produces. NEVER the raw XP_THRESHOLDS boundary (475 for level 3): those
# are not multiples of 20, so a floored-to-threshold XP is a permanent forensic marker no played account can
# hold. Stable per seed_key so it survives restarts (the seeder is raise-only and real wins carry it higher).
func _ultra_bot_mastery_floor(seed_key: String, min_level: int) -> int:
	var lo: int = MasteryConfig.XP_THRESHOLDS[min_level]
	var hi: int = (MasteryConfig.XP_THRESHOLDS[min_level + 1] if min_level + 1 < MasteryConfig.XP_THRESHOLDS.size() else lo + 320)
	var lo20: int = int(ceil(float(lo) / 20.0)) * 20        # smallest multiple of 20 at/above the band floor
	var hi20: int = int(floor(float(hi - 1) / 20.0)) * 20   # largest multiple of 20 below the band ceiling
	if hi20 < lo20:
		hi20 = lo20
	var span: int = (hi20 - lo20) / 20 + 1
	var pick: int = abs((seed_key + "|mxp").hash()) % span
	return lo20 + pick * 20

# Give an Ultra bot a coherent, EARNED playercard and the mastery that backs it. An explicit roster
# `player_card` wins; otherwise the bot gets the mastery card of one of its OWN team characters (stable by
# username, only if that card art actually exists in the pool). A mastery playercard is only unlocked at
# character-mastery level 3 (MasteryConfig.UNLOCK_THRESHOLDS.playercard), so the card's character is floored
# at the level-3 XP threshold — RAISE-ONLY, so mastery accrued from real wins carries it higher. Idempotent:
# safe to re-run every boot on an existing bot (self-healing). No-op for a color/default card (no character).
# Returns true if it changed the equipped card or any mastery XP (so the caller can decide to resave).
func _ultra_bot_apply_card_and_mastery(bot, entry: Dictionary) -> bool:
	var changed := false
	var want_card := ""
	# Base the card on a FAVORED character (one it always fields) rather than a fill seat that re-rolls, so
	# the profile card stays consistent with a character the bot actually mains. Fall back to the fielded
	# team if no favored core is recorded (e.g. a legacy account before favored existed).
	var card_pool: Array = _ultra_bot_favored_sanitized(entry.get("preferred_team", []))
	if card_pool.is_empty() and bot.equipped_characters is Array:
		card_pool = bot.equipped_characters
	if entry.has("player_card"):
		want_card = str(entry["player_card"])
	elif card_pool.size() > 0:
		_load_cosmetic_pools()
		var idx: int = abs((str(bot.username) + "|card").hash()) % card_pool.size()
		var team_card := MasteryConfig.get_cosmetic_id("playercard", str(card_pool[idx]))
		if team_card in _playercard_pool:
			want_card = team_card
	if want_card != "" and str(bot.equipped_player_card) != want_card:
		bot.equipped_player_card = want_card
		changed = true
	# Seed EARNED-looking mastery on the characters the bot mains: the card character to level 3 (which the
	# playercard requires), the rest of its favored core to level 2 (enough to unlock their lesser title words
	# and make the profile read like a real 1-3-character main). Every value is a plausible multiple-of-20 XP,
	# never the raw level threshold. RAISE-ONLY + deterministic per (bot, character): real wins carry it higher
	# and a restart re-derives the same floor.
	var card_char := _mastery_card_character(str(bot.equipped_player_card))
	for mc in card_pool:
		var mname := str(mc)
		var want_level: int = 3 if mname == card_char else 2
		var floor_xp := _ultra_bot_mastery_floor(str(bot.username) + "|" + mname, want_level)
		if bot.character_progress.get_xp(mname) < floor_xp:
			bot.character_progress.xp_data[mname] = floor_xp
			changed = true
	# A roster override card can name a character outside the favored core; still back it at level 3.
	if card_char != "" and not (card_char in card_pool):
		var cfx := _ultra_bot_mastery_floor(str(bot.username) + "|" + card_char, 3)
		if bot.character_progress.get_xp(card_char) < cfx:
			bot.character_progress.xp_data[card_char] = cfx
			changed = true
	return changed

# Boot-time seeder: ensure every roster entry has a persistent account. Creates missing ones through the
# same live-object path as registration (build -> players[name] -> save_player), and heals the
# is_ultra_bot marker on any pre-existing account. Idempotent. Runs once at server startup, AFTER
# initialize_players() has populated the cache. NEVER hand-edits .dat — the cache would revert it.
func _seed_ultra_bots() -> void:
	var created := 0
	var healed := 0
	for entry in _load_ultra_bot_roster():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var uname := str(entry.get("username", "")).strip_edges()
		if uname == "":
			continue
		# Record the favored core from the roster for EVERY entry (created or existing) so per-match team
		# rolls have it after a restart, even for accounts that predate the favored-characters feature.
		_ultra_bot_favored[uname] = _ultra_bot_favored_sanitized(entry.get("preferred_team", []))
		if uname in players:
			var existing: Player = players[uname]
			var changed := false
			if not existing.is_ultra_bot:
				existing.is_ultra_bot = true
				changed = true
				healed += 1
			# Reconcile the earned-playercard invariant on accounts seeded before this rule existed (or
			# whose roster card/team changed): give them a coherent mastery card + its level-3 backing.
			# Idempotent + raise-only, so it never undoes mastery an existing bot accrued from real wins.
			if _ultra_bot_apply_card_and_mastery(existing, entry):
				changed = true
			# Apply a roster avatar_url the owner filled in AFTER the account was first seeded — so all
			# they have to do is paste URLs into ultra_bots.json and restart (a blank field is a no-op,
			# so it never clobbers an already-set avatar).
			var roster_avatar := _ultra_bot_roster_avatar(entry)
			if roster_avatar != "" and str(existing.avatar_url) != roster_avatar:
				existing.avatar_url = roster_avatar
				changed = true
			if changed:
				resave_player(existing)   # preserves the on-disk pass_hash
		else:
			var bot := _build_ultra_bot_player(entry)
			if bot == null:
				continue
			players[uname] = bot
			save_player(bot, _ultra_bot_pass_hash())
			created += 1
	if created > 0 or healed > 0:
		print("[ULTRABOT] seed complete — created ", created, ", healed ", healed, " account(s)")


# --- Ultra Bot presence: a socket-less "virtual login" (Phase 3) ---------------------------------------
# A logged-in Ultra Bot gets a real ServerSession keyed by its username, on a reserved NEGATIVE peer id.
# Negative is deliberate: it lands in the _is_bot_peer range, so (a) the existing turn-driver drives its
# seats for free, (b) send_to_peer's JSON-peer guard makes every outbound frame a no-op (no socket), and
# (c) it can never collide with a real web peer (>= 1e9). The range sits far below the ephemeral
# fallback-bot counter so the two never overlap. This is the "register/log in" step done in-process,
# with no inbound frame and no client — the crux the Ultra Bots design hinges on.
const ULTRA_BOT_PEER_BASE := -1000000000
var _ultra_bot_peers: Dictionary = {}          # username -> its reserved session peer id while online
var _ultra_bot_peer_counter := ULTRA_BOT_PEER_BASE
# Human-like re-queue pause: after a bot ACTIVATES or FINISHES a game it waits a random spell before the
# rotation tick puts it back in the ranked queue, instead of re-queueing instantly. username -> the earliest
# Time.get_ticks_msec() at which it may auto-requeue. The window widens when NO human is online (below), so
# the bots don't churn through bot-vs-bot games with nobody watching. Erased when a bot goes offline.
var _ultra_bot_next_queue_at: Dictionary = {}
const ULTRA_BOT_REQUEUE_MIN_SEC := 15      # random re-queue pause while >=1 human is online
const ULTRA_BOT_REQUEUE_MAX_SEC := 180
const ULTRA_BOT_REQUEUE_IDLE_MIN_SEC := 180   # ...stretched when the ladder has NO humans online at all
const ULTRA_BOT_REQUEUE_IDLE_MAX_SEC := 600
# Silent friend-request handling: an Ultra bot never chats, never accepts — it just auto-DECLINES an incoming
# friend request after a random, human-like delay, so the request resolves instead of pending forever (the
# loudest social tell). Key "botname|requester" -> the earliest Time.get_ticks_msec() at which to decline it.
# Ephemeral + re-derived: the rotation tick re-arms any un-armed pending request, so a restart just re-rolls
# the delay (the request still gets declined, just a fresh amount of time later).
var _ultra_bot_decline_at: Dictionary = {}
const ULTRA_BOT_DECLINE_MIN_SEC := 120     # 2 minutes
const ULTRA_BOT_DECLINE_MAX_SEC := 7200    # 2 hours
# Favored characters (always fielded) + the colour-matched fill team the bot is currently using. The fill
# is re-rolled with ULTRA_BOT_TEAM_RESHUFFLE_CHANCE each time the bot re-queues, so a bot with <3 favored
# "occasionally switches the team it's trying to use" while always keeping its favorites. Both keyed by
# username; _ultra_bot_favored is repopulated from the roster at seed, _ultra_bot_current_team is transient.
var _ultra_bot_favored: Dictionary = {}         # username -> Array of 1-3 favored path_names (may be < full team)
var _ultra_bot_current_team: Dictionary = {}    # username -> the full 3-char team it is fielding right now
const ULTRA_BOT_TEAM_RESHUFFLE_CHANCE := 0.30   # chance, per re-queue, to re-roll the non-favored fill
# Admin-PINNED bots: manually brought online via the admin panel, kept online + queued regardless of the
# time-of-day schedule (so a smoke-test bot isn't reclaimed by the rotation tick 30s later). Cleared when
# the bot is taken offline. Keyed by username.
var _ultra_bot_pinned: Dictionary = {}

# Is any REAL player (human) currently connected? Ultra bots hold negative (_is_bot_peer) sessions and
# ephemeral bots have none, so a session on a non-bot peer that isn't DISCONNECTED is a live human. Drives
# how long a bot waits before re-queueing (an empty-of-humans ladder gets the longer pause).
func _any_human_online() -> bool:
	for uname in sessions:
		var sess = sessions[uname]
		if sess == null or _is_bot_peer(sess.peer_id):
			continue
		if sess.status == ServerSession.ConnectionState.DISCONNECTED:
			continue
		return true
	return false

# Arm the human-like re-queue pause for a bot: after activating or finishing a game it waits a random
# 15-180s before the rotation tick re-queues it — stretched to 180-600s when NO human is online, so the bots
# don't burn cycles churning bot-vs-bot games nobody is watching. Unseeded global RNG on purpose (server
# pacing, not battle state — same rationale as _bot_think_seconds). The tick honors _ultra_bot_next_queue_at.
func _ultra_bot_arm_requeue_delay(username: String) -> void:
	var lo: int = ULTRA_BOT_REQUEUE_MIN_SEC
	var hi: int = ULTRA_BOT_REQUEUE_MAX_SEC
	if not _any_human_online():
		lo = ULTRA_BOT_REQUEUE_IDLE_MIN_SEC
		hi = ULTRA_BOT_REQUEUE_IDLE_MAX_SEC
	_ultra_bot_next_queue_at[username] = Time.get_ticks_msec() + randi_range(lo, hi) * 1000

# Bring an Ultra Bot ONLINE: mint its session so it resolves through get_player/get_session, survives the
# ranked queue liveness gate (_ranked_entry_verdict), and can be seated + driven like a human. Idempotent.
# Returns the bot's session peer id, or 0 on failure.
func _ultra_bot_online(username: String) -> int:
	if not username in players:
		return 0
	var bot: Player = players[username]
	if not bot.is_ultra_bot:
		return 0
	if username in sessions and sessions[username].peer_id in peer_map:
		return sessions[username].peer_id   # already online
	_ultra_bot_peer_counter -= 1
	var bot_peer: int = _ultra_bot_peer_counter
	var session := ServerSession.new(username, bot_peer, bot)
	session.status = ServerSession.ConnectionState.ONLINE
	sessions[username] = session
	peer_map[bot_peer] = username
	_ultra_bot_peers[username] = bot_peer
	bot.bot_player = true                        # runtime: drive its seats with the AI
	# "Upon first activating" — don't queue instantly; wait a random spell (the rotation tick enforces it).
	_ultra_bot_arm_requeue_delay(username)
	return bot_peer

# Bring an Ultra Bot OFFLINE: pull it from the queues and drop its session. Refuses to yank a bot out
# from under a LIVE game (only dequeues then; the scheduler retries once the match ends). Safe to call
# when the bot is not online.
func _ultra_bot_offline(username: String) -> void:
	if not username in _ultra_bot_peers:
		return
	var bot_peer: int = _ultra_bot_peers[username]
	_release_queues(bot_peer)                    # always leave the queue so it can't be paired again
	var sess = sessions.get(username, null)
	if sess != null and sess.current_match != null and is_instance_valid(sess.current_match) \
			and not (is_instance_valid(sess.current_match.manager) and sess.current_match.manager.match_over):
		return                                    # in a live match — stay logged in until it finishes
	peer_map.erase(bot_peer)
	if username in sessions and sessions[username].peer_id == bot_peer:
		sessions.erase(username)
	_ultra_bot_peers.erase(username)
	_ultra_bot_pinned.erase(username)   # going offline always clears any admin pin
	_ultra_bot_next_queue_at.erase(username)   # fresh re-queue pause armed on the next activation
	_ultra_bot_current_team.erase(username)    # re-roll a fresh fill team on the next activation
	var bot = players.get(username, null)
	if bot != null:
		bot.bot_player = false


# --- Ultra Bot self-queue + seating (Phase 4) ----------------------------------------------------------
# Push an ONLINE bot into the ranked queue as a normal candidate — the sweep (_gate_tick) then pairs it
# with the closest-rated HUMAN (or another queued Ultra bot) exactly like any player. Mirrors
# receive_ranked_match_queue's core, including the ephemeral-bot fallback so a LONE queued bot meets a
# regular bot at the same 30s cadence a player would; only the web-frame reject path is dropped.
func _ultra_bot_enqueue_ranked(username: String) -> void:
	if not username in _ultra_bot_peers:
		return
	var bot_peer: int = _ultra_bot_peers[username]
	var bot: Player = players.get(username, null)
	if bot == null or _already_in_match(bot_peer):
		return
	# Favored core + occasionally-reshuffled colour-matched fill (also updates bot.equipped_characters so the
	# queue package / profile show the team it is fielding this game).
	var chars: Array = _ultra_bot_pick_match_team(username, bot)
	var pkg = bot.display_package()
	_release_queues(bot_peer)
	# Defensive: tiers are seeded at boot, but create the bucket if absent so this never crashes.
	if not (pkg.tier in ranked_queue[pkg.rank]):
		ranked_queue[pkg.rank][pkg.tier] = []
	ranked_queue[pkg.rank][pkg.tier].append([bot_peer, pkg, chars])
	_ranked_wait_start[bot_peer] = Time.get_ticks_msec()
	# Encounter regular (ephemeral) bots at the SAME rate a player would: if no human or other Ultra bot
	# pairs with it within RANKED_BOT_DELAY, seat it against an ephemeral fallback bot (a real ranked game
	# whose rating moves capped, like a player-vs-bot). Two online Ultra bots pair each other first (the 1 Hz
	# sweep beats the 30s timer), so this only fires for a LONE queued bot — exactly the player experience.
	_start_ranked_bot_fallback(bot_peer)
	_gate_tick()   # sweep now so a waiting human pairs with the bot instantly

# The team an Ultra bot fields for its next game: its FAVORED characters (always), the rest filled by a
# colour-matched random draft. With 3 favored the team is fixed; with fewer, the fill is re-rolled with
# ULTRA_BOT_TEAM_RESHUFFLE_CHANCE per re-queue (else the last team is kept), so the bot "occasionally
# switches the team it's trying to use" without churning it every single game. Also stamps the chosen team
# onto bot.equipped_characters so display_package() / the profile show what it is actually fielding.
func _ultra_bot_pick_match_team(username: String, bot) -> Array:
	var favored: Array = _ultra_bot_favored.get(username, [])
	# 3 favored => a fixed trio. Fewer — INCLUDING zero favorites (an empty or all-invalid roster team) — keep
	# the current team but occasionally re-roll the colour-matched fill, so even a no-favorites bot varies its
	# team instead of freezing on one. _ultra_bot_team([]) drafts a fully random colour-matched team.
	if favored.size() >= 3:
		_ultra_bot_current_team[username] = favored.slice(0, 3)
	elif not (username in _ultra_bot_current_team) or randf() < ULTRA_BOT_TEAM_RESHUFFLE_CHANCE:
		_ultra_bot_current_team[username] = _ultra_bot_team(favored)
	var team: Array = (_ultra_bot_current_team[username] as Array).duplicate()
	bot.equipped_characters = team.duplicate()
	return team

# A lone bot vs a human must take the p2 / enemy seat — historically the only seat the turn-driver ran.
# Human-vs-human is returned unchanged. A bot-vs-bot pair (now allowed — see _best_gated_ranked_pair) also
# reaches here and is returned unchanged: both peers are bots, so the swap guard below is false, and the
# driver alternates both seats anyway (_run_shadow_bot_turn resolves the acting side from waiting_for_turn).
# Returns [p1_package, p2_package].
func _order_seats_bot_second(pkg_a, pkg_b) -> Array:
	if _is_bot_peer(pkg_a[0]) and not _is_bot_peer(pkg_b[0]):
		return [pkg_b, pkg_a]
	return [pkg_a, pkg_b]


# --- Ultra Bot daily rotation scheduler (Phase 5) ------------------------------------------------------
# A STATELESS wall-clock tick: "which bots are online right now" is a pure function of the current hour and
# each roster entry's online_windows, so a restart can never lose the schedule. Each tick brings the right
# bots ONLINE (mint session + keep them queued) and drops the rest OFFLINE, and re-queues any online bot
# that just finished a game. Runs on a Timer + once at boot. _ultra_bot_rotation_enabled is a live kill-switch.
const ULTRA_BOT_TICK := 30.0          # seconds between rotation ticks
const ULTRA_BOT_MAX_ONLINE := 12      # safety cap on concurrent online bots (30-strong roster; windows overlap)
var _ultra_bot_rotation_enabled := true
var _ultra_bot_timer: Timer = null

# DEPLOY switch (persistent): the master on/off for the whole Ultra Bot system. Until an admin deploys, the
# bots are dormant — not seeded, never online, never queued, never playing. Persisted to a flag file so the
# decision survives restarts; loaded at boot. `_ultra_bot_rotation_enabled` above is a lighter LIVE pause that
# only applies WHILE deployed (stop bringing bots online without tearing the fleet down).
const ULTRA_BOT_DEPLOY_FLAG := "ultra_bots_deployed.flag"
var _ultra_bot_deployed := false

func _load_ultra_bot_deployed() -> void:
	_ultra_bot_deployed = false
	if FileAccess.file_exists(ULTRA_BOT_DEPLOY_FLAG):
		var f := FileAccess.open(ULTRA_BOT_DEPLOY_FLAG, FileAccess.READ)
		if f != null:
			_ultra_bot_deployed = f.get_as_text().strip_edges().begins_with("1")
			f.close()

func _persist_ultra_bot_deployed() -> void:
	var f := FileAccess.open(ULTRA_BOT_DEPLOY_FLAG, FileAccess.WRITE)
	if f != null:
		f.store_string("1" if _ultra_bot_deployed else "0")
		f.close()

# Flip the master DEPLOY switch. Deploying seeds the accounts (idempotent) and activates the current hour's
# roster immediately; un-deploying persists the choice and lets the tick drain every bot offline. Idempotent.
func _ultra_bot_deploy(on: bool) -> void:
	_ultra_bot_deployed = on
	_persist_ultra_bot_deployed()
	if on:
		_seed_ultra_bots()
		_ultra_bot_rotation_tick()
	else:
		# Undeploy: take idle bots offline now; the tick drains any that were mid-match once they finish.
		for uname in _ultra_bot_peers.keys():
			_ultra_bot_offline(uname)

func _on_ultra_bot_tick() -> void:    # 0-arg Timer callback (the tick itself takes an optional test hour)
	_ultra_bot_rotation_tick()

# Is `hour` (0-23) inside any of the bot's online_windows ([[start, end), ...], end-exclusive, local time)?
# A stable, per-bot minute offset (~ +/- half an hour) applied to that bot's window edges. This is what breaks
# the "everyone logs in exactly at HH:00 in synchronized batches" schedule tell: two bots sharing an integer
# window edge now come online/offline tens of minutes apart, and no transition snaps to the round hour.
func _ultra_bot_window_offset(username: String) -> int:
	return (abs((username + "|winjit").hash()) % 60) - 29   # [-29, +30] minutes, deterministic per bot

# Is `minute_of_day` (0..1439) inside any of the bot's online_windows ([[startHr, endHr), ...], end-exclusive)
# AFTER shifting the bot's clock by its stable per-bot offset? Sub-hour precision + the offset de-synchronize
# the fleet instead of flipping everyone on the integer hour.
func _ultra_bot_in_window(entry: Dictionary, minute_of_day: int) -> bool:
	var windows = entry.get("online_windows", [])
	if not (windows is Array):
		return false
	var shifted := posmod(minute_of_day - _ultra_bot_window_offset(str(entry.get("username", ""))), 24 * 60)
	for w in windows:
		if w is Array and w.size() == 2 and shifted >= int(w[0]) * 60 and shifted < int(w[1]) * 60:
			return true
	return false

# One rotation pass. force_hour >= 0 overrides the wall clock (for tests); -1 = use the current hour.
func _ultra_bot_rotation_tick(force_hour: int = -1) -> void:
	# Master DEPLOY switch: until deployed, the fleet is fully dormant. If we ever tick while undeployed with
	# bots still online (e.g. one that was mid-match when the admin undeployed), drain them offline.
	if not _ultra_bot_deployed:
		for uname in _ultra_bot_peers.keys():
			_ultra_bot_offline(uname)
		return
	# Friend-request auto-declines run BEFORE the scheduler kill-switch: a request must never pend forever
	# just because an admin paused bot rotation (that switch governs online/queue presence, not the accounts).
	_ultra_bot_process_declines()
	if not _ultra_bot_rotation_enabled:
		return
	# Minute-of-day drives the per-bot window offset (below). A test's force_hour is the top of that hour.
	var minute_of_day: int
	if force_hour >= 0:
		minute_of_day = force_hour * 60
	else:
		var dt := Time.get_datetime_dict_from_system()
		minute_of_day = int(dt.get("hour", 0)) * 60 + int(dt.get("minute", 0))
	var online_now := 0
	for entry in _load_ultra_bot_roster():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var uname := str(entry.get("username", "")).strip_edges()
		if uname == "" or not (uname in players):
			continue
		var is_online: bool = uname in _ultra_bot_peers
		var pinned: bool = uname in _ultra_bot_pinned
		# Keep online if an admin PINNED it, or it is in its (offset-shifted) window (and under the safety cap).
		var keep_online: bool = pinned or (_ultra_bot_in_window(entry, minute_of_day) and (is_online or online_now < ULTRA_BOT_MAX_ONLINE))
		if keep_online:
			if not is_online:
				_ultra_bot_online(uname)
			online_now += 1
			# Keep an online, idle bot in the ranked queue so a queuing human pairs with it instantly — but
			# only once its human-like re-queue pause (armed on activation / at the end of its last game) has
			# elapsed, so it doesn't snap back into the queue the instant it comes free.
			var bp: int = _ultra_bot_peers.get(uname, 0)
			if bp != 0 and not _already_in_match(bp) and _find_ranked_entry(bp).is_empty() \
					and Time.get_ticks_msec() >= int(_ultra_bot_next_queue_at.get(uname, 0)):
				_ultra_bot_enqueue_ranked(uname)
		elif is_online:
			_ultra_bot_offline(uname)   # refuses to yank a bot mid-match; retries next tick


# --- Ultra Bot silent friend-request auto-decline ---------------------------------------------------------
# Arm a decline for one (bot, requester) pair the first time we see it. Idempotent (a re-arm never shortens an
# existing delay). Uses the unseeded global RNG — social pacing, not battle state.
func _ultra_bot_arm_decline(bot_name: String, requester: String) -> void:
	var key := bot_name + "|" + requester
	if not _ultra_bot_decline_at.has(key):
		_ultra_bot_decline_at[key] = Time.get_ticks_msec() + randi_range(ULTRA_BOT_DECLINE_MIN_SEC, ULTRA_BOT_DECLINE_MAX_SEC) * 1000

# Scan every ULTRA-BOT ACCOUNT's pending inbox each tick: arm any un-armed request (covers a restart, or a
# request that arrived while the bot was offline), execute the ones whose delay has elapsed, and prune stale
# timers (a request the human cancelled, or one we just declined). Iterates the players cache — NOT the roster
# file — so a bot dropped from ultra_bots.json still drains its inbox, and a transient roster-read failure
# can't wipe every in-flight timer. `players.keys()` is a snapshot: a decline can disk-load+cache a requester
# into `players`, which would otherwise mutate the collection mid-iteration.
func _ultra_bot_process_declines() -> void:
	var now := Time.get_ticks_msec()
	var live := {}   # keys still backed by a pending request after this pass
	for uname in players.keys():
		var bot = players[uname]
		if bot == null or not bot.is_ultra_bot or not (bot.friend_requests_in is Array):
			continue
		for requester in bot.friend_requests_in.duplicate():   # duplicate: the decline mutates this list
			var key := str(uname) + "|" + str(requester)
			if not _ultra_bot_decline_at.has(key):
				_ultra_bot_arm_decline(str(uname), str(requester))
				live[key] = true
			elif now >= int(_ultra_bot_decline_at[key]):
				_ultra_bot_decline_friend(bot, str(requester))
				_ultra_bot_decline_at.erase(key)   # request is gone now — do not keep the timer
			else:
				live[key] = true
	for key in _ultra_bot_decline_at.keys():
		if not live.has(key):
			_ultra_bot_decline_at.erase(key)   # cancelled request — drop its dangling timer

# Execute a decline exactly like _json_friend_decline (the bot is the decliner): drop the incoming request,
# clear the requester's outgoing entry, resave both, and refresh the requester so their pending entry clears.
# Never touches `friends` — a bot declines, it never accepts.
func _ultra_bot_decline_friend(bot, requester_name: String) -> void:
	bot.friend_requests_in.erase(requester_name)
	var requester = _admin_get_target(requester_name)
	if requester != null and requester != bot:
		requester.friend_requests_out.erase(bot.username)
		resave_player(requester)
		_send_social_state_to(requester_name)   # online: clears their pending outgoing entry; offline: no-op
	resave_player(bot)


# Single-player CAMPAIGN battle: the human's campaign team vs an EXPLICIT scripted enemy team
# (campaign-only + existing characters). Reuses the entire bot-match path — same shadow
# BattleManager, wire snapshots, event stream, and AI-driven enemy seat — but with match_type
# CAMPAIGN so handle_server_match_ended skips all PvP bookkeeping. `params`:
#   { player_team: [3 path_names], enemy_team: [3 path_names], encounter?, enemy_name? }
func start_campaign_battle(human_peer, params) -> void:
	var p1 = get_player(human_peer)
	if not p1:
		return
	var sess = get_session(human_peer)
	if sess and sess.current_match != null and is_instance_valid(sess.current_match):
		send_to_peer(human_peer, "error", {"reason": "Already in a match"})
		return
	# ANTI-CHEAT: the encounter is NOT trusted from the client. It must be a battle step of the player's
	# CURRENT active beat; the enemy team + name AND the player party are then derived server-side (from the
	# campaign definition / campaign_state), never from raw client params. Otherwise a client could start a
	# trivial fight for any encounter id, win, and bank a pending_win to skip a real story battle later.
	var prog = p1.campaign_state
	if not (prog is Dictionary) or not (prog.get("active") is Dictionary):
		send_to_peer(human_peer, "error", {"reason": "Campaign: no active beat to fight"})
		return
	var active = prog["active"]
	var enc_id = str(params.get("encounter", ""))
	var live = Campaign.activation_by_id(Campaign.node(Campaign.chapter(prog.get("chapter")), active.get("node")), active.get("activation"))
	var enc_in_beat := false
	if live != null and enc_id != "":
		for step in live.get("sequence", []):
			if step is Dictionary and str(step.get("battle", "")) == enc_id:
				enc_in_beat = true
				break
	if not enc_in_beat:
		send_to_peer(human_peer, "error", {"reason": "Campaign: that battle isn't part of your current beat"})
		return
	# Player party = campaign_state.party; enemy = the encounter definition. Both server-authoritative.
	var enc_def = Campaign.encounter(enc_id)
	var human_chars = (prog.get("party", []) as Array).slice(0, 3)
	var enemy_team = (enc_def.get("enemy_team", []) as Array).slice(0, 3)
	var enemy_name = str(enc_def.get("enemy_name", "Enemy Forces"))
	if human_chars.size() != 3 or enemy_team.size() != 3 or _has_dupes(human_chars) or _has_dupes(enemy_team):
		send_to_peer(human_peer, "error", {"reason": "Campaign: encounter/party misconfigured (need 3 distinct each)"})
		return

	var seed = _fresh_match_seed()

	var enemy = _make_campaign_enemy(enemy_team, enemy_name)
	var enemy_chars = enemy.team.characters.map(func(c): return c.path_name)
	_bot_peer_counter -= 1
	var enemy_peer = _bot_peer_counter

	var new_match = Match.from_players(human_peer, p1, human_chars, enemy_peer, enemy, enemy_chars, seed, BattleManager.MatchType.CAMPAIGN)
	# Belt-and-braces: the "Already in a match" gate at the top of this function should make this
	# unreachable. If it does fire, free the synthetic enemy (nothing else owns it yet) and answer the
	# client — it is waiting on receive_campaign_match and would otherwise hang on the loading screen.
	if new_match == null:
		enemy.queue_free()
		send_to_peer(human_peer, "error", {"reason": "Already in a match"})
		print("[CAMPAIGN] Battle ABORTED — from_players refused: ", p1.username, " already holds a live match")
		return
	new_match.campaign_encounter = enc_id
	new_match.campaign_activation = str(active.get("activation", ""))   # scopes the banked win to THIS beat
	# from_players rebuilt the enemy team from names, dropping the per-character bot flag — re-apply
	# it (ability usable() refuses to let a non-bot character act while it's the waiting seat).
	for character in enemy.team.characters:
		character.bot_character = true
	# The Vessel assembles its kit at battle-build time (begin_match → initialize(true)). Stamp the
	# campaign-unlocked ability keys onto its seat now so they merge into its 4 default abilities.
	var vessel_unlocks = []
	if prog.get("campaign_unlocked_abilities") is Array:
		vessel_unlocks = prog["campaign_unlocked_abilities"]
	var vessel_loadout = []
	if prog.get("vessel_loadout") is Array:
		vessel_loadout = prog["vessel_loadout"]
	for character in p1.team.characters:
		if character.path_name == "vessel":
			character.extra_ability_keys = vessel_unlocks
			character.loadout = vessel_loadout   # player-chosen skills (empty = defaults)
	new_match.timeout_current_player.connect(handle_timeout)
	new_match.server_match_ended.connect(handle_server_match_ended)
	new_match.match_over.connect(match_ended)
	add_child(new_match)
	new_match.begin_match()
	new_match.start_turn_timer()

	get_session(human_peer).current_match = new_match   # only the human has a session

	var human_first = new_match.player_goes_first(human_peer)
	send_to_peer(human_peer, "receive_campaign_match", {"opponent": enemy.display_package(), "opponent_team": enemy_chars, "first_turn": human_first, "seed": seed, "canonical_role": 0, "encounter": enc_id})
	_broadcast_turn_result(new_match)
	bot_matches.append(new_match)   # tracked/cleaned up alongside bot matches (both are AI-driven)
	print("[CAMPAIGN] Battle started: ", p1.username, " vs [", enemy_chars, "] (encounter=", enc_id, ", beat=", active.get("activation"), ", seed=", seed, ")")
	# If the coin flip put the enemy first, drive its opening turn now.
	_drive_bot_if_acting(new_match)


# Build the peer-less CAMPAIGN enemy Player from an explicit team. Phase 1: generic-bot AI drives
# it (scripted boss AI + boss stat/passive overrides land in a later phase). Freed in
# Match.release_player_objects like any bot seat.
func _make_campaign_enemy(enemy_team, enemy_name):
	var enemy = load("res://components/player_component.tscn").instantiate()
	enemy.set_username(str(enemy_name))
	enemy.bot_player = true
	# Stable on the enemy's NAME: a scripted story opponent should not change face between attempts.
	_apply_bot_cosmetics(enemy, str(enemy_name))
	for char_name in enemy_team:
		enemy.recruit_character(Character.from_character_name(char_name), true)
	for character in enemy.team.characters:
		character.bot_character = true
	return enemy


func _has_dupes(arr) -> bool:
	var seen := {}
	for x in arr:
		if x in seen:
			return true
		seen[x] = true
	return false


# ===========================================================================
# CAMPAIGN PROGRESSION (server-authoritative)
# ===========================================================================
# The client sends INTENTS (enter / travel / activation_complete / choice); the server validates
# each against the authoritative campaign_state + the shared rule tables (Campaign / campaign_*.json),
# mutates state, grants rewards (unlocks), persists, and echoes the authoritative state. The client
# never writes campaign_state (it's excluded from the cosmetics-absorb path). Mirrors the bounty model.

func _send_campaign_state(json_pid, p, note := "", arrive := false) -> void:
	json_gateway.send(json_pid, {"type": "campaign_state", "state": p.campaign_state, "unlocks": p.unlocks, "note": note, "arrive": arrive})

# The server tracks which beat the player is CURRENTLY inside (set when they arrive at a node), so a
# later activation_complete / choice validates against the beat they actually started — not a fresh
# re-resolve, which can shift mid-sequence when a choice sets a flag (e.g. market_quest → market_after).
# This also blocks completing an out-of-order beat (win enc_defense early, then claim hub_return).
func _campaign_set_active(prog) -> void:
	var ch = Campaign.chapter(prog.get("chapter"))
	var live = Campaign.resolve_activation(Campaign.node(ch, prog.get("node")), prog)
	if live != null:
		prog["active"] = {"node": prog.get("node"), "activation": live.get("id")}
	else:
		prog.erase("active")

# Reject an illegal intent AND ship the authoritative state so the client reconciles (reverts optimism).
func _campaign_reject(json_pid, p, reason) -> void:
	print("[CAMPAIGN] rejected: ", reason)
	json_gateway.send(json_pid, {"type": "campaign_error", "reason": reason, "state": p.campaign_state, "unlocks": p.unlocks})

func _ensure_campaign_keys(prog) -> void:
	if not (prog.get("flags") is Dictionary): prog["flags"] = {}
	if not (prog.get("visited") is Array): prog["visited"] = []
	if not (prog.get("completed") is Array): prog["completed"] = []
	if not (prog.get("pending_wins") is Array): prog["pending_wins"] = []
	if not (prog.get("vessel_loadout") is Array): prog["vessel_loadout"] = []

# pending_wins holds {activation, encounter} records (beat-scoped). Membership tests match BOTH fields so
# a win banked for one beat never satisfies a different beat reusing the same encounter id.
func _has_pending_win(pending, activation, encounter) -> bool:
	for w in pending:
		if w is Dictionary and w.get("activation") == activation and w.get("encounter") == encounter:
			return true
	return false

func _erase_pending_win(pending, activation, encounter) -> void:
	for i in range(pending.size() - 1, -1, -1):
		var w = pending[i]
		if w is Dictionary and w.get("activation") == activation and w.get("encounter") == encounter:
			pending.remove_at(i)

# Drop every banked win for a beat (used when abandoning it after a loss) so it re-fights from the top.
func _erase_beat_wins(pending, activation) -> void:
	for i in range(pending.size() - 1, -1, -1):
		var w = pending[i]
		if w is Dictionary and w.get("activation") == activation:
			pending.remove_at(i)

func _campaign_apply_effects(p, eff) -> void:
	if not (eff is Dictionary): return
	var prog = p.campaign_state
	_ensure_campaign_keys(prog)
	if "set_stage" in eff:
		prog["stage"] = eff["set_stage"]
	for f in eff.get("set_flags", []):
		prog["flags"][str(f)] = true
	for u in eff.get("unlocks", []):
		var uu = str(u)
		if uu.begins_with("char:"):
			var tok = uu.substr(5) + "_unlock"   # shared PvP unlock token
			if not (tok in p.unlocks):
				p.unlocks.append(tok)
				print("[CAMPAIGN] granted unlock: ", tok, " to ", p.username)
		elif uu.begins_with("ability:"):
			var ab = uu.substr(8)   # campaign-only vessel ability
			if not (prog.get("campaign_unlocked_abilities") is Array): prog["campaign_unlocked_abilities"] = []
			if not (ab in prog["campaign_unlocked_abilities"]): prog["campaign_unlocked_abilities"].append(ab)

func _campaign_enter(peer, json_pid) -> void:
	var p = get_player(peer)
	if not p:
		return json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
	if not (p.campaign_state is Dictionary) or not p.campaign_state.has("chapter"):
		p.campaign_state = Campaign.fresh_state("chapterX")
	var prog = p.campaign_state
	_ensure_campaign_keys(prog)
	# Entering (fresh, or re-entering after a loss/exit/reconnect) ALWAYS lands on the MAP at the last
	# node — we never auto-play a beat on enter. Starting a node's events requires clicking it
	# (campaign_arrive re-arms `active` + replays from the top; pending_wins lets that replay skip a
	# battle step already won). So clear any stale in-progress beat and tell the client not to arrive.
	prog.erase("active")
	resave_player(p)
	_send_campaign_state(json_pid, p, "enter", false)

func _campaign_travel(peer, json_pid, to) -> void:
	var p = get_player(peer)
	if not p:
		return json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
	var prog = p.campaign_state
	if not (prog is Dictionary) or not prog.has("chapter"):
		return _campaign_reject(json_pid, p, "no campaign in progress")
	var ch = Campaign.chapter(prog.get("chapter"))
	var cur = Campaign.node(ch, prog.get("node"))
	var target = Campaign.node(ch, to)
	if cur == null or target == null or not (to in cur.get("edges", [])):
		return _campaign_reject(json_pid, p, "invalid travel target")
	if not Campaign.node_open(target, prog):
		return _campaign_reject(json_pid, p, "that path isn't open yet")
	_ensure_campaign_keys(prog)
	prog["node"] = to
	if not (to in prog["visited"]): prog["visited"].append(to)
	_campaign_set_active(prog)   # arriving at the node starts its beat (main or idle)
	resave_player(p)
	_send_campaign_state(json_pid, p, "travel", true)

func _campaign_complete(peer, json_pid, node_id, activation_id) -> void:
	var p = get_player(peer)
	if not p:
		return json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
	var prog = p.campaign_state
	if not (prog is Dictionary) or prog.get("node") != node_id:
		return _campaign_reject(json_pid, p, "not at that node")
	# Must match the beat the player is currently inside (set on arrival), not a fresh re-resolve.
	var active = prog.get("active")
	if not (active is Dictionary) or active.get("node") != node_id or active.get("activation") != activation_id:
		return _campaign_reject(json_pid, p, "no such active beat")
	var ch = Campaign.chapter(prog.get("chapter"))
	var live = Campaign.activation_by_id(Campaign.node(ch, node_id), activation_id)
	if live == null:
		return _campaign_reject(json_pid, p, "unknown activation")
	_ensure_campaign_keys(prog)
	# Every battle step must have been WON FOR THIS BEAT — a pending_win record {activation, encounter}
	# matching this activation (persisted, survives reconnect). Beat-scoped so a win banked for another
	# beat that reuses the same encounter id can't satisfy this gate. Then consume the matched records.
	for step in live.get("sequence", []):
		if step is Dictionary and "battle" in step:
			var enc = str(step["battle"])
			if not _has_pending_win(prog["pending_wins"], activation_id, enc):
				return _campaign_reject(json_pid, p, "battle not completed: " + enc)
	for step in live.get("sequence", []):
		if step is Dictionary and "battle" in step:
			_erase_pending_win(prog["pending_wins"], activation_id, str(step["battle"]))
	if live.get("once", true) and not (activation_id in prog["completed"]):
		prog["completed"].append(activation_id)
	_campaign_apply_effects(p, live.get("on_complete", {}))
	prog.erase("active")   # beat consumed; the player is back on the map
	resave_player(p)
	_send_campaign_state(json_pid, p, "complete")

func _campaign_choice(peer, json_pid, scene_id, line_idx, choice_idx) -> void:
	var p = get_player(peer)
	if not p:
		return json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
	var prog = p.campaign_state
	if not (prog is Dictionary) or not prog.has("chapter"):
		return _campaign_reject(json_pid, p, "no campaign in progress")
	# The chosen scene must be reachable within the beat the player is currently inside.
	var active = prog.get("active")
	if not (active is Dictionary):
		return _campaign_reject(json_pid, p, "no active beat")
	var ch = Campaign.chapter(prog.get("chapter"))
	var live = Campaign.activation_by_id(Campaign.node(ch, active.get("node")), active.get("activation"))
	if live == null or not (scene_id in Campaign.activation_scenes(live)):
		return _campaign_reject(json_pid, p, "invalid choice context")
	var scene = Campaign.dialogue_scene(scene_id)
	var lines = scene.get("lines", []) if scene is Dictionary else []
	if line_idx < 0 or line_idx >= lines.size():
		return _campaign_reject(json_pid, p, "bad line index")
	var choices = lines[line_idx].get("choices", [])
	if choice_idx < 0 or choice_idx >= choices.size():
		return _campaign_reject(json_pid, p, "bad choice index")
	_campaign_apply_effects(p, choices[choice_idx])
	resave_player(p)
	_send_campaign_state(json_pid, p, "choice")

# Re-select the CURRENT node to (re)start its beat — used to replay a beat after a battle loss (see
# _campaign_abandon) or to trigger a pending beat the player is standing on. Sets `active` from a fresh
# resolve and tells the client to arrive.
func _campaign_arrive(peer, json_pid, node_id) -> void:
	var p = get_player(peer)
	if not p:
		return json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
	var prog = p.campaign_state
	if not (prog is Dictionary) or prog.get("node") != node_id:
		return _campaign_reject(json_pid, p, "not at that node")
	_ensure_campaign_keys(prog)
	_campaign_set_active(prog)
	resave_player(p)
	# arrive true only if there's actually a beat to play (idle-less node → active erased → no arrive).
	_send_campaign_state(json_pid, p, "arrive", prog.get("active") is Dictionary)

# Abandon the in-progress beat after a LOST battle: clear `active` (so the beat is NOT consumed and the
# player is dropped back onto the map at the node) and discard any wins banked for this beat's battle
# steps (so a partially-won multi-battle beat re-fights from the top when re-selected). Does NOT apply
# on_complete or mark the activation completed.
func _campaign_abandon(peer, json_pid, node_id, activation_id) -> void:
	var p = get_player(peer)
	if not p:
		return json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
	var prog = p.campaign_state
	if not (prog is Dictionary) or not prog.has("chapter"):
		return _campaign_reject(json_pid, p, "no campaign in progress")
	_ensure_campaign_keys(prog)
	_erase_beat_wins(prog["pending_wins"], activation_id)   # drop this beat's banked wins so it re-fights from the top
	prog.erase("active")
	resave_player(p)
	_send_campaign_state(json_pid, p, "abandon", false)

# Set the campaign PARTY (3 distinct path_names) from the chapter's allowed pool = roster_grants + the
# Vessel + any character the player has unlocked in PvP. Server-authoritative (start_campaign_battle
# reads campaign_state.party), so it's validated here rather than trusting the client's team.
func _campaign_set_party(peer, json_pid, party) -> void:
	var p = get_player(peer)
	if not p:
		return json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
	var prog = p.campaign_state
	if not (prog is Dictionary) or not prog.has("chapter"):
		return _campaign_reject(json_pid, p, "no campaign in progress")
	if not (party is Array) or party.size() != 3 or _has_dupes(party):
		return _campaign_reject(json_pid, p, "party must be 3 distinct characters")
	if not ("vessel" in party):
		# The Vessel is the campaign avatar — without it, the vessel loadout + unlocks would be inert.
		return _campaign_reject(json_pid, p, "your team must include the Vessel")
	var ch = Campaign.chapter(prog.get("chapter"))
	var pool := ["vessel"]   # the Vessel is always pickable (the campaign avatar)
	if ch != null:
		for c in ch.get("roster_grants", []):
			if not (str(c) in pool): pool.append(str(c))
	for member in party:
		var m := str(member)
		var ok = (m in pool) or ((m + "_unlock") in p.unlocks) or ("all_unlock" in p.unlocks)
		if not ok:
			return _campaign_reject(json_pid, p, "character not available: " + m)
	prog["party"] = [str(party[0]), str(party[1]), str(party[2])]
	resave_player(p)
	_send_campaign_state(json_pid, p, "party")

# Set the Vessel's skill loadout (1–4 distinct keys) from its available pool + campaign-unlocked keys.
# Empty/unset falls back to the 4 defaults (see vessel.gd _resolve_kit_keys).
func _campaign_set_vessel_skills(peer, json_pid, skills) -> void:
	var p = get_player(peer)
	if not p:
		return json_gateway.send(json_pid, {"type": "error", "reason": "not logged in"})
	var prog = p.campaign_state
	if not (prog is Dictionary) or not prog.has("chapter"):
		return _campaign_reject(json_pid, p, "no campaign in progress")
	if not (skills is Array) or skills.size() < 1 or skills.size() > 4 or _has_dupes(skills):
		return _campaign_reject(json_pid, p, "choose 1 to 4 distinct skills")
	var pool := ["vessel1", "vessel2", "vessel3", "vessel4", "vessel5", "vessel6"]   # keep in sync with vessel.gd AVAILABLE_ABILITY_KEYS
	if prog.get("campaign_unlocked_abilities") is Array:
		for a in prog["campaign_unlocked_abilities"]:
			pool.append(str(a))
	var clean := []
	for s in skills:
		var k := str(s)
		if not (k in pool):
			return _campaign_reject(json_pid, p, "skill not available: " + k)
		clean.append(k)
	prog["vessel_loadout"] = clean
	resave_player(p)
	_send_campaign_state(json_pid, p, "loadout")


func _is_bot_peer(peer_id) -> bool:
	return typeof(peer_id) == TYPE_INT and peer_id <= BOT_PEER_BASE


func _drive_bot_if_acting(nmatch) -> void:
	# Whenever the bot seat holds the turn, run its AI on the shadow and broadcast.
	# Called after each human turn / timeout and at match start (bot-first flip).
	#
	# Gated on the SEAT, not the match type: a bot can now be seated in a RANKED match
	# too (the 30s ranked fallback), and a type whitelist here would have left that bot
	# frozen on its turn until the clock ran out. The `while _is_bot_peer(acting_player)`
	# loop below is already the real condition — a match with no bot seat never enters it,
	# so this guard only needs to reject a dead Match.
	if not is_instance_valid(nmatch):
		return
	while is_instance_valid(nmatch) and nmatch.manager != null and not nmatch.manager.match_over and _is_bot_peer(nmatch.acting_player):
		# Stop the turn timer apply_input started for the bot's "turn"; the bot
		# acts after a short "thinking" pause, well inside the window.
		var timer = nmatch.get_node_or_null("Timer")
		if timer:
			timer.stop()
		# Pause before moving so the human can read the board. The "think" time scales with how much the
		# bot still has to consider (living characters) plus human-like jitter — no instant snap, no fixed
		# tell. (P6 — variable think-time.)
		await get_tree().create_timer(_bot_think_seconds(nmatch.manager)).timeout
		# The match may have ended / been cancelled, or the seat changed, during the pause.
		if not is_instance_valid(nmatch) or nmatch.manager == null or nmatch.manager.match_over or not _is_bot_peer(nmatch.acting_player):
			return
		# Surrender-if-behind (ULTRA bots only): concede a clearly-lost game rather than playing to the
		# bitter end, like a human typing /ff. Routes through the normal surrender path so the human wins
		# with FULL rating (P7). Gated on BOARD STATE (HP + deaths), never the policy score. (P6.)
		if _ultra_bot_should_surrender(nmatch):
			var bsess = get_session(nmatch.acting_player)
			if bsess != null:
				finalize_surrender(bsess)
			return
		await _run_shadow_bot_turn(nmatch.manager)
		# The bot's turn may have ended the match, in which case
		# handle_server_match_ended already broadcast the finale and tore it down.
		if not is_instance_valid(nmatch) or nmatch.manager == null or nmatch.manager.match_over:
			return
		# Hand the turn back to the human, broadcast the bot's turn, re-arm the timer. The bot acting
		# does NOT reset the human's AFK miss streak — a human who keeps letting their turns time out
		# against the bot keeps shaving their timer and eventually forfeits.
		nmatch.acting_player = nmatch.get_opponent(nmatch.acting_player)
		_broadcast_turn_result(nmatch)
		nmatch.start_turn_timer()


# --- P6 bot behaviours: variable think-time + surrender-if-behind -------------------------------------
# Think time grows with how many characters the bot still has to move (a busier turn "takes longer"),
# plus human jitter. The bot is the p2/enemy seat (see _run_shadow_bot_turn). Uses the UNSEEDED global RNG
# on purpose — think-time is server-side pacing, not part of the deterministic battle stream.
func _bot_think_seconds(mgr) -> float:
	var actors := 0
	var speed := 1.0
	if mgr != null and is_instance_valid(mgr):
		var acting = mgr.enemy if mgr.waiting_for_turn else mgr.player   # the seat about to move (bot-vs-bot alternates)
		if acting != null:
			for c in acting.team.characters:
				if not (c.dead or c.banished):
					actors += 1
			if acting.is_ultra_bot:
				speed = _ultra_bot_think_speed(acting)   # per-bot pacing personality (snappy .. deliberate)
	return _think_seconds_for(actors, speed)

# Pure: base grows with actor count, scaled by the per-bot speed, + jitter, clamped to a human-plausible band.
func _think_seconds_for(actors: int, speed: float = 1.0) -> float:
	var base := (2.5 + 1.3 * float(actors)) * speed      # ~3.8s at 1 actor, ~6.4s at 3 (before speed)
	return clampf(base + randf_range(0.0, 2.5) * speed, 2.5, 11.0)

# Per-turn probability an ULTRA bot concedes, from BOARD STATE ONLY (HP + living counts). Never the policy
# score — a score-based give-up caused the old STOP death-spiral. 0.0 while the game is still competitive.
func _surrender_pressure(bot_hp: int, bot_alive: int, hum_hp: int, hum_alive: int) -> float:
	if bot_alive <= 0:
		return 0.0
	var behind := hum_alive - bot_alive
	var hp_ratio := float(bot_hp) / float(maxi(hum_hp, 1))
	if behind >= 2 and hp_ratio < 0.35:
		return 0.6                              # down 2 characters and crushed on HP -> very likely concede
	if behind >= 2 and hp_ratio < 0.55:
		return 0.35                             # down 2 characters, clearly behind
	if behind >= 1 and bot_alive == 1 and hp_ratio < 0.4:
		return 0.3                              # last character standing, well behind
	return 0.0                                  # otherwise play it out

# True if the ULTRA bot on the acting seat should throw in the towel this turn. Ephemeral fallback bots
# never surrender (they play the throwaway game to the end).
func _ultra_bot_should_surrender(nmatch) -> bool:
	if not is_instance_valid(nmatch) or nmatch.manager == null:
		return false
	var acting = nmatch.acting_player
	var bot = nmatch.players.get(acting, null)
	if bot == null or not bot.is_ultra_bot:
		return false
	var hum = null
	for pid in nmatch.players:
		if pid != acting:
			hum = nmatch.players[pid]
			break
	if hum == null:
		return false
	var bot_hp := 0
	var bot_alive := 0
	for c in bot.team.characters:
		if not (c.dead or c.banished):
			bot_hp += int(c.health.hp)
			bot_alive += 1
	var hum_hp := 0
	var hum_alive := 0
	for c in hum.team.characters:
		if not (c.dead or c.banished):
			hum_hp += int(c.health.hp)
			hum_alive += 1
	return randf() < _surrender_pressure(bot_hp, bot_alive, hum_hp, hum_alive) * _ultra_bot_surrender_tilt(bot)


# --- P4: per-bot battle PERSONALITY --------------------------------------------------------------------------
# The 30 bots share ONE policy, so without this they'd all show the same target priorities, the same softmax
# temperature, the same energy-dumping, the same think-time and surrender timing — a fingerprintable "they all
# feel identical" tell. Each personality axis (skill, aggression, defense, thrift, speed, grit) is a stable,
# independent per-bot trait derived from the username, so a bot plays consistently but the fleet spreads out.
const ULTRA_BOT_TEMP_SHARP := 0.15    # low softmax temperature = tight, near-argmax play
const ULTRA_BOT_TEMP_SLOPPY := 0.85   # high temperature = loose, more mistakes

func _ultra_bot_trait(username: String, salt: String, lo: float, hi: float) -> float:
	return lo + (float(abs((username + "|" + salt).hash()) % 1000) / 999.0) * (hi - lo)

# Per-bot skill in [0,1] (0 sloppy .. 1 sharp): a stable personality baseline, nudged mildly by the bot's live
# rating so a higher-rated bot plays a touch sharper (the visible number loosely tracks how it actually plays).
func _ultra_bot_skill(bot) -> float:
	var s := _ultra_bot_trait(str(bot.username), "skill", 0.0, 1.0)
	var rating: float = float(bot.rank.get_rating()) if bot.rank != null else 0.0
	return clampf(s + clampf((rating - 1200.0) / 6000.0, -0.15, 0.20), 0.0, 1.0)

# The softmax temperature this bot pilots its turn with (sharp .. sloppy by skill).
func _ultra_bot_temperature(bot) -> float:
	return lerpf(ULTRA_BOT_TEMP_SLOPPY, ULTRA_BOT_TEMP_SHARP, _ultra_bot_skill(bot))

# A per-bot copy of the live tuning overlay with the STYLE knobs personalised: aggression/defense scale how
# much it favours harmful/helpful skills, energy_thrift how much it hoards energy. Deep-copies the global so
# any admin character-tuning still applies and the shared cache is never mutated.
func _ultra_bot_tuning(bot) -> Dictionary:
	var base = BattleManager._get_live_bot_tuning()
	var t: Dictionary = base.duplicate(true) if base is Dictionary else {}
	var g: Dictionary = t.get("global", {}) if t.get("global", null) is Dictionary else {}
	var u := str(bot.username)
	g["aggression"] = _ultra_bot_trait(u, "agg", 0.80, 1.25)
	g["defense"] = _ultra_bot_trait(u, "def", 0.80, 1.25)
	g["energy_thrift"] = _ultra_bot_trait(u, "thrift", 0.0, 0.30)
	t["global"] = g
	return t

# Per-bot think-time multiplier (0.6 = a snappy player, 1.5 = a deliberate one).
func _ultra_bot_think_speed(bot) -> float:
	return _ultra_bot_trait(str(bot.username), "speed", 0.6, 1.5)

# Per-bot surrender multiplier applied to _surrender_pressure (0.5 = a grinder who plays lost games out,
# 1.5 = quicker to concede).
func _ultra_bot_surrender_tilt(bot) -> float:
	return _ultra_bot_trait(str(bot.username), "grit", 0.5, 1.5)


func _run_shadow_bot_turn(mgr) -> void:
	# Run the bot directly on the authoritative shadow. The bot is on WHICHEVER seat holds the turn:
	# usually p2/enemy (human-vs-bot), but a BOT-vs-BOT game drives both seats in alternation, so resolve
	# the acting side from the shadow's waiting_for_turn (true => enemy/p2 acts, false => player/p1 acts).
	# For a human-vs-bot game the bot always acts with waiting_for_turn=true, so this is `mgr.enemy` exactly
	# as before — backward compatible. Energy for the acting team was pre-generated by wait_for_turn
	# mid-match, or is generated here on a bot-first opening. No display pacing on the server.
	var acting = mgr.enemy if mgr.waiting_for_turn else mgr.player
	# Mirror process_turn_package's latch handling. A human-vs-bot game routes the HUMAN's turn through
	# process_turn_package, which resets acting_energy_prepared every round; a BOT-vs-BOT game never does,
	# so without this the latch sticks true and the p2/enemy seat starves for energy from turn 2 (and a
	# p1-first seat double-generates on turn 1). Capture whether the acting team's energy was ALREADY
	# pre-generated (p2 via wait_for_turn -> prepare_acting_energy_if_needed; p1 via start_new_turn), then
	# reset the latch so next turn re-preps. Self-generate ONLY for a p2/enemy seat whose energy was not
	# already prepped (the bot-first opening) — a p1/player seat's energy always comes from start_new_turn,
	# so self-generating it would double it. This is byte-identical for existing human-vs-bot games.
	var skip_acting_gen: bool = mgr.acting_energy_prepared
	mgr.acting_energy_prepared = false
	if not skip_acting_gen and mgr.waiting_for_turn:
		mgr.generate_team_energy(acting.team, mgr.went_second)
	mgr.went_second = false
	mgr.paced_bot_actions = false
	# v3 policy when a promoted bot_policy.json exists; legacy contextual
	# model (5-mode mixture) until then. Difficulty = softmax temperature
	# from the hot-reloaded bot_tuning.json overlay.
	var policy = BattleManager._get_live_bot_policy()
	if policy != null:
		# Per-bot personality for ULTRA bots (skill temperature + style tuning); ephemeral fallback bots keep
		# the single global difficulty so a throwaway opponent still plays the configured tier.
		var temp: float = BattleManager._live_tier_temperature()
		var tuning = BattleManager._get_live_bot_tuning()
		if acting != null and acting.is_ultra_bot:
			temp = _ultra_bot_temperature(acting)
			tuning = _ultra_bot_tuning(acting)
		await acting.perform_turn_v3(mgr, policy, null, temp, tuning, false, true)
	else:
		await acting.perform_turn_contextual(mgr, BattleManager._get_live_bot_model(), 1)


# Shared cleanup for a ranked seating that Match.from_players refused. Both ranked entry points have
# identical needs, and getting either half wrong strands a player who did nothing wrong.
func _abort_ranked_seat(peer1, rp1, peer2, rp2, label: String) -> void:
	var busy1 := _in_live_match(peer1)
	var busy2 := _in_live_match(peer2)
	if rp1 == rp2 or (not busy1 and not busy2):
		# Same account on both seats, or a refusal we cannot attribute: drop BOTH rather than leave
		# an entry the 1 Hz gate sweep re-selects every second.
		busy1 = true
		busy2 = true
	# Scan-by-peer, NOT the bucket-indexed erase the success path uses: that indexes by the queued
	# DISPLAY PACKAGE's rank/tier and misses the entry entirely if the player's rating moved buckets
	# since they enqueued.
	if busy1:
		_erase_from_ranked_queue(peer1)
	if busy2:
		_erase_from_ranked_queue(peer2)
	# _gate_tick erased BOTH wait stamps before calling us. Whoever stays queued needs a fresh one or
	# _collect_ranked_candidates defaults their wait to "now" on every sweep, their computed wait is
	# 0.0 forever, and the rating bands can never widen for them again.
	if not busy1:
		_ranked_wait_start[peer1] = Time.get_ticks_msec()
		_start_ranked_bot_fallback(peer1)   # self-superseding; a duplicate arm is a no-op
	if not busy2:
		_ranked_wait_start[peer2] = Time.get_ticks_msec()
		_start_ranked_bot_fallback(peer2)
	print("[MATCH] ", label, " ABORTED — from_players refused: ", rp1.username, "(busy=", busy1, ") vs ", rp2.username, "(busy=", busy2, ")")


# A well-randomized match seed. RandomNumberGenerator.new() IS auto-seeded in Godot 4, but that behavior is
# undocumented and, drawing from a low-resolution time source, it CLUSTERS for instances created microseconds
# apart (a headless probe pulling 20000 in a tight loop saw only ~16k distinct seeds). randomize() pulls fresh
# OS entropy per call, so match seeds are always independent. The seed drives the ENTIRE match RNG — including
# the who-goes-first coin in Match.from_players (set_seed(seed) -> randi_range(0,1)) — and is persisted for
# replays, so a well-distributed seed is what keeps the opening coin a true 50/50.
func _fresh_match_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 6900000)


func start_ranked_match(player1_package, player2_package):
	# Ultra Bots: pin a lone bot to the p2/enemy seat so the existing bot-turn driver can run it.
	var _ordered = _order_seats_bot_second(player1_package, player2_package)
	player1_package = _ordered[0]
	player2_package = _ordered[1]
	var p1 = get_player(player1_package[0])
	var p2 = get_player(player2_package[0])
	
	# --- SAFETY CHECK ---
	if not p1 or not p2:
		
		# We must remove the invalid player from the queue, otherwise the valid player
		# will keep trying to match with this 'ghost' and get stuck forever.
		if not p1:
			ranked_queue[player1_package[1].rank][player1_package[1].tier].erase(player1_package)
			
		if not p2:
			ranked_queue[player2_package[1].rank][player2_package[1].tier].erase(player2_package)
			
		# We RETURN here so the valid player stays in the queue and waits for the next cycle
		return
	# --------------------

	var seed = _fresh_match_seed()

	var new_match = Match.from_players(player1_package[0], p1, player1_package[2], player2_package[0], p2, player2_package[2], seed, BattleManager.MatchType.RANKED)
	if new_match == null:
		_abort_ranked_seat(player1_package[0], p1, player2_package[0], p2, "Ranked match")
		return
	# Record who each player just faced. Between HUMANS this is inert (back-to-back rematches are allowed,
	# owner 2026-08-15), but _best_gated_ranked_pair DOES consume it for ULTRA bots (owner 2026-08-16): an
	# ultra bot won't be re-paired with this opponent next sweep. Recorded ONLY now that from_players has
	# confirmed the seat; persisted with the rest of the Player at match end.
	p1.last_ranked_opponent = str(p2.username)
	p2.last_ranked_opponent = str(p1.username)
	new_match.timeout_current_player.connect(handle_timeout)
	new_match.server_match_ended.connect(handle_server_match_ended)
	new_match.match_over.connect(match_ended)
	add_child(new_match)
	new_match.begin_match()
	new_match.start_turn_timer()

	get_session(player1_package[0]).current_match = new_match
	get_session(player2_package[0]).current_match = new_match

	var p1_first = new_match.player_goes_first(player1_package[0])
	send_to_peer(player1_package[0], "receive_ranked_match", {"opponent": player2_package[1], "opponent_team": player2_package[2], "first_turn": p1_first, "seed": seed, "canonical_role": 0})
	send_to_peer(player2_package[0], "receive_ranked_match", {"opponent": player1_package[1], "opponent_team": player1_package[2], "first_turn": not p1_first, "seed": seed, "canonical_role": 1})
	# Drain the shadow's initial events so the acting client sees turn-1 energy
	# before submitting. See start_private_match for details.
	_broadcast_turn_result(new_match)
	ranked_matches.append(new_match)

	# Standard cleanup for successful match
	ranked_queue[player1_package[1].rank][player1_package[1].tier].erase(player1_package)
	ranked_queue[player2_package[1].rank][player2_package[1].tier].erase(player2_package)
	# Also drop them from the QUICK queue. A player sitting in both had a pending quick bot-fallback
	# timer that would otherwise fire mid-ranked-game and seat them into a second match (see
	# start_private_match, which does the same for the same reason).
	queued_players.erase(player1_package[0])
	queued_players.erase(player2_package[0])
	print("[MATCH] Ranked match started: ", p1.username, " vs ", p2.username, " (seed=", seed, ")")
	# If the bot holds the opening turn, drive it now. (After each HUMAN turn the bot is re-driven for
	# free by _process_turn_input / the timeout path, which call _drive_bot_if_acting.) No-op unless a
	# seat is a bot, so human-vs-human is unaffected.
	_drive_bot_if_acting(new_match)


# Ranked draft: match two players, create the Match with empty teams, run the
# ban/pick draft, then hand off to the battle (see _start_drafted_battle).
func start_ranked_draft(player1_package, player2_package):
	var p1 = get_player(player1_package[0])
	var p2 = get_player(player2_package[0])
	if not p1 or not p2:
		if not p1:
			ranked_queue[player1_package[1].rank][player1_package[1].tier].erase(player1_package)
		if not p2:
			ranked_queue[player2_package[1].rank][player2_package[1].tier].erase(player2_package)
		return

	var mseed = _fresh_match_seed()
	# Empty teams + draft_mode=true so from_players skips team-building.
	var new_match = Match.from_players(player1_package[0], p1, [], player2_package[0], p2, [], mseed, BattleManager.MatchType.RANKED, true)
	# This function currently has NO callers (_gate_tick always uses start_ranked_match), but it is the
	# one call site that passes draft_mode=true — the clear-WITHOUT-recruit shape that produces the
	# empty-board symptom outright. Guarded so re-enabling it can never reintroduce the bug.
	if new_match == null:
		_abort_ranked_seat(player1_package[0], p1, player2_package[0], p2, "Ranked draft")
		return
	new_match.timeout_current_player.connect(handle_timeout)
	new_match.server_match_ended.connect(handle_server_match_ended)
	new_match.match_over.connect(match_ended)
	new_match.draft_state_changed.connect(_broadcast_draft_update)
	new_match.draft_completed.connect(_start_drafted_battle)
	add_child(new_match)
	get_session(player1_package[0]).current_match = new_match
	get_session(player2_package[0]).current_match = new_match
	ranked_matches.append(new_match)

	new_match.start_draft()
	var pool = new_match.draft_pool
	var first_role = new_match.draft_role_of(new_match.draft_first_picker)
	send_to_peer(player1_package[0], "draft_start", {"opponent": player2_package[1], "pool": pool, "my_role": 0, "first_picker_role": first_role, "max_bans": 3, "phase": "BAN", "phase_seconds": 60, "deadline_unix": new_match.draft_deadline_unix})
	send_to_peer(player2_package[0], "draft_start", {"opponent": player1_package[1], "pool": pool, "my_role": 1, "first_picker_role": first_role, "max_bans": 3, "phase": "BAN", "phase_seconds": 60, "deadline_unix": new_match.draft_deadline_unix})

	ranked_queue[player1_package[1].rank][player1_package[1].tier].erase(player1_package)
	ranked_queue[player2_package[1].rank][player2_package[1].tier].erase(player2_package)
	# Same reason as start_ranked_match: clear any quick-queue entry so its pending bot-fallback
	# timer can't seat these players into a second match mid-draft.
	queued_players.erase(player1_package[0])
	queued_players.erase(player2_package[0])
	print("[DRAFT] Ranked draft started: ", p1.username, " vs ", p2.username, " (seed=", mseed, ", first_picker=", new_match.draft_first_picker, ")")


# Ship each player their per-peer draft snapshot (opponent bans hidden until reveal).
func _broadcast_draft_update(nmatch):
	if nmatch == null or not is_instance_valid(nmatch):
		return
	for client_peer in nmatch.players.keys():
		var expected = nmatch.get_expected_username(client_peer)
		if client_peer in peer_map and expected != null and peer_map[client_peer] == expected:
			send_to_peer(client_peer, "draft_update", nmatch.draft_state_for(client_peer))


# Draft complete -> spin up the shadow battle with the drafted teams and send the
# usual receive_ranked_match handoff. The second picker (acting_player) goes first.
func _start_drafted_battle(nmatch):
	if nmatch == null or not is_instance_valid(nmatch):
		return
	nmatch.begin_match()
	nmatch.start_turn_timer()
	var keys = nmatch.players.keys()
	var peer1 = keys[0]
	var peer2 = keys[1]
	var p1_first = nmatch.player_goes_first(peer1)
	var p1_pkg = nmatch.players[peer1].display_package()
	var p2_pkg = nmatch.players[peer2].display_package()
	send_to_peer(peer1, "receive_ranked_match", {"opponent": p2_pkg, "opponent_team": nmatch.picks[peer2].duplicate(), "first_turn": p1_first, "seed": nmatch.seed, "canonical_role": 0})
	send_to_peer(peer2, "receive_ranked_match", {"opponent": p1_pkg, "opponent_team": nmatch.picks[peer1].duplicate(), "first_turn": not p1_first, "seed": nmatch.seed, "canonical_role": 1})
	_broadcast_turn_result(nmatch)
	print("[DRAFT] Draft complete — battle starting: ", nmatch.players[peer1].username, " vs ", nmatch.players[peer2].username)




func send_hero_ban(character):
	rpc_id(1, "receive_hero_ban_communication", multiplayer.get_unique_id(), character.character_name)

	

func send_hero_pick(character):
	rpc_id(1, "receive_hero_pick_communication", multiplayer.get_unique_id(), character.character_name)


func send_turn_input(input):
	rpc_id(1, "submit_turn_input", 0, input)

# Phase 2 shadow validation: client wraps its post-turn hash in an RPC back
# to the server. The server matches it against its own shadow hash.
func send_state_hash(match_id, turn_number, state_hash):
	rpc_id(1, "report_state_hash", match_id, turn_number, state_hash)


func _prune_match_history(hist) -> Array:
	var cutoff := int(Time.get_unix_time_from_system()) - 604800   # 7 days in seconds
	var kept := []
	for e in hist:
		if e is Dictionary and int(e.get("date", 0)) >= cutoff:
			kept.append(e)
	if kept.size() > 100:
		kept = kept.slice(-100)
	return kept

# Append one entry to a player's recent-match history (newest last). Called only from
# handle_server_match_ended for non-bot players; persisted by the resave there.
func _record_match_entry(subject, opponent_name, won, mode, my_team, opp_team, match_uid):
	subject.match_history.append({
		"result": "win" if won else "loss",
		"opponent": str(opponent_name),
		"mode": mode,
		"my_team": my_team,
		"opp_team": opp_team,
		"match_uid": match_uid,
		"date": int(Time.get_unix_time_from_system()),
	})
	subject.match_history = _prune_match_history(subject.match_history)

# --- REPLAY PERSISTENCE (P3) ---
# Write the finished match's replay to replays/<match_uid>.replay as ONE line of JSON
# (MatchReplayLog.to_dict()). Only real PvP matches are kept: BOT (practice AND quick-queue
# fallback) and CAMPAIGN games are skipped. Participants fetch via "replay_fetch" (D3);
# _sweep_replays enforces retention (D4).
func _persist_replay(nmatch) -> void:
	if nmatch.replay_log == null:
		return
	if nmatch.match_type == BattleManager.MatchType.BOT or nmatch.match_type == BattleManager.MatchType.CAMPAIGN:
		return
	if not DirAccess.dir_exists_absolute(REPLAY_DIR.trim_suffix("/")):
		DirAccess.make_dir_absolute(REPLAY_DIR.trim_suffix("/"))
	var path := REPLAY_DIR + str(nmatch.match_uid) + ".replay"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("[REPLAY] Could not write ", path, " (err ", FileAccess.get_open_error(), ")")
		return
	f.store_line(JSON.stringify(nmatch.replay_log.to_dict()))
	print("[REPLAY] Persisted ", path, " (", nmatch.replay_log.turns.size(), " turns)")

# Retention sweep (D4): delete replay files whose leading YYYYMMDD (the match_uid is
# "YYYYMMDD_<match_id>_<rand>") is older than REPLAY_RETENTION_DAYS, then if still over
# REPLAY_MAX_FILES delete oldest-by-prefix first. Runs at boot and daily (see _ready).
func _sweep_replays() -> void:
	if not DirAccess.dir_exists_absolute(REPLAY_DIR.trim_suffix("/")):
		return
	var files := []
	for file_name in DirAccess.get_files_at(REPLAY_DIR.trim_suffix("/")):
		if str(file_name).ends_with(".replay"):
			files.append(str(file_name))
	# Cutoff as a comparable YYYYMMDD int, derived from unix time so month/year rollovers are safe.
	var cutoff_dict := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) - REPLAY_RETENTION_DAYS * 86400)
	var cutoff := int(cutoff_dict.get("year", 0)) * 10000 + int(cutoff_dict.get("month", 0)) * 100 + int(cutoff_dict.get("day", 0))
	var expired := 0
	var kept := []
	for file_name in files:
		var stamp := int(str(file_name).get_slice("_", 0))   # leading YYYYMMDD; 0 for malformed names (kept)
		if stamp > 0 and stamp < cutoff:
			DirAccess.remove_absolute(REPLAY_DIR + file_name)
			expired += 1
		else:
			kept.append(file_name)
	var overflow := 0
	if kept.size() > REPLAY_MAX_FILES:
		# The fixed-width YYYYMMDD prefix sorts lexicographically -> oldest-by-prefix first
		# (order within a single day is arbitrary, accepted).
		kept.sort()
		while kept.size() > REPLAY_MAX_FILES:
			DirAccess.remove_absolute(REPLAY_DIR + kept.pop_front())
			overflow += 1
	print("[REPLAY] Sweep: ", files.size(), " file(s), ", expired, " expired, ", overflow, " over-cap, ", kept.size(), " kept")

## Where a player sits on the ladder right now. rank/rank_tier are derived getters over the rating,
## so this is only meaningful at the instant it is taken.
func _rank_snapshot(p) -> Dictionary:
	var r: int = int(p.rank.get_rating())
	var t: Array = Rank.tier_for_rating(r)
	return {"rating": r, "rank": int(t[0]), "tier": int(t[1])}


## Post-game ladder movement for one human player: both rating endpoints, both division endpoints,
## and whether that crossed a division line. The client renders it verbatim — it derives nothing, so
## a reconnect or a page reload mid-match cannot lose the "before" half of the comparison.
##
## Promotion/demotion is one comparison because rank*DIVISIONS + tier is monotonic up the ladder
## (division 1 is the WORST inside a rank, 4 the best — see Rank.DIVISIONS).
func _send_ranked_result(p, before: Dictionary, won: bool) -> void:
	if p == null or not (p.username in sessions):
		return
	var sess = sessions[p.username]
	if not (sess.peer_id in peer_map) or not _is_json_peer(sess.peer_id):
		return
	var after := _rank_snapshot(p)
	var pos_before: int = int(before["rank"]) * Rank.DIVISIONS + int(before["tier"])
	var pos_after: int = int(after["rank"]) * Rank.DIVISIONS + int(after["tier"])
	send_to_peer(sess.peer_id, "ranked_result", {
		"won": won,
		"rating_before": int(before["rating"]),
		"rating_after": int(after["rating"]),
		"delta": int(after["rating"]) - int(before["rating"]),
		"rank_before": int(before["rank"]), "tier_before": int(before["tier"]),
		"rank_after": int(after["rank"]), "tier_after": int(after["tier"]),
		"promoted": pos_after > pos_before,
		"demoted": pos_after < pos_before,
		"rank_changed": int(after["rank"]) != int(before["rank"]),
	})


func handle_server_match_ended(nmatch, winner_peer_id):
	if not is_instance_valid(nmatch):
		return
	var winner = nmatch.players.get(winner_peer_id, null)
	var loser_peer_id = nmatch.get_opponent(winner_peer_id)
	var loser = nmatch.players.get(loser_peer_id, null) if loser_peer_id != null else null
	if winner == null or loser == null:
		print("[MATCH END] Missing winner/loser on match ", nmatch.match_id, " — aborting bookkeeping")
		match_ended(nmatch)   # STILL tear down: skipping this leaked the match (live turn timer) and left
							  # sessions[username].current_match bound to a dead match
		return

	print("[MATCH END] Match ", nmatch.match_id, " ended: ", winner.username, " beat ", loser.username, " (type=", nmatch.match_type, ")")

	# A bot seat (synthetic, peer-less Player) is never ranked, AP-credited,
	# bountied, or saved — only the human side gets rewards.
	var winner_is_bot = winner.bot_player
	var loser_is_bot = loser.bot_player
	# Ultra Bots (P7): a PERSISTENT ultra bot moves REAL rating/records and PERSISTS like a human; only the
	# EPHEMERAL 30s-fallback bot keeps the capped/scaled/skip/free treatment. The *_is_ephemeral predicates
	# below gate the "treat as a throwaway" sites (rating cap/scale, rating award to the seat, match_history,
	# resave). The raw *_is_bot flags stay for the sites that exclude ANY bot seat (no AP to the bot itself,
	# no bounty/mastery/char-stats for a bot's synthetic team, no client frames to the socket-less bot).
	var winner_is_ephemeral = winner.is_ephemeral_bot()
	var loser_is_ephemeral = loser.is_ephemeral_bot()

	# Campaign encounters are single-player PvE: NO rank / AP / bounty / mastery / stats side
	# effects (win/loss must never touch the PvP account). The battle result reaches the client
	# via the MATCH_ENDED wire event; campaign progression + rewards are granted separately in the
	# campaign message handlers (server-validated, bounty-style). Push the final state, then tear down
	# EXPLICITLY via match_ended() below — match_over is only emitted by cancel_match/_forfeit_afk_player,
	# so it never fires for a normally-ended battle.
	if nmatch.match_type == BattleManager.MatchType.CAMPAIGN:
		print("[CAMPAIGN] Match ", nmatch.match_id, " ended (winner_is_bot=", winner_is_bot, ") — skipping all PvP bookkeeping")
		# Record the human's win in the PERSISTED pending_wins (survives a reconnect, unlike a session-scoped
		# array), SCOPED to the beat (activation) it belongs to — so a win for one beat can't satisfy a
		# different beat that happens to reuse the same encounter id. Verified + consumed in _campaign_complete.
		if not winner_is_bot and nmatch.campaign_encounter != "" and winner.campaign_state is Dictionary:
			_ensure_campaign_keys(winner.campaign_state)
			var win_rec = {"activation": nmatch.campaign_activation, "encounter": nmatch.campaign_encounter}
			if not _has_pending_win(winner.campaign_state["pending_wins"], nmatch.campaign_activation, nmatch.campaign_encounter):
				winner.campaign_state["pending_wins"].append(win_rec)
				resave_player(winner)
		# Site-usage metrics: campaign encounters are real play, so they belong in the engagement
		# numbers even though they touch no PvP bookkeeping. Recorded here because this branch
		# returns before the shared match-end recorder below. The human is whichever seat is not
		# the bot-driven shadow.
		if metrics_db != null:
			var cmp_ts := int(Time.get_unix_time_from_system())
			var cmp_mid := str(nmatch.match_uid)
			if not winner_is_bot:
				metrics_db.record_event("match", winner.username, cmp_ts, "campaign", cmp_mid)
			if not loser_is_bot:
				metrics_db.record_event("match", loser.username, cmp_ts, "campaign", cmp_mid)
		_send_post_match_player_updates(nmatch)
		_broadcast_turn_result(nmatch)
		match_ended(nmatch)   # MUST be explicit: the old comment claimed teardown rides the
							  # match_over -> match_ended signal, but match_over is only ever emitted by
							  # cancel_match()/_forfeit_afk_player(). A normally-ended campaign battle
							  # therefore leaked forever, keeping a live turn timer + a bound session.
		return

	# NOTE (owner 2026-08-15): bot-vs-bot games are NO LONGER an exhibition — Ultra bots track rating/record/
	# AP like players, INCLUDING from games against other Ultra bots and against ephemeral fallback bots. So a
	# two-bot game falls through to the normal ranked bookkeeping below, where the is_ephemeral gates give the
	# right treatment: ultra-vs-ultra moves both bots' rating FULLY (vs_bot false); ultra-vs-ephemeral moves
	# the ultra bot's rating CAPPED (vs_bot true, like a player farming a bot) and the ephemeral side is
	# skipped. Char-usage stats / mastery / match archive stay bot-free via the raw bot_player gates.

	# Rank adjustments — all multiplayer modes except PRIVATE. Practice (explicit Bot Match queue) games
	# award NO win/loss: the record is untouched, so the queue plays like a practice mode.
	# W/L record + rating: RANKED ONLY. Quick Match no longer produces wins or losses (and therefore
	# doesn't move the streak either) — it's a pure-AP casual queue now, so Quick, its bot fallback,
	# practice Bot games and Private all leave the record untouched.
	if nmatch.match_type == BattleManager.MatchType.RANKED:
		var winner_rating = loser.rank.get_rating()
		var loser_rating = winner.rank.get_rating()
		# A ranked game against an EPHEMERAL fallback bot still counts as a real win/loss, but must barely
		# move the ladder — otherwise a fixed 30s wait would be the cheapest way to climb. An ULTRA bot game
		# is a FULL ranked game (uncapped/unscaled) — is_ephemeral is false for it.
		var vs_bot: bool = winner_is_ephemeral or loser_is_ephemeral
		# Snapshot BEFORE the mutation. Rating is changed IN PLACE by add_win/add_loss and rank/tier
		# are derived getters over it, so once those calls run there is no way to recover where the
		# player started — the delta has to be captured here or not at all.
		var w_before := _rank_snapshot(winner)
		var l_before := _rank_snapshot(loser)
		# Ephemeral gate (not raw bot): an ULTRA bot's own rank ALSO moves (it climbs/falls like a player),
		# and vs_bot is false in a human-vs-ultra game so BOTH sides take the full uncapped branch.
		if not winner_is_ephemeral:
			if vs_bot:
				# A ranked win over an ephemeral bot: base award, capped low (min(award, cap)), then floored at
				# the +/-10 ladder minimum inside add_win. opponent_rating is ignored (rank-disparity scaling gone).
				winner.rank.add_win(nmatch.match_type, winner.rank.get_rating(), 1.0, RANKED_BOT_RATING_CAP)
			else:
				winner.rank.add_win(nmatch.match_type, winner_rating, 1.0)
		if not loser_is_ephemeral:
			loser.rank.add_loss(nmatch.match_type, loser_rating, RANKED_BOT_LOSS_RATING_SCALE if vs_bot else 1.0, RANKED_BOT_RATING_CAP if vs_bot else -1.0)
		# Authoritative post-game numbers, straight from the objects that just moved. The client used
		# to derive this itself from a rating cached at queue time, which was lost on any reconnect
		# or page reload; this survives both because it carries both endpoints.
		if not winner_is_bot:
			_send_ranked_result(winner, w_before, true)
		if not loser_is_bot:
			_send_ranked_result(loser, l_before, false)
		# Clan W/L counts any ladder match between two humans who are NOT in the same clan — the
		# opponent no longer has to be in a clan themselves. Each side updates its OWN record only if
		# it has one, so a clan-vs-Clanless game moves exactly one record. Two Clanless players match
		# on the "same clan" test ("Clanless" == "Clanless") and move nothing, which is correct.
		# (Only RANKED reaches here now that Quick records nothing, so clan W/L is ranked-only. Any
		# bot seat fails the non-bot gate.)
		# Ephemeral gate (owner 2026-08-15): an ULTRA bot game DOES move the human's clan W/L — otherwise a
		# clan player could spot a bot by its games never touching their clan record. Ultra bots are
		# Clanless, so only the human's clan moves; do NOT put an ultra bot in a real human clan or it pads.
		if clan_record_counts(winner.clan, loser.clan, winner_is_ephemeral, loser_is_ephemeral):
			if winner.clan in clans:
				clans[winner.clan].wins += 1
				save_clan(clans[winner.clan])   # persist — the old path only bumped it in memory
			if loser.clan in clans:
				clans[loser.clan].losses += 1
				save_clan(clans[loser.clan])

	# AP — ULTRA bots earn AP like players (ephemeral gates); only the throwaway ephemeral fallback bot is
	# never credited (it has no .dat and is freed). The reduced "vs bot" AP amount applies when an EPHEMERAL
	# bot is in the game (human/ultra vs ephemeral); an ultra-vs-human or ultra-vs-ultra game pays full AP.
	var ap_vs_bot: bool = winner_is_ephemeral or loser_is_ephemeral
	if not winner_is_ephemeral:
		var winner_ap = _calculate_ap_gain(nmatch.match_type, true, nmatch.practice_match, ap_vs_bot)
		winner.gain_ap(winner_ap)
		print("[AP] ", winner.username, " gained ", winner_ap, " AP")
	if not loser_is_ephemeral:
		var loser_ap = _calculate_ap_gain(nmatch.match_type, false, nmatch.practice_match, ap_vs_bot)
		loser.gain_ap(loser_ap)
		print("[AP] ", loser.username, " gained ", loser_ap, " AP")

	# Bounty progress — mirror battle_manager.end_match's winner-only rule.
	# Must run before resave_player / _send_post_match_player_updates so the
	# updated active_bounties get persisted and broadcast to the client.
	if nmatch.match_type != BattleManager.MatchType.PRIVATE and not winner_is_bot:
		var winner_team = winner.team.characters.map(func(c): return c.path_name)
		var loser_team = loser.team.characters.map(func(c): return c.path_name)
		winner.check_all_bounties(winner_team, loser_team)

	# Mastery XP. stats_manager.record_match deliberately skips BOT and PRIVATE
	# (no match record / aggregates / XP), so bot matches award per-character mastery here,
	# mirroring the old client-reported bot path.
	# Split on the BOT SEAT, not the match type: a ranked bot match must still pay out mastery,
	# but stats_manager.record_match would archive the bot's throwaway username and fold its
	# random team into global character win rates, so it refuses any match with a bot in it.
	# EPHEMERAL gate (owner 2026-08-16): a persistent ULTRA bot accrues mastery like a human so its
	# profile shows real per-character mastery (persisted by the resave below); only the throwaway
	# EPHEMERAL fallback bot (freed, no .dat) is skipped. A human in a bot game is non-ephemeral too,
	# so this still pays the human exactly as before.
	if winner_is_bot or loser_is_bot:
		if not winner_is_ephemeral:
			_award_bot_mastery(winner, true)
		if not loser_is_ephemeral:
			_award_bot_mastery(loser, false)
	else:
		stats_manager.record_match(nmatch, winner.username)

	# Recent-match history (server-authoritative): record Quick, Ranked, PRIVATE, and quick-queue bot
	# fallbacks — everything EXCEPT practice-Bot games (Campaign already returned early). Private shows
	# in history but still does NOT touch the W/L record or rating (those stay gated above). Bot seats
	# are never recorded. The resave_player calls just below persist it — no extra write.
	# Player.match_history is not client-writable (save-only).
	# Ephemeral gate: an ULTRA bot is a real ladder account, so its recent-match history is recorded too
	# (visible on its profile). Only the throwaway ephemeral bot is skipped.
	if not nmatch.practice_match:
		var mh_wteam = winner.team.characters.map(func(c): return c.path_name)
		var mh_lteam = loser.team.characters.map(func(c): return c.path_name)
		if not winner_is_ephemeral:
			_record_match_entry(winner, loser.username, true, nmatch.match_type, mh_wteam, mh_lteam, nmatch.match_uid)
		if not loser_is_ephemeral:
			_record_match_entry(loser, winner.username, false, nmatch.match_type, mh_lteam, mh_wteam, nmatch.match_uid)

	# CRUX: persist the ULTRA bot's moved rating/record/streak/history (an ephemeral bot has no .dat and is
	# freed, so it stays skipped). Without this the bots would look like they never move on reload.
	if not winner_is_ephemeral:
		resave_player(winner)
	if not loser_is_ephemeral:
		resave_player(loser)

	# "Upon finishing a game" — an ULTRA bot that just played waits a random spell before the rotation tick
	# re-queues it (stretched when no human is online), instead of snapping straight back into the queue.
	# This throttles bot-vs-bot churn most when nobody is watching. Ephemeral bots are freed, so skip them.
	if winner.is_ultra_bot:
		_ultra_bot_arm_requeue_delay(winner.username)
	if loser.is_ultra_bot:
		_ultra_bot_arm_requeue_delay(loser.username)

	# Character usage / win-rate aggregates (StatsDB). Quick + Ranked (PvP) and
	# Bot are tracked; Private is excluded per policy. Only a HUMAN-fielded team
	# counts as usage, so a bot seat's synthetic team is never recorded (in a
	# BOT match only the human side is a bot_player==false player).
	# A RANKED match against the queue's own bot is filed under BOT, not its match_type: the admin
	# dashboard buckets QUICK+RANKED as "pvp", and humans win the overwhelming majority of bot games,
	# so recording those picks as PvP would inflate the meta win rate of whatever they fielded with
	# results no human ever contested. (The quick-queue fallback is already MatchType.BOT.)
	if stats_db != null and nmatch.match_type != BattleManager.MatchType.PRIVATE:
		var usage_type = BattleManager.MatchType.BOT if (winner_is_bot or loser_is_bot) else nmatch.match_type
		# Every appearance is ALSO written as a dated row so the admin dashboard can window
		# stats by date. The aggregate above can only answer "all time" — its updated_at is
		# overwritten each write, so a period can never be subtracted back out of it.
		var played_at := int(Time.get_unix_time_from_system())
		var usage_mid := str(nmatch.match_uid)
		if not winner_is_bot and not StatsDB.is_excluded_user(winner.username):
			for c in winner.team.characters:
				stats_db.record_character(c.path_name, usage_type, true)
				stats_db.record_character_appearance(usage_mid, c.path_name, usage_type, true, played_at)
		if not loser_is_bot and not StatsDB.is_excluded_user(loser.username):
			for c in loser.team.characters:
				stats_db.record_character(c.path_name, usage_type, false)
				stats_db.record_character_appearance(usage_mid, c.path_name, usage_type, false, played_at)

	# Site-usage metrics: one row per HUMAN participant, sharing the match id. Same rows answer
	# "how many matches" (distinct ids) and "how many people played" (distinct usernames), which
	# is why the participant is the row and the match is only the key. Bot seats — ephemeral AND
	# Ultra — are excluded: they would otherwise appear as the most engaged players on the site.
	# A game containing an ephemeral fallback bot is filed under "bot" rather than the queue it
	# came from, matching how the character-usage bucket treats it.
	if metrics_db != null:
		var met_ts := int(Time.get_unix_time_from_system())
		var met_mode := "bot" if (winner_is_ephemeral or loser_is_ephemeral) else MetricsDB.mode_label(nmatch.match_type)
		var met_mid := str(nmatch.match_uid)
		if not winner_is_bot:
			metrics_db.record_event("match", winner.username, met_ts, met_mode, met_mid)
		if not loser_is_bot:
			metrics_db.record_event("match", loser.username, met_ts, met_mode, met_mid)

	# Push fresh player data to both clients (the bot has no peer → skipped)
	_send_post_match_player_updates(nmatch)

	# Drain whatever the recorder accumulated this turn (DAMAGE / DIED /
	# MATCH_ENDED / etc.) and broadcast it before the match scene tree is freed.
	_broadcast_turn_result(nmatch)

	# Persist the replay to server disk (P3): participants fetch it later via "replay_fetch".
	# The old pending_replays in-RAM stash is RETIRED — the var + its wipe_session erase stay
	# as harmless dead code feeding only the legacy Godot submit_replay_request RPC.
	if nmatch.replay_log != null:
		nmatch.replay_log.set_winner(winner.username)
	_persist_replay(nmatch)

	# Tear down the match (releases players, frees the node, clears sessions)
	match_ended(nmatch)


func _award_bot_mastery(player, won: bool) -> void:
	# Per-character mastery XP for a bot match (record_match skips BOT). Mirrors
	# the old _handle_bot_match_ending: win awards XP_PER_WIN, loss deducts
	# XP_PER_LOSS, for each of the player's own characters.
	for character in player.team.characters:
		var char_name = character.path_name
		if won:
			player.character_progress.award_xp(char_name, MasteryConfig.XP_PER_WIN)
		else:
			player.character_progress.deduct_xp(char_name, MasteryConfig.XP_PER_LOSS)

# Drain the shadow's event recorder, capture a snapshot, and ship them to
# both clients via apply_turn_result. Used by both the normal turn path
# (submit_turn_input) and the surrender / match-end paths so all clients
# observe state changes through the same wire format.
func _broadcast_turn_result(nmatch):
	if nmatch == null or not is_instance_valid(nmatch):
		return
	if nmatch.event_recorder == null or nmatch.manager == null:
		return
	var events_payload = nmatch.event_recorder.events.duplicate()
	nmatch.event_recorder.clear()
	var snapshot_payload = nmatch.manager.serialize_wire_snapshot()
	# acting_player was already flipped to the next player (apply_input) before this broadcast, so this
	# reflects whose turn it now is — and their (possibly AFK-penalized) turn duration.
	snapshot_payload["turn_timer"] = nmatch._timer_seconds_for(nmatch.acting_player)
	for client_peer in nmatch.players.keys():
		var expected = nmatch.get_expected_username(client_peer)
		if client_peer in peer_map and expected != null and peer_map[client_peer] == expected:
			send_to_peer(client_peer, "apply_turn_result", {"events": events_payload, "snapshot": snapshot_payload})
	# Spectators get a HIDDEN-INFO-STRIPPED copy (invisible-tagged events + non-"all"
	# visibility effects removed), built once per broadcast. Players above and the replay
	# below keep the FULL payloads (replays are participants-only — D3).
	if nmatch.spectators.size() > 0:
		var spec_events := _spectator_safe_events(events_payload)
		var spec_snapshot := _spectator_safe_snapshot(snapshot_payload)
		for spectator_peer in nmatch.spectators.keys():
			if spectator_peer in peer_map:
				send_to_peer(spectator_peer, "apply_turn_result", {"events": spec_events, "snapshot": spec_snapshot})
	if nmatch.replay_log != null and events_payload.size() > 0:
		nmatch.replay_log.record_turn(events_payload, snapshot_payload)

func remove_match(_match):
	quick_matches.erase(_match)
	ranked_matches.erase(_match)
	private_matches.erase(_match)
	bot_matches.erase(_match)
	# Also purge any invalid (freed) references that may have accumulated
	quick_matches = quick_matches.filter(func(m): return is_instance_valid(m))
	ranked_matches = ranked_matches.filter(func(m): return is_instance_valid(m))
	private_matches = private_matches.filter(func(m): return is_instance_valid(m))
	bot_matches = bot_matches.filter(func(m): return is_instance_valid(m))
	
	
func report_match_ending(package):
	rpc_id(1, "send_match_ending", multiplayer.get_unique_id(), package)

# ===========================================================================
# Phase 2 shadow validation
#
# Server drives a passive BattleManager per match. After every package the
# server processes, it asks both clients for their post-turn state hash and
# compares them to its own — any mismatch is logged as a desync sample so we
# can iterate on parity before going server-authoritative.
# ===========================================================================

func _advance_shadow(nmatch, package, _sender_peer_id):
	if nmatch == null or nmatch.manager == null:
		return
	if nmatch.manager.match_over:
		return
	nmatch.manager.receive_turn_package(package)
	nmatch.current_turn_number += 1
	var turn_n: int = nmatch.current_turn_number
	# Snapshot the state at this exact turn so a later desync dump shows the
	# state we were comparing against, not the post-advancement state.
	var state_snapshot = nmatch.manager.serialize_gamestate()
	var json_str = JSON.stringify(state_snapshot)
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(json_str.to_utf8_buffer())
	var server_hash: String = ctx.finish().hex_encode()
	nmatch.server_state_hashes[turn_n] = {"hash": server_hash, "state": state_snapshot}
	print("[HASH] Match ", nmatch.match_id, " turn ", turn_n, " server=", server_hash)
	# Phase 5: drain the event recorder and broadcast the new wire payload to
	# both clients in parallel with the existing relay path. The client-side
	# apply_turn_result is a no-op stub during Phase 5; Phase 6 wires it into
	# the local BattleManager. Drained events include any setup events that
	# fired during start_battle on the very first call.
	if nmatch.event_recorder != null:
		var events_payload = nmatch.event_recorder.events.duplicate()
		nmatch.event_recorder.clear()
		var snapshot_payload = nmatch.manager.serialize_wire_snapshot()
		print("[PROTOCOL] Match ", nmatch.match_id, " turn ", turn_n, " broadcasting ", events_payload.size(), " events")
		for client_peer in nmatch.players.keys():
			var expected_proto = nmatch.get_expected_username(client_peer)
			if client_peer in peer_map and expected_proto != null and peer_map[client_peer] == expected_proto:
				rpc_id(client_peer, "apply_turn_result", events_payload, snapshot_payload)
	# Ask both clients for their post-turn hash so we can compare. The reply
	# arrives asynchronously via report_state_hash. RPC ordering on the same
	# channel guarantees that process_turn_package (sent above) is delivered
	# before request_state_hash, so the opponent's manager has finished
	# processing this turn before being asked to hash.
	for client_peer in nmatch.players.keys():
		var expected = nmatch.get_expected_username(client_peer)
		if client_peer in peer_map and expected != null and peer_map[client_peer] == expected:
			rpc_id(client_peer, "request_state_hash", nmatch.match_id, turn_n)

# Server-side: a client has computed its post-turn hash and reported it back.
# Compare against the server's hash for that turn and log any mismatch.

func _dump_desync_sample(nmatch, turn_number, client_username, client_hash, server_hash, server_state):
	if not DirAccess.dir_exists_absolute("desync"):
		DirAccess.make_dir_absolute("desync")
	var filename = "desync/desync_" + str(nmatch.match_id) + "_" + str(turn_number) + ".json"
	var sample = {
		"match_id": nmatch.match_id,
		"turn": turn_number,
		"server_hash": server_hash,
		"client_hash": client_hash,
		"client_username": client_username,
		"server_state": server_state,
		"player_usernames": nmatch.get_player_usernames(),
	}
	var f = FileAccess.open(filename, FileAccess.WRITE)
	if f == null:
		print("[DESYNC] Failed to open ", filename, " for write")
		return
	f.store_string(JSON.stringify(sample, "\t"))
	f.close()
	print("[DESYNC] Wrote sample to ", filename)

func send_queue_cancellation():
	rpc_id(1, "cancel_queue", multiplayer.get_unique_id())

func _poll_open() -> bool:
	# Whether Nexus donations are currently open (bucket data/poll.dat = single int 0/1).
	# Defaults to open when the file is absent/unreadable.
	if not FileAccess.file_exists("bucket data/poll.dat"):
		return true
	var f = FileAccess.open("bucket data/poll.dat", FileAccess.READ)
	if f == null:
		return true
	return bool(int(f.get_line()))

# Periodic Nexus disk poll (see NEXUS_POLL_INTERVAL). Re-scans bucket data/ and broadcasts a fresh
# nexus_state to every client only when the roster actually changed on disk — or when the poll open/closed
# flag (poll.dat) was toggled externally — so an admin editing files on the box, or another service writing
# .dat files, shows up live without a restart and without spamming clients when nothing changed.
func _nexus_poll_tick() -> void:
	if bucket_handler == null:
		return
	var changed := bucket_handler.refresh_from_disk()
	var po := _poll_open()
	if po != _last_poll_open:
		_last_poll_open = po
		changed = true
	if changed:
		broadcast_nexus_state()

# Fan the current Nexus standings + poll state out to every connected client. Shared by the periodic poll
# and the admin close-round / scale ops so the payload shape stays in one place.
func broadcast_nexus_state() -> void:
	if json_gateway == null:
		return
	var ns = bucket_handler.get_all_bucket_sets()
	json_gateway.broadcast({"type": "nexus_state", "max": ns[0], "sets": ns[1], "poll_open": _poll_open()})

func check_poll_active():
	rpc_id(1, "poll_active", multiplayer.get_unique_id())

	

func notify_poll_state(poll_active):
	bucket_handler.get_poll_state(poll_active)

func cancel_queue(peer_id):
	var player = get_player(peer_id)
	if not player: return
	# One primitive for every dequeue path: clears both queues plus the private invite,
	# drops the wait stamp, and bumps the fallback generation so a pending coroutine
	# (an awaited SceneTreeTimer can't be cancelled) knows its queue session is over.
	# It also scans EVERY ranked bucket rather than only the player's current one, so a
	# rating change while queued can't strand the entry.
	_release_queues(peer_id)


func send_surrender():
	rpc_id(1, "process_surrender", multiplayer.get_unique_id())

func process_surrender(id):
	var session = get_session(id)
	if session:
		# PARTICIPANT GUARD (P4): a spectator also carries current_match — without this check a
		# spectator could send the raw "surrender" message and force-end (and decide!) a match they
		# are merely watching. Mirrors the handle_disconnect / wipe_session spectator detachment.
		var cm = session.current_match
		if cm != null and is_instance_valid(cm) and not (session.username in cm.get_player_usernames()):
			print("[MATCH] Ignoring surrender from spectator ", session.username)
			return
		print("[MATCH] Surrender from ", session.username)
		finalize_surrender(session)


func finalize_surrender(session: ServerSession):
	var current_match = session.current_match
	# Nullify immediately to prevent stale reference access
	session.current_match = null
	if not (current_match and is_instance_valid(current_match)):
		return

	# Look up opponent by username — session.peer_id may have been erased from
	# peer_map 60s ago after a disconnect-driven auto-surrender.
	var opponent_username = current_match.get_opponent_username(session.peer_id)

	if current_match.manager == null:
		# Surrender during ban/pick (no shadow yet) — fall back to plain cancel.
		current_match.cancel_match()
	else:
		# Resolve the winner peer_id by username so the auto-surrender path
		# (where session.peer_id may be stale) still routes to the right side.
		var winner_peer_id = null
		for pid in current_match.players:
			if opponent_username != null and current_match.players[pid].username == opponent_username:
				winner_peer_id = pid
				break

		if winner_peer_id == null:
			current_match.cancel_match()
		else:
			# Drive the shadow's natural end_match flow with the surrendering
			# side as the loser. end_match emits match_ended_event (recorded as
			# MATCH_ENDED) and match_ended (which fires server_match_ended →
			# handle_server_match_ended → bookkeeping + broadcast + teardown).
			# Phase 7.7: surrenders flow through the same wire path as natural
			# match ends; receive_surrender stays as a redundant notification
			# until Phase 10 collapses it into apply_turn_result.
			var p1_peer = current_match.players.keys()[0]
			var won_for_manager = (winner_peer_id == p1_peer)
			current_match.manager.end_match(won_for_manager)

	# Direct opponent notification — preserved until Phase 10 folds SURRENDER
	# into the apply_turn_result event stream.
	if opponent_username and opponent_username in sessions:
		var opponent_session = sessions[opponent_username]
		if opponent_session.status == ServerSession.ConnectionState.ONLINE:
			if opponent_session.peer_id in peer_map:
				send_to_peer(opponent_session.peer_id, "receive_surrender", {})

func request_png_image(url):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", image_request_completed)
	var error = http_request.request(url)

func image_request_completed(result, response_code, headers, body):
	return_texture.emit(body)

func update_cosmetics(player):
	rpc_id(1, "update_player_cosmetics", multiplayer.get_unique_id(), player.username, player.make_cosmetic_update())


func update_missions(player):
	rpc_id(1, "update_mission_progress", multiplayer.get_unique_id(), player.username, player.get_mission_delta())

	
	

func finalize_avatar_update(player):
	rpc_id(1, "update_player_cosmetics", multiplayer.get_unique_id(), player.username, player.save())
	

func check_latest_client_version(reroute=true):
	var version_package = [_version, OS.get_name()]
	rpc_id(1, "compare_versions", multiplayer.get_unique_id(), version_package, reroute)

	
	
func download_version():
	var version = needed_versions[0]
	var http_request = HTTPRequest.new()
	http_request.download_chunk_size = 65536
	http_request.download_file = "res://patch" + version + ".pck"
	add_child(http_request)
	http_request.connect("request_completed", new_version_mod_pack)
	var error = http_request.request("https://storage.googleapis.com/a-a-patch/patch" + version + ".pck")

func new_version_mod_pack(result, response_code, headers, body):
	ProjectSettings.load_resource_pack("res://patch" + needed_versions[0] + ".pck")
	needed_versions.pop_front()
	if len(needed_versions) > 0:
		download_version()
	else:
		if not game_loaded:
			request_game_refresh.emit()
		else:
			prompt_restart.emit()


func handle_timeout(nmatch, events, snapshot):
	# Never let a finished/freed match broadcast. A zombie match's timeout would push an apply_turn_result
	# to a peer who has already moved on to a DIFFERENT match, desyncing their client so their real turns
	# stop resolving — and would then drive its bot seat, keeping the dead match playing itself.
	if not is_instance_valid(nmatch) or nmatch.manager == null or nmatch.manager.match_over:
		return
	print("[TIMEOUT] Match ", nmatch.match_id, " turn timeout, broadcasting ", events.size(), " events")
	for client_peer in nmatch.players.keys():
		var expected = nmatch.get_expected_username(client_peer)
		if client_peer in peer_map and expected != null and peer_map[client_peer] == expected:
			send_to_peer(client_peer, "apply_turn_result", {"events": events, "snapshot": snapshot})
	# Spectators get the hidden-info-stripped copy (see _broadcast_turn_result); players
	# above and the replay record below keep the FULL payloads.
	if nmatch.spectators.size() > 0:
		var spec_events := _spectator_safe_events(events)
		var spec_snapshot := _spectator_safe_snapshot(snapshot)
		for spectator_peer in nmatch.spectators.keys():
			if spectator_peer in peer_map:
				send_to_peer(spectator_peer, "apply_turn_result", {"events": spec_events, "snapshot": spec_snapshot})
	if nmatch.replay_log != null and events.size() > 0:
		nmatch.replay_log.record_turn(events, snapshot)
	# If a human's timeout passed the turn to the bot seat, drive the bot. Deferred,
	# because handle_turn_timeout emits this signal BEFORE it flips acting_player to
	# the opponent — running now would still see the (timed-out) human as acting.
	_drive_bot_if_acting.call_deferred(nmatch)

# Phase 7.3 — server-authoritative input handler. Replaces receive_turn_package
# for non-bot multiplayer matches. Validates the canonical-frame input
# (MATCH_PROTOCOL.md section 2.2) against the live shadow, applies it through
# the shadow's BattleManager, and broadcasts the resulting events + snapshot
# to both clients via apply_turn_result. Unlike the legacy relay, the server
# does NOT forward the raw input to the opponent — both clients are passive
# and consume only the authoritative event stream.
func _process_turn_input(sender_id, _match_id, input, from_web = false) -> bool:
	var session = get_session(sender_id)
	if not session:
		return true
	var current_match = session.current_match
	if not current_match or not is_instance_valid(current_match):
		return true
	if current_match.cancelling or current_match.timed_out:
		return true
	if current_match.manager == null:
		return true
	# Spectators also carry current_match (P4) — they never act. Swallow silently (true)
	# so a stray frame doesn't bounce a "turn rejected" error back at a watcher.
	if not (session.username in current_match.get_player_usernames()):
		return true

	# from_web: the JSON web client bundles its exchange in the input and never applies it to
	# the shadow up front (no submit_energy_exchange), so the pool is still pre-exchange here —
	# tell validate_input to pre-apply it for the affordability check.
	if not current_match.validate_input(input, sender_id, from_web):
		var sender_name = peer_map[sender_id] if sender_id in peer_map else "unknown"
		push_warning("[INPUT] Rejected from ", sender_name)
		return false   # caller replies with an error so a (web) client recovers instead of locking

	current_match.apply_input(input, sender_id)

	# If the input ended the match, handle_server_match_ended already drained
	# the recorder, broadcast the final apply_turn_result, and tore the match
	# down synchronously while the manager.match_ended signal was firing.
	# Skip the normal broadcast in that case so we don't double-send events.
	if not is_instance_valid(current_match) or current_match.manager == null:
		return true
	if current_match.manager.match_over:
		return true

	_broadcast_turn_result(current_match)

	# Bot matches: if the human's turn handed the turn to the bot seat, run the
	# bot's turn now (synchronously) and broadcast it. No-op for human matches.
	_drive_bot_if_acting(current_match)
	return true

func send_energy_exchange(offer: Dictionary, request: int):
	var wire_offer := {}
	for key in offer.keys():
		wire_offer[int(key)] = int(offer[key])
	rpc_id(1, "submit_energy_exchange", wire_offer, int(request))


# ---------------------------------------------------------------------------
# SPECTATOR
# ---------------------------------------------------------------------------

func send_spectate_request(target_username: String):
	rpc_id(1, "submit_spectate_request", target_username)




# --- JSON SPECTATE (P4) ---
# ONE generic denial for EVERYTHING about the TARGET (offline / no such account / no match /
# wrong match type / not started / privacy setting / ignored / spectator cap) so a watcher
# can never probe presence, privacy settings, or blocks. Only the actor's OWN state (already
# in a match / queued) gets a specific message.
const SPECTATE_DENY := "That player isn't in a match you can watch right now"

func _spectate_deny(json_pid):
	json_gateway.send(json_pid, {"type": "spectate_result", "ok": false, "note": SPECTATE_DENY})

func _json_spectate(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return json_gateway.send(json_pid, {"type": "spectate_result", "ok": false, "note": "Not logged in"})
	var session = get_session(logical_peer)
	if not _rate_ok(session, "spectate", 5, 60000):
		return json_gateway.send(json_pid, {"type": "spectate_result", "ok": false, "note": "Too many spectate requests — slow down"})
	# Own-state errors may be specific (they reveal nothing about anyone else):
	if session.current_match != null and is_instance_valid(session.current_match):
		return json_gateway.send(json_pid, {"type": "spectate_result", "ok": false, "note": "You're already in a match"})
	var in_queue: bool = logical_peer in queued_players
	if not in_queue:
		for pq_target in private_queue:
			if private_queue[pq_target][0] == logical_peer:
				in_queue = true
				break
	if not in_queue:
		# Ranked queue entries live in ranked_queue[rank][tier] arrays, NOT queued_players —
		# without this scan a ranked-queued player could start spectating and then be drafted
		# into a real match while watching (double current_match).
		for rq_rank in ranked_queue:
			for rq_tier in ranked_queue[rq_rank]:
				for rq_pkg in ranked_queue[rq_rank][rq_tier]:
					if rq_pkg[0] == logical_peer:
						in_queue = true
						break
	if in_queue:
		return json_gateway.send(json_pid, {"type": "spectate_result", "ok": false, "note": "Leave the queue first"})
	# Everything from here on concerns the TARGET -> generic denial only.
	var target_name := str(msg.get("username", "")).strip_edges()
	if target_name == "" or target_name == actor.username:
		return _spectate_deny(json_pid)
	if not (target_name in sessions):
		return _spectate_deny(json_pid)
	var target_session = sessions[target_name]
	if target_session.status != ServerSession.ConnectionState.ONLINE:
		return _spectate_deny(json_pid)
	var target_player = target_session.player_data
	var m = target_session.current_match
	if m == null or not is_instance_valid(m) or m.cancelling:
		return _spectate_deny(json_pid)
	# Watchable match types: Quick, Ranked, Private (a challenge between two players), and Bot (the
	# human seat vs a server-driven AI — the bot's turns broadcast via _drive_bot_if_acting). All are
	# still governed by the target human's allow_spectators setting checked below (off/friends/all), so
	# this never bypasses a player's opt-out. Only Campaign stays unwatchable — it's solo story content.
	if not (m.match_type in [BattleManager.MatchType.QUICK, BattleManager.MatchType.RANKED, BattleManager.MatchType.PRIVATE, BattleManager.MatchType.BOT]):
		return _spectate_deny(json_pid)
	if m.manager == null:   # still in ban/pick (or not started) — nothing watchable yet
		return _spectate_deny(json_pid)
	var allow := str(target_player.allow_spectators)
	if allow == "off":
		return _spectate_deny(json_pid)
	if allow == "friends" and not (actor.username in target_player.friends):
		return _spectate_deny(json_pid)
	if actor.username in target_player.ignored:
		return _spectate_deny(json_pid)
	if m.spectators.size() >= 20:   # per-match spectator cap
		return _spectate_deny(json_pid)
	m.add_spectator(logical_peer)
	session.current_match = m
	var raw: String = m.get_spectator_init()
	if raw == "":
		# <2 seated players — undo and deny generically.
		m.remove_spectator(logical_peer)
		session.current_match = null
		return _spectate_deny(json_pid)
	# Strip hidden info from the init snapshot the same way the live stream does.
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		m.remove_spectator(logical_peer)
		session.current_match = null
		return _spectate_deny(json_pid)
	parsed["snapshot"] = _spectator_safe_snapshot(parsed.get("snapshot", {}))
	send_to_peer(logical_peer, "spectate_init", {"info": JSON.stringify(parsed)})
	json_gateway.send(json_pid, {"type": "spectate_result", "ok": true, "note": "Spectating " + target_name})
	print("[SPECTATOR] ", actor.username, " is watching ", target_name, "'s match ", m.match_id)

func _json_spectate_leave(logical_peer, json_pid, _msg):
	var session = get_session(logical_peer)
	if session and session.current_match != null and is_instance_valid(session.current_match) \
			and not (session.username in session.current_match.get_player_usernames()):
		session.current_match.remove_spectator(logical_peer)
		session.current_match = null
		return json_gateway.send(json_pid, {"type": "spectate_result", "ok": true, "note": "Stopped spectating"})
	# Idempotent: leaving when there's nothing to leave is fine — the match may have already ended
	# (match_ended clears the pointer server-side first), and an err here would just flash a spurious
	# red toast at a viewer who clicked Leave after the finale.
	json_gateway.send(json_pid, {"type": "spectate_result", "ok": true, "note": "Not spectating"})

# Tab-away reconnection: server validated the session and the player has an
# active match. The package is the same JSON that attempt_match_reconnect
# produces, so the client can rebuild the battle scene from it.

# ---------------------------------------------------------------------------
# REPLAY DOWNLOAD
# ---------------------------------------------------------------------------

# Client calls this to ask the server for the replay data from the last match.
func send_replay_request():
	rpc_id(1, "submit_replay_request")



# --- JSON REPLAY FETCH (P3, D3: participants-only) ---
# Streams replays/<match_id>.replay to a participant as CHUNKED replay_data frames
# ({match_id, part, total, data}: REPLAY_CHUNK-char substrings of the one-line replay JSON;
# the client joins parts in order then JSON-parses). Chunked because the gateway's WS buffers
# are the Godot-default 64KB and a full replay can exceed 1MB. Every target-side failure
# (missing file, unreadable, parse-fail, non-participant) sends the SAME opaque
# replay_result so there is no replay-existence oracle.
func _json_replay_fetch(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return json_gateway.send(json_pid, {"type": "replay_result", "ok": false, "note": "Not logged in"})
	if not _rate_ok(get_session(logical_peer), "replay", 10, 60000):
		return json_gateway.send(json_pid, {"type": "replay_result", "ok": false, "note": "Too many replay requests — slow down"})
	# The id flows into a file path: reject traversal outright, then whitelist to the
	# match_uid alphabet ("YYYYMMDD_<match_id>_<rand>" — digits and underscores only).
	var id := str(msg.get("match_id", ""))
	var id_ok := id != "" and not id.contains("/") and not id.contains("\\") and not id.contains("..")
	if id_ok:
		for i in id.length():
			if not id[i] in "0123456789_":
				id_ok = false
				break
	var opaque := {"type": "replay_result", "ok": false, "note": "Replay not available"}
	if not id_ok:
		return json_gateway.send(json_pid, opaque)
	var f := FileAccess.open(REPLAY_DIR + id + ".replay", FileAccess.READ)
	if f == null:
		return json_gateway.send(json_pid, opaque)
	var line := f.get_line()
	var parsed = JSON.parse_string(line)
	if not parsed is Dictionary:
		return json_gateway.send(json_pid, opaque)
	# Participants-only (D3) — same opaque note as "missing" so denial doesn't reveal existence.
	if actor.username != str(parsed.get("p1_username", "")) and actor.username != str(parsed.get("p2_username", "")):
		return json_gateway.send(json_pid, opaque)
	var total := int(ceil(float(line.length()) / float(REPLAY_CHUNK)))
	if total < 1:
		total = 1
	for part in total:
		# send_queued, NOT send: a big replay is many ~26KB frames back-to-back, and the peer's
		# outbound WebSocket buffer is 64KB — plain send_text silently DROPS frames once it backs up
		# on a real network (loopback never reproduces it). The gateway queue drains with headroom
		# checks across poll() ticks, preserving order and dropping nothing.
		json_gateway.send_queued(json_pid, {"type": "replay_data", "match_id": id, "part": part, "total": total, "data": line.substr(part * REPLAY_CHUNK, REPLAY_CHUNK)})
	print("[REPLAY] Queued ", id, " to ", actor.username, " in ", total, " chunk(s)")

# --- AUTHORED CHARACTER HELPERS ---------------------------------------------

# "" when every authored id on this team is permitted for `username` in this
# match kind, else a player-facing reason. Non-authored ids are ignored here
# (normal unlock rules still apply elsewhere).
func _authored_team_error(characters, username: String, is_private_or_bot: bool) -> String:
	if not characters is Array:
		return ""
	for entry in characters:
		# Team entries may carry suffixes (Toga disguise, Jin-woo form token).
		var cid := str(entry).split(":")[0].strip_edges()
		if not AuthoredRegistry.is_authored(cid):
			continue
		# While the Creator is switched off, previously-saved authored characters can't be fielded
		# either — otherwise anyone who built one before the switch flipped would keep an unvetted
		# character in live matches.
		if _creator_blocked(username):
			return "The Character Creator isn't available yet."
		if not AuthoredRegistry.can_use(cid, username, is_private_or_bot, _is_admin(username)):
			var spec = AuthoredRegistry.get_spec(cid)
			var cname := str(spec.get("name", cid)) if spec != null else cid
			# Owner ruling: custom characters are admin-only to field right now (the approval/roster
			# pipeline for normal players is deferred). A non-admin never sees authored characters in
			# char-select, so reaching here means a FORGED pick — reject plainly rather than reusing the
			# old "not approved yet"/"still in testing" wording, which would now LIE (an APPROVED authored
			# character would be reported as unapproved, and match-kind is no longer the reason).
			return "%s is a custom character that isn't available for play yet." % cname
	return ""

# Trimmed view for list screens (never ships the whole block tree).
func _authored_summary(spec: Dictionary) -> Dictionary:
	return {
		"id": str(spec.get("id", "")),
		"name": str(spec.get("name", "")),
		"author": str(spec.get("author", "")),
		"status": str(spec.get("status", "draft")),
		"colors": spec.get("colors", []),
		"description": str(spec.get("description", "")),
		"ability_count": (spec.get("abilities", []) as Array).size() if spec.get("abilities", []) is Array else 0,
		"has_portrait": AuthoredAssets.has_asset(str(spec.get("id", "")), "portrait"),
		"review_note": str(spec.get("review_note", "")),
	}

# The editor builds its palette from the SERVER's schema, so the two can never
# drift: if a block isn't offered here, the validator would reject it anyway.
func _authored_palette() -> Dictionary:
	return {
		"ops": BlockSchema.OPS,
		"effect_kinds": BlockSchema.EFFECT_KINDS,
		# The fields every effect accepts on top of its kind's own. The editor renders one
		# control per entry, so a field added to the schema shows up with no client change.
		"effect_universal": BlockSchema.UNIVERSAL_EFFECT_FIELDS,
		# Which of those universal fields each KIND'S FACTORY already owns — {kind: {field: the
		# authored field it is written from}}. Exported because the validator REJECTS them: a control
		# that renders and then fails to save is the same lie as one that saves and does nothing, so
		# the editor must stop drawing the control, not just watch the error appear. See
		# BlockSchema.EFFECT_KINDS' `reserves` column.
		"effect_reserved": BlockSchema.reserved_by_kind(),
		# Pre-rename effect-kind names. The editor needs these to render a character SAVED
		# before a rename: without the map it looks up the kind's fields under a name the
		# palette no longer has, finds none, and silently drops every factory control on that
		# block — the author can see it but not fix it.
		"kind_aliases": BlockSchema.KIND_ALIASES,
		"selectors": BlockSchema.SELECTORS,
		# Kept SEPARATE from `selectors` on purpose: these are legal as a block's `to` and
		# nowhere else (a condition's own `on`/`of`/`vs` would be an infinite regress), and
		# the editor builds two different pickers out of the two lists.
		"filtered_selectors": BlockSchema.FILTERED_SELECTORS,
		# Third list for the same reason `filtered_selectors` is a second one: PLACEMENT. These
		# two are legal only inside a trigger/counter `then` payload, so the editor may only
		# offer them on a block it is rendering INSIDE one — the validator rejects them anywhere
		# else. Both lists are name -> human description, and the description is what the picker
		# should show: "holder" means nothing to an author, "the character carrying this effect"
		# does.
		"payload_selectors": BlockSchema.PAYLOAD_SELECTORS,
		# Which selector names can answer with MORE THAN ONE character. Exported because `banish`
		# forbids them outright (a whole-team banish ends the match on the spot), so an editor that
		# offers them on that op produces specs the validator refuses to save — the same
		# offer-what-cannot-be-saved trap `payload_selectors` exists to avoid. It is a LIST of names
		# from `selectors`/`filtered_selectors`, not a fourth picker.
		"pool_selectors": BlockSchema.POOL_SELECTORS + BlockSchema.FILTERED_SELECTORS.keys(),
		"conditions": BlockSchema.CONDITIONS,
		"triggers": BlockSchema.TRIGGERS,
		# Which trigger hooks accept the event-class filter. The other four are dispatched with
		# the trigger effect itself as the context source, so a scope there filters on nothing;
		# the editor hides the control off this list, and the validator rejects it regardless.
		"scoped_triggers": BlockSchema.SCOPED_TRIGGERS,
		"damage_types": BlockSchema.DAMAGE_TYPES,
		"limits": BlockSchema.LIMITS,
		"asset_slots": AuthoredAssets.SLOTS,
		"max_image_bytes": AuthoredAssets.MAX_BYTES,
		# How many alternate-portrait slots exist. The editor draws a `portrait_change`'s index picker
		# (0..count-1) and that many upload fields off this ONE number, and the validator bounds the index
		# to the same count — so growing AuthoredAssets.ALT_PORTRAIT_SLOTS grows every layer at once.
		"alt_portrait_count": AuthoredAssets.alt_portrait_slots().size(),
		# Everything below is a vocabulary the editor renders a control over. Shipping the
		# SERVER's copy is the whole point: a hard-coded client list is how the editor ended
		# up seeding cost_change.colour to "random" with no picker, and offering 12 of the
		# validator's class names while silently dropping Uncounterable.
		# authorable_classes(), not Ability.CLASS_NAMES: a chip the validator will reject must not be
		# offered (the same offer-what-cannot-be-saved trap `effect_reserved` avoids). "Action" is
		# retired here — it is now driven by a recurring effect's stops_when_stunned. See
		# BlockValidator.RETIRED_AUTHOR_CLASSES.
		"classes": BlockValidator.authorable_classes(),
		"target_modes": BlockValidator.TARGET_MODES,
		# PHASE F — the SELECTOR SYSTEM vocabularies. Layer 1 (the eligibility object at `target`) and
		# Layer 2 (the selector object at a block's `to`) share `picks`/`orders`/`measures` and the
		# condition list already exported as `conditions`. Shipping the SERVER's copy is the usual rule:
		# a value added here shows up in the editor with no client change and cannot drift from what the
		# validator accepts. Stage 2 (the editor) builds the selector card from these.
		"target_object_modes": BlockSchema.TARGET_OBJECT_MODES,   # Layer 1 `mode` (the SIDE)
		"target_shapes": BlockSchema.TARGET_SHAPES,               # Layer 1 `shape` (the fan-out)
		"pools": BlockSchema.POOLS,                               # Layer 2 `pool` (name -> description)
		# Which pools re-run can_*_target (A2) — the editor can surface `bypassing` only where it bites.
		"pool_gated": BlockSchema.POOL_GATED,
		# Pools that always resolve to at most one character — the only ones `banish` may aim at.
		"pool_single": BlockSchema.POOL_SINGLE,
		"picks": BlockSchema.PICKS,                               # all / random / lowest / highest
		"orders": BlockSchema.ORDERS,                             # clicked_first / pool
		"measures": BlockSchema.MEASURES,                         # per-character lowest/highest key
		"ability_flags": BlockValidator.ABILITY_FLAGS,
		"cost_colours": BlockSchema.COST_COLOURS,
		"gain_colours": BlockSchema.GAIN_COLOURS,
		"cleanse_scopes": BlockSchema.CLEANSE_SCOPES,
		"break_targets": BlockSchema.BREAK_TARGETS,
		"counter_scopes": BlockSchema.COUNTER_SCOPES.keys(),
		# `counter`.on — which side of the exchange it watches. Two values, and the editor needs
		# both: the default ("incoming") is what every counter meant before the field existed.
		"counter_sides": BlockSchema.COUNTER_SIDES,
		# `reflect`'s two authoring decisions. Neither renders without a control branch of its own
		# (the effect-kind field chain is a fixed list of known field NAMES), so shipping the
		# vocabulary is only half the job — see the editor's reflect branch.
		"reflect_destinations": BlockSchema.REFLECT_DESTINATIONS,
		"reflect_charges": BlockSchema.REFLECT_CHARGES,
		# `cost_change`.mode — three different engine effects behind one kind, so the editor has to
		# show/hide `amount` and `from` per mode or it offers fields the validator will refuse.
		"cost_modes": BlockSchema.COST_MODES,
		# `recurring`.first — whether the first tick lands this turn ("now") or next ("next"). Shipped
		# so the picker's two values come from the server, exactly as cost_modes/counter_sides do.
		"recurring_firsts": BlockSchema.RECURRING_FIRSTS,
		# The ability-level channel flag. NOT in `ability_flags`: those are bools and this is a
		# three-state picker (off / control / channel).
		"channel_modes": BlockSchema.CHANNEL_MODES,
		# A presence condition's `.by`. Ships with `immunity_effects` (its `.effect` partner already
		# rides out through that key) because the two are one feature — see BlockSchema.PRESENCE_BY.
		"presence_by": BlockSchema.PRESENCE_BY,
		"immunity_effects": BlockSchema.immunity_effects(),
		"compare_values": BlockSchema.COMPARE_VALUES,
		"compare_ops": BlockSchema.COMPARE_GROUP_OPS + BlockSchema.COMPARE_PAIR_OPS,
		# The reading `read` enum, for the scaling-amount widget's `read` dropdown and the compare
		# value picker's "a reading" branch — the same node mounts in both. Shipping the SERVER's
		# list is the usual rule: a member added here shows up with no client change and cannot
		# drift from what the validator accepts.
		"readings": BlockSchema.READINGS,
	}

# Save: the author and any privileged status transition are decided here. A
# client may never set its own status to "approved", nor overwrite someone
# else's character by guessing an id.
func _authored_save(username: String, incoming) -> Dictionary:
	if not incoming is Dictionary:
		return {"type": "error", "reason": "malformed character"}
	var spec: Dictionary = (incoming as Dictionary).duplicate(true)
	var id := str(spec.get("id", "")).strip_edges()
	if id.is_empty():
		id = "auth_%s_%d" % [username.to_lower().left(8), Time.get_unix_time_from_system()]
		id = id.replace(" ", "_")
		spec["id"] = id
	var existing = AuthoredRegistry.get_spec(id)
	if existing != null and str(existing.get("author", "")) != username and not _is_admin(username):
		return {"type": "error", "reason": "that id belongs to another player"}
	# Author is always the session; status is clamped to author-settable values.
	spec["author"] = existing.get("author", username) if existing != null else username
	var wanted := str(spec.get("status", "draft"))
	if not wanted in ["draft", "testing"]:
		wanted = str(existing.get("status", "draft")) if existing != null else "draft"
	# Editing an approved character sends it back for re-review rather than
	# letting a live, public character be silently rewritten.
	if existing != null and str(existing.get("status", "")) == "approved":
		wanted = "submitted"
	spec["status"] = wanted
	spec.erase("review_note")
	var errs := AuthoredRegistry.save_spec(spec)
	if not errs.is_empty():
		return {"type": "authored_invalid", "id": id, "errors": errs}
	return {"type": "authored_saved", "id": id, "status": spec["status"]}

# Validate a candidate spec and render its generated descriptions, without
# touching disk. Descriptions come from the real ScriptedAbility generator so
# the editor preview is exactly what players will read in battle.
func _authored_validate(cand) -> Dictionary:
	if not cand is Dictionary:
		return {"type": "authored_validated", "errors": ["malformed character"], "abilities": []}
	# A brand-new draft has no id/author yet — the SAVE path assigns both. Fill
	# placeholders so the editor only ever shows problems the author can actually
	# fix; otherwise a new character reports two errors it cannot clear and the
	# error-gated Save button is unreachable.
	var probe: Dictionary = (cand as Dictionary).duplicate(true)
	if str(probe.get("id", "")).strip_edges().is_empty():
		probe["id"] = "auth_preview"
	if str(probe.get("author", "")).strip_edges().is_empty():
		probe["author"] = "preview"
	var errs := AuthoredRegistry.validate_character(probe)
	var previews: Array = []
	var defs = cand.get("abilities", [])
	if defs is Array:
		for def in defs:
			if not def is Dictionary:
				continue
			var a := ScriptedAbility.new()
			a.configure(def)
			a.ability_name = str(def.get("name", "Skill"))
			var classes := {}
			for c in ["Physical", "Energy", "Mental", "Affliction", "Strategic", "Harmful",
					"Helpful", "Instant", "Action", "Control", "Channeled", "Uncounterable",
					"Bypassing", "Stealthed", "Passive", "Preserves Channel", "Damaging"]:
				classes[c] = false
			var dcl = def.get("classes", [])
			if dcl is Array:
				for c in dcl:
					if str(c) in classes:
						classes[str(c)] = true
			a.classes = classes
			# split_desc segments are either a String or [text, Color]; flatten to
			# {text, color} so the client renders them the same way it renders
			# ability_split.json entries.
			var segs: Array = []
			for s in a.split_desc():
				if s is Array and s.size() >= 1:
					var entry := {"text": str(s[0])}
					if s.size() >= 2 and s[1] is Color:
						entry["color"] = "#" + (s[1] as Color).to_html(false)
					segs.append(entry)
				else:
					segs.append({"text": str(s)})
			previews.append({"name": a.ability_name, "desc": segs, "damage_hint": a.bot_damage_hint()})
	return {"type": "authored_validated", "errors": errs, "abilities": previews}

# Chunked image upload. Ownership is re-checked on begin; the stored path is
# derived from (id, slot) so nothing client-supplied reaches the filesystem.
func _authored_upload(username: String, msg: Dictionary) -> Dictionary:
	match str(msg.get("type", "")):
		"authored_upload_begin":
			var cid := str(msg.get("id", ""))
			var spec = AuthoredRegistry.get_spec(cid)
			if spec == null or (str(spec.get("author", "")) != username and not _is_admin(username)):
				return {"type": "error", "reason": "not your character"}
			# A SKILL icon names its ability by INDEX; the server picks the storage
			# slot so the client can never choose the filename, and so the binding
			# survives the author removing a skill (which shifts every later index).
			var uslot := str(msg.get("slot", ""))
			var aidx := int(msg.get("ability_index", -1))
			if aidx >= 0:
				# The index is into the client's WORKING copy, which may have had skills
				# added or removed since the last save — and removing one is a common
				# flow, since a wrong VISIBLE-skill count blocks saving. Resolving a stale index here
				# would hand back a DIFFERENT skill's slot and overwrite its art. Ability
				# names are already unique per character (validate_character rejects
				# duplicates), so use the name to prove both sides mean the same skill.
				var uabs = spec.get("abilities", [])
				var uname := str(msg.get("ability_name", ""))
				if not uabs is Array or aidx >= (uabs as Array).size() \
						or not uabs[aidx] is Dictionary or str(uabs[aidx].get("name", "")) != uname:
					return {"type": "error", "reason": "Save your changes before uploading art for this skill"}
				uslot = AuthoredRegistry.allocate_icon_slot(spec, aidx)
				if uslot.is_empty():
					return {"type": "error", "reason": "no free image slot for that skill"}
			var errs := AuthoredAssets.begin(username, cid, uslot,
				int(msg.get("bytes", 0)), int(msg.get("chunks", 0)), aidx)
			if not errs.is_empty():
				return {"type": "error", "reason": "; ".join(errs)}
			return {"type": "authored_upload_ready"}
		"authored_upload_chunk":
			var cerrs := AuthoredAssets.chunk(username, int(msg.get("part", -1)), str(msg.get("data", "")))
			if not cerrs.is_empty():
				return {"type": "error", "reason": "; ".join(cerrs)}
			return {"type": "authored_upload_ack", "part": int(msg.get("part", -1))}
		"authored_upload_end":
			# finish() clears the pending record before returning, so read it first.
			var pend := AuthoredAssets.peek(username)
			var ferrs := AuthoredAssets.finish(username)
			if not ferrs.is_empty():
				return {"type": "error", "reason": "; ".join(ferrs)}
			var ucid := str(pend.get("char_id", ""))
			var dslot := str(pend.get("slot", ""))
			var didx := int(pend.get("ability_index", -1))
			if didx >= 0:
				# Bind the stored slot to the skill. save_spec directly, NOT
				# _authored_save — that path force-demotes an approved character to
				# `submitted`, which would pull live public content out of the roster
				# just because its author changed a picture. get_spec hands back the
				# CACHED dict by reference (a live match may be holding it), so edit a
				# deep copy.
				var bound = AuthoredRegistry.get_spec(ucid)
				if bound is Dictionary:
					var edited: Dictionary = (bound as Dictionary).duplicate(true)
					var eabs = edited.get("abilities", [])
					if eabs is Array and didx < eabs.size() and eabs[didx] is Dictionary:
						eabs[didx]["icon"] = dslot
						AuthoredRegistry.save_spec(edited)
			# The client caches art by "id|slot" and must evict the exact key it just
			# replaced, so echo what was actually written instead of a bare ack.
			return {"type": "authored_upload_done", "id": ucid, "slot": dslot, "ability_index": didx}
	return {"type": "error", "reason": "bad upload message"}

# --- server feature flags ---------------------------------------------------
func _load_server_flags() -> void:
	var flags := _read_json_dict(SERVER_FLAGS_PATH)
	# Absent/among-friends-unparseable file -> keep the defaults, which are the SAFE ones.
	creator_enabled = bool(flags.get("creator_enabled", false))
	print("[FLAGS] creator_enabled=", creator_enabled)

func _save_server_flags() -> void:
	var f := FileAccess.open(SERVER_FLAGS_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[FLAGS] could not write " + SERVER_FLAGS_PATH)
		return
	f.store_string(JSON.stringify({"creator_enabled": creator_enabled}, "\t"))
	f.close()

# True when this user must not reach the authored-character system. The button being hidden is
# convenience only — a hand-written client can still send authored_* frames, so every entry point
# checks here. Admins are exempt so they can build and test while the feature is dark.
func _creator_blocked(username: String) -> bool:
	return not creator_enabled and not _is_admin(username)

# Small helper for the admin training dashboard: parse a JSON file into a
# Dictionary, or {} when missing/invalid (callers treat {} as "no data").
func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


# Shape-validate an admin_set_bot_tuning payload BEFORE it reaches disk: the
# file hot-reloads into every live bot's scoring path, so a structurally wrong
# value must be rejected here, not discovered as runtime script errors
# mid-match. Returns "" when valid, else a human-readable problem.
func _validate_bot_tuning(tuning) -> String:
	if not tuning is Dictionary:
		return "payload must be a JSON object"
	if str(tuning.get("format", "")) != "aa-bot-tuning":
		return "format must be \"aa-bot-tuning\""
	var g = tuning.get("global", {})
	if not g is Dictionary:
		return "global must be an object"
	for knob in ["aggression", "defense", "energy_thrift"]:
		if g.has(knob) and not (g[knob] is float or g[knob] is int):
			return "global.%s must be a number" % knob
	if g.has("difficulty_tiers"):
		if not g["difficulty_tiers"] is Dictionary:
			return "global.difficulty_tiers must be an object"
		for tier in g["difficulty_tiers"]:
			if not (g["difficulty_tiers"][tier] is float or g["difficulty_tiers"][tier] is int):
				return "difficulty_tiers.%s must be a number" % tier
	var chars = tuning.get("characters", {})
	if not chars is Dictionary:
		return "characters must be an object"
	for char_path in chars:
		var ct = chars[char_path]
		if not ct is Dictionary:
			return "characters.%s must be an object" % char_path
		if ct.has("banned_abilities") and not ct["banned_abilities"] is Array:
			return "characters.%s.banned_abilities must be an array" % char_path
		for map_key in ["ability_multipliers", "ability_offsets"]:
			if not ct.has(map_key):
				continue
			if not ct[map_key] is Dictionary:
				return "characters.%s.%s must be an object" % [char_path, map_key]
			for ability_name in ct[map_key]:
				if not (ct[map_key][ability_name] is float or ct[map_key][ability_name] is int):
					return "characters.%s.%s.%s must be a number" % [char_path, map_key, ability_name]
	return ""


func send_leaderboard_request():
	rpc_id(1, "receive_leaderboard_request", multiplayer.get_unique_id())
	



func send_ladder_request(panel):
	for connection in ladder_info_received.get_connections():
		ladder_info_received.disconnect(connection['callable'])
	ladder_info_received.connect(panel.accept_ladder_data)
	rpc_id(1, "request_ladder_details", multiplayer.get_unique_id())

const LADDER_TOP_N = 50


func _build_ladder_info(requesting_username: String) -> Dictionary:
	var all_players = []
	for username in players:
		var player = players[username]
		if not player:
			continue
		all_players.append({
			"username": username,
			"wins": player.rank.wins,
			"losses": player.rank.losses,
			"rating": player.rank.get_rating(),
			# Derived from rating, but shipped rather than re-derived client-side so the badge on the
			# ladder can never disagree with the one on the profile.
			"rank": player.rank.rank,
			"tier": player.rank.rank_tier,
			"streak": player.rank.streak,
			"ranked_streak": player.rank._ranked_streak,
			"clan_name": player.clan
		})

	var all_clans = []
	for clan_name in clans:
		var clan = clans[clan_name]
		if clan.wins == 0 or clan.member_count() == 1:
			continue
		all_clans.append({
			"clan_name": clan.clan_name,
			"wins": clan.wins,
			"losses": clan.losses,
			"level": clan.get_level_from_wins(),
			"members": clan.member_count()
		})
	all_clans.sort_custom(func(a, b): return a["level"] > b["level"])

	return {
		"by_rating": _build_top_n_with_me(all_players, "rating", LADDER_TOP_N, requesting_username),
		"by_wins": _build_top_n_with_me(all_players, "wins", LADDER_TOP_N, requesting_username),
		"by_streak": _build_top_n_with_me(all_players, "streak", LADDER_TOP_N, requesting_username),
		"clan_data": all_clans.slice(0, LADDER_TOP_N)
	}


# Sorts `rows` by `sort_key` descending, drops non-positive entries (0-rating
# / 0-win / 0-or-loss-streak players don't belong on a "top" board), takes
# top `n`, and — when the requester isn't in that top — appends their full
# rank + row so the client can show a "you" entry below the cut.
func _build_top_n_with_me(rows: Array, sort_key: String, n: int, my_username: String) -> Dictionary:
	var sorted_rows = []
	for row in rows:
		if row[sort_key] <= 0:
			continue
		sorted_rows.append(row)
	sorted_rows.sort_custom(func(a, b): return a[sort_key] > b[sort_key])

	var top = sorted_rows.slice(0, n)

	var me_entry = null
	if my_username != "":
		var found_in_top = false
		for row in top:
			if row["username"] == my_username:
				found_in_top = true
				break
		if not found_in_top:
			for i in range(sorted_rows.size()):
				if sorted_rows[i]["username"] == my_username:
					me_entry = {"rank": i + 1, "row": sorted_rows[i]}
					break

	return {"top": top, "me": me_entry}


func send_character_mastery_request(panel, character_path):
	for connection in character_mastery_received.get_connections():
		character_mastery_received.disconnect(connection['callable'])
	character_mastery_received.connect(panel.accept_character_mastery_data)
	rpc_id(1, "request_character_mastery_ladder", multiplayer.get_unique_id(), character_path)





func _on_ladder_timer_timeout():
	return
	if DisplayServer.get_name() != "headless":
		return
	for player in players:
		ladder[players[player].username] = players[player].rank.get_rating()
	for clan in clans:
		clan_ladder[clan] = clan.get_level_from_wins()

# ===========================================================================
# CLANS — web (JSON gateway) implementation. The core Clan model + persistence
# (Clan / save_clan / load_clan / initialize_clans / clans{}) predate this; the
# retired @rpc handlers below are unreachable from the web client. These handlers
# re-implement create / join(via invite+request) / invite / leave / kick /
# disband for JSON peers WITH the server-side authority + name validation the old
# code lacked. The clans/<name>.dat files are the single source of truth for
# membership and pending offers (a player's own clan_invitations/clan_applications
# arrays aren't persisted, so we derive pending state from the clan side).
# ===========================================================================

const CLAN_NAME_MIN := 3
const CLAN_NAME_MAX := 24

# A clan name becomes the filename clans/<name>.dat, so it must be sanitized:
# reject path separators / traversal and restrict to a safe charset + length.
func _clan_name_valid(raw) -> bool:
	var name := str(raw).strip_edges()
	if name.length() < CLAN_NAME_MIN or name.length() > CLAN_NAME_MAX:
		return false
	for ch in name:
		var ok := (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") \
			or (ch >= "0" and ch <= "9") or ch == " " or ch == "_" or ch == "-" or ch == "'"
		if not ok:
			return false
	return true

# Case-insensitive uniqueness so "Foo" and "foo" can't both exist / confuse.
func _clan_name_taken(name) -> bool:
	var lower := str(name).to_lower()
	for cn in clans:
		if str(cn).to_lower() == lower:
			return true
	return FileAccess.file_exists("clans/" + str(name) + ".dat")

# The live Player object for a username: the session copy if they're connected
# (so live server state stays consistent), else the on-boot players cache.
func _resolve_member_player(username):
	if username in sessions and sessions[username].player_data != null:
		return sessions[username].player_data
	return players.get(username, null)

func _clan_player_brief(username) -> Dictionary:
	var p = players.get(username, null)
	if p == null:
		p = _resolve_member_player(username)
	var w := 0
	var l := 0
	var avatar := ""
	if p != null:
		if p.rank != null:
			w = p.rank.wins
			l = p.rank.losses
		avatar = str(p.avatar_url)
	return {"username": str(username), "wins": w, "losses": l, "avatar_url": avatar}

# Public summary for search results / a Clanless player's invite & application lists.
func _clan_summary(clan) -> Dictionary:
	return {
		"clan_name": clan.clan_name,
		"members": clan.member_count(),
		"banner_url": clan.banner_url,
		"wins": clan.wins,
		"losses": clan.losses,
		"level": clan.get_level_from_wins(),
	}

# Full detail for a member's "My Clan" view. Leader-only fields (applications /
# outstanding invites) are only included when the viewer is the leader.
func _clan_detail(clan, viewer_username) -> Dictionary:
	var member_rows := []
	for rank in [Clan.Rank.LEADER, Clan.Rank.OFFICER, Clan.Rank.MEMBER]:
		for uname in clan.members.get(rank, []):
			var brief := _clan_player_brief(uname)
			brief["role"] = "Leader" if rank == Clan.Rank.LEADER else ("Officer" if rank == Clan.Rank.OFFICER else "Member")
			member_rows.append(brief)
	var is_leader: bool = viewer_username in clan.members.get(Clan.Rank.LEADER, [])
	var is_officer: bool = viewer_username in clan.members.get(Clan.Rank.OFFICER, [])
	var prog = clan.get_level_progress()
	var detail := {
		"name": clan.clan_name,
		"banner_url": clan.banner_url,
		"wins": clan.wins,
		"losses": clan.losses,
		"level": prog["level"],
		"level_progress": prog["into"],   # wins banked into the current level
		"level_needed": prog["needed"],   # wins the current level costs to reach the next
		"member_count": clan.member_count(),
		"my_role": "Leader" if is_leader else ("Officer" if is_officer else "Member"),
		"members": member_rows,
	}
	# Officers manage invites + join requests too, so they need those lists — not just the leader.
	if is_leader or is_officer:
		var apps := []
		for u in clan.applied_players:
			apps.append(_clan_player_brief(u))
		var invs := []
		for u in clan.invited_players:
			invs.append(_clan_player_brief(u))
		detail["applications"] = apps
		detail["invites"] = invs
	return detail

# The clan panel payload: the member's clan detail, OR (for a Clanless player)
# their pending invitations + applications (derived from the authoritative clan side).
func _clan_state_body(username) -> Dictionary:
	var out := {"clan": null, "invitations": [], "applications": []}
	var p = _resolve_member_player(username)
	var my_clan := ""
	if p != null:
		my_clan = str(p.clan)
	# Self-heal a dangling membership: the player points at a clan the server no longer has
	# (e.g. an inconsistent old record). Reset to Clanless so the panel isn't stuck loading.
	if p != null and my_clan != "" and my_clan != "Clanless" and not my_clan in clans:
		p.clan = "Clanless"
		resave_player(p)
		my_clan = "Clanless"
	if my_clan != "" and my_clan != "Clanless" and my_clan in clans:
		out["clan"] = _clan_detail(clans[my_clan], username)
	else:
		for cn in clans:
			var clan = clans[cn]
			if username in clan.invited_players:
				out["invitations"].append(_clan_summary(clan))
			if username in clan.applied_players:
				out["applications"].append(_clan_summary(clan))
	return out

# Push a fresh clan-panel snapshot to a user if they're online (their panel updates live).
func _send_clan_state_to(username):
	if username in sessions and sessions[username].status == ServerSession.ConnectionState.ONLINE:
		send_to_peer(sessions[username].peer_id, "clan_state", _clan_state_body(username))

func _clan_ok(json_pid, note):
	json_gateway.send(json_pid, {"type": "clan_result", "ok": true, "note": note})

func _clan_err(json_pid, note):
	json_gateway.send(json_pid, {"type": "clan_result", "ok": false, "note": note})

# --- clan role predicates -----------------------------------------------------
# Officers can invite, approve/deny join requests, and remove regular members. Only the LEADER can
# promote to / remove Officer rank or change the clan picture. Every side-effect handler re-checks
# these server-side — the client's role-gated UI is convenience only.
func _clan_is_leader(clan, username) -> bool:
	return username in clan.members.get(Clan.Rank.LEADER, [])

func _clan_is_officer(clan, username) -> bool:
	return username in clan.members.get(Clan.Rank.OFFICER, [])

func _clan_can_manage(clan, username) -> bool:
	return _clan_is_leader(clan, username) or _clan_is_officer(clan, username)

# ============================================================================
# SOCIAL — friends / ignore (Phase 1). Cloned from the clan system's shape:
#   ack       -> _social_ok / _social_err        (mirror _clan_ok / _clan_err)
#   snapshot  -> _send_social_state_to            (mirror _send_clan_state_to)
#   presence  -> _push_presence_to_friends        (friend-list live dots)
# The four lists live on the unforgeable Player object (friends,
# friend_requests_in/out, ignored). Targets are resolved traversal-safe via
# _admin_get_target; both affected players are resaved and re-pushed.
# ============================================================================
const FRIENDS_CAP := 100
const FRIEND_REQ_CAP := 50
const IGNORED_CAP := 100

func _social_ok(json_pid, note):
	json_gateway.send(json_pid, {"type": "social_result", "ok": true, "note": note})

func _social_err(json_pid, note):
	json_gateway.send(json_pid, {"type": "social_result", "ok": false, "note": note})

# Full social snapshot for `username`: friends carry live presence; the pending /
# ignore lists are raw username arrays (duplicated so a client-bound copy can't
# alias the live Player arrays). Resolved traversal-safe (session -> cache -> disk).
func _social_state_body(username) -> Dictionary:
	var out := {"friends": [], "requests_in": [], "requests_out": [], "ignored": []}
	var p = _admin_get_target(str(username))
	if p == null:
		return out
	var friend_rows := []
	for f in p.friends:
		friend_rows.append({"username": f, "status": _player_status(f)})
	out["friends"] = friend_rows
	out["requests_in"] = p.friend_requests_in.duplicate()
	out["requests_out"] = p.friend_requests_out.duplicate()
	out["ignored"] = p.ignored.duplicate()
	return out

# Push a fresh social snapshot to a user if they're online (panel updates live).
func _send_social_state_to(username):
	if username in sessions and sessions[username].status == ServerSession.ConnectionState.ONLINE:
		send_to_peer(sessions[username].peer_id, "social_state", _social_state_body(username))

# Live presence fan-out: when `username`'s presence flips, notify each of THEIR
# friends who is currently online so their friend-list dot updates without a refetch.
func _push_presence_to_friends(username, status):
	var p = _resolve_member_player(username)
	if p == null:
		return
	for f in p.friends:
		if f in sessions and sessions[f].status == ServerSession.ConnectionState.ONLINE:
			send_to_peer(sessions[f].peer_id, "friend_presence", {"username": username, "status": status})

func _json_social_state(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _social_err(json_pid, "Not logged in")
	var body := _social_state_body(actor.username)
	body["type"] = "social_state"
	json_gateway.send(json_pid, body)

func _json_friend_request(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _social_err(json_pid, "Not logged in")
	if not _rate_ok(sessions.get(actor.username), "friend_request", 6, 60000):
		return _social_err(json_pid, "You're sending requests too fast — try again shortly")
	var target_name := str(msg.get("username", "")).strip_edges()
	if target_name == "":
		return _social_err(json_pid, "Enter a username")
	if target_name == actor.username:
		return _social_err(json_pid, "You can't friend yourself")
	var target = _admin_get_target(target_name)
	if target == null:
		return _social_err(json_pid, "No player named '" + target_name + "'")
	var t_name := str(target.username)
	if t_name == actor.username:
		return _social_err(json_pid, "You can't friend yourself")
	# Keep friends ∩ ignored empty: you can't befriend someone you're ignoring. This reports the
	# actor's OWN ignore state (not the target's), so it is not an oracle.
	if t_name in actor.ignored:
		return _social_err(json_pid, "You're ignoring " + t_name + " — unignore them first")
	if t_name in actor.friends:
		return _social_err(json_pid, "You're already friends with " + t_name)
	# MUTUAL auto-accept: the target already requested me. Unreachable when the target ignores me
	# (ignore severs their pending request to me), so it is safe to keep ahead of the silent-drop.
	if t_name in actor.friend_requests_in:
		if actor.friends.size() >= FRIENDS_CAP:
			return _social_err(json_pid, "Your friends list is full")
		if not actor.username in target.friends and target.friends.size() >= FRIENDS_CAP:
			return _social_err(json_pid, t_name + "'s friends list is full")
		actor.friend_requests_in.erase(t_name)
		actor.friend_requests_out.erase(t_name)
		target.friend_requests_in.erase(actor.username)
		target.friend_requests_out.erase(actor.username)
		if not t_name in actor.friends:
			actor.friends.append(t_name)
		if not actor.username in target.friends:
			target.friends.append(actor.username)
		resave_player(actor)
		resave_player(target)
		_send_social_state_to(actor.username)
		_send_social_state_to(t_name)
		return _social_ok(json_pid, "You and " + t_name + " are now friends")
	# dedup + my-own-outgoing cap: both are the ACTOR's own state, safe to report.
	if t_name in actor.friend_requests_out:
		return _social_err(json_pid, "You've already sent " + t_name + " a request")
	if actor.friend_requests_out.size() >= FRIEND_REQ_CAP:
		return _social_err(json_pid, "You have too many pending requests")
	# ACTOR-side commit. Everything the actor can observe (the note, the extra social_state frame,
	# and the persisted requests_out entry) happens here, IDENTICALLY whether or not the target ends
	# up receiving the request — so an ignore or a full inbox is undetectable from the actor's side.
	actor.friend_requests_out.append(t_name)
	resave_player(actor)
	_social_ok(json_pid, "Friend request sent to " + t_name)
	_send_social_state_to(actor.username)
	# Deliver to the target UNLESS they ignore the actor (block) or their inbox is full. In either
	# case stop silently — the target is never mutated or notified, and the actor already saw the
	# exact success it would see for a delivered request, so neither state leaks a block/saturation oracle.
	if actor.username in target.ignored:
		return
	if target.friend_requests_in.size() >= FRIEND_REQ_CAP:
		return
	target.friend_requests_in.append(actor.username)
	resave_player(target)
	# An Ultra bot never accepts and never replies — it silently auto-declines after a random delay, so the
	# request resolves instead of pending forever. The rotation tick also re-arms this if the process restarts.
	if target.is_ultra_bot:
		_ultra_bot_arm_decline(t_name, actor.username)
	if t_name in sessions and sessions[t_name].status == ServerSession.ConnectionState.ONLINE:
		send_to_peer(sessions[t_name].peer_id, "friend_request_notice", {"from": actor.username})
	_send_social_state_to(t_name)

func _json_friend_accept(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _social_err(json_pid, "Not logged in")
	if not _rate_ok(sessions.get(actor.username), "friend_mutate", 30, 60000):
		return _social_err(json_pid, "You're doing that too fast — try again shortly")
	var target_name := str(msg.get("username", "")).strip_edges()
	var target = _admin_get_target(target_name)
	if target == null:
		return _social_err(json_pid, "No player named '" + target_name + "'")
	var t_name := str(target.username)
	if t_name == actor.username:
		return _social_err(json_pid, "You can't do that to yourself")
	if not t_name in actor.friend_requests_in:
		return _social_err(json_pid, "No pending request from " + t_name)
	if t_name in actor.ignored:
		return _social_err(json_pid, "You're ignoring " + t_name + " — unignore them first")
	if not t_name in actor.friends and actor.friends.size() >= FRIENDS_CAP:
		return _social_err(json_pid, "Your friends list is full")
	if not actor.username in target.friends and target.friends.size() >= FRIENDS_CAP:
		return _social_err(json_pid, t_name + "'s friends list is full")
	actor.friend_requests_in.erase(t_name)
	actor.friend_requests_out.erase(t_name)
	target.friend_requests_out.erase(actor.username)
	target.friend_requests_in.erase(actor.username)
	if not t_name in actor.friends:
		actor.friends.append(t_name)
	if not actor.username in target.friends:
		target.friends.append(actor.username)
	resave_player(actor)
	resave_player(target)
	_send_social_state_to(actor.username)
	_send_social_state_to(t_name)
	_social_ok(json_pid, "You and " + t_name + " are now friends")

func _json_friend_decline(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _social_err(json_pid, "Not logged in")
	if not _rate_ok(sessions.get(actor.username), "friend_mutate", 30, 60000):
		return _social_err(json_pid, "You're doing that too fast — try again shortly")
	var target_name := str(msg.get("username", "")).strip_edges()
	var target = _admin_get_target(target_name)
	if target == null:
		return _social_err(json_pid, "No player named '" + target_name + "'")
	var t_name := str(target.username)
	if t_name == actor.username:
		return _social_err(json_pid, "You can't do that to yourself")
	# Existence guard: bail before any write if there's nothing to decline, so a client can't force
	# repeated resave_player + social_state pushes against an arbitrary account (disk-write amplifier).
	if not t_name in actor.friend_requests_in:
		return _social_err(json_pid, "No pending request from " + t_name)
	actor.friend_requests_in.erase(t_name)
	target.friend_requests_out.erase(actor.username)
	resave_player(actor)
	resave_player(target)
	_send_social_state_to(actor.username)
	_send_social_state_to(t_name)
	_social_ok(json_pid, "Declined " + t_name + "'s request")

func _json_friend_cancel(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _social_err(json_pid, "Not logged in")
	if not _rate_ok(sessions.get(actor.username), "friend_mutate", 30, 60000):
		return _social_err(json_pid, "You're doing that too fast — try again shortly")
	var target_name := str(msg.get("username", "")).strip_edges()
	var target = _admin_get_target(target_name)
	if target == null:
		return _social_err(json_pid, "No player named '" + target_name + "'")
	var t_name := str(target.username)
	if t_name == actor.username:
		return _social_err(json_pid, "You can't do that to yourself")
	if not t_name in actor.friend_requests_out:
		return _social_err(json_pid, "No pending request to " + t_name)
	actor.friend_requests_out.erase(t_name)
	target.friend_requests_in.erase(actor.username)
	resave_player(actor)
	resave_player(target)
	_send_social_state_to(actor.username)
	_send_social_state_to(t_name)
	_social_ok(json_pid, "Cancelled request to " + t_name)

func _json_friend_remove(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _social_err(json_pid, "Not logged in")
	if not _rate_ok(sessions.get(actor.username), "friend_mutate", 30, 60000):
		return _social_err(json_pid, "You're doing that too fast — try again shortly")
	var target_name := str(msg.get("username", "")).strip_edges()
	var target = _admin_get_target(target_name)
	if target == null:
		return _social_err(json_pid, "No player named '" + target_name + "'")
	var t_name := str(target.username)
	if t_name == actor.username:
		return _social_err(json_pid, "You can't do that to yourself")
	if not t_name in actor.friends:
		return _social_err(json_pid, "You're not friends with " + t_name)
	actor.friends.erase(t_name)
	target.friends.erase(actor.username)
	resave_player(actor)
	resave_player(target)
	_send_social_state_to(actor.username)
	_send_social_state_to(t_name)
	_social_ok(json_pid, "Removed " + t_name)

func _json_ignore_add(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _social_err(json_pid, "Not logged in")
	if not _rate_ok(sessions.get(actor.username), "ignore_mutate", 20, 60000):
		return _social_err(json_pid, "You're doing that too fast — try again shortly")
	var target_name := str(msg.get("username", "")).strip_edges()
	if target_name == "":
		return _social_err(json_pid, "Enter a username")
	if target_name == actor.username:
		return _social_err(json_pid, "You can't ignore yourself")
	var target = _admin_get_target(target_name)
	if target == null:
		return _social_err(json_pid, "No player named '" + target_name + "'")
	var t_name := str(target.username)
	if t_name == actor.username:
		return _social_err(json_pid, "You can't ignore yourself")
	if t_name in actor.ignored:
		return _social_err(json_pid, "You're already ignoring " + t_name)
	if actor.ignored.size() >= IGNORED_CAP:
		return _social_err(json_pid, "Your ignore list is full")
	actor.ignored.append(t_name)
	# SEVER: any friendship and pending requests in BOTH directions.
	actor.friends.erase(t_name)
	target.friends.erase(actor.username)
	actor.friend_requests_in.erase(t_name)
	actor.friend_requests_out.erase(t_name)
	target.friend_requests_in.erase(actor.username)
	target.friend_requests_out.erase(actor.username)
	resave_player(actor)
	resave_player(target)
	_send_social_state_to(actor.username)
	# Refresh the target too — their friend list lost `actor`. The push is a plain
	# snapshot and never reveals it was an ignore (no distinct "you were blocked").
	_send_social_state_to(t_name)
	_social_ok(json_pid, "Ignoring " + t_name)

func _json_ignore_remove(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _social_err(json_pid, "Not logged in")
	if not _rate_ok(sessions.get(actor.username), "ignore_mutate", 20, 60000):
		return _social_err(json_pid, "You're doing that too fast — try again shortly")
	var target_name := str(msg.get("username", "")).strip_edges()
	var t_name := target_name
	var target = _admin_get_target(target_name)
	if target != null:
		t_name = str(target.username)
	# Erase the resolved canonical AND the raw typed value, so a stale entry whose
	# account was since removed can still be cleared from the ignore list.
	actor.ignored.erase(t_name)
	actor.ignored.erase(target_name)
	resave_player(actor)
	_send_social_state_to(actor.username)
	_social_ok(json_pid, "Stopped ignoring " + t_name)

# Per-player social settings (D2). Currently only allow_spectators: "all" (default) /
# "friends" / "off". The stored value rides the login player blob via Player.save(), so the
# client reads it from its player object — this endpoint only writes.
func _json_social_setting(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _social_err(json_pid, "Not logged in")
	var key := str(msg.get("key", ""))
	# Ladder bot opt-out: a plain bool preference persisted the same way as allow_spectators — written
	# only here (never from save_cosmetics), rides the login blob via Player.save(). Kept off the
	# cosmetic bridge so an out-of-date client can't reset it. No spectator-eviction side effects.
	if key == "ranked_allow_bots":
		actor.ranked_allow_bots = bool(msg.get("value", true))
		resave_player(actor)
		return _social_ok(json_pid, "Settings saved")
	var value := str(msg.get("value", ""))
	if key != "allow_spectators" or not (value in ["all", "friends", "off"]):
		return _social_err(json_pid, "Bad setting")
	actor.allow_spectators = value
	resave_player(actor)
	# Enforce the tightened policy on CURRENT watchers too: if the actor is playing right now,
	# re-check every spectator of their match against the new setting and evict the ones that no
	# longer pass ("off" evicts all; "friends" evicts non-friends). The evicted client gets a
	# spectate_result err — its handler exits the viewer.
	var m = get_session(logical_peer).current_match if get_session(logical_peer) else null
	if value != "all" and m != null and is_instance_valid(m) and actor.username in m.get_player_usernames():
		for spec_peer in m.spectators.keys().duplicate():
			var spec_name = peer_map.get(spec_peer, "")
			if spec_name == "" or not (spec_name in sessions):
				continue
			if value == "friends" and spec_name in actor.friends:
				continue
			m.remove_spectator(spec_peer)
			if sessions[spec_name].current_match == m:
				sessions[spec_name].current_match = null
			send_to_peer(spec_peer, "spectate_result", {"ok": false, "note": SPECTATE_DENY})
	_social_ok(json_pid, "Spectator setting saved")

# ============================================================================
# CHAT (Phase 2) — global / match / dm over RAM ring buffers (no durable history, D5).
# Cloned from the SOCIAL handler shape (_json_ignore_* / _social_err). Ignore is unified:
#   FANOUT  — skip any recipient who has the SENDER in their .ignored (no live delivery).
#   HISTORY — skip any message whose .from is in the VIEWER's .ignored.
#   DM send — sender ignores target -> err; target ignores sender -> record + echo, silent-drop
#             to the target (oracle-free: the sender's echo is identical whether delivered or not).
# muted senders are dropped; global has an admin kill switch (global_chat_enabled). Spectators
# are NOT chat members (D6): they can neither send to nor read the match channel.
# ============================================================================
func _chat_err(json_pid, note):
	json_gateway.send(json_pid, {"type": "chat_result", "ok": false, "note": note})

# Append to a chat ring buffer, evicting the oldest entries once over cap.
func _chat_ring_push(buf: Array, entry: Dictionary, cap: int) -> void:
	buf.append(entry)
	while buf.size() > cap:
		buf.pop_front()

# Canonical DM bucket key: the two usernames sorted and joined by "|" (order-independent).
func _dm_key(a, b) -> String:
	var pair := [str(a), str(b)]
	pair.sort()
	return pair[0] + "|" + pair[1]

# --- SPECTATOR-SAFE STRIPPING (P4) ---
# Spectator copies of the live stream hide hidden information: events the recorder tagged
# "invisible" (hidden ability uses) are dropped, and every effect whose "visibility" != "all"
# is removed from snapshot characters. Players and the replay always keep the FULL payloads
# (replays are participants-only, post-hoc reveal accepted — D3).
func _spectator_safe_events(events: Array) -> Array:
	var out := []
	for e in events:
		if e is Dictionary and e.get("invisible", false):
			continue
		out.append(e)
	return out

func _spectator_safe_snapshot(snap: Dictionary) -> Dictionary:
	var safe := snap.duplicate(true)
	for side in safe.get("sides", []):
		for snap_char in side.get("team", []):
			var visible := []
			for eff in snap_char.get("effects", []):
				if str(eff.get("visibility", "all")) == "all":
					visible.append(eff)
			snap_char["effects"] = visible
	# execution_preview labels queued casts by name ("<X>'s Damage from <Ability>") — including ones
	# sourced from invisible abilities. It only exists to seed the acting player's End-Turn reorder
	# modal, which a spectator can never open, so blank it outright rather than filter it.
	safe["execution_preview"] = []
	return safe

func _json_chat_send(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _chat_err(json_pid, "Not logged in")
	if not _rate_ok(sessions.get(actor.username), "chat", 5, 10000):
		return _chat_err(json_pid, "You're sending messages too fast — slow down")
	var text := _clean_text(msg.get("text", ""), CHAT_MAX_LEN)
	if text == "":
		return
	if actor.muted:
		return _chat_err(json_pid, "You are muted")
	var ts := int(Time.get_unix_time_from_system())
	var channel := str(msg.get("channel", ""))
	match channel:
		"global":
			if not global_chat_enabled:
				return _chat_err(json_pid, "Global chat is disabled")
			_chat_ring_push(chat_global, {"from": actor.username, "text": text, "ts": ts}, CHAT_GLOBAL_CAP)
			var g_frame := {"channel": "global", "from": actor.username, "text": text, "ts": ts}
			for g_uname in sessions:
				var gs = sessions[g_uname]
				if gs.status != ServerSession.ConnectionState.ONLINE:
					continue
				# FANOUT ignore rule: skip anyone who ignores the sender (sender never ignores self -> echoes).
				if actor.username in gs.player_data.ignored:
					continue
				send_to_peer(gs.peer_id, "chat_message", g_frame)
		"match":
			var m_session = get_session(logical_peer)
			var m = m_session.current_match if m_session else null
			if m == null or not is_instance_valid(m):
				return _chat_err(json_pid, "You're not in a match")
			# Membership (D6): only the two match participants chat here — spectators also carry a
			# current_match pointer, so exclude anyone who isn't an actual player.
			if not (actor.username in m.get_player_usernames()):
				return _chat_err(json_pid, "You're not in a match")
			var m_key := str(m.match_uid)
			if not chat_match.has(m_key):
				chat_match[m_key] = []
			_chat_ring_push(chat_match[m_key], {"from": actor.username, "text": text, "ts": ts}, CHAT_MATCH_CAP)
			var m_frame := {"channel": "match", "from": actor.username, "text": text, "ts": ts}
			# Only m.players (the two participants) — spectators are NOT chat members (D6).
			for mp in m.players.values():
				var mun = mp.username
				if not (mun in sessions):
					continue
				var ms = sessions[mun]
				if ms.status != ServerSession.ConnectionState.ONLINE:
					continue
				if actor.username in ms.player_data.ignored:
					continue
				send_to_peer(ms.peer_id, "chat_message", m_frame)
		"dm":
			var d_target = _admin_get_target(str(msg.get("to", "")))
			if d_target == null:
				return _chat_err(json_pid, "No such player")
			var d_t := str(d_target.username)
			if d_t == actor.username:
				return _chat_err(json_pid, "You can't DM yourself")
			# Sender-side ignore is own state (not an oracle): refuse to DM someone you ignore.
			if d_t in actor.ignored:
				return _chat_err(json_pid, "You're ignoring " + d_t)
			var d_key := _dm_key(actor.username, d_t)
			if not chat_dm.has(d_key):
				chat_dm[d_key] = []
			# LRU bound on the NUMBER of dm buffers: touch this key to most-recent, then evict the
			# least-recently-used keys past the cap. Without this, chat_dm grows one permanent buffer
			# per pair that ever DMed (never freed on logout/match-end) — an unbounded RAM leak.
			chat_dm_lru.erase(d_key)
			chat_dm_lru.append(d_key)
			while chat_dm.size() > MAX_DM_BUFFERS and chat_dm_lru.size() > 0:
				var evict = chat_dm_lru.pop_front()
				if evict != d_key:
					chat_dm.erase(evict)
			_chat_ring_push(chat_dm[d_key], {"from": actor.username, "to": d_t, "text": text, "ts": ts}, CHAT_DM_CAP)
			var d_frame := {"channel": "dm", "from": actor.username, "to": d_t, "text": text, "ts": ts}
			# Sender ALWAYS gets the echo (identical frame whether or not the target receives it).
			send_to_peer(logical_peer, "chat_message", d_frame)
			# Deliver to the target only if online AND they don't ignore the sender (oracle-free silent drop).
			if d_t in sessions and sessions[d_t].status == ServerSession.ConnectionState.ONLINE and not (actor.username in d_target.ignored):
				send_to_peer(sessions[d_t].peer_id, "chat_message", d_frame)
		_:
			return _chat_err(json_pid, "Unknown channel")

func _json_chat_history(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _chat_err(json_pid, "Not logged in")
	var channel := str(msg.get("channel", ""))
	var buf: Array = []
	var reply := {"type": "chat_history", "channel": channel}
	match channel:
		"global":
			buf = chat_global
		"match":
			var h_session = get_session(logical_peer)
			var m = h_session.current_match if h_session else null
			# Spectators (and no-match) read nothing (D6): only participants get match history.
			if m != null and is_instance_valid(m) and actor.username in m.get_player_usernames():
				buf = chat_match.get(str(m.match_uid), [])
		"dm":
			var h_target = _admin_get_target(str(msg.get("to", "")))
			if h_target == null:
				return _chat_err(json_pid, "No such player")
			var h_t := str(h_target.username)
			reply["to"] = h_t
			buf = chat_dm.get(_dm_key(actor.username, h_t), [])
		_:
			return _chat_err(json_pid, "Unknown channel")
	# HISTORY ignore rule: hide any message whose .from is in the VIEWER's ignore list.
	var filtered := []
	for e in buf:
		if str(e.get("from", "")) in actor.ignored:
			continue
		filtered.append({"from": e.get("from", ""), "text": e.get("text", ""), "ts": e.get("ts", 0)})
	reply["messages"] = filtered
	json_gateway.send(json_pid, reply)

# When a player becomes claned, drop any stale invites/applications they had to OTHER clans.
func _clan_purge_offers(username, keep_clan := ""):
	var touched := false
	for cn in clans:
		if cn == keep_clan:
			continue
		var clan = clans[cn]
		var changed := false
		if username in clan.invited_players:
			clan.invited_players.erase(username)
			changed = true
		if username in clan.applied_players:
			clan.applied_players.erase(username)
			changed = true
		if changed:
			save_clan(clan)
			touched = true
			# the affected clan's leaders just lost a pending offer — refresh their live panels
			for leader in clan.members.get(Clan.Rank.LEADER, []):
				_send_clan_state_to(leader)
	if touched:
		_send_clan_state_to(username)

func _json_clan_create(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	if actor.clan != "Clanless":
		return _clan_err(json_pid, "You're already in a clan")
	var name := str(msg.get("name", "")).strip_edges()
	if not _clan_name_valid(name):
		return _clan_err(json_pid, "Invalid name — 3-24 chars, letters/numbers/spaces/- _ ' only")
	if _clan_name_taken(name):
		return _clan_err(json_pid, "A clan with that name already exists")
	var clan = load("res://components/clan.tscn").instantiate()
	clan.clan_name = name
	clan.banner_url = _sanitize_banner_url(str(msg.get("banner_url", "")))
	clan.members[Clan.Rank.LEADER] = [actor.username]
	clan.members[Clan.Rank.OFFICER] = []
	clan.members[Clan.Rank.MEMBER] = []
	clan.applied_players = []
	clan.invited_players = []
	clan.wins = 0
	clan.losses = 0
	save_clan(clan)
	clans[name] = clan
	actor.clan = name
	resave_player(actor)
	_clan_purge_offers(actor.username, name)
	print("[CLAN] '", actor.username, "' created clan '", name, "'")
	_clan_ok(json_pid, "Clan '" + name + "' created")
	send_player_update(logical_peer)
	_send_clan_state_to(actor.username)

func _json_clan_search(logical_peer, json_pid, msg):
	if get_player(logical_peer) == null:
		return
	var q := str(msg.get("query", "")).strip_edges().to_lower()
	var results := []
	for cn in clans:
		if q == "" or q in str(cn).to_lower():
			results.append(_clan_summary(clans[cn]))
			if results.size() >= 40:
				break
	results.sort_custom(func(a, b): return a["members"] > b["members"])
	json_gateway.send(json_pid, {"type": "clan_search_result", "clans": results})

func _json_clan_apply(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	if actor.clan != "Clanless":
		return _clan_err(json_pid, "You're already in a clan")
	var cn := str(msg.get("clan_name", ""))
	if not cn in clans:
		return _clan_err(json_pid, "No such clan")
	var clan = clans[cn]
	if actor.username in clan.invited_players:
		return _clan_err(json_pid, "You've been invited to " + cn + " — accept the invite instead")
	if actor.username in clan.applied_players:
		return _clan_err(json_pid, "You've already applied to " + cn)
	clan.applied_players.append(actor.username)
	save_clan(clan)
	_clan_ok(json_pid, "Applied to " + cn)
	_send_clan_state_to(actor.username)
	# nudge the leader's panel if they're online
	for leader in clan.members.get(Clan.Rank.LEADER, []):
		_send_clan_state_to(leader)

func _json_clan_cancel_application(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(msg.get("clan_name", ""))
	if cn in clans and actor.username in clans[cn].applied_players:
		clans[cn].applied_players.erase(actor.username)
		save_clan(clans[cn])
		for leader in clans[cn].members.get(Clan.Rank.LEADER, []):
			_send_clan_state_to(leader)
	_clan_ok(json_pid, "Application cancelled")
	_send_clan_state_to(actor.username)

func _json_clan_invite(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(actor.clan)
	if cn == "Clanless" or not cn in clans:
		return _clan_err(json_pid, "You're not in a clan")
	var clan = clans[cn]
	if not _clan_can_manage(clan, actor.username):
		return _clan_err(json_pid, "Only the leader or an officer can invite")
	var target := str(msg.get("username", "")).strip_edges()
	if target == "":
		return _clan_err(json_pid, "Enter a username to invite")
	if target == actor.username:
		return _clan_err(json_pid, "You can't invite yourself")
	if not target in players:
		return _clan_err(json_pid, "No player named '" + target + "'")
	if players[target].clan != "Clanless":
		return _clan_err(json_pid, target + " is already in a clan")
	if target in clan.invited_players:
		return _clan_err(json_pid, target + " is already invited")
	if target in clan.applied_players:
		return _clan_err(json_pid, target + " has already requested to join — approve their request instead")
	clan.invited_players.append(target)
	save_clan(clan)
	_clan_ok(json_pid, "Invited " + target)
	_send_clan_state_to(actor.username)
	# live nudge to the invited player if online
	if target in sessions and sessions[target].status == ServerSession.ConnectionState.ONLINE:
		send_to_peer(sessions[target].peer_id, "clan_invite_notice", {"clan_name": cn})
		_send_clan_state_to(target)

func _json_clan_cancel_invite(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(actor.clan)
	if cn == "Clanless" or not cn in clans:
		return _clan_err(json_pid, "You're not in a clan")
	var clan = clans[cn]
	if not _clan_can_manage(clan, actor.username):
		return _clan_err(json_pid, "Only the leader or an officer can manage invites")
	var target := str(msg.get("username", ""))
	clan.invited_players.erase(target)
	save_clan(clan)
	_clan_ok(json_pid, "Invite to " + target + " cancelled")
	_send_clan_state_to(actor.username)
	_send_clan_state_to(target)

func _json_clan_accept_invite(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	if actor.clan != "Clanless":
		return _clan_err(json_pid, "You're already in a clan")
	var cn := str(msg.get("clan_name", ""))
	if not cn in clans:
		return _clan_err(json_pid, "That clan no longer exists")
	var clan = clans[cn]
	if not actor.username in clan.invited_players:
		return _clan_err(json_pid, "That invite is no longer valid")
	clan.invited_players.erase(actor.username)
	clan.applied_players.erase(actor.username)
	if not actor.username in clan.members.get(Clan.Rank.MEMBER, []):
		clan.members[Clan.Rank.MEMBER].append(actor.username)
	save_clan(clan)
	actor.clan = cn
	resave_player(actor)
	_clan_purge_offers(actor.username, cn)
	print("[CLAN] '", actor.username, "' joined clan '", cn, "' (invite)")
	_clan_ok(json_pid, "Joined " + cn)
	send_player_update(logical_peer)
	_send_clan_state_to(actor.username)
	for leader in clan.members.get(Clan.Rank.LEADER, []):
		_send_clan_state_to(leader)

func _json_clan_decline_invite(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(msg.get("clan_name", ""))
	if cn in clans and actor.username in clans[cn].invited_players:
		clans[cn].invited_players.erase(actor.username)
		save_clan(clans[cn])
		for leader in clans[cn].members.get(Clan.Rank.LEADER, []):
			_send_clan_state_to(leader)
	_clan_ok(json_pid, "Invite declined")
	_send_clan_state_to(actor.username)

func _json_clan_approve_application(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(actor.clan)
	if cn == "Clanless" or not cn in clans:
		return _clan_err(json_pid, "You're not in a clan")
	var clan = clans[cn]
	if not _clan_can_manage(clan, actor.username):
		return _clan_err(json_pid, "Only the leader or an officer can approve members")
	var target := str(msg.get("username", ""))
	if not target in clan.applied_players:
		return _clan_err(json_pid, "No pending application from " + target)
	clan.applied_players.erase(target)
	clan.invited_players.erase(target)   # if they were also invited, clear that too (no dangling row)
	var tp = _resolve_member_player(target)
	if tp == null or tp.clan != "Clanless":
		save_clan(clan)
		_clan_err(json_pid, target + " has already joined a clan")
		_send_clan_state_to(actor.username)
		return
	if not target in clan.members.get(Clan.Rank.MEMBER, []):
		clan.members[Clan.Rank.MEMBER].append(target)
	save_clan(clan)
	tp.clan = cn
	resave_player(tp)
	_clan_purge_offers(target, cn)
	print("[CLAN] '", actor.username, "' approved '", target, "' into '", cn, "'")
	_clan_ok(json_pid, "Accepted " + target)
	_send_clan_state_to(actor.username)
	check_for_online_player_to_update(target)
	_send_clan_state_to(target)

func _json_clan_deny_application(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(actor.clan)
	if cn == "Clanless" or not cn in clans:
		return _clan_err(json_pid, "You're not in a clan")
	var clan = clans[cn]
	if not _clan_can_manage(clan, actor.username):
		return _clan_err(json_pid, "Only the leader or an officer can deny applications")
	var target := str(msg.get("username", ""))
	clan.applied_players.erase(target)
	save_clan(clan)
	_clan_ok(json_pid, "Denied " + target)
	_send_clan_state_to(actor.username)
	_send_clan_state_to(target)

func _json_clan_kick(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(actor.clan)
	if cn == "Clanless" or not cn in clans:
		return _clan_err(json_pid, "You're not in a clan")
	var clan = clans[cn]
	if not _clan_can_manage(clan, actor.username):
		return _clan_err(json_pid, "Only the leader or an officer can remove members")
	var target := str(msg.get("username", ""))
	if target == actor.username:
		return _clan_err(json_pid, "Use Disband to remove yourself as leader" if _clan_is_leader(clan, actor.username) else "Use Leave Clan to remove yourself")
	if target in clan.members.get(Clan.Rank.LEADER, []):
		return _clan_err(json_pid, "Can't kick the leader")
	# Officers may only remove regular members — removing an officer is the leader's call.
	if not _clan_is_leader(clan, actor.username) and target in clan.members.get(Clan.Rank.OFFICER, []):
		return _clan_err(json_pid, "Only the leader can remove an officer")
	if not target in clan.all_members():
		return _clan_err(json_pid, target + " isn't in the clan")
	clan.members[Clan.Rank.OFFICER].erase(target)
	clan.members[Clan.Rank.MEMBER].erase(target)
	save_clan(clan)
	var tp = _resolve_member_player(target)
	if tp != null and tp.clan == cn:
		tp.clan = "Clanless"
		resave_player(tp)
	print("[CLAN] '", actor.username, "' kicked '", target, "' from '", cn, "'")
	_clan_ok(json_pid, "Kicked " + target)
	_send_clan_state_to(actor.username)
	check_for_online_player_to_update(target)
	_send_clan_state_to(target)

func _json_clan_promote(logical_peer, json_pid, msg):
	# Leader-only: raise a regular member to Officer. Authority re-checked HERE server-side.
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(actor.clan)
	if cn == "Clanless" or not cn in clans:
		return _clan_err(json_pid, "You're not in a clan")
	var clan = clans[cn]
	if not _clan_is_leader(clan, actor.username):
		return _clan_err(json_pid, "Only the leader can promote members to officer")
	var target := str(msg.get("username", ""))
	if target == actor.username:
		return _clan_err(json_pid, "You're the leader — you can't be an officer")
	if target in clan.members.get(Clan.Rank.OFFICER, []):
		return _clan_err(json_pid, target + " is already an officer")
	if not target in clan.members.get(Clan.Rank.MEMBER, []):
		return _clan_err(json_pid, target + " isn't a member of the clan")
	clan.change_rank(target, Clan.Rank.OFFICER)
	save_clan(clan)
	print("[CLAN] '", actor.username, "' promoted '", target, "' to Officer in '", cn, "'")
	_clan_ok(json_pid, "Promoted " + target + " to Officer")
	# Roles are shown to everyone, and the target's own controls change — refresh all online members.
	for uname in clan.all_members():
		_send_clan_state_to(uname)

func _json_clan_demote(logical_peer, json_pid, msg):
	# Leader-only: drop an Officer back to a regular member. Authority re-checked HERE server-side.
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(actor.clan)
	if cn == "Clanless" or not cn in clans:
		return _clan_err(json_pid, "You're not in a clan")
	var clan = clans[cn]
	if not _clan_is_leader(clan, actor.username):
		return _clan_err(json_pid, "Only the leader can remove officer rank")
	var target := str(msg.get("username", ""))
	if not target in clan.members.get(Clan.Rank.OFFICER, []):
		return _clan_err(json_pid, target + " isn't an officer")
	clan.change_rank(target, Clan.Rank.MEMBER)
	save_clan(clan)
	print("[CLAN] '", actor.username, "' removed officer rank from '", target, "' in '", cn, "'")
	_clan_ok(json_pid, "Removed officer rank from " + target)
	for uname in clan.all_members():
		_send_clan_state_to(uname)

func _json_clan_leave(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(actor.clan)
	if cn == "Clanless" or not cn in clans:
		return _clan_err(json_pid, "You're not in a clan")
	var clan = clans[cn]
	if actor.username in clan.members.get(Clan.Rank.LEADER, []):
		return _clan_err(json_pid, "As leader, use Disband — leaving would orphan the clan")
	clan.members[Clan.Rank.OFFICER].erase(actor.username)
	clan.members[Clan.Rank.MEMBER].erase(actor.username)
	save_clan(clan)
	actor.clan = "Clanless"
	resave_player(actor)
	print("[CLAN] '", actor.username, "' left '", cn, "'")
	_clan_ok(json_pid, "Left " + cn)
	send_player_update(logical_peer)
	_send_clan_state_to(actor.username)
	for leader in clan.members.get(Clan.Rank.LEADER, []):
		_send_clan_state_to(leader)

func _json_clan_disband(logical_peer, json_pid, msg):
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(actor.clan)
	if cn == "Clanless" or not cn in clans:
		return _clan_err(json_pid, "You're not in a clan")
	var clan = clans[cn]
	if not actor.username in clan.members.get(Clan.Rank.LEADER, []):
		return _clan_err(json_pid, "Only the leader can disband the clan")
	var affected: Array = clan.all_members().duplicate()
	for uname in affected:
		var p = _resolve_member_player(uname)
		if p != null and p.clan == cn:
			p.clan = "Clanless"
			resave_player(p)
	clans.erase(cn)
	var dir = DirAccess.open("clans")
	if dir and dir.file_exists(cn + ".dat"):
		dir.remove(cn + ".dat")
	print("[CLAN] '", actor.username, "' disbanded '", cn, "'")
	_clan_ok(json_pid, "Clan disbanded")
	for uname in affected:
		if uname == actor.username:
			send_player_update(logical_peer)
		else:
			check_for_online_player_to_update(uname)
		_send_clan_state_to(uname)

func _json_clan_reset_record(logical_peer, json_pid, msg):
	# Leader-only: zero the clan's win/loss record (and thus its win-derived level). Authority is
	# re-checked HERE server-side — the client's leader-gated button is convenience only.
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(actor.clan)
	if cn == "Clanless" or not cn in clans:
		return _clan_err(json_pid, "You're not in a clan")
	var clan = clans[cn]
	if not actor.username in clan.members.get(Clan.Rank.LEADER, []):
		return _clan_err(json_pid, "Only the leader can reset the clan's record")
	clan.wins = 0
	clan.losses = 0
	save_clan(clan)
	print("[CLAN] '", actor.username, "' reset the record of '", cn, "'")
	_clan_ok(json_pid, "Clan record reset")
	# W/L is shown to every member — refresh all online members' panels.
	for uname in clan.all_members():
		_send_clan_state_to(uname)

# Banners are rendered as an <img src> on every client, so only a plain http(s) URL of sane length is
# valid — reject data:/javascript:/other schemes and oversized strings.
func _banner_url_valid(s: String) -> bool:
	return s.length() <= 512 and (s.begins_with("http://") or s.begins_with("https://"))

# Collapse an invalid banner to blank. Used by clan CREATION only, where there's no prior picture to
# lose (the update path rejects invalid input instead — see _json_clan_set_banner).
func _sanitize_banner_url(raw) -> String:
	var banner := str(raw).strip_edges()
	if banner != "" and not _banner_url_valid(banner):
		return ""
	return banner

func _json_clan_set_banner(logical_peer, json_pid, msg):
	# Leader-only: change the clan's banner / profile picture. Authority is re-checked HERE
	# server-side — the client's leader-gated form is convenience only.
	var actor = get_player(logical_peer)
	if actor == null:
		return _clan_err(json_pid, "Not logged in")
	var cn := str(actor.clan)
	if cn == "Clanless" or not cn in clans:
		return _clan_err(json_pid, "You're not in a clan")
	var clan = clans[cn]
	if not actor.username in clan.members.get(Clan.Rank.LEADER, []):
		return _clan_err(json_pid, "Only the leader can change the clan picture")
	var raw := str(msg.get("banner_url", "")).strip_edges()
	# Reject an invalid NON-EMPTY URL and KEEP the current picture — only an explicit empty value
	# (the Remove button) clears the banner. Otherwise a malformed paste would silently wipe the
	# existing picture and falsely report "removed".
	if raw != "" and not _banner_url_valid(raw):
		return _clan_err(json_pid, "That doesn't look like a valid image URL — it must start with http:// or https://")
	clan.banner_url = raw
	save_clan(clan)
	print("[CLAN] '", actor.username, "' changed the banner of '", cn, "'")
	_clan_ok(json_pid, "Clan picture updated" if raw != "" else "Clan picture removed")
	# The banner shows in every member's clan panel AND their player-info card, so refresh both.
	for uname in clan.all_members():
		_send_clan_state_to(uname)
		if uname == actor.username:
			send_player_update(logical_peer)
		else:
			check_for_online_player_to_update(uname)

func send_clan_creation_request(clan_name, clan_avatar_url, panel):
	clan_creation_response_received.connect(panel.receive_clan_creation_response)
	rpc_id(1, "receive_clan_creation_request", multiplayer.get_unique_id(), clan_name, clan_avatar_url)



func request_clan_info(clan_name, receiver):
	print("Client requesting clan info")
	clan_info_received.connect(receiver.on_clan_info_received)
	rpc_id(1, "receive_clan_info_request", multiplayer.get_unique_id(), clan_name)



func request_clan_search(clan_search_string, receiver):
	print("Requesting a clan search!")
	clan_search_info_received.connect(receiver.receive_clan_search_info)
	rpc_id(1, "receive_clan_search_request", multiplayer.get_unique_id(), clan_search_string)
	
	

func request_player_search(player_search_string, receiver):
	player_search_info_received.connect(receiver.player_search_info_received)
	rpc_id(1, "receive_player_search_request", multiplayer.get_unique_id(), player_search_string)



func send_clan_application(clan_name, player_name):
	rpc_id(1, "receive_clan_application", multiplayer.get_unique_id(), clan_name, player_name)


func request_player_application_invite_info(player_name, panel):
	send_player_application_invite_info.connect(panel.receive_player_application_invite_info)
	rpc_id(1, "receive_player_application_invite_request", multiplayer.get_unique_id(), player_name)

func send_player_invite(clan_name, player_name):
	rpc_id(1, "receive_player_invite", multiplayer.get_unique_id(), clan_name, player_name)





func request_clan_application_invite_info(clan_name, panel):
	send_clan_application_invite_info.connect(panel.receive_clan_application_invite_info)
	rpc_id(1, "receive_clan_application_invite_request", multiplayer.get_unique_id(), clan_name)

	



func send_clan_application_cancel(clan_name, player_name):
	rpc_id(1, "receive_clan_application_cancel", multiplayer.get_unique_id(), clan_name, player_name)
	


func send_player_invitation_cancel(clan_name, player_name):
	rpc_id(1, "receive_player_invitation_cancel", multiplayer.get_unique_id(), clan_name, player_name)


func send_clan_offer_accepted(clan_name, player_name):
	rpc_id(1, "receive_clan_offer_accepted", multiplayer.get_unique_id(), clan_name, player_name)
	

func check_for_online_player_to_update(username):
	if username in sessions and sessions[username].status == ServerSession.ConnectionState.ONLINE:
		var peer_id = sessions[username].peer_id
		send_player_update(peer_id)

func receive_kick(clan_name, player_name):
	rpc_id(1, "kick_received", clan_name, player_name)


func receive_promotion(clan_name, player_name):
	rpc_id(1, "promotion_received", clan_name, player_name)

	
func receive_demotion(clan_name, player_name):
	rpc_id(1, "demotion_received", clan_name, player_name)

	
func receive_leave(clan_name, player_name):
	rpc_id(1, "leave_received", clan_name, player_name)
