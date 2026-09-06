extends Node
class_name Bounty

const MASTERY_SUFFIX = "_mastery"

static func get_bounty(player_name, path_name, rerolls, bounty_type = "unlock"):
	var bounty = load("res://scripts/bounty.gd").new()
	bounty.generate_from_details(player_name, path_name, rerolls, bounty_type)
	return bounty

var mission_types = [
	"with",
	"with",
	"with",
	"against",
	"against",
	"versus"
]


var missions = []

var requires_bounty_target = false
var bounty_target_path

var winning_patterns = [
	[0, 1, 2, 3, 4],
	[5, 6, 7, 8, 9],
	[10, 11, 12, 13, 14],
	[15, 16, 17, 18, 19],
	[20, 21, 22, 23, 24],
	[0, 5, 10, 15, 20],
	[1, 6, 11, 16, 21],
	[2, 7, 12, 17, 22],
	[3, 8, 13, 18, 23],
	[4, 9, 14, 19, 24],
	[0, 6, 12, 18, 24],
	[4, 8, 12, 16, 20],
]

func check_bounty_progress(own_team, enemy_team):
	var results = [
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
	]

	if requires_bounty_target and not (bounty_target_path in own_team):
		return results

	var count = -1
	for mission in missions:
		count += 1
		var mission_type = mission[0]
		var mission_count = mission[2]
		var mission_targets = mission[1]
		match mission_type:
			"with":
				var with_target = mission_targets[0]
				if with_target in archetypes:
					for path_name in own_team:
						if requires_bounty_target and path_name == bounty_target_path:
							continue
						if path_name in categories[with_target]:
							results[count] += 1
							break
				else:
					for path_name in own_team:
						if path_name == with_target:
							results[count] += 1
							break

			"against":
				var against_target = mission_targets[0]
				if against_target in archetypes:
					for path_name in enemy_team:
						if path_name in categories[against_target]:
							results[count] += 1
							break
				else:
					for path_name in enemy_team:
						if path_name == against_target:
							results[count] += 1
							break
			"versus":
				var with_target = mission_targets[0]
				var against_target = mission_targets[1]
				var valid_team = false
				for path_name in own_team:
					if requires_bounty_target and path_name == bounty_target_path and with_target in archetypes:
						continue
					if with_target in archetypes:
						if path_name in categories[with_target]:
							valid_team = true
					else:
						if path_name == with_target:
							valid_team = true
				if not valid_team:
					continue
				for path_name in enemy_team:
					if against_target in archetypes:
						if path_name in categories[against_target]:
							results[count] += 1
							break
					else:
						if path_name == against_target:
							results[count] += 1
							break
	return results

func bounty_completed(bounty_progress):
	for pattern in winning_patterns:
		var passing = true
		for mission_index in pattern:
			if not passing:
				break
			if bounty_progress[mission_index] < missions[mission_index][2]:
				passing = false
				continue
		if passing:
			return true
	return false
			
var random = RandomNumberGenerator.new()

