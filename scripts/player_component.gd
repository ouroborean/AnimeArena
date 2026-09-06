extends Node
class_name Player

@export var team: TeamComponent
@export var _name: NameComponent
@export var rank: Rank
var clan = "Clanless"
# Server-only: username of this player's most recent LADDER opponent ("" = none, or the last ladder
# game was against a bot). Written server-side at ranked match start; used by the matchmaker to block
# two players from being paired twice in a row (see _best_gated_ranked_pair). Never client-writable.
var last_ranked_opponent = ""
var current_match
var mission_data: Dictionary
var mission_reference: Dictionary
var avatar_texture = load("res://assets/avatars/toko_toda.png")
var character_progress: CharacterProgress = CharacterProgress.new()
var waiting_for_turn = false
var username = "default_username"
var json_string
var pass_hash
var equipped_disguise = ""
var ap = 0
var enemy: bool
var avatar_url = ""
var bot_player = false
var bot_difficulty = 35
# Ultra Bot marker — a PERSISTENT, player-like bot account (see Anime Arena/Proposals/Ultra Bots).
# Unlike `bot_player` (a runtime-only flag that says "drive this seat with the AI"), is_ultra_bot is a
# DURABLE account property: it rides save()/load_player and marks the account as one of the scheduled,
# self-queuing bots. Ultra bots move REAL rating and are visible on ladders/search like any player, so
# this must NOT be exposed to opponents (kept out of display_package/public profile — the player-facing
# disguise) and must be UNFORGEABLE (server-written only; deliberately absent from absorb_cosmetic_update
# / make_cosmetic_update, same recipe as friends/muted/ranked_allow_bots). Admin surfaces MAY read it.
var is_ultra_bot = false
var title_data = ["Beta", "Tester", "The", "of", "the", "Test", "and", "Anime", "Arena", "for", "to"]
var title = ""
var unlocks = []
var equipped_character_frames = ["portrait_color_default", "portrait_color_default", "portrait_color_default"]
var equipped_action_frames = ["gamepanel_color_default", "gamepanel_color_default", "gamepanel_color_default"]
var equipped_hats = ["None", "None", "None"]
var equipped_characters = []
var equipped_mastery_profiles = []
var equipped_mastery_skins = []
var equipped_charselect_background = "background_charselect_default"
var equipped_ingame_background = "background_ingame_default"
var equipped_player_card = "playercard_color_default"
var clan_invitations = []
var clan_applications = []
# Social graph — server-written / unforgeable (like match_history). Persisted in save()/load_player
# but DELIBERATELY absent from absorb_cosmetic_update, so a client save_cosmetics can never forge them.
var friends: Array = []               # mutual usernames, cap 100
var friend_requests_in: Array = []    # usernames who have requested ME, cap 50
var friend_requests_out: Array = []   # usernames I have requested, cap 50
var ignored: Array = []               # usernames I ignore; one-way, cap 100
# Spectate privacy (D2): "all" | "friends" | "off". Server-written via the dedicated
# "social_setting" message ONLY — deliberately NOT absorbed from save_cosmetics
# (absent from absorb_cosmetic_update / make_cosmetic_update), same unforgeable
# recipe as friends/ignored. Rides the login player blob via save().
var allow_spectators: String = "all"
var bot_turn_delay = 5
var bot_queue_delay = 15
# Ladder opt-out: when false the ranked bot fallback will not seat this player against a bot. They
# stay in the queue instead, which means accepting whatever rating gap the gate bands eventually
# allow — see _start_ranked_bot_fallback. Default true (bots on) so nothing changes for anyone who
# never touches the setting.
# Written ONLY via the dedicated "social_setting" message (like allow_spectators) — deliberately NOT
# absorbed from save_cosmetics (absent from absorb_cosmetic_update / make_cosmetic_update). An
# out-of-date client whose cosmetic payload omits the field would otherwise reset it to the default
# on every equip. The stored value still rides the login blob via save()/load_player.
var ranked_allow_bots = true
var cosmetics_on = false
var muted = false
var mark_significant = true
var animations_enabled = true
var bounty_rerolls = {}
var active_bounties = {

}
# Campaign progress blob (chapter, node, stage, flags, visited, completed activations, party,
# vessel loadout, etc.). Client-written progress persisted alongside cosmetics (like active_bounties);
# character unlocks still go to the server-authoritative `unlocks`. See .claude/plans/campaign-mode.md.
var campaign_state = {}
# Server-authoritative recent-match history (ring buffer, newest last). Written ONLY in
# handle_server_match_ended (like wins/losses) — never absorbed from a client cosmetic update, so it
# can't be forged. Each entry: {result, opponent, mode, my_team[], opp_team[], date}.
var match_history: Array = []


func get_bounty_rerolls(path_name):
	# Guard against a corrupted bounty_rerolls (a client once sent 0 as the default, storing a
	# float) — otherwise `path_name in <float>` throws and breaks the bounty panel + match-end
	# progression for that player until they re-save.
	if not (bounty_rerolls is Dictionary) or not (path_name in bounty_rerolls):
		return 0
	return int(bounty_rerolls[path_name])

func check_all_bounties(own_team, enemy_team):
	for bounty_path in active_bounties:
		var bounty_type = "unlock"
		var raw_path = bounty_path
		if bounty_path.ends_with(Bounty.MASTERY_SUFFIX):
			bounty_type = "mastery"
			raw_path = bounty_path.trim_suffix(Bounty.MASTERY_SUFFIX)
		var bounty = Bounty.get_bounty(username, raw_path, str(get_bounty_rerolls(bounty_path)), bounty_type)
		var bounty_results = bounty.check_bounty_progress(own_team, enemy_team)
		for i in range(25):
			active_bounties[bounty_path][i] += bounty_results[i]
			if active_bounties[bounty_path][i] > bounty.missions[i][2]:
				active_bounties[bounty_path][i] = bounty.missions[i][2]
	

func set_mission_diff():
	pass

func get_mission_delta():
	return {}


# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	

# A bot seat that still gets the THROWAWAY treatment at match-end (capped/scaled rating, no persist,
# freed after the match): the EPHEMERAL 30s-fallback bot. An ULTRA bot is a durable account that moves
# REAL rating and persists like a human, so it is NOT ephemeral. A human is obviously not ephemeral.
# (P7 — Ultra Bots full-rating reconciliation.)
func is_ephemeral_bot() -> bool:
	return bot_player and not is_ultra_bot

