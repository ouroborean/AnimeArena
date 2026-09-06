extends Node
class_name Clan

enum Rank {
	LEADER = 0,
	OFFICER = 1,
	MEMBER = 2
}

var members: Dictionary = {
	Rank.LEADER: [],
	Rank.OFFICER: [],
	Rank.MEMBER: []
}
var clan_name: String
var rank = "None"
var xp: int = 0
var wins: int = 0
var losses: int = 0
var applied_players = []
var invited_players = []
var banner_url = ""
var banner_texture
var member_info = {
	Rank.LEADER: [],
	Rank.OFFICER: [],
	Rank.MEMBER: []
}

signal invite_player(username)
signal accept_player_application(username)

func add_member(username):
	if not username in members[Rank.MEMBER]:
		members[Rank.MEMBER].append(username)

func set_banner_url(url):
	banner_url = url

func save():
	var data = {}
	data['members'] = members
	data['clan_name'] = clan_name
	data['xp'] = xp
	data['wins'] = wins
	data['losses'] = losses
	data['applied_players'] = applied_players
	data['invited_players'] = invited_players
	data['banner_url'] = banner_url
	data['rank'] = rank
	return data
	
static func load_clan(data):
	var clan = load("res://components/clan.tscn").instantiate()
	clan.rank = data['rank']
	clan.members = data['members']
	print("Pre-formatting, member dict is: " + str(clan.members))
	print("Loading clan " + data['clan_name'])
	print("Clan loading with member list: " + str(data['members']))
	for key in clan.members.keys():
		if key is String:
			clan.members[int(key)] = clan.members[key]
			clan.members.erase(key)
	clan.clan_name = data['clan_name']
	clan.xp = data['xp']
	clan.applied_players = data['applied_players']
	clan.invited_players = data['invited_players']
	clan.banner_url = data['banner_url']
	clan.wins = data['wins']
	clan.losses = data['losses']
	if 'member_info' in data:
		clan.member_info = data['member_info']
	return clan


func fetch_banner_texture():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", banner_fetch_completed)
	
	# Perform the HTTP request. The URL below returns a PNG image as of writing.
	var error = http_request.request(banner_url)

func banner_fetch_completed(result, response_code, headers, body):
	var image = Image.new()
	var error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")
		banner_url = ""
		banner_texture = load("res://assets/avatars/angy_wendy.png")
	else:
		var texture = ImageTexture.new().create_from_image(image)
		banner_texture = texture

func member_count():
	return len(all_members())

func all_members():
	return members[Rank.LEADER] + members[Rank.OFFICER] + members[Rank.MEMBER]

func get_rank(username):
	if username in members[Rank.LEADER]:
		return Rank.LEADER
	elif username in members[Rank.OFFICER]:
		return Rank.OFFICER
	elif username in members[Rank.MEMBER]:
		return Rank.MEMBER

func change_rank(username, rank):
	if username in all_members():
		members[get_rank(username)].erase(username)
	members[rank].append(username)

func get_level_progress() -> Dictionary:
	# Single source of truth for the win-derived level. Returns the level plus how many wins
	# are banked INTO the current level and how many that level costs to clear (for the client's
	# progress bar). Never mutates `wins` (an old version subtracted from it, corrupting the count).
	var level_requirement = 10
	var level = 1
	var remaining = wins
	while remaining >= level_requirement:
		level += 1
		remaining -= level_requirement
		level_requirement = int(level_requirement * 1.8)
	return {"level": level, "into": remaining, "needed": level_requirement}

func get_level_from_wins():
	return get_level_progress()["level"]
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