static func flat_bounty_categories(path_name):
	var _categories = {
		"sword": ["arima", "esdeath", "zoro", "meliodas", "erza", "sayaka", "asta", "blackstar", "tatsumi", "akame", "tanjiro", "zenitsu", "inosuke", "rengoku", "muichiro", "yamamoto", "squalo", "eren", "mikasa", "kurapika", "emiya", "saber", "emiyaarcher", "ryuko", "satsuki", "ichigo", "byakuya", "nimaiya", "omnimon", "uzui", "inuyasha", "toudou", "yoh", "alphamon", "halibel", "kurotsuchi", "arthur", "toji", "levi", "jinwoo", "tsubasa", "law", "sesshomaru"],
		"air": ["naruto", "yuno", "aang", "korra", "hawkmon", "nonon", "boruto", "muichiro", "jaden", "uranus"],
		"water": ["lucy", "hashirama", "noelle", "aang", "korra", "tanjiro", "muichiro", "yamamoto", "squalo", "gray", "mercury", "jaden", "kitara", "horohoro", "halibel"],
		"earth": ["diane", "hashirama", "aang", "toph", "korra", "alphonse", "jaden", "yoh"],
		"ice": ["gray", "esdeath", "mercury", "kitara", "todoroki", "horohoro"],
		"fire": ["sasuke", "bakugo", "natsu", "meliodas", "frieren", "ace", "sukuna", "aang", "korra", "rengoku", "tsunayoshi", "genos", "shinra", "tamaki", "mars", "megumin", "renamon", "jaden", "chrome", "todoroki", "lyserg", "uranus", "arthur", "impmon", "tsubasa", "escanor"],
		"lightning": ["sasuke", "zenitsu", "genos", "killua", "misaka", "frankenstein", "jupiter", "toudou", "lightning", "yoruichi"],
		"undead": ["jack", "ken", "touka", "myotismon", "hashirama", "ban", "muzan", "ainz"],
		"ninja": ["naruto", "sasuke", "sakura", "hinata", "hashirama", "tsubaki", "boruto", "uzui", "itachi"],
		"hero": ["midoriya", "uraraka", "bakugo", "saitama", "genos", "tatsumaki", "gilgamesh", "gallantmon", "omnimon", "tsuyu", "sayaka", "jaden", "todoroki", "allmight", "blackwargreymon", "yusuke"],
		"fairy tail": ["natsu", "lucy", "gray", "erza", "mavis"],
		"vongola": ["tsunayoshi", "yamamoto", "ryohei", "xanxus", "squalo", "chrome", "hibari"],
		"leader": ["esdeath", "shinoa", "gojo", "luffy", "meliodas", "koro", "hashirama", "rob", "tsunayoshi", "xanxus", "rimuru", "venus", "toudou", "ichibe", "jeanne", "mavis", "levi", "death", "frieza", "law", "muzan"],
		"brawler": ["edward", "gon", "luffy", "yuji", "midoriya", "bakugo", "goku", "vegeta", "natsu", "rob", "ryohei", "saitama", "genos", "shinra", "gunha", "gogeta", "sakura", "shiro", "gohan", "allmight", "veldora", "cooler", "cell", "seventeen", "hibari", "broly", "adam", "toji", "aiohto", "denji", "yoruichi", "stark", "escanor", "hibiki", "piccolo", "mashburnedead", "baki", "yusuke"],
		"servant": ["saber", "gilgamesh", "emiyaarcher", "jack", "semiramis", "frankenstein", "mash", "astolfo"],
		"shinigami": ["ichigo", "byakuya", "nimaiya", "kid", "ichibe", "kurotsuchi", "yoruichi"],
		"pirate": ["luffy", "zoro", "usopp", "marco", "ace", "law"],
		"esper": ["tatsumaki", "misaka", "kuroko", "gunha", "shokuhou", "rakko"],
		"magical girl": ["madoka", "sayaka", "mami", "mars", "jupiter", "saturn", "mercury", "venus", "uranus"],
		"night raid": ["tatsumi", "akame", "sheele", "mine"],
		"sins": ["meliodas", "king", "diane", "ban", "escanor"],
		"villain": ["esdeath", "sasuke", "gilgamesh", "ken", "vegeta", "machinedramon", "xanxus", "toga", "sukuna", "rob", "myotismon", "hisoka", "neferpitou", "koro", "ladydevimon", "pegasus", "halibel", "veldora", "itachi", "eren", "yubel", "cooler", "cell", "seventeen", "broly", "toji", "blackwargreymon", "frieza", "muzan", "ainz"],
		"digimon": ["gatomon", "omnimon", "myotismon", "machinedramon", "gallantmon", "renamon", "hawkmon", "ladydevimon", "alphamon", "impmon", "blackwargreymon"],
		"assassin": ["arima", "esdeath", "rob", "blackstar", "tatsumi", "sheele", "akame", "killua", "jack", "semiramis", "nagisa", "tsubaki", "koro", "mine", "rakko", "jinwoo", "minene", "sesshomaru"],
		"mage" : ["asta", "noelle", "yuno", "natsu", "gray", "lucy", "semiramis", "megumin", "frieren", "erza", "megumi", "nobara", "gojo", "sukuna", "mavis", "jinwoo", "fern"],
		"blood": ["toga", "crona", "nezuko", "ganta", "shiro", "myotismon", "inuyasha", "ken", "touka", "denji", "power", "muzan"],
		"sound": ["sayaka", "soul", "toph", "uzui", "nonon"], 
		"bow": ["sukuna", "madoka", "gilgamesh", "emiyaarcher", "gatomon"], 
		"gun": ["mami", "kid", "xanxus", "nonon", "ganta", "mine", "lizandpatty", "rakko", "impmon", "gasai", "yusuke"],
		"shadow": ["megumi", "tokoyami", "jack", "rimuru", "saturn", "yugi", "ichibe", "ladydevimon", "pegasus", "yubel", "impmon", "jinwoo", "death"],
		"tech": ["edward", "genos", "shokuhou", "nonon", "machinedramon", "yugi", "kaiba", "jaden", "jesse", "mine", "lyserg", "kurotsuchi", "rakko", "seventeen", "gasai", "minene", "tsubasa", "hibiki"],
		"defender": ["arima", "gallantmon", "eren", "mash", "orihime", "alphonse", "jaden", "nel", "jeanne", "allmight", "uranus", "gasai", "astolfo", "jinwoo", "tsubasa", "stark", "hibiki"],
		"beast": ["marco", "tokoyami", "tsuyu", "inosuke", "gatomon", "hawkmon", "renamon", "jesse", "nel", "halibel", "neferpitou"],
		"eye": ["sasuke", "boruto", "gojo", "ken", "hinata", "kurapika", "pegasus", "itachi", "yubel", "adam", "aiohto"],
		"scythe": ["maka", "soul", "tsubaki", "shinoa", "death"]
	}
	var archetypes = []
	for key in _categories:
		if path_name in _categories[key]:
			archetypes.append(key)
	return archetypes