func save():
	var data = {}
	data['username'] = username
	data['wins'] = rank.wins
	data['losses'] = rank.losses
	data['rank'] = rank.rank
	data['tier'] = rank.rank_tier
	data['title'] = title
	data['muted'] = muted
	data['hats'] = equipped_hats
	data['character_frames'] = equipped_character_frames
	data['action_frames'] = equipped_action_frames
	data['streak'] = rank.streak
	data['ranked_streak'] = rank._ranked_streak
	data['rp'] = rank._rp
	data['missions'] = {}
	data['charselect_background'] = equipped_charselect_background
	data['ingame_background'] = equipped_ingame_background
	data['ap'] = ap
	data['cosmetics_on'] = cosmetics_on
	data['bot_turn_delay'] = bot_turn_delay
	data['bot_queue_delay'] = bot_queue_delay
	data['ranked_allow_bots'] = ranked_allow_bots
	data['unlocks'] = unlocks
	data['avatar_url'] = avatar_url
	data['player_card'] = equipped_player_card
	if len(equipped_characters) > 3:
		equipped_characters = equipped_characters.slice(0, 3)
	data['characters'] = equipped_characters
	data['mastery_profiles'] = equipped_mastery_profiles
	data['mastery_skins'] = equipped_mastery_skins
	data['clan'] = clan
	#for mission_id in mission_data.keys():
	#	data['missions'][mission_id] = {}
	#	for obj_id in mission_data[mission_id].keys():
	#		data['missions'][mission_id][obj_id] = mission_data[mission_id][obj_id]
	data['rating'] = rank.get_rating()
	data['bounty_rerolls'] = bounty_rerolls
	data['active_bounties'] = active_bounties
	data['mark_significant'] = mark_significant
	data['animations_enabled'] = animations_enabled
	data['mastery_xp'] = character_progress.to_dict()
	data['campaign_state'] = campaign_state
	data['match_history'] = match_history
	data['friends'] = friends
	data['friend_requests_in'] = friend_requests_in
	data['friend_requests_out'] = friend_requests_out
	data['ignored'] = ignored
	data['allow_spectators'] = allow_spectators
	data['last_ranked_opponent'] = last_ranked_opponent
	data['is_ultra_bot'] = is_ultra_bot
	return data

func display_package():
	var data = {}
	data['username'] = username
	data['wins'] = rank.wins
	data['losses'] = rank.losses
	data['rank'] = rank.rank
	data['streak'] = rank.streak
	data['tier'] = rank.rank_tier
	data['rating'] = rank.get_rating()
	data['character_frames'] = equipped_character_frames
	data['action_frames'] = equipped_action_frames
	data['hats'] = equipped_hats
	data['mastery_profiles'] = equipped_mastery_profiles
	data['mastery_skins'] = equipped_mastery_skins
	if len(equipped_characters) > 3:
		equipped_characters = equipped_characters.slice(0, 3)
	data['characters'] = equipped_characters
	data['cosmetics_on'] = cosmetics_on
	data['title'] = title
	data['avatar_url'] = avatar_url

	data['clan'] = clan

	data['player_card'] = equipped_player_card
	return data

func absorb_cosmetic_update(data):
	# `muted` is a server-only moderation field (admin mute/unmute) — deliberately NOT absorbed from a
	# client save_cosmetics payload, so a modified client can't clear its own mute. Same unforgeable
	# recipe as friends/ignored (server-written; save()/load only).
	equipped_character_frames = data['character_frames']
	equipped_action_frames = data['action_frames']
	equipped_hats = data['hats']
	equipped_characters = data['characters']
	equipped_mastery_profiles = data['mastery_profiles']
	equipped_mastery_skins = data['mastery_skins']
	equipped_ingame_background = data['ingame_background']
	equipped_charselect_background = data['charselect_background']
	title = data['title']
	unlocks = data['unlocks']
	ap = data['ap']
	clan = data['clan']
	cosmetics_on = data['cosmetics_on']
	bot_turn_delay = data['bot_turn_delay']
	bot_queue_delay = data['bot_queue_delay']
	# ranked_allow_bots is NOT absorbed here — it's a server-written setting (social_setting), so a
	# client save_cosmetics payload can't set OR reset it. See the var declaration for the rationale.
	equipped_player_card = data['player_card']
	avatar_url = data['avatar_url']
	# wins, losses, and rating are server-authoritative (updated in
	# send_match_ending) — do not overwrite them from the client
	# Coerce to Dictionary — a client bug could send 0 / [] here; storing those corrupts the
	# player (crash on get_bounty_rerolls / wiped bounties). This also heals an already-corrupted
	# player on their next save.
	bounty_rerolls = data['bounty_rerolls'] if data['bounty_rerolls'] is Dictionary else {}
	active_bounties = data['active_bounties'] if data['active_bounties'] is Dictionary else {}
	# campaign_state is server-authoritative: it is mutated ONLY by the campaign_* intent
	# handlers in server_connection.gd, never absorbed from a client cosmetic update. It still
	# round-trips to disk (save/load_player) and out to the client (make_cosmetic_update).
	mark_significant = data['mark_significant']
	if 'animations_enabled' in data:
		animations_enabled = data['animations_enabled']
	if 'mastery_xp' in data:
		character_progress.from_dict(data['mastery_xp'])


func make_cosmetic_update():
	var data = {}
	data['muted'] = muted
	data['character_frames'] = equipped_character_frames
	data['action_frames'] = equipped_action_frames
	data['hats'] = equipped_hats
	data['characters'] = equipped_characters
	data['mastery_profiles'] = equipped_mastery_profiles
	data['mastery_skins'] = equipped_mastery_skins
	data['ingame_background'] = equipped_ingame_background
	data['charselect_background'] = equipped_charselect_background
	data['title'] = title
	data['unlocks'] = unlocks
	data['ap'] = ap
	data['clan'] = clan
	data['cosmetics_on'] = cosmetics_on
	data['bot_turn_delay'] = bot_turn_delay
	data['bot_queue_delay'] = bot_queue_delay
	# ranked_allow_bots deliberately omitted (like allow_spectators) — it is server-written and rides
	# the login blob via save(), not the cosmetic echo.
	data['player_card'] = equipped_player_card
	data['avatar_url'] = avatar_url
	data['bounty_rerolls'] = bounty_rerolls
	data['active_bounties'] = active_bounties
	data['mark_significant'] = mark_significant
	data['animations_enabled'] = animations_enabled
	data['mastery_xp'] = character_progress.to_dict()
	data['campaign_state'] = campaign_state
	return data

func make_mission_update():
	var data = {
		'missions':{}
	}
	for mission_id in mission_data.keys():
		data['missions'][mission_id] = {}
		for obj_id in mission_data[mission_id].keys():
			data['missions'][mission_id][obj_id] = mission_data[mission_id][obj_id]
	return data

func absorb_mission_update(data):
	for mission_id in data['missions'].keys():
		mission_data[mission_id] = {}
		for obj_id in data['missions'][mission_id].keys():
			if obj_id is String:
				mission_data[mission_id][obj_id] = data['missions'][mission_id][obj_id]

static func load_display_player(data):
	var player = load("res://components/player_component.tscn").instantiate()
	player.set_username(data['username'])
	player.username = data['username']
	player.equipped_character_frames = data['character_frames']
	player.equipped_action_frames = data['action_frames']
	player.equipped_hats = data['hats']
	player.equipped_mastery_profiles = data['mastery_profiles']
	player.equipped_mastery_skins = data['mastery_skins']
	player.equipped_characters = data['characters']
	player.title = data['title']
	player.cosmetics_on = data['cosmetics_on']
	# data['tier'] is display-only now — the live tier is derived from rating, so loading it would
	# just be overwritten by the getter. Kept in the payload for older clients.
	player.avatar_url = data['avatar_url']
	player.clan = data['clan']
	player.rank.wins = data['wins']
	player.rank.losses = data['losses']
	player.equipped_player_card = data['player_card']
	player.rank.set_values(data['wins'], data['losses'], data['streak'], data['rating'])
	return player



static func load_player(data):
	var player = load("res://components/player_component.tscn").instantiate()
	player.username = data['username']
	player.set_username(data['username'])
	player.rank.wins = data['wins']
	player.rank.losses = data['losses']
	# data['rank'] / data['tier'] are NOT loaded: the badge is derived from rating on every read
	# (Rank.tier_for_rating), so a saved tier could only ever disagree with it. They stay in the
	# save file as a human-readable record of where the account stood.
	player.title = data['title']
	player.equipped_character_frames = data['character_frames']
	player.equipped_action_frames = data['action_frames']
	player.rank.streak = data['streak']
	player.rank._rp = data['rp']
	player.rank._ranked_streak = data['ranked_streak']
	player.avatar_url = data['avatar_url']
	var rating = 0
	if "rating" in data:
		rating = data['rating']
	player.rank.set_values(data['wins'], data['losses'], data['streak'], rating)
	if not "muted" in data:
		player.muted = false
	else:
		player.muted = data['muted']
	if not "player_card" in data:
		player.equipped_player_card = "playercard_color_default"
	else:
		player.equipped_player_card = data["player_card"]
	if not "clan_invitations" in data:
		player.clan_invitations = []
	else:
		player.clan_invitations = data['clan_invitations']
	if not "clan_applications" in data:
		player.clan_applications = []
	else:
		player.clan_applications = data['clan_applications']
	
	if not "clan" in data:
		player.clan = "Clanless"
	else:
		player.clan = data['clan']

	if not "cosmetics_on" in data:
		player.cosmetics_on = false
	else:
		player.cosmetics_on = data['cosmetics_on']
	if not "ap" in data:
		player.ap = 0
	else:
		player.ap = data['ap']
	if not "unlocks" in data:
		player.unlocks = []
	else:
		player.unlocks = data['unlocks']
	if not "hats" in data:
		player.equipped_hats = ["None", "None", "None"]
	else:
		player.equipped_hats = data['hats']
	if not "mastery_skins" in data:
		player.equipped_mastery_skins = []
	else:
		player.equipped_mastery_skins = data['mastery_skins']
	if not "mastery_profiles" in data:
		player.equipped_mastery_profiles = []
	else:
		player.equipped_mastery_profiles = data['mastery_profiles']
	if not "characters" in data:
		player.equipped_characters = []
	else:
		if len(data["characters"]) > 3:
			data["characters"] = data["characters"].slice(0, 3)
		player.equipped_characters = data["characters"]
	if not "bot_queue_delay" in data:
		player.bot_queue_delay = 15
	else:
		player.bot_queue_delay = data['bot_queue_delay']
	# Absent on every save written before the setting existed -> bots stay ON.
	player.ranked_allow_bots = bool(data.get('ranked_allow_bots', true))
	if not "bot_turn_delay" in data:
		player.bot_turn_delay = 5
	else:
		player.bot_turn_delay = data['bot_turn_delay']
	if not "ingame_background" in data:
		player.equipped_ingame_background = "background_ingame_default"
	else:
		player.equipped_ingame_background = data['ingame_background']
	if not "charselect_background" in data:
		player.equipped_charselect_background = "background_charselect_default"
	else:
		player.equipped_charselect_background = data['charselect_background']
	if not "bounty_rerolls" in data:
		player.bounty_rerolls = {}
	else:
		player.bounty_rerolls = data['bounty_rerolls']
	if not "active_bounties" in data:
		player.active_bounties = {}
	else:
		player.active_bounties = data['active_bounties']
	if not "campaign_state" in data or not (data['campaign_state'] is Dictionary):
		player.campaign_state = {}
	else:
		player.campaign_state = data['campaign_state']
	if not "match_history" in data or not (data['match_history'] is Array):
		player.match_history = []
	else:
		player.match_history = data['match_history']
	if not "friends" in data or not (data['friends'] is Array):
		player.friends = []
	else:
		player.friends = data['friends']
	if not "friend_requests_in" in data or not (data['friend_requests_in'] is Array):
		player.friend_requests_in = []
	else:
		player.friend_requests_in = data['friend_requests_in']
	if not "friend_requests_out" in data or not (data['friend_requests_out'] is Array):
		player.friend_requests_out = []
	else:
		player.friend_requests_out = data['friend_requests_out']
	if not "ignored" in data or not (data['ignored'] is Array):
		player.ignored = []
	else:
		player.ignored = data['ignored']
	# Back-compat: pre-spectate saves lack the key; also heal any invalid value.
	if not "allow_spectators" in data or not (data['allow_spectators'] in ["all", "friends", "off"]):
		player.allow_spectators = "all"
	else:
		player.allow_spectators = data['allow_spectators']
	player.last_ranked_opponent = str(data.get('last_ranked_opponent', ''))   # back-compat: absent -> "" (no block)
	player.is_ultra_bot = bool(data.get('is_ultra_bot', false))   # back-compat: absent -> a normal human account
	if not "mark_significant" in data:
		player.mark_significant = true
	else:
		player.mark_significant = data["mark_significant"]
	if not "animations_enabled" in data:
		player.animations_enabled = true
	else:
		player.animations_enabled = data["animations_enabled"]
	if "mastery_xp" in data:
		player.character_progress.from_dict(data['mastery_xp'])
	player.sanitize_old_equipped_cosmetics()
	player.mission_data = {}
	#for mission_id in data['missions'].keys():
	#	player.mission_data[mission_id] = {}
	#	for obj_id in data['missions'][mission_id].keys():
	#		if obj_id is String:
	#			player.mission_data[mission_id][obj_id] = data['missions'][mission_id][obj_id]
	#for path_name in CharacterDatabase.char_name_list():
	#	for i in range(10):
	#		var mission_id = path_name + "_mastery" + str(i + 1)
	#		if not mission_id in player.mission_data:
	#			player.mission_data[mission_id] = {}
	#			player.mission_data[mission_id][mission_id + "_0"] = 0
	return player

static func new_gen(username, pass_hash, mission_ref):
	var player = load("res://components/player_component.tscn").instantiate()
	player.mission_data = {}
	player.ap = 25000   # welcome bonus: new accounts start with 25,000 AP
	#player.mission_reference = mission_ref
	#for mission_id in player.mission_reference.keys():
	#	player.mission_data[mission_id] = {}
	#	for obj in player.mission_reference[mission_id].objectives:
	#		player.mission_data[mission_id][obj.obj_id] = 0
		
	return player

func compare_mission_reference():
	print("Comparing mission reference")
	#for mission_id in mission_reference:
	#	print("Checking mission_id " + mission_id)
	#	if not mission_id in mission_data:
	#		print("mission ID " + mission_id + " not in data. Adding now.")
	#		mission_data[mission_id] = {}
	#		for obj in mission_reference[mission_id].objectives:
	#			mission_data[mission_id][obj.obj_id] = 0