var categories = {
		"sword": ["arima", "esdeath", "zoro", "meliodas", "erza", "sayaka", "asta", "blackstar", "tatsumi", "akame", "tanjiro", "zenitsu", "inosuke", "rengoku", "muichiro", "yamamoto", "squalo", "eren", "mikasa", "kurapika", "emiya", "saber", "emiyaarcher", "ryuko", "satsuki", "ichigo", "byakuya", "nimaiya", "omnimon", "uzui", "inuyasha", "toudou", "yoh", "alphamon", "halibel", "kurotsuchi", "arthur", "toji", "levi", "jinwoo", "tsubasa", "law", "sesshomaru"],
		"air": ["naruto", "yuno", "aang", "korra", "hawkmon", "nonon", "boruto", "muichiro", "jaden", "uranus"],
		"water": ["lucy", "hashirama", "noelle", "aang", "korra", "tanjiro", "muichiro", "yamamoto", "squalo", "gray", "mercury", "jaden", "kitara", "horohoro", "halibel"],
		"earth": ["diane", "hashirama", "aang", "toph", "korra", "alphonse", "jaden", "yoh"],
		"ice": ["gray", "esdeath", "mercury", "kitara", "todoroki", "horohoro"],
		"fire": ["sasuke", "bakugo", "natsu", "meliodas", "frieren", "ace", "sukuna", "aang", "korra", "rengoku", "tsunayoshi", "genos", "shinra", "tamaki", "mars", "megumin", "renamon", "jaden", "chrome", "todoroki", "lyserg", "uranus", "arthur", "impmon", "tsubasa", "escanor"],
		"lightning": ["sasuke", "zenitsu", "genos", "killua", "misaka", "frankenstein", "jupiter", "toudou", "lightning", "yoruichi"],
		"undead": ["jack", "ken", "touka", "myotismon", "hashirama", "ban", "muzan", "ainz"],
		"ninja": ["naruto", "sasuke", "sakura", "hinata", "hashirama", "tsubaki", "boruto", "uzui", "itachi"],
		"hero": ["midoriya", "uraraka", "bakugo", "saitama", "genos", "tatsumaki", "gilgamesh", "gallantmon", "omnimon", "tsuyu", "sayaka", "jaden", "todoroki", "allmight", "blackwargreymon", "yusuke"],
		"fairy tail": ["natsu", "lucy", "gray", "erza", "mavis"],
		"vongola": ["tsunayoshi", "yamamoto", "ryohei", "xanxus", "squalo", "chrome", "hibari"],
		"leader": ["esdeath", "shinoa", "gojo", "luffy", "meliodas", "koro", "hashirama", "rob", "tsunayoshi", "xanxus", "rimuru", "venus", "toudou", "ichibe", "jeanne", "mavis", "levi", "death", "frieza", "law", "muzan"],
		"brawler": ["edward", "gon", "luffy", "yuji", "midoriya", "bakugo", "goku", "vegeta", "natsu", "rob", "ryohei", "saitama", "genos", "shinra", "gunha", "gogeta", "sakura", "shiro", "gohan", "allmight", "veldora", "cooler", "cell", "seventeen", "hibari", "broly", "adam", "toji", "aiohto", "denji", "yoruichi", "stark", "escanor", "hibiki", "piccolo", "mashburnedead", "baki", "yusuke"],
		"servant": ["saber", "gilgamesh", "emiyaarcher", "jack", "semiramis", "frankenstein", "mash", "astolfo"],
		"shinigami": ["ichigo", "byakuya", "nimaiya", "kid", "ichibe", "kurotsuchi", "yoruichi"],
		"pirate": ["luffy", "zoro", "usopp", "marco", "ace", "law"],
		"esper": ["tatsumaki", "misaka", "kuroko", "gunha", "shokuhou", "rakko"],
		"magical girl": ["madoka", "sayaka", "mami", "mars", "jupiter", "saturn", "mercury", "venus", "uranus"],
		"night raid": ["tatsumi", "akame", "sheele", "mine"],
		"sins": ["meliodas", "king", "diane", "ban", "escanor"],
		"villain": ["esdeath", "sasuke", "gilgamesh", "ken", "vegeta", "machinedramon", "xanxus", "toga", "sukuna", "rob", "myotismon", "hisoka", "neferpitou", "koro", "ladydevimon", "pegasus", "halibel", "veldora", "itachi", "eren", "yubel", "cooler", "cell", "seventeen", "broly", "toji", "blackwargreymon", "frieza", "muzan", "ainz"],
		"digimon": ["gatomon", "omnimon", "myotismon", "machinedramon", "gallantmon", "renamon", "hawkmon", "ladydevimon", "alphamon", "impmon", "blackwargreymon"],
		"assassin": ["arima", "esdeath", "rob", "blackstar", "tatsumi", "sheele", "akame", "killua", "jack", "semiramis", "nagisa", "tsubaki", "koro", "mine", "rakko", "jinwoo", "minene", "sesshomaru"],
		"mage" : ["asta", "noelle", "yuno", "natsu", "gray", "lucy", "semiramis", "megumin", "frieren", "erza", "megumi", "nobara", "gojo", "sukuna", "mavis", "jinwoo", "fern"],
		"blood": ["toga", "crona", "nezuko", "ganta", "shiro", "myotismon", "inuyasha", "ken", "touka", "denji", "power", "muzan"],
		"sound": ["sayaka", "soul", "toph", "uzui", "nonon"], 
		"bow": ["sukuna", "madoka", "gilgamesh", "emiyaarcher", "gatomon"], 
		"gun": ["mami", "kid", "xanxus", "nonon", "ganta", "mine", "lizandpatty", "rakko", "impmon", "gasai", "yusuke"],
		"shadow": ["megumi", "tokoyami", "jack", "rimuru", "saturn", "yugi", "ichibe", "ladydevimon", "pegasus", "yubel", "impmon", "jinwoo", "death"],
		"tech": ["edward", "genos", "shokuhou", "nonon", "machinedramon", "yugi", "kaiba", "jaden", "jesse", "mine", "lyserg", "kurotsuchi", "rakko", "seventeen", "gasai", "minene", "tsubasa", "hibiki"],
		"defender": ["arima", "gallantmon", "eren", "mash", "orihime", "alphonse", "jaden", "nel", "jeanne", "allmight", "uranus", "gasai", "astolfo", "jinwoo", "tsubasa", "stark", "hibiki"],
		"beast": ["marco", "tokoyami", "tsuyu", "inosuke", "gatomon", "hawkmon", "renamon", "jesse", "nel", "halibel", "neferpitou"],
		"eye": ["sasuke", "boruto", "gojo", "ken", "hinata", "kurapika", "pegasus", "itachi", "yubel", "adam", "aiohto"],
		"scythe": ["maka", "soul", "tsubaki", "shinoa", "death"]
	}