func fetch_avatar_texture():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", avatar_fetch_completed)
	
	# Perform the HTTP request. The URL below returns a PNG image as of writing.
	var error = http_request.request(avatar_url)

func avatar_fetch_completed(result, response_code, headers, body):
	var image = Image.new()
	var error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")
		avatar_url = ""
		avatar_texture = load("res://assets/avatars/angy_wendy.png")
	else:
		var texture = ImageTexture.new().create_from_image(image)
		avatar_texture = texture

func sanitize_old_equipped_cosmetics():
	var new_hats = []
	var new_portraits = []
	var new_gamepanels = []
	for hat in equipped_hats:
		if "res://" in hat:
			new_hats.append("None")
		else:
			new_hats.append(hat)
	for portrait in equipped_character_frames:
		if "res://" in portrait:
			new_portraits.append("portrait_color_default")
		else:
			new_portraits.append(portrait)
	for gamepanel in equipped_action_frames:
		if "res://" in gamepanel:
			new_gamepanels.append("gamepanel_color_default")
		else:
			new_gamepanels.append(gamepanel)
	equipped_hats = new_hats
	equipped_character_frames = new_portraits
	equipped_action_frames = new_gamepanels

func set_username(user_name):
	username = user_name
	_name.change_name(user_name)

func gain_ap(amount):
	ap += amount

func contribute_ap(amount):
	ap -= amount

func equip_mastery_profile(char_name):
	print("Equipping mastery profile: " + char_name)
	if not char_name in equipped_mastery_profiles:
		equipped_mastery_profiles.append(char_name)

func remove_mastery_profile(char_name):
	if char_name in equipped_mastery_profiles:
		equipped_mastery_profiles.erase(char_name)

func remove_mastery_skin(char_name):
	if char_name in equipped_mastery_skins:
		equipped_mastery_skins.erase(char_name)

func equip_mastery_skin(char_name):
	print("Equipping mastery skin: " + char_name)
	if not char_name in equipped_mastery_skins:
		equipped_mastery_skins.append(char_name)

func set_avatar(avatar_name):
	avatar_texture = load("res://assets/avatars/" + avatar_name)

func recruit_character(character, enemy=false):
	character.enemy = enemy
	if len(equipped_characters) < 3:
		equipped_characters.append(character.path_name)
	team.add_character(character)

func remove_character(char_name):
	for character in team.characters:
		if character.path_name == char_name:
			equipped_characters.erase(char_name)
			team.remove_character(character)
			return

func request_new_mission_data():
	#mission_data = Mission.initial_mission_status()
	mission_reference = {}
	print("Loading with mission reference: " + str(mission_reference))

func mission_complete(mission_id):
	var mission = mission_reference[mission_id]
	return mission.completed(self)

func perform_turn(battle):
	#TODO add check for bot-player specific behavior
	
	var ticking_information = battle.get_ticking_effect_information(battle.waiting_for_turn)
	for key in ticking_information.keys():
		battle.execution_order[key] = ticking_information[key]
		battle.true_execution_order.append(key)
	var breakout = 0
	while true:
		breakout += 1
		if breakout > 100:
			break
		var actions = get_team_actions()
		if len(actions) <= 0:
			break
		var sort_func = func (a, b):
			return a[0] > b[0]
		actions.sort_custom(sort_func)
		var user = actions[0][1][0]
		var action = actions[0][1][1]
		var targets = actions[0][1][2]
		actions.pop_front()
		if action is String:
			user.bot_acted = true
		else:
			user.targeter.targets = targets
			if targets != []:
				user.targeter.main_target = targets[0]
			user.used_ability = action
			var cost = action.cost()
			
			battle.execute_ability(action)
			#Spend specific energy for the ability
			for energy_type in cost.keys():
				if not energy_type == Energy.Type.RANDOM:
					team.change_energy(energy_type, -cost[energy_type])
			if Energy.Type.RANDOM in cost.keys():
				var limit = cost[Energy.Type.RANDOM]
				while limit > 0:
					if team.energy.total_available() == 0:
						break
					#TODO Consider the team when spending random energy
					var random_roll = battle.roll(0, 3)
					if team.energy.pool[random_roll] > 0:
						team.change_energy(random_roll, -1)
						limit -= 1
			user.bot_acted = true
	
	battle.start_round_loop()
	battle.reset_character_targeted()
	#TODO turn end stuff

## Highest total energy cost among the abilities a character can currently
## use. Used to order character turns: characters with expensive ready
## options act first so they claim energy before cheap-utility teammates
## spend it. Characters with no usable abilities (or only cooldown-locked
## ones) sort to the bottom (cost 0). Doesn't probe valid targets — an
## ability that's "usable" but has no targets won't actually consume energy
## anyway, so the ordering is harmless.
static func _max_usable_cost(character) -> int:
	var max_cost: int = 0
	for ability in character.moveset.get_active_abilities(character):
		if not ability.usable(character):
			continue
		if not ability.extra_usable(character):
			continue
		var cost = ability.cost()
		var total: int = 0
		for k in cost:
			total += int(cost[k])
		if total > max_cost:
			max_cost = total
	return max_cost


# ── Contextual bot action mixture ──
# Cumulative thresholds for randf() — each band's width is the probability
# of that mode. Ordered so a single dice roll dispatches to one branch.
#   [0.00, 0.05) → PASS      ( 5% — bot does nothing this turn)
#   [0.05, 0.10) → RANDOM    ( 5% — uniform-random ability AND target)
#   [0.10, 0.40) → EXPENSIVE (30% — highest-cost ability, model-best target)
#   [0.40, 0.70) → PRIORITY  (30% — old game priority-bot decision-making)
#   [0.70, 1.00) → BEST      (30% — contextual model's argmax ability+target)
# Five modes give the bot more texture: deliberate optimal play, "save your
# big skill" pressure, the legacy priority logic for diversity, occasional
# pure randomness, and the rare "indecision" pass — all on a single roll.
const _MIX_PASS_UPPER := 0.01
const _MIX_RANDOM_UPPER := 0.02
const _MIX_EXPENSIVE_UPPER := 0.03
const _MIX_PRIORITY_MODEL := 0.30

## Pick the most expensive usable ability (highest total energy cost).
## Random tiebreak on cost. Returns [ability, valid_targets].
static func _argmax_cost_ability(usable_with_targets: Array) -> Array:
	var max_cost: int = -1
	var best_indices: Array = []
	for i in range(usable_with_targets.size()):
		var ab = usable_with_targets[i][0]
		var cost = ab.cost()
		var total: int = 0
		for k in cost:
			total += int(cost[k])
		if total > max_cost:
			max_cost = total
			best_indices = [i]
		elif total == max_cost:
			best_indices.append(i)
	var idx = best_indices[randi() % best_indices.size()]
	return usable_with_targets[idx]


## Pick the highest-scoring usable ability per the contextual model.
## Random tiebreak on score. Returns [ability, valid_targets, features_used].
static func _argmax_model_ability(character, battle, model, usable_with_targets: Array) -> Array:
	var best_score = null
	var best_indices: Array = []
	var features_cache: Array = []
	for i in range(usable_with_targets.size()):
		var ab = usable_with_targets[i][0]
		var features = BotContextualModel.extract_ability_features(character, battle, ab)
		features_cache.append(features)
		var score = model.get_ability_score(character.path_name, ab.ability_name, features)
		if best_score == null or score > best_score:
			best_score = score
			best_indices = [i]
		elif score == best_score:
			best_indices.append(i)
	var idx = best_indices[randi() % best_indices.size()]
	return [usable_with_targets[idx][0], usable_with_targets[idx][1], features_cache[idx]]


## Pick the highest-scoring target for a given ability per the contextual
## model. Random tiebreak on score. Returns [target, target_features].
static func _argmax_model_target(character, battle, model, chosen_ability, valid_targets: Array) -> Array:
	var best_score = null
	var best_indices: Array = []
	var features_cache: Array = []
	for i in range(valid_targets.size()):
		var t = valid_targets[i]
		var features = BotContextualModel.extract_target_features(character, t, battle, chosen_ability)
		features_cache.append(features)
		var score = model.get_target_score(character.path_name, chosen_ability.ability_name, features)
		if best_score == null or score > best_score:
			best_score = score
			best_indices = [i]
		elif score == best_score:
			best_indices.append(i)
	var idx = best_indices[randi() % best_indices.size()]
	return [valid_targets[idx], features_cache[idx]]


## Highest contextual-model score across a character's currently-usable
## abilities. Returns null if the character has no usable ability with a
## valid target — those characters sort to the bottom of action order
## (they're passing anyway). Used as the ordering criterion for
## perform_turn_contextual when a model is present: highest-confidence
## action goes first, regardless of cost. Replaces the cost-based proxy
## with the model's actual preference signal.
static func _best_ability_score(character, battle, model) -> Variant:
	var best_score = null
	for ability in character.moveset.get_active_abilities(character):
		if not ability.usable(character):
			continue
		if not ability.extra_usable(character):
			continue
		# Cheap viability check: does this ability have any valid target?
		# We don't bother caching this; it'll be re-probed by the real pick
		# inside _contextual_bot_act. Roughly doubles per-turn extraction
		# cost (~600 vs 300 ops/turn) — negligible in practice.
		ability.target(character, battle)
		var has_target := false
		for c in battle.all_characters():
			if c.targeted:
				has_target = true
				break
		for c in battle.all_characters():
			c.set_untargeted()
		if not has_target:
			continue
		var features = BotContextualModel.extract_ability_features(character, battle, ability)
		var score = model.get_ability_score(character.path_name, ability.ability_name, features)
		if best_score == null or score > best_score:
			best_score = score
	return best_score


## Random/trained bot turn: each character picks an ability and target.
## When training_data is provided, choices are weighted by historical win
## rates; otherwise falls back to uniform random.
## side: identifies this player's team in the training data (0 or 1).
func perform_turn_random(battle, training_data = null, side: int = 0):
	var ticking_information = battle.get_ticking_effect_information(battle.waiting_for_turn)
	for key in ticking_information.keys():
		battle.execution_order[key] = ticking_information[key]
		battle.true_execution_order.append(key)

	# Same ordering rule as perform_turn_contextual: expensive-need characters
	# claim energy first. Keeps random/training and contextual behavior
	# consistent so eval comparisons aren't muddied by different action orders.
	var ordered = team.characters.duplicate()
	ordered.sort_custom(func(a, b): return _max_usable_cost(a) > _max_usable_cost(b))
	for character in ordered:
		if character.dead or character.banished or character.bot_acted:
			continue
		_random_bot_act(character, battle, training_data, side)

	battle.start_round_loop()


func _random_bot_act(character, battle, training_data = null, side: int = 0):
	var has_data := training_data != null
	var tag := "[train]" if has_data else "[random-bot]"
	#print("%s === %s ===" % [tag, character.character_name])

	# Step 1: discover which abilities are usable and their valid targets
	var abilities = character.moveset.get_active_abilities(character)
	var usable_with_targets: Array = []   # [[ability, [targets]], ...]

	for ability in abilities:
		if not ability.usable(character):
			#print("%s   %s — not usable (cost/cooldown/state)" % [tag, ability.ability_name])
			continue
		if not ability.extra_usable(character):
			#print("%s   %s — not usable (extra condition)" % [tag, ability.ability_name])
			continue

		# Step 2: probe which characters are valid targets for this ability
		ability.target(character, battle)
		var valid_targets: Array = []
		for c in battle.all_characters():
			if c.targeted:
				valid_targets.append(c)
		for c in battle.all_characters():
			c.set_untargeted()

		if valid_targets.size() > 0:
			if has_data:
				var ab_score = training_data.get_ability_score(
					character.path_name, ability.ability_name)
				var ab_stats = training_data.get_ability_stats(
					character.path_name, ability.ability_name)
				var uses_str := "%dW/%dU" % [ab_stats.wins, ab_stats.uses] if ab_stats else "new"
				var target_parts: Array = []
				for t in valid_targets:
					var ts = training_data.get_target_score(
						character.path_name, ability.ability_name, t.path_name)
					target_parts.append("%s(%.2f)" % [t.character_name, ts])
				#print("%s   %s — score %.2f (%s), targets: %s" % [
					#tag, ability.ability_name, ab_score, uses_str,
					#", ".join(target_parts)])
			else:
				var names: Array = []
				for t in valid_targets:
					names.append(t.character_name)
				#print("%s   %s — usable, %d target(s): %s" % [
					#tag, ability.ability_name, valid_targets.size(),
					#", ".join(names)])
			usable_with_targets.append([ability, valid_targets])
		else:
			#print("%s   %s — usable but no valid targets" % [tag, ability.ability_name])
			pass

	# Step 3: if nothing is usable, pass
	if usable_with_targets.is_empty():
		#print("%s   -> PASS (nothing usable with valid targets)" % tag)
		character.bot_acted = true
		return

	# Step 4: pick an ability — weighted by training data or uniform random
	var chosen_ability: Ability
	var valid_targets: Array
	if has_data:
		var weights: Array = []
		for pair in usable_with_targets:
			weights.append(training_data.get_ability_score(
				character.path_name, pair[0].ability_name))
		var idx := _weighted_pick(weights)
		chosen_ability = usable_with_targets[idx][0]
		valid_targets = usable_with_targets[idx][1]
	else:
		var pick = usable_with_targets[randi() % usable_with_targets.size()]
		chosen_ability = pick[0]
		valid_targets = pick[1]

	# Step 5: pick a primary target — weighted or uniform
	var primary_target
	if has_data:
		var tw: Array = []
		for t in valid_targets:
			tw.append(training_data.get_target_score(
				character.path_name, chosen_ability.ability_name, t.path_name))
		var tidx := _weighted_pick(tw)
		primary_target = valid_targets[tidx]
		if BotContextualModel.verbose_logging:
			print("%s   -> %s [%.2f] -> %s [%.2f]" % [
				tag, chosen_ability.ability_name,
				training_data.get_ability_score(character.path_name, chosen_ability.ability_name),
				primary_target.character_name,
				training_data.get_target_score(character.path_name, chosen_ability.ability_name, primary_target.path_name)])
	else:
		primary_target = valid_targets[randi() % valid_targets.size()]
		if BotContextualModel.verbose_logging:
			print("%s   -> chose %s targeting %s" % [
				tag, chosen_ability.ability_name, primary_target.character_name])

	# Step 6: wire up the targeter
	character.targeter.targets = [primary_target]
	character.targeter.main_target = primary_target
	character.used_ability = chosen_ability

	# Re-mark targets so get_other_aoe_targets can see who is valid
	chosen_ability.target(character, battle)

	# Step 7: resolve AoE — add other valid targets based on target type
	var ttype = chosen_ability.target_type()
	if ttype == TargetType.Type.ALL:
		battle.get_other_aoe_targets(character, primary_target, false, chosen_ability.and_targeter)
	elif ttype == TargetType.Type.ALL_FACTION:
		battle.get_other_aoe_targets(character, primary_target, true, chosen_ability.and_targeter)
	elif chosen_ability.and_targeter:
		battle.get_other_aoe_targets(character, primary_target, false, true)

	if character.targeter.targets.size() > 1 and BotContextualModel.verbose_logging:
		var aoe_names: Array = []
		for t in character.targeter.targets:
			aoe_names.append(t.character_name)
		print("%s   -> AoE resolved, full targets: %s" % [tag, ", ".join(aoe_names)])

	# Clear targeted flags after resolution
	for c in battle.all_characters():
		c.set_untargeted()

	# Record the action for training
	if has_data:
		training_data.record_action(side, character.path_name,
			chosen_ability.ability_name, primary_target.path_name)

	# Step 8: execute the ability and spend energy
	var cost = chosen_ability.cost()
	battle.execute_ability(chosen_ability)

	for energy_type in cost.keys():
		if not energy_type == Energy.Type.RANDOM:
			team.change_energy(energy_type, -cost[energy_type])
	if Energy.Type.RANDOM in cost.keys():
		var limit = cost[Energy.Type.RANDOM]
		while limit > 0:
			if team.energy.total_available() == 0:
				break
			var random_roll = battle.roll(0, 3)
			if team.energy.pool[random_roll] > 0:
				team.change_energy(random_roll, -1)
				limit -= 1

	character.bot_acted = true