var archetypes = ["scythe", "eye", "sword", "air", "water", "earth", "ice", "fire", "lightning", "undead", "ninja", "hero", "fairy tail", "vongola", "leader", "brawler", "servant", "shinigami", "pirate", "esper", "magical girl", "night raid", "sins", "villain", "digimon", "assassin", "non human", "mage", "blood", "sound", "bow", "gun", "shadow", "tech", "defender", "beast"]

var bounty_path

static func get_archetype_list():
	return ["scythe", "eye", "sword", "air", "water", "earth", "ice", "fire", "lightning", "undead", "ninja", "hero", "fairy tail", "vongola", "leader", "brawler", "servant", "shinigami", "pirate", "esper", "magical girl", "night raid", "sins", "villain", "digimon", "assassin", "non human", "mage", "blood", "sound", "bow", "gun", "shadow", "tech", "defender", "beast"]

func get_archetypes(character):
	var archetypes = []
	for key in categories:
		if character in categories[key]:
			archetypes.append(key)
	return archetypes


func generate_from_details(player_name, path_name, rerolls, bounty_type = "unlock"):
	requires_bounty_target = bounty_type == "mastery"
	var seed_input = player_name + path_name + str(rerolls)
	if bounty_type == "mastery":
		seed_input += MASTERY_SUFFIX
	random.seed = hash(seed_input)
	var bounty_types = get_archetypes(path_name)
	if bounty_types.is_empty():
		# A character in no archetype category would make bounty_types[randi_range(0, -1)] throw
		# ("index -1 on Array"); fall back to every category so mission generation still succeeds.
		bounty_types = categories.keys()
	bounty_target_path = path_name
	bounty_path = path_name + MASTERY_SUFFIX if requires_bounty_target else path_name
	var character_instance = Character.from_character_name(path_name)
	var universe_dict = CharacterDatabase.by_universe(path_name)
	for i in range(25):
		var mission_type = mission_types[random.randi_range(0, 5)]
		
		var mission_details = []
		mission_details.append(mission_type)
		match mission_type:
			"with":
				var specific_odds = random.randi_range(0, 4)
				var bounty_category = bounty_types[random.randi_range(0, len(bounty_types) - 1)]
				if not specific_odds:
					var specific_target = categories[bounty_category][random.randi_range(0, len(categories[bounty_category]) - 1)]
					if specific_target == path_name:
						mission_details.append([bounty_category])
						mission_details.append(6)
					else:
						mission_details.append([specific_target])
						mission_details.append(4)
				elif specific_odds == 1 and len(universe_dict[character_instance.universe]) != 0:
					var specific_target = universe_dict[character_instance.universe][random.randi_range(0, len(universe_dict[character_instance.universe]) - 1)]
					mission_details.append([specific_target])
					mission_details.append(4)
				else:
					mission_details.append([bounty_category])
					mission_details.append(6)
					
			"against":
				var specific_odds = random.randi_range(0, 8)
				var bounty_category = bounty_types[random.randi_range(0, len(bounty_types) - 1)]
				if not specific_odds:
					var specific_target = categories[bounty_category][random.randi_range(0, len(categories[bounty_category]) - 1)]
					if specific_target == path_name:
						mission_details.append([bounty_category])
						mission_details.append(4)
					else:
						mission_details.append([specific_target])
						mission_details.append(3)
				elif specific_odds == 1 and len(universe_dict[character_instance.universe]) != 0:
					var specific_target = universe_dict[character_instance.universe][random.randi_range(0, len(universe_dict[character_instance.universe]) - 1)]
					mission_details.append([specific_target])
					mission_details.append(3)
				else:
					mission_details.append([bounty_category])
					mission_details.append(4)
			"versus":
				var with_specific_odds = random.randi_range(0, 4)
				var target_specific_odds = random.randi_range(0, 8)
				var with_bounty_category = bounty_types[random.randi_range(0, len(bounty_types) - 1)]
				var target_bounty_category = bounty_types[random.randi_range(0, len(bounty_types) - 1)]
				var versus_details = []
				if not with_specific_odds:
					var specific_target = categories[with_bounty_category][random.randi_range(0, len(categories[with_bounty_category]) - 1)]
					if specific_target == path_name:
						versus_details.append(with_bounty_category)
						with_specific_odds = 1
					else:
						versus_details.append(specific_target)
				elif with_specific_odds == 1 and len(universe_dict[character_instance.universe]) != 0:
					var specific_target = universe_dict[character_instance.universe][random.randi_range(0, len(universe_dict[character_instance.universe]) - 1)]
					versus_details.append(specific_target)
				else:
					versus_details.append(with_bounty_category)
					
				if not target_specific_odds:
					var specific_target = categories[target_bounty_category][random.randi_range(0, len(categories[target_bounty_category]) - 1)]
					if specific_target == path_name:
						versus_details.append(target_bounty_category)
						target_specific_odds = 1
					else:
						versus_details.append(specific_target)
				elif target_specific_odds == 1 and len(universe_dict[character_instance.universe]) != 0:
					var specific_target = universe_dict[character_instance.universe][random.randi_range(0, len(universe_dict[character_instance.universe]) - 1)]
					versus_details.append(specific_target)
				else:
					versus_details.append(target_bounty_category)
				mission_details.append(versus_details)
				var win_count = 0
				if with_specific_odds:
					win_count += 2
				else:
					win_count += 1
				
				if target_specific_odds:
					win_count += 1
				else:
					win_count += 0
				mission_details.append(win_count)
		missions.append(mission_details)
	# character_instance is a full scene subtree read only for universe/category
	# data during the 25-square roll above — free it or every board leaks it.
	character_instance.queue_free()

func get_mission_details(mission):
	var details = {"name": "", "portrait": ""}
	if mission in archetypes:
		details.name = mission.capitalize()
		details.portrait = load("res://assets/bounty/" + mission + ".png")
	else:
		var character_instance = Character.from_character_name(mission)
		details.name = character_instance.character_name
		details.portrait = character_instance.portrait_texture   # refcounted Resource — outlives the node
		character_instance.queue_free()
	return details