## Weighted random pick — returns an index. Weights don't need to sum to 1.
static func _weighted_pick(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return randi() % weights.size()
	var roll := randf() * total
	var cumulative := 0.0
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return i
	return weights.size() - 1


## Contextual-bandits bot turn: uses board-state features to weight decisions.
## model: a BotContextualModel instance (or null for uniform random fallback).
## side: identifies this player's team in the model (0 or 1).
func perform_turn_contextual(battle, model = null, side: int = 0):
	var ticking_information = battle.get_ticking_effect_information(battle.waiting_for_turn)
	for key in ticking_information.keys():
		battle.execution_order[key] = ticking_information[key]
		battle.true_execution_order.append(key)

	# Score-based ordering: characters whose model-preferred action has the
	# highest score act first. Letting the model's own judgment drive order
	# (rather than a "max cost" proxy) avoids a side effect we saw with the
	# proxy where expensive-having characters claimed energy that an impactful
	# 1-cost on a teammate needed. If no model is supplied (random fallback
	# path), use cost-based ordering as before.
	var ordered = team.characters.duplicate()
	if model != null:
		var score_cache: Dictionary = {}
		for c in ordered:
			score_cache[c] = _best_ability_score(c, battle, model)
		ordered.sort_custom(func(a, b):
			var sa = score_cache.get(a)
			var sb = score_cache.get(b)
			# Null = no usable ability with a target; sort to bottom.
			if sa == null: return false
			if sb == null: return true
			return sa > sb)
	else:
		ordered.sort_custom(func(a, b): return _max_usable_cost(a) > _max_usable_cost(b))
	for character in ordered:
		if character.dead or character.banished or character.bot_acted:
			continue
		_contextual_bot_act(character, battle, model, side)
		if battle.paced_bot_actions:
			# Live bot match — pace this character's action so the player can
			# read the acted animation and resulting floats before the next
			# bot character takes their turn. Headless training leaves the
			# flag false so the loop stays synchronous.
			var pacing = BattleManager.ACTED_ANIM_HOLD + BattleManager.POST_ACTED_GAP + BattleManager.FEEDBACK_HOLD
			await battle._await_pacing(pacing)

	battle.start_round_loop()


func _contextual_bot_act(character, battle, model = null, side: int = 0):
	var has_model := model != null
	var tag := "[ctx]" if has_model else "[random-bot]"

	# Step 1: discover usable abilities and their valid targets
	var abilities = character.moveset.get_active_abilities(character)
	var usable_with_targets: Array = []   # [[ability, [targets]], ...]

	for ability in abilities:
		if not ability.usable(character):
			continue
		if not ability.extra_usable(character):
			continue

		ability.target(character, battle)
		var valid_targets: Array = []
		for c in battle.all_characters():
			if c.targeted:
				valid_targets.append(c)
		for c in battle.all_characters():
			c.set_untargeted()

		if valid_targets.size() > 0:
			usable_with_targets.append([ability, valid_targets])

	if usable_with_targets.is_empty():
		character.bot_acted = true
		return

	# Step 2: pick a decision mode via a single dice roll. See _MIX_*_UPPER
	# constants at the top of the file for probabilities. PASS returns
	# immediately; the other four each pick an ability + target according
	# to the mode, then fall through to the shared wire/exec path.
	var mode_roll: float = randf()

	# 5% — do nothing this turn even though there are usable options.
	if mode_roll < _MIX_PASS_UPPER:
		if BotContextualModel.verbose_logging:
			print("%s   %s -> [pass]" % [tag, character.character_name])
		character.bot_acted = true
		return

	var chosen_ability: Ability
	var valid_targets: Array
	var primary_target
	var ability_features: Array = []   # recorded later for training (model only)
	var target_features: Array = []
	var mode_label: String = ""

	if mode_roll < _MIX_RANDOM_UPPER:
		# 5% — fully random: uniform ability AND uniform target.
		mode_label = "random"
		var pick = usable_with_targets[randi() % usable_with_targets.size()]
		chosen_ability = pick[0]
		valid_targets = pick[1]
		primary_target = valid_targets[randi() % valid_targets.size()]
		if has_model:
			ability_features = BotContextualModel.extract_ability_features(
				character, battle, chosen_ability)
			target_features = BotContextualModel.extract_target_features(
				character, primary_target, battle, chosen_ability)
	elif mode_roll < _MIX_EXPENSIVE_UPPER:
		# 30% — most expensive usable ability; target chosen by model when
		# available so the expensive cast still lands somewhere sensible.
		mode_label = "expensive"
		var pair = _argmax_cost_ability(usable_with_targets)
		chosen_ability = pair[0]
		valid_targets = pair[1]
		if has_model:
			ability_features = BotContextualModel.extract_ability_features(
				character, battle, chosen_ability)
			var tgt = _argmax_model_target(character, battle, model,
				chosen_ability, valid_targets)
			primary_target = tgt[0]
			target_features = tgt[1]
		else:
			primary_target = valid_targets[randi() % valid_targets.size()]
	elif mode_roll < _MIX_PRIORITY_MODEL:
		# 30% — use the legacy priority bot's decision-making.
		# character.get_action returns [priority_score, [user, ability, targets]].
		# If ability is a String ("PASS"), the priority bot is choosing to
		# pass. Otherwise we use the chosen ability and its primary target —
		# the shared AoE-resolution path below will re-fan to the full target
		# list for ALL/ALL_FACTION abilities, matching what the priority
		# bot's own execution would produce.
		mode_label = "priority"
		var pri = character.get_action(bot_difficulty)
		var pri_inner = pri[1]   # [user, ability, targets]
		var pri_action = pri_inner[1]
		var pri_targets = pri_inner[2]
		if pri_action is String or pri_targets == null or pri_targets.is_empty():
			if BotContextualModel.verbose_logging:
				print("%s   %s -> [priority pass]" % [tag, character.character_name])
			character.bot_acted = true
			return
		chosen_ability = pri_action
		valid_targets = pri_targets
		primary_target = pri_targets[0]
		if has_model:
			ability_features = BotContextualModel.extract_ability_features(
				character, battle, chosen_ability)
			target_features = BotContextualModel.extract_target_features(
				character, primary_target, battle, chosen_ability)
	else:
		# 30% — contextual model: argmax over abilities, then argmax over
		# targets. When no model is present, fall back to uniform random
		# (this branch can't actually use a learned preference).
		mode_label = "best"
		if has_model:
			var ab = _argmax_model_ability(character, battle, model,
				usable_with_targets)
			chosen_ability = ab[0]
			valid_targets = ab[1]
			ability_features = ab[2]
			var tgt = _argmax_model_target(character, battle, model,
				chosen_ability, valid_targets)
			primary_target = tgt[0]
			target_features = tgt[1]
		else:
			var pick = usable_with_targets[randi() % usable_with_targets.size()]
			chosen_ability = pick[0]
			valid_targets = pick[1]
			primary_target = valid_targets[randi() % valid_targets.size()]

	if BotContextualModel.verbose_logging:
		if has_model:
			print("%s   %s -> %s [%s] -> %s" % [
				tag, character.character_name,
				chosen_ability.ability_name, mode_label,
				primary_target.character_name])
		else:
			print("%s   %s -> %s -> %s" % [
				tag, character.character_name,
				chosen_ability.ability_name, primary_target.character_name])

	# Step 5: wire up the targeter
	character.targeter.targets = [primary_target]
	character.targeter.main_target = primary_target
	character.used_ability = chosen_ability

	chosen_ability.target(character, battle)

	# Step 6: resolve AoE
	var ttype = chosen_ability.target_type()
	if ttype == TargetType.Type.ALL:
		battle.get_other_aoe_targets(character, primary_target, false, chosen_ability.and_targeter)
	elif ttype == TargetType.Type.ALL_FACTION:
		battle.get_other_aoe_targets(character, primary_target, true, chosen_ability.and_targeter)
	elif chosen_ability.and_targeter:
		battle.get_other_aoe_targets(character, primary_target, false, true)

	if character.targeter.targets.size() > 1 and BotContextualModel.verbose_logging:
		var aoe_names: Array = []
		for t in character.targeter.targets:
			aoe_names.append(t.character_name)
		print("%s   -> AoE resolved, full targets: %s" % [tag, ", ".join(aoe_names)])

	for c in battle.all_characters():
		c.set_untargeted()

	# Step 7: record the action with features for training
	if has_model:
		model.record_action(side, character.path_name,
			chosen_ability.ability_name, primary_target.path_name,
			ability_features, target_features)

	# Step 8: execute the ability and spend energy
	var cost = chosen_ability.cost()
	battle.execute_ability(chosen_ability)

	for energy_type in cost.keys():
		if not energy_type == Energy.Type.RANDOM:
			team.change_energy(energy_type, -cost[energy_type])
	if Energy.Type.RANDOM in cost.keys():
		var limit = cost[Energy.Type.RANDOM]
		while limit > 0:
			if team.energy.total_available() == 0:
				break
			var random_roll = battle.roll(0, 3)
			if team.energy.pool[random_roll] > 0:
				team.change_energy(random_roll, -1)
				limit -= 1

	character.bot_acted = true


# ===========================================================================
# V3 POLICY BOT (training/bot_policy.gd + training/bot_observation.gd)
# ===========================================================================

## v3 bot turn: joint team planning over a human-parity observation.
## Global loop: gather scored candidates from EVERY un-acted character, pick
## one (softmax T / argmax), execute, repeat — so a cheap high-value pick on
## one character naturally outbids an expensive mediocre one on another
## (replacing the old act-order heuristics). RANDOM costs are paid from the
## most abundant color (closing the "Consider the team" TODO above), with a
## one-per-turn 2-for-1 exchange when it unlocks a strictly better action.
##
## rng: seeded generator (required for reproducible training; falls back to a
## fresh randomized one live). temperature: softmax T — 0 = argmax; live
## difficulty tiers map onto it. tuning: parsed bot_tuning.json dict or null.
## record: when true, returns [{char, ability, phi_a, phi_t, turn}] for the
## trainer to attach returns to (empty otherwise).
func perform_turn_v3(battle, policy, rng: RandomNumberGenerator = null,
		temperature: float = 0.0, tuning = null, record: bool = false,
		combat_heuristics: bool = false) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var ticking_information = battle.get_ticking_effect_information(battle.waiting_for_turn)
	for key in ticking_information.keys():
		battle.execution_order[key] = ticking_information[key]
		battle.true_execution_order.append(key)

	var records: Array = []
	var focus_map: Dictionary = {}   # Characters already hit by a planned action this turn
	var exchanged := false
	var guard := 0                   # 3 actions + exchange retry, with headroom
	while guard < 12:
		guard += 1
		# Fresh observation every pick — the previous action may have killed,
		# stunned, or transformed someone (and reveal caps can change).
		var obs := BotObservation.for_player(battle, self)
		var scored: Array = []
		var best_unaffordable = null
		var best_affordable_score := -INF
		for character in team.characters:
			if character.dead or character.banished or character.bot_acted:
				continue
			for cand in obs.own_candidates(character):
				var variants: Array = policy.score_candidate(obs, character, cand, focus_map, tuning)
				if cand["affordable"]:
					scored.append_array(variants)
					for v in variants:
						best_affordable_score = maxf(best_affordable_score, v["score"])
				else:
					for v in variants:
						if best_unaffordable == null or v["score"] > best_unaffordable["score"]:
							best_unaffordable = v
		# One 2-for-1 exchange per turn, when the best unaffordable candidate
		# clearly beats everything affordable (or nothing is affordable at all).
		if (not exchanged) and best_unaffordable != null:
			var bar: float = 0.0 if scored.is_empty() else best_affordable_score
			if best_unaffordable["score"] > bar + 0.5 \
					and _v3_try_exchange(battle, best_unaffordable["cand"]["cost"]):
				exchanged = true
				continue
		if scored.is_empty():
			break
		# allow_stop=false: a fixed-0 STOP competing in softmax is a death
		# spiral — losing streaks drive all scores negative, STOP starts
		# dominating, the bot passes whole turns, loses more, repeat (observed
		# in the first gate run: 20.7% vs RANDOM and falling). Energy banking
		# should return as a LEARNED pass action with its own weights, not a
		# fixed competitor.
		var pick = _v3_combat_pick(scored, obs, policy, temperature, rng) if combat_heuristics \
			else policy.select(scored, temperature, rng, false)
		if pick == null:
			break   # defensive: only possible if scored was emptied
		var hit: Array = _v3_execute(pick["character"], battle, pick["cand"], pick["primary_target"])
		for t in hit:
			focus_map[t] = true
		if record and pick.has("phi_a_grad"):
			# Only softmax picks carry centered gradients; argmax (T<=0) picks
			# are never recorded — the true T->0 gradient is ~0, and recording
			# raw phi there would reintroduce unbounded common-mode inflation.
			records.append({
				"char": pick["character"].path_name,
				"ability": pick["cand"]["ability"].ability_name,
				"phi_a": pick["phi_a_grad"],
				"phi_t": pick["phi_t_grad"],
				"phi_a_e": pick.get("phi_a_egrad", pick["phi_a_grad"]),
				"phi_t_e": pick.get("phi_t_egrad", pick["phi_t_grad"]),
				"turn": battle.current_turn_number,
			})
		if battle.paced_bot_actions:
			# Live match — pace between bot actions exactly like the other bots.
			var pacing = BattleManager.ACTED_ANIM_HOLD + BattleManager.POST_ACTED_GAP + BattleManager.FEEDBACK_HOLD
			await battle._await_pacing(pacing)
	for character in team.characters:
		if not (character.dead or character.banished):
			character.bot_acted = true
	battle.start_round_loop()
	return records


## LIVE-only combat heuristics layered over the learned policy (P1). Three hard rules the pre-semantic live
## weights are blind to, each grounded in policy.combat_verdict:
##   1. LETHAL-SECURE — if any affordable action is a guaranteed kill (after shield + DR), take the best one
##      outright instead of softmax-sampling, so the bot never fails to finish a killable enemy.
##   2. DO-NOTHING VETO — drop actions that accomplish literally nothing (a non-damaging skill whose payload
##      is nullified), as long as at least one real action remains (never freezes the turn).
##   3. MITIGATION / COUNTER PENALTY — deprioritize attacking into a full shield+DR or an armed counter, and
##      re-controlling an already-disabled target, so the bot avoids them when a better play exists.
## Kills are re-evaluated each loop pass (the turn loop re-observes after every action), so multi-kill turns
## emerge naturally without over-piling on one target. Returns a scored variant, or null.
func _v3_combat_pick(scored: Array, obs, policy, temperature: float, rng):
	var kills: Array = []
	var kept: Array = []
	for v in scored:
		var verdict: Dictionary = policy.combat_verdict(obs, v["character"], v["cand"], v["primary_target"])
		if verdict["penalty"] > 0.0:
			v["score"] -= verdict["penalty"]
		if verdict["kill"]:
			kills.append(v)
		if not verdict["waste"]:
			kept.append(v)
	if not kills.is_empty():
		var best: Dictionary = kills[0]
		for v in kills:
			if v["score"] > best["score"]:
				best = v
		return best
	var pool: Array = kept if not kept.is_empty() else scored
	return policy.select(pool, temperature, rng, false)


## Wire targeter, resolve AoE, execute, and spend energy for one v3 action —
## the same engine idiom as _contextual_bot_act steps 5/6/8, with the RANDOM
## spend upgraded from uniform rolls to most-abundant-color.
## Returns the resolved target list (for focus-fire tracking).
func _v3_execute(character, battle, cand: Dictionary, primary_target) -> Array:
	var ability = cand["ability"]
	character.targeter.targets = [primary_target]
	character.targeter.main_target = primary_target
	character.used_ability = ability

	ability.target(character, battle)

	var ttype = ability.target_type()
	if ttype == TargetType.Type.ALL:
		battle.get_other_aoe_targets(character, primary_target, false, ability.and_targeter)
	elif ttype == TargetType.Type.ALL_FACTION:
		battle.get_other_aoe_targets(character, primary_target, true, ability.and_targeter)
	elif ability.and_targeter:
		battle.get_other_aoe_targets(character, primary_target, false, true)
	var hit_targets: Array = character.targeter.targets.duplicate()

	for c in battle.all_characters():
		c.set_untargeted()

	var cost = ability.cost()
	battle.execute_ability(ability)

	for energy_type in cost.keys():
		if not energy_type == Energy.Type.RANDOM:
			team.change_energy(energy_type, -cost[energy_type])
	if Energy.Type.RANDOM in cost.keys():
		var limit = cost[Energy.Type.RANDOM]
		while limit > 0 and team.energy.total_available() > 0:
			# Pay from the most abundant color, preserving scarce colors for
			# teammates' specific costs.
			var best_color := -1
			var best_count := 0
			for color in range(4):
				var count = int(team.energy.pool[color])
				if count > best_count:
					best_count = count
					best_color = color
			if best_color < 0:
				break
			team.change_energy(best_color, -1)
			limit -= 1

	character.bot_acted = true
	return hit_targets


## One-per-turn 2-for-1 exchange when the candidate is short EXACTLY one pip
## of a specific color and some other color has 2 spare beyond the candidate's
## own needs. (A shortfall on the RANDOM part can't be fixed by an exchange —
## it's net -1 total energy.) Side-aware: uses the engine's own exchange path.
func _v3_try_exchange(battle, cost: Dictionary) -> bool:
	if not team.energy.can_exchange():
		return false
	var tp: Dictionary = team.energy.true_pool()
	var missing_color := -1
	var missing_total := 0
	var leftover := 0
	for color in range(4):
		var need := int(cost.get(color, 0))
		var have := int(tp.get(color, 0))
		if need > have:
			missing_total += need - have
			missing_color = color
		else:
			leftover += have - need
	var rand_need := int(cost.get(Energy.Type.RANDOM, 0))
	if leftover < rand_need:
		missing_total += rand_need - leftover
	if missing_total != 1 or missing_color < 0:
		return false
	for color in range(4):
		if color == missing_color:
			continue
		var spare := int(tp.get(color, 0)) - int(cost.get(color, 0))
		# The 2 offered pips come out of the same leftover that must still
		# cover the cost's RANDOM part — without this check the exchange nets
		# -1 energy and burns the once-per-turn allowance for nothing.
		if spare >= 2 and (rand_need == 0 or leftover - 2 >= rand_need):
			var offer := {color: 2}
			if battle.player == self:
				battle.accept_exchange(offer, missing_color)
			else:
				battle.accept_enemy_exchange(offer, missing_color)
			return true
	return false


func get_mastery_score_from_character(character, cheater = 0):
	if cheater != 0:
		return cheater
	return character_progress.get_level(character.path_name)

func get_team_actions():
	var output = []
	for character in team.characters:
		if not character.bot_acted:
			#Get the highest priority action from each character
			var best_priority = character.get_action(bot_difficulty)
			output.append(best_priority)
	return output

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
