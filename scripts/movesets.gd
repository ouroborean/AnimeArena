class_name Movesets


static func get_moveset_by_id(char_id):
	
	match char_id:
		0:
			Movesets.sample_moveset()
		1:
			Movesets.sample_moveset()
		

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

static func sample_moveset():
	return []

static func from_skill_count(character):
	var moveset = []
	
	var file = "res://character_ability_counts.json"
	var json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict = JSON.parse_string(json_as_text)
	var skill_count = json_as_dict[character.path_name]
	
	for i in range(skill_count):
		var label = str(i + 1)
		var skill = Ability.from_database(character.path_name + label)
		moveset.append(skill)
	return moveset

static func ash_moveset():
	var ash1 = load("res://abilities/ash1.tscn").instantiate()
	var ash2 = load("res://abilities/ash2.tscn").instantiate()
	var ash3 = load("res://abilities/ash3.tscn").instantiate()
	var ash4 = load("res://abilities/ash4.tscn").instantiate()
	var ash5 = load("res://abilities/ash5.tscn").instantiate()
	var ash6 = load("res://abilities/ash6.tscn").instantiate()
	var ash7 = load("res://abilities/ash7.tscn").instantiate()
	var ash8 = load("res://abilities/ash8.tscn").instantiate()
	var ash9 = load("res://abilities/ash9.tscn").instantiate()
	var ash10 = load("res://abilities/ash10.tscn").instantiate()
	var ash11 = load("res://abilities/ash11.tscn").instantiate()
	var ash12 = load("res://abilities/ash12.tscn").instantiate()
	var ash13 = load("res://abilities/ash13.tscn").instantiate()
	var ash14 = load("res://abilities/ash14.tscn").instantiate()
	
	
	var moveset = [
		ash1,
		ash2,
		ash3,
		ash4,
		ash5,
		ash6,
		ash7,
		ash8,
		ash9,
		ash10,
		ash11,
		ash12,
		ash13,
		ash14,
	]
	return moveset


static func bakugo_moveset():
	var bakugou1 = load("res://abilities/bakugo1.tscn").instantiate()
	var bakugou2 = load("res://abilities/bakugo2.tscn").instantiate()
	var bakugou3 = load("res://abilities/bakugo3.tscn").instantiate()
	var bakugou4 = load("res://abilities/bakugo4.tscn").instantiate()
	var bakugou5 = load("res://abilities/bakugo5.tscn").instantiate()
	var bakugou6 = load("res://abilities/bakugo6.tscn").instantiate()
	
	var moveset = [
		bakugou1,
		bakugou2,
		bakugou3,
		bakugou4,
		bakugou5,
		bakugou6,
		
	]
	return moveset

static func eren_moveset():
	var eren1 = load("res://abilities/eren1.tscn").instantiate()
	var eren2 = load("res://abilities/eren2.tscn").instantiate()
	var eren3 = load("res://abilities/eren3.tscn").instantiate()
	var eren4 = load("res://abilities/eren4.tscn").instantiate()
	var eren5 = load("res://abilities/eren5.tscn").instantiate()
	var eren6 = load("res://abilities/eren6.tscn").instantiate()
	var eren7 = load("res://abilities/eren7.tscn").instantiate()
	var eren8 = load("res://abilities/eren8.tscn").instantiate()
	
	var moveset = [
		eren1,
		eren2,
		eren3,
		eren4,
		eren5,
		eren6,
		eren7,
		eren8,
		
	]
	return moveset

static func genos_moveset():
	var genos1 = load("res://abilities/genos1.tscn").instantiate()
	var genos2 = load("res://abilities/genos2.tscn").instantiate()
	var genos3 = load("res://abilities/genos3.tscn").instantiate()
	var genos4 = load("res://abilities/genos4.tscn").instantiate()
	var genos5 = load("res://abilities/genos5.tscn").instantiate()
	var genos6 = load("res://abilities/genos6.tscn").instantiate()
	
	var moveset = [
		genos1,
		genos2,
		genos3,
		genos4,
		genos5,
		genos6,
		
	]
	return moveset
	
static func ken_moveset():
	var ken1 = load("res://abilities/ken1.tscn").instantiate()
	var ken2 = load("res://abilities/ken2.tscn").instantiate()
	var ken3 = load("res://abilities/ken3.tscn").instantiate()
	var ken4 = load("res://abilities/ken4.tscn").instantiate()
	var moveset = [
		ken1,
		ken2,
		ken3,
		ken4
	]
	return moveset

static func killua_moveset():
	var killua1 = load("res://abilities/killua1.tscn").instantiate()
	var killua2 = load("res://abilities/killua2.tscn").instantiate()
	var killua3 = load("res://abilities/killua3.tscn").instantiate()
	var killua4 = load("res://abilities/killua4.tscn").instantiate()
	var moveset = [
		killua1,
		killua2,
		killua3,
		killua4,
	]
	return moveset
	
static func korra_moveset():
	var korra1 = load("res://abilities/korra1.tscn").instantiate()
	var korra2 = load("res://abilities/korra2.tscn").instantiate()
	var korra3 = load("res://abilities/korra3.tscn").instantiate()
	var korra4 = load("res://abilities/korra4.tscn").instantiate()
	var korra5 = load("res://abilities/korra5.tscn").instantiate()
	var korra6 = load("res://abilities/korra6.tscn").instantiate()
	var korra7 = load("res://abilities/korra7.tscn").instantiate()
	var korra8 = load("res://abilities/korra8.tscn").instantiate()
	var korra9 = load("res://abilities/korra9.tscn").instantiate()
	var korra10= load("res://abilities/korra10.tscn").instantiate()
	var korra11= load("res://abilities/korra11.tscn").instantiate()
	var moveset = [
		korra1,
		korra2,
		korra3,
		korra4,
		korra5,
		korra6,
		korra7,
		korra8,
		korra9,
		korra10,
		korra11
	]
	return moveset
	
static func kurapika_moveset():
	var kurapika1 = load("res://abilities/kurapika1.tscn").instantiate()
	var kurapika2 = load("res://abilities/kurapika2.tscn").instantiate()
	var kurapika3 = load("res://abilities/kurapika3.tscn").instantiate()
	var kurapika4 = load("res://abilities/kurapika4.tscn").instantiate()
	var kurapika5 = load("res://abilities/kurapika5.tscn").instantiate()
	var moveset = [
		kurapika1,
		kurapika2,
		kurapika3,
		kurapika4,
		kurapika5,
		
	]
	return moveset

static func xanxus_moveset():
	var kurapika1 = load("res://abilities/xanxus1.tscn").instantiate()
	var kurapika2 = load("res://abilities/xanxus2.tscn").instantiate()
	var kurapika3 = load("res://abilities/xanxus3.tscn").instantiate()
	var kurapika4 = load("res://abilities/xanxus4.tscn").instantiate()
	var kurapika5 = load("res://abilities/xanxus5.tscn").instantiate()
	var moveset = [
		kurapika1,
		kurapika2,
		kurapika3,
		kurapika4,
		kurapika5,
	]
	return moveset

static func midoriya_moveset():
	var midoriya1 = load("res://abilities/midoriya1.tscn").instantiate()
	var midoriya2 = load("res://abilities/midoriya2.tscn").instantiate()
	var midoriya3 = load("res://abilities/midoriya3.tscn").instantiate()
	var midoriya4 = load("res://abilities/midoriya4.tscn").instantiate()
	var midoriya5 = load("res://abilities/midoriya5.tscn").instantiate()
	var moveset = [
		midoriya1,
		midoriya2,
		midoriya3,
		midoriya4,
		midoriya5,
	]
	return moveset

static func mikasa_moveset():
	var mikasa1 = load("res://abilities/mikasa1.tscn").instantiate()
	var mikasa2 = load("res://abilities/mikasa2.tscn").instantiate()
	var mikasa3 = load("res://abilities/mikasa3.tscn").instantiate()
	var mikasa4 = load("res://abilities/mikasa4.tscn").instantiate()
	var mikasa5 = load("res://abilities/mikasa5.tscn").instantiate()
	var moveset = [
		mikasa1,
		mikasa2,
		mikasa3,
		mikasa4,
		mikasa5,
		
	]
	return moveset

static func nezuko_moveset():
	var nezuko1 = load("res://abilities/nezuko1.tscn").instantiate()
	var nezuko2 = load("res://abilities/nezuko2.tscn").instantiate()
	var nezuko3 = load("res://abilities/nezuko3.tscn").instantiate()
	var nezuko4 = load("res://abilities/nezuko4.tscn").instantiate()
	var nezuko5 = load("res://abilities/nezuko5.tscn").instantiate()
	var moveset = [
		nezuko1,
		nezuko2,
		nezuko3,
		nezuko4,
		nezuko5,
		
	]
	return moveset
	
static func rimuru_moveset():
	var rimuru1 = load("res://abilities/rimuru1.tscn").instantiate()
	var rimuru2 = load("res://abilities/rimuru2.tscn").instantiate()
	var rimuru3 = load("res://abilities/rimuru3.tscn").instantiate()
	var rimuru4 = load("res://abilities/rimuru4.tscn").instantiate()
	var rimuru5 = load("res://abilities/rimuru5.tscn").instantiate()
	var rimuru6 = load("res://abilities/rimuru6.tscn").instantiate()
	var rimuru7 = load("res://abilities/rimuru7.tscn").instantiate()
	var rimuru8 = load("res://abilities/rimuru8.tscn").instantiate()
	var moveset = [
		rimuru1,
		rimuru2,
		rimuru3,
		rimuru4,
		rimuru5,
		rimuru6,
		rimuru7,
		rimuru8
	]
	return moveset

static func tatsumaki_moveset():
	var rimuru1 = load("res://abilities/tatsumaki1.tscn").instantiate()
	var rimuru2 = load("res://abilities/tatsumaki2.tscn").instantiate()
	var rimuru3 = load("res://abilities/tatsumaki3.tscn").instantiate()
	var rimuru4 = load("res://abilities/tatsumaki4.tscn").instantiate()
	var rimuru5 = load("res://abilities/tatsumaki5.tscn").instantiate()
	var rimuru6 = load("res://abilities/tatsumaki6.tscn").instantiate()
	var moveset = [
		rimuru1,
		rimuru2,
		rimuru3,
		rimuru4,
		rimuru5,
		rimuru6,
	]
	return moveset
	
static func blackstar_moveset():
	var rimuru1 = load("res://abilities/blackstar1.tscn").instantiate()
	var rimuru2 = load("res://abilities/blackstar2.tscn").instantiate()
	var rimuru3 = load("res://abilities/blackstar3.tscn").instantiate()
	var rimuru4 = load("res://abilities/blackstar4.tscn").instantiate()
	var rimuru5 = load("res://abilities/blackstar5.tscn").instantiate()
	var rimuru6 = load("res://abilities/blackstar6.tscn").instantiate()
	var moveset = [
		rimuru1,
		rimuru2,
		rimuru3,
		rimuru4,
		rimuru5,
		rimuru6,
	]
	return moveset

static func semiramis_moveset():
	var rimuru1 = load("res://abilities/semiramis1.tscn").instantiate()
	var rimuru2 = load("res://abilities/semiramis2.tscn").instantiate()
	var rimuru3 = load("res://abilities/semiramis3.tscn").instantiate()
	var rimuru4 = load("res://abilities/semiramis4.tscn").instantiate()
	var rimuru5 = load("res://abilities/semiramis5.tscn").instantiate()
	var moveset = [
		rimuru1,
		rimuru2,
		rimuru3,
		rimuru4,
		rimuru5,
	]
	return moveset

static func machinedramon_moveset():
	var rimuru1 = load("res://abilities/machinedramon1.tscn").instantiate()
	var rimuru2 = load("res://abilities/machinedramon2.tscn").instantiate()
	var rimuru3 = load("res://abilities/machinedramon3.tscn").instantiate()
	var rimuru4 = load("res://abilities/machinedramon4.tscn").instantiate()
	var rimuru5 = load("res://abilities/machinedramon5.tscn").instantiate()
	var moveset = [
		rimuru1,
		rimuru2,
		rimuru3,
		rimuru4,
		rimuru5,
	]
	return moveset
	
static func rengoku_moveset():
	var rimuru1 = load("res://abilities/rengoku1.tscn").instantiate()
	var rimuru2 = load("res://abilities/rengoku2.tscn").instantiate()
	var rimuru3 = load("res://abilities/rengoku3.tscn").instantiate()
	var rimuru4 = load("res://abilities/rengoku4.tscn").instantiate()
	var rimuru6 = load("res://abilities/rengoku6.tscn").instantiate()
	var moveset = [
		rimuru1,
		rimuru2,
		rimuru3,
		rimuru4,
		rimuru6,
	]
	
	return moveset

static func usopp_moveset():
	var rimuru1 = load("res://abilities/usopp3.tscn").instantiate()
	var rimuru2 = load("res://abilities/usopp4.tscn").instantiate()
	var rimuru3 = load("res://abilities/usopp2.tscn").instantiate()
	var rimuru4 = load("res://abilities/usopp1.tscn").instantiate()
	var rimuru5 = load("res://abilities/usopp5.tscn").instantiate()
	var moveset = [
		rimuru1,
		rimuru2,
		rimuru3,
		rimuru4,
		rimuru5,
	]
	return moveset

static func saitama_moveset():
	var saitama1 = load("res://abilities/saitama1.tscn").instantiate()
	var saitama2 = load("res://abilities/saitama2.tscn").instantiate()
	var saitama3 = load("res://abilities/saitama3.tscn").instantiate()
	var saitama4 = load("res://abilities/saitama4.tscn").instantiate()
	var saitama5 = load("res://abilities/saitama5.tscn").instantiate()
	var saitama6 = load("res://abilities/saitama6.tscn").instantiate()
	var saitama7 = load("res://abilities/saitama7.tscn").instantiate()
	var moveset = [
		saitama1,
		saitama2,
		saitama3,
		saitama4,
		saitama5,
		saitama6,
		saitama7
	]
	return moveset

static func sakura_moveset():
	var sakura1 = load("res://abilities/sakura1.tscn").instantiate()
	var sakura2 = load("res://abilities/sakura2.tscn").instantiate()
	var sakura3 = load("res://abilities/sakura3.tscn").instantiate()
	var sakura4 = load("res://abilities/sakura4.tscn").instantiate()
	var sakura5 = load("res://abilities/sakura5.tscn").instantiate()
	var sakura6 = load("res://abilities/sakura6.tscn").instantiate()
	var moveset = [
		sakura1,
		sakura2,
		sakura3,
		sakura4,
		sakura5,
		sakura6,
	]
	return moveset

static func sasuke_moveset():
	var sasuke1 = load('res://abilities/sasuke1.tscn').instantiate()
	var sasuke2 = load('res://abilities/sasuke2.tscn').instantiate()
	var sasuke3 = load('res://abilities/sasuke3.tscn').instantiate()
	var sasuke4 = load('res://abilities/sasuke4.tscn').instantiate()
	var sasuke5 = load('res://abilities/sasuke5.tscn').instantiate()
	var sasuke6 = load('res://abilities/sasuke6.tscn').instantiate()
	var moveset = [
		sasuke1,
		sasuke2,
		sasuke3,
		sasuke4,
		sasuke5,
		sasuke6,
		
	]
	return moveset

static func tanjiro_moveset():
	var tanjiro1 = load("res://abilities/tanjiro1.tscn").instantiate()
	var tanjiro2 = load("res://abilities/tanjiro2.tscn").instantiate()
	var tanjiro3 = load("res://abilities/tanjiro3.tscn").instantiate()
	var tanjiro4 = load("res://abilities/tanjiro4.tscn").instantiate()
	var tanjiro5 = load("res://abilities/tanjiro5.tscn").instantiate()
	var tanjiro6 = load("res://abilities/tanjiro6.tscn").instantiate()
	var tanjiro7 = load("res://abilities/tanjiro7.tscn").instantiate()
	var tanjiro8 = load("res://abilities/tanjiro8.tscn").instantiate()
	var moveset = [
		tanjiro1,
		tanjiro2,
		tanjiro3,
		tanjiro4,
		tanjiro5,
		tanjiro6,
		tanjiro7,
		tanjiro8,
	]
	return moveset
	
static func urahara_moveset():
	var urahara1 = load("res://abilities/urahara1.tscn").instantiate()
	var urahara2 = load("res://abilities/urahara2.tscn").instantiate()
	var urahara3 = load("res://abilities/urahara3.tscn").instantiate()
	var urahara4 = load("res://abilities/urahara4.tscn").instantiate()
	var urahara5 = load("res://abilities/urahara5.tscn").instantiate()
	var moveset = [
		urahara1,
		urahara2,
		urahara3,
		urahara4,
		urahara5,
	]
	return moveset
	
	
static func satsuki_moveset():
	var urahara1 = load("res://abilities/satsuki1.tscn").instantiate()
	var urahara2 = load("res://abilities/satsuki2.tscn").instantiate()
	var urahara3 = load("res://abilities/satsuki3.tscn").instantiate()
	var urahara4 = load("res://abilities/satsuki4.tscn").instantiate()
	var urahara5 = load("res://abilities/satsuki5.tscn").instantiate()
	var moveset = [
		urahara1,
		urahara2,
		urahara3,
		urahara4,
		urahara5
	]
	return moveset

static func zenitsu_moveset():
	var zenitsu1 = load("res://abilities/zenitsu1.tscn").instantiate()
	var zenitsu2 = load("res://abilities/zenitsu2.tscn").instantiate()
	var zenitsu3 = load("res://abilities/zenitsu3.tscn").instantiate()
	var zenitsu4 = load("res://abilities/zenitsu4.tscn").instantiate()
	var moveset = [
		zenitsu1,
		zenitsu2,
		zenitsu3,
		zenitsu4,
		
	]
	return moveset

static func zoro_moveset():
	var zoro1 = load("res://abilities/zoro1.tscn").instantiate()
	var zoro2 = load("res://abilities/zoro2.tscn").instantiate()
	var zoro3 = load("res://abilities/zoro3.tscn").instantiate()
	var zoro4 = load("res://abilities/zoro4.tscn").instantiate()
	var zoro5 = load("res://abilities/zoro5.tscn").instantiate()
	var zoro6 = load("res://abilities/zoro6.tscn").instantiate()
	var zoro7 = load("res://abilities/zoro7.tscn").instantiate()
	var moveset = [
		zoro1,
		zoro2,
		zoro3,
		zoro4,
		zoro5,
		zoro6,
		zoro7,
		
	]
	return moveset

static func ichigo_moveset():
	var ichigo1 = load("res://abilities/ichigo1.tscn").instantiate()
	var ichigo2 = load("res://abilities/ichigo2.tscn").instantiate()
	var ichigo3 = load("res://abilities/ichigo3.tscn").instantiate()
	var ichigo4 = load("res://abilities/ichigo4.tscn").instantiate()
	var ichigo5 = load("res://abilities/ichigo5.tscn").instantiate()
	var ichigo6 = load("res://abilities/ichigo6.tscn").instantiate()
	var ichigo7 = load("res://abilities/ichigo7.tscn").instantiate()
	var ichigo8 = load("res://abilities/ichigo8.tscn").instantiate()
	var ichigo9 = load("res://abilities/ichigo9.tscn").instantiate()
	var moveset = [
		ichigo1,
		ichigo2,
		ichigo3,
		ichigo4,
		ichigo5,
		ichigo6,
		ichigo7,
		ichigo8,
		ichigo9,
		
	]
	return moveset
	

static func maka_moveset():
	var maka1 = load("res://abilities/maka1.tscn").instantiate()
	var maka2 = load("res://abilities/maka2.tscn").instantiate()
	var maka3 = load("res://abilities/maka3.tscn").instantiate()
	var maka4 = load("res://abilities/maka4.tscn").instantiate()
	var maka5 = load("res://abilities/maka5.tscn").instantiate()
	var maka6 = load("res://abilities/maka6.tscn").instantiate()
	var moveset = [
		maka1,
		maka2,
		maka3,
		maka4,
		maka5,
		maka6,
	]
	return moveset
	
static func soul_moveset():
	var soul1 = load("res://abilities/soul1.tscn").instantiate()
	var soul2 = load("res://abilities/soul2.tscn").instantiate()
	var soul3 = load("res://abilities/soul3.tscn").instantiate()
	var soul4 = load("res://abilities/soul4.tscn").instantiate()
	var soul5 = load("res://abilities/soul5.tscn").instantiate()
	var moveset = [
		soul1,
		soul2,
		soul3,
		soul4,
		soul5,
	]
	return moveset

static func touka_moveset():
	var ukaku_slam = load("res://abilities/touka1.tscn").instantiate()
	var crystal_shard = load('res://abilities/touka2.tscn').instantiate()
	var crystal_ukaku = load('res://abilities/crystallized_ukaku.tscn').instantiate()
	var touka_observe = load('res://abilities/touka_observation.tscn').instantiate()
	var moveset = [
		ukaku_slam,
		crystal_shard,
		crystal_ukaku,
		touka_observe
	]
	return moveset

static func gon_moveset():
	var jajaken = load("res://abilities/gon1.tscn").instantiate()
	var jajaken_rock = load("res://abilities/gon2.tscn").instantiate()
	var jajaken_paper = load("res://abilities/gon3.tscn").instantiate()
	var jajaken_scissors = load("res://abilities/gon4.tscn").instantiate()
	var moveset = [
		jajaken,
		jajaken_rock,
		jajaken_paper,
		jajaken_scissors,
	]
	return moveset
	
static func kakashi_moveset():
	var kunai = load('res://abilities/kakashi1.tscn').instantiate()
	var kamui = load('res://abilities/kakashi2.tscn').instantiate()
	var clone = load('res://abilities/kakashi3.tscn').instantiate()
	var ambush = load('res://abilities/kakashi4.tscn').instantiate()
	var passive = load('res://abilities/kakashi5.tscn').instantiate()
	var moveset = [
		kunai,
		kamui,
		clone,
		ambush,
		passive,
	]
	return moveset
	
static func akame_moveset():
	var move1 = load('res://abilities/akame1.tscn').instantiate()
	var move2 = load('res://abilities/akame2.tscn').instantiate()
	var move3 = load('res://abilities/akame3.tscn').instantiate()
	var move4 = load('res://abilities/akame4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
	]
	return moveset

static func asta_moveset():
	var move1 = load('res://abilities/asta1.tscn').instantiate()
	var move2 = load('res://abilities/asta2.tscn').instantiate()
	var move3 = load('res://abilities/asta3.tscn').instantiate()
	var move4 = load('res://abilities/asta4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
	]
	return moveset
	
static func diane_moveset():
	var move1 = load('res://abilities/diane1.tscn').instantiate()
	var move2 = load('res://abilities/diane2.tscn').instantiate()
	var move3 = load('res://abilities/diane3.tscn').instantiate()
	var move4 = load('res://abilities/diane4.tscn').instantiate()
	var move5 = load('res://abilities/diane5.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
	]
	return moveset



static func gilgamesh_moveset():
	var move1 = load('res://abilities/gilgamesh1.tscn').instantiate()
	var move2 = load('res://abilities/gilgamesh2.tscn').instantiate()
	var move3 = load('res://abilities/gilgamesh3.tscn').instantiate()
	var move4 = load('res://abilities/gilgamesh4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
	]
	return moveset

static func gray_moveset():
	var move1 = load('res://abilities/gray1.tscn').instantiate()
	var move2 = load('res://abilities/gray2.tscn').instantiate()
	var move3 = load('res://abilities/gray3.tscn').instantiate()
	var move4 = load('res://abilities/gray4.tscn').instantiate()
	var move5 = load('res://abilities/gray5.tscn').instantiate()
	var move6 = load('res://abilities/gray6.tscn').instantiate()
	var move7 = load('res://abilities/gray7.tscn').instantiate()
	var move8 = load('res://abilities/gray8.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6,
		move7,
		move8
	]
	return moveset

static func jack_moveset():
	var move1 = load('res://abilities/jack1.tscn').instantiate()
	var move2 = load('res://abilities/jack2.tscn').instantiate()
	var move3 = load('res://abilities/jack3.tscn').instantiate()
	var move4 = load('res://abilities/jack4.tscn').instantiate()
	var move5 = load('res://abilities/jack5.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
	]
	return moveset

static func king_moveset():
	var move1 = load('res://abilities/king1.tscn').instantiate()
	var move2 = load('res://abilities/king2.tscn').instantiate()
	var move3 = load('res://abilities/king3.tscn').instantiate()
	var move4 = load('res://abilities/king4.tscn').instantiate()
	var move5 = load('res://abilities/king5.tscn').instantiate()
	var move6 = load('res://abilities/king6.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6
	]
	return moveset

static func kuroko_moveset():
	var move1 = load('res://abilities/kuroko1.tscn').instantiate()
	var move2 = load('res://abilities/kuroko2.tscn').instantiate()
	var move3 = load('res://abilities/kuroko3.tscn').instantiate()
	var move4 = load('res://abilities/kuroko4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
	]
	return moveset

static func lucy_moveset():
	var move1 = load('res://abilities/lucy1.tscn').instantiate()
	var move2 = load('res://abilities/lucy2.tscn').instantiate()
	var move3 = load('res://abilities/lucy3.tscn').instantiate()
	var move4 = load('res://abilities/lucy4.tscn').instantiate()
	var move5 = load('res://abilities/lucy5.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
	]
	return moveset

static func meliodas_moveset():
	var move1 = load('res://abilities/meliodas1.tscn').instantiate()
	var move2 = load('res://abilities/meliodas2.tscn').instantiate()
	var move3 = load('res://abilities/meliodas3.tscn').instantiate()
	var move4 = load('res://abilities/meliodas4.tscn').instantiate()
	var move5 = load('res://abilities/meliodas5.tscn').instantiate()
	var move6 = load('res://abilities/meliodas6.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6
	]
	return moveset

static func misaka_moveset():
	var move1 = load('res://abilities/misaka1.tscn').instantiate()
	var move2 = load('res://abilities/misaka2.tscn').instantiate()
	var move3 = load('res://abilities/misaka3.tscn').instantiate()
	var move4 = load('res://abilities/misaka4.tscn').instantiate()
	var move5 = load('res://abilities/misaka5.tscn').instantiate()
	var move6 = load('res://abilities/misaka6.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6,
	]
	return moveset

static func natsu_moveset():
	var move1 = load('res://abilities/natsu1.tscn').instantiate()
	var move2 = load('res://abilities/natsu2.tscn').instantiate()
	var move3 = load('res://abilities/natsu3.tscn').instantiate()
	var move4 = load('res://abilities/natsu4.tscn').instantiate()
	var move5 = load('res://abilities/natsu5.tscn').instantiate()
	var move6 = load('res://abilities/natsu6.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6
	]
	return moveset

static func noelle_moveset():
	var move1 = load('res://abilities/noelle1.tscn').instantiate()
	var move2 = load('res://abilities/noelle2.tscn').instantiate()
	var move5 = load('res://abilities/noelle3.tscn').instantiate()
	var move4 = load('res://abilities/noelle4.tscn').instantiate()
	var move6 = load('res://abilities/noelle6.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move5,
		move4,
		move6
	]
	return moveset

static func nonon_moveset():
	var move1 = load('res://abilities/nonon1.tscn').instantiate()
	var move2 = load('res://abilities/nonon2.tscn').instantiate()
	var move3 = load('res://abilities/nonon3.tscn').instantiate()
	var move4 = load('res://abilities/nonon4.tscn').instantiate()
	var move5 = load('res://abilities/nonon5.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

static func pucelle_moveset():
	var move1 = load('res://abilities/pucelle1.tscn').instantiate()
	var move2 = load('res://abilities/pucelle2.tscn').instantiate()
	var move3 = load('res://abilities/pucelle3.tscn').instantiate()
	var move4 = load('res://abilities/pucelle4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset

static func ruler_moveset():
	var move1 = load('res://abilities/ruler1.tscn').instantiate()
	var move2 = load('res://abilities/ruler2.tscn').instantiate()
	var move3 = load('res://abilities/ruler3.tscn').instantiate()
	var move4 = load('res://abilities/ruler4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset

static func ryohei_moveset():
	var move1 = load('res://abilities/ryohei1.tscn').instantiate()
	var move2 = load('res://abilities/ryohei2.tscn').instantiate()
	var move3 = load('res://abilities/ryohei3.tscn').instantiate()
	var move4 = load('res://abilities/ryohei4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset

static func ryuko_moveset():
	var move1 = load('res://abilities/ryuko1.tscn').instantiate()
	var move2 = load('res://abilities/ryuko2.tscn').instantiate()
	var move3 = load('res://abilities/ryuko3.tscn').instantiate()
	var move4 = load('res://abilities/ryuko4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset

static func saber_moveset():
	var move1 = load('res://abilities/saber1.tscn').instantiate()
	var move2 = load('res://abilities/saber2.tscn').instantiate()
	var move3 = load('res://abilities/saber3.tscn').instantiate()
	var move4 = load('res://abilities/saber4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset

static func sheele_moveset():
	var move1 = load('res://abilities/sheele1.tscn').instantiate()
	var move2 = load('res://abilities/sheele2.tscn').instantiate()
	var move3 = load('res://abilities/sheele3.tscn').instantiate()
	var move4 = load('res://abilities/sheele4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset

static func shinra_moveset():
	var move1 = load('res://abilities/shinra1.tscn').instantiate()
	var move2 = load('res://abilities/shinra2.tscn').instantiate()
	var move3 = load('res://abilities/shinra3.tscn').instantiate()
	var move4 = load('res://abilities/shinra4.tscn').instantiate()
	var move5 = load('res://abilities/shinra5.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

static func snowwhite_moveset():
	var move1 = load('res://abilities/snowwhite1.tscn').instantiate()
	var move2 = load('res://abilities/snowwhite2.tscn').instantiate()
	var move3 = load('res://abilities/snowwhite3.tscn').instantiate()
	var move4 = load('res://abilities/snowwhite4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset

static func tamaki_moveset():
	var move1 = load('res://abilities/tamaki1.tscn').instantiate()
	var move2 = load('res://abilities/tamaki2.tscn').instantiate()
	var move3 = load('res://abilities/tamaki3.tscn').instantiate()
	var move4 = load('res://abilities/tamaki4.tscn').instantiate()
	var move5 = load('res://abilities/tamaki5.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

static func tsunayoshi_moveset():
	var move1 = load('res://abilities/tsunayoshi1.tscn').instantiate()
	var move2 = load('res://abilities/tsunayoshi2.tscn').instantiate()
	var move3 = load('res://abilities/tsunayoshi3.tscn').instantiate()
	var move4 = load('res://abilities/tsunayoshi4.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset

static func yamamoto_moveset():
	var move1 = load('res://abilities/yamamoto1.tscn').instantiate()
	var move2 = load('res://abilities/yamamoto2.tscn').instantiate()
	var move3 = load('res://abilities/yamamoto3.tscn').instantiate()
	var move4 = load('res://abilities/yamamoto4.tscn').instantiate()
	var move5 = load('res://abilities/yamamoto5.tscn').instantiate()
	var move6 = load('res://abilities/yamamoto6.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6
	]
	return moveset

static func yuno_moveset():
	var move1 = load('res://abilities/yuno1.tscn').instantiate()
	var move2 = load('res://abilities/yuno2.tscn').instantiate()
	var move3 = load('res://abilities/yuno3.tscn').instantiate()
	var move4 = load('res://abilities/yuno4.tscn').instantiate()
	var move5 = load('res://abilities/yuno5.tscn').instantiate()
	var move6 = load('res://abilities/yuno6.tscn').instantiate()
	var move7 = load('res://abilities/yuno7.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6,
		move7
	]
	return moveset


static func uraraka_moveset():
	var comet = load('res://abilities/uraraka1.tscn').instantiate()
	var zero = load('res://abilities/uraraka2.tscn').instantiate()
	var comet_shower = load('res://abilities/uraraka3.tscn').instantiate()
	var urafloat = load('res://abilities/uraraka4.tscn').instantiate()
	var comet_throw = load('res://abilities/uraraka5.tscn').instantiate()
	var gravity_plus = load('res://abilities/uraraka6.tscn').instantiate()
	var moveset = [
		comet,
		zero,
		comet_shower,
		urafloat,
		comet_throw,
		gravity_plus
	]
	return moveset
	
static func luffy_moveset():
	var pistol = load('res://abilities/luffy1.tscn').instantiate()
	var gatling = load('res://abilities/luffy2.tscn').instantiate()
	var bazooka = load('res://abilities/luffy3.tscn').instantiate()
	var balloon = load('res://abilities/luffy4.tscn').instantiate()
	var passive = load('res://abilities/luffy5.tscn').instantiate()
	var moveset = [
		pistol,
		gatling,
		bazooka,
		balloon,
		passive
	]
	return moveset

static func uryu_moveset():
	var quincy = load('res://abilities/uryu1.tscn').instantiate()
	var kojaku = load('res://abilities/uryu2.tscn').instantiate()
	var seele = load('res://abilities/uryu3.tscn').instantiate()
	var evasion = load('res://abilities/uryu4.tscn').instantiate()
	var final = load('res://abilities/uryu5.tscn').instantiate()
	var moveset = [
		quincy,
		kojaku,
		seele,
		evasion,
		final
	]
	return moveset

static func naruto_moveset():
	var move1 = load('res://abilities/naruto1.tscn').instantiate()
	var move2 = load('res://abilities/naruto2.tscn').instantiate()
	var move3 = load('res://abilities/naruto3.tscn').instantiate()
	var move4 = load('res://abilities/naruto4.tscn').instantiate()
	var move5 = load('res://abilities/naruto5.tscn').instantiate()
	var move6 = load('res://abilities/naruto6.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6,
	]
	return moveset
	

static func aang_moveset():
	var move1 = load('res://abilities/aang1.tscn').instantiate()
	var move2 = load('res://abilities/aang2.tscn').instantiate()
	var move3 = load('res://abilities/aang3.tscn').instantiate()
	var move4 = load('res://abilities/aang4.tscn').instantiate()
	var move5 = load('res://abilities/aang5.tscn').instantiate()
	var move6 = load('res://abilities/aang6.tscn').instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6
	]
	return moveset

static func sayaka_moveset():
	var move1 = load("res://abilities/sayaka1.tscn").instantiate()
	var move2 = load("res://abilities/sayaka2.tscn").instantiate()
	var move3 = load("res://abilities/sayaka3.tscn").instantiate()
	var move4 = load("res://abilities/sayaka4.tscn").instantiate()
	var move5 = load("res://abilities/sayaka5.tscn").instantiate()
	var move6 = load("res://abilities/sayaka6.tscn").instantiate()
	var move7 = load("res://abilities/sayaka7.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6,
		move7
	]
	
	return moveset

static func madoka_moveset():
	var move1 = load("res://abilities/madoka1.tscn").instantiate()
	var move2 = load("res://abilities/madoka2.tscn").instantiate()
	var move3 = load("res://abilities/madoka3.tscn").instantiate()
	var move4 = load("res://abilities/madoka4.tscn").instantiate()
	var move5 = load("res://abilities/madoka5.tscn").instantiate()
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	
	return moveset

	
static func ganta_moveset():
	var move1 = load("res://abilities/ganta1.tscn").instantiate()
	var move2 = load("res://abilities/ganta2.tscn").instantiate()
	var move3 = load("res://abilities/ganta3.tscn").instantiate()
	var move4 = load("res://abilities/ganta4.tscn").instantiate()
	var move5 = load("res://abilities/ganta5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset
	
static func tatsumi_moveset():
	var move1 = load("res://abilities/tatsumi1.tscn").instantiate()
	var move2 = load("res://abilities/tatsumi2.tscn").instantiate()
	var move3 = load("res://abilities/tatsumi3.tscn").instantiate()
	var move4 = load("res://abilities/tatsumi4.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset
	
static func shiro_moveset():
	var move1 = load("res://abilities/shiro1.tscn").instantiate()
	var move2 = load("res://abilities/shiro2.tscn").instantiate()
	var move3 = load("res://abilities/shiro3.tscn").instantiate()
	var move4 = load("res://abilities/shiro4.tscn").instantiate()
	var move5 = load("res://abilities/shiro5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

static func invincible_moveset():
	var move1 = load("res://abilities/invincible1.tscn").instantiate()
	var move2 = load("res://abilities/invincible2.tscn").instantiate()
	var move3 = load("res://abilities/invincible3.tscn").instantiate()
	var move4 = load("res://abilities/invincible4.tscn").instantiate()
	var move5 = load("res://abilities/invincible5.tscn").instantiate()
	var move6 = load("res://abilities/invincible6.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6
	]
	return moveset
	
static func atomeve_moveset():
	var move1 = load("res://abilities/atomeve1.tscn").instantiate()
	var move2 = load("res://abilities/atomeve2.tscn").instantiate()
	var move3 = load("res://abilities/atomeve3.tscn").instantiate()
	var move4 = load("res://abilities/atomeve4.tscn").instantiate()
	var move5 = load("res://abilities/atomeve5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

	
static func goku_moveset():
	var move1 = load("res://abilities/goku1.tscn").instantiate()
	var move2 = load("res://abilities/goku2.tscn").instantiate()
	var move3 = load("res://abilities/goku3.tscn").instantiate()
	var move4 = load("res://abilities/goku4.tscn").instantiate()
	var move5 = load("res://abilities/goku5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

	
static func vegeta_moveset():
	var move1 = load("res://abilities/vegeta1.tscn").instantiate()
	var move2 = load("res://abilities/vegeta2.tscn").instantiate()
	var move3 = load("res://abilities/vegeta3.tscn").instantiate()
	var move4 = load("res://abilities/vegeta4.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset

	
static func edward_moveset():
	var move1 = load("res://abilities/edward1.tscn").instantiate()
	var move2 = load("res://abilities/edward2.tscn").instantiate()
	var move3 = load("res://abilities/edward3.tscn").instantiate()
	var move4 = load("res://abilities/edward4.tscn").instantiate()
	var move5 = load("res://abilities/edward5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

	
static func alphonse_moveset():
	var move1 = load("res://abilities/alphonse1.tscn").instantiate()
	var move2 = load("res://abilities/alphonse2.tscn").instantiate()
	var move3 = load("res://abilities/alphonse3.tscn").instantiate()
	var move4 = load("res://abilities/alphonse4.tscn").instantiate()
	var move5 = load("res://abilities/alphonse5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

static func omniman_moveset():
	var move1 = load("res://abilities/omniman1.tscn").instantiate()
	var move2 = load("res://abilities/omniman2.tscn").instantiate()
	var move3 = load("res://abilities/omniman3.tscn").instantiate()
	var move4 = load("res://abilities/omniman4.tscn").instantiate()
	var move5 = load("res://abilities/omniman5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

static func byakuya_moveset():
	var move1 = load("res://abilities/byakuya1.tscn").instantiate()
	var move2 = load("res://abilities/byakuya2.tscn").instantiate()
	var move3 = load("res://abilities/byakuya3.tscn").instantiate()
	var move4 = load("res://abilities/byakuya4.tscn").instantiate()
	var move5 = load("res://abilities/byakuya5.tscn").instantiate()
	var move6 = load("res://abilities/byakuya6.tscn").instantiate()
	var move7 = load("res://abilities/byakuya7.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6,
		move7
	]
	return moveset

static func gatomon_moveset():
	var move1 = load("res://abilities/gatomon1.tscn").instantiate()
	var move2 = load("res://abilities/gatomon2.tscn").instantiate()
	var move3 = load("res://abilities/gatomon3.tscn").instantiate()
	var move4 = load("res://abilities/gatomon4.tscn").instantiate()
	var move5 = load("res://abilities/gatomon5.tscn").instantiate()
	var move6 = load("res://abilities/gatomon6.tscn").instantiate()
	var move7 = load("res://abilities/gatomon7.tscn").instantiate()
	var move8 = load("res://abilities/gatomon8.tscn").instantiate()
	var move9 = load("res://abilities/gatomon9.tscn").instantiate()
	var move10 = load("res://abilities/gatomon10.tscn").instantiate()
	var move11 = load("res://abilities/gatomon11.tscn").instantiate()
	var move12 = load("res://abilities/gatomon12.tscn").instantiate()
	var move13 = load("res://abilities/gatomon13.tscn").instantiate()
	var move14 = load("res://abilities/gatomon14.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6,
		move7,
		move8,
		move9,
		move10,
		move11,
		move12,
		move13,
		move14
	]
	return moveset


static func mash_moveset():
	var move1 = load("res://abilities/mash1.tscn").instantiate()
	var move2 = load("res://abilities/mash2.tscn").instantiate()
	var move3 = load("res://abilities/mash3.tscn").instantiate()
	var move4 = load("res://abilities/mash4.tscn").instantiate()
	var move5 = load("res://abilities/mash5.tscn").instantiate()
	var move6 = load("res://abilities/mash6.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5,
		move6
	]
	return moveset

static func nimaiya_moveset():
	var move1 = load("res://abilities/nimaiya1.tscn").instantiate()
	var move2 = load("res://abilities/nimaiya2.tscn").instantiate()
	var move3 = load("res://abilities/nimaiya3.tscn").instantiate()
	var move4 = load("res://abilities/nimaiya4.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset
	
static func gallantmon_moveset():
	var move1 = load("res://abilities/gallantmon1.tscn").instantiate()
	var move2 = load("res://abilities/gallantmon2.tscn").instantiate()
	var move3 = load("res://abilities/gallantmon3.tscn").instantiate()
	var move4 = load("res://abilities/gallantmon4.tscn").instantiate()
	var move5 = load("res://abilities/gallantmon5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

	
static func hashirama_moveset():
	var move1 = load("res://abilities/hashirama1.tscn").instantiate()
	var move2 = load("res://abilities/hashirama2.tscn").instantiate()
	var move3 = load("res://abilities/hashirama3.tscn").instantiate()
	var move4 = load("res://abilities/hashirama4.tscn").instantiate()
	var move5 = load("res://abilities/hashirama5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset
	
static func omnimon_moveset():
	var move1 = load("res://abilities/omnimon1.tscn").instantiate()
	var move2 = load("res://abilities/omnimon2.tscn").instantiate()
	var move3 = load("res://abilities/omnimon3.tscn").instantiate()
	var move4 = load("res://abilities/omnimon4.tscn").instantiate()
	var move5 = load("res://abilities/omnimon5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset
	
static func koro_moveset():
	var move1 = load("res://abilities/koro1.tscn").instantiate()
	var move2 = load("res://abilities/koro2.tscn").instantiate()
	var move3 = load("res://abilities/koro3.tscn").instantiate()
	var move4 = load("res://abilities/koro4.tscn").instantiate()
	var move5 = load("res://abilities/koro5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

static func nagisa_moveset():
	var move1 = load("res://abilities/nagisa1.tscn").instantiate()
	var move2 = load("res://abilities/nagisa2.tscn").instantiate()
	var move3 = load("res://abilities/nagisa3.tscn").instantiate()
	var move4 = load("res://abilities/nagisa4.tscn").instantiate()
	var move5 = load("res://abilities/nagisa5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

static func toga_moveset():
	var move1 = load("res://abilities/toga1.tscn").instantiate()
	var move2 = load("res://abilities/toga2.tscn").instantiate()
	var move3 = load("res://abilities/toga3.tscn").instantiate()
	var move4 = load("res://abilities/toga4.tscn").instantiate()
	var move5 = load("res://abilities/toga5.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4,
		move5
	]
	return moveset

static func frankenstein_moveset():
	var move1 = load("res://abilities/frankenstein1.tscn").instantiate()
	var move2 = load("res://abilities/frankenstein2.tscn").instantiate()
	var move3 = load("res://abilities/frankenstein3.tscn").instantiate()
	var move4 = load("res://abilities/frankenstein4.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset


static func myotismon_moveset():
	var move1 = load("res://abilities/myotismon1.tscn").instantiate()
	var move2 = load("res://abilities/myotismon2.tscn").instantiate()
	var move3 = load("res://abilities/myotismon3.tscn").instantiate()
	var move4 = load("res://abilities/myotismon4.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset

static func mars_moveset():
	var move1 = load("res://abilities/mars1.tscn").instantiate()
	var move2 = load("res://abilities/mars2.tscn").instantiate()
	var move3 = load("res://abilities/mars3.tscn").instantiate()
	var move4 = load("res://abilities/mars4.tscn").instantiate()
	
	var moveset = [
		move1,
		move2,
		move3,
		move4
	]
	return moveset


static func laria_moveset():
	var moveset = []
	var nightwrap = load("res://abilities/nightwrap.tscn").instantiate()
	var soothing_darkness = load("res://abilities/soothing_night.tscn").instantiate()
	var suffocating_darkness = load("res://abilities/suffocating_night.tscn").instantiate()
	var shadowblade = load("res://abilities/shadowblade.tscn").instantiate()
	var nightfall = load("res://abilities/nightfall.tscn").instantiate()
	moveset.append(nightwrap)
	moveset.append(soothing_darkness)
	moveset.append(suffocating_darkness)
	moveset.append(shadowblade)
	moveset.append(nightfall)
	return moveset
	
static func pyrrha_moveset():
	var moveset = []
	var pyrrha1 = load("res://abilities/pyrrha1.tscn").instantiate()
	var pyrrha2 = load("res://abilities/pyrrha2.tscn").instantiate()
	var pyrrha3 = load("res://abilities/pyrrha3.tscn").instantiate()
	var pyrrha4 = load("res://abilities/pyrrha4.tscn").instantiate()
	var pyrrha5 = load("res://abilities/pyrrha5.tscn").instantiate()
	moveset.append(pyrrha1)
	moveset.append(pyrrha2)
	moveset.append(pyrrha3)
	moveset.append(pyrrha4)
	moveset.append(pyrrha5)
	return moveset

static func gommar_moveset():
	var moveset = []
	var iceblood_hammer = load("res://abilities/iceblood_hammer.tscn").instantiate()
	var horn_of_winter = load("res://abilities/horn_of_winter.tscn").instantiate()
	var howling_blast = load("res://abilities/howling_blast.tscn").instantiate()
	var absolute_zero = load("res://abilities/absolute_zero.tscn").instantiate()
	var frozen_rampart = load("res://abilities/frozen_rampart.tscn").instantiate()
	moveset.append(iceblood_hammer)
	moveset.append(horn_of_winter)
	moveset.append(howling_blast)
	moveset.append(absolute_zero)
	moveset.append(frozen_rampart)
	return moveset

	
static func augur_moveset():
	var moveset = []
	var alter_fate = load("res://abilities/alter_fate.tscn").instantiate()
	var augury_storm = load("res://abilities/augury_storm.tscn").instantiate()
	var cloudless_skies = load("res://abilities/cloudless_skies.tscn").instantiate()
	var forewarn = load("res://abilities/forewarn.tscn").instantiate()
	var day_of_destiny = load("res://abilities/day_of_destiny.tscn").instantiate()
	moveset.append(alter_fate)
	moveset.append(augury_storm)
	moveset.append(cloudless_skies)
	moveset.append(forewarn)
	moveset.append(day_of_destiny)
	return moveset

static func riverdaughter_moveset():
	var moveset = []
	var current = load("res://abilities/river_daughter_1.tscn").instantiate()
	var undertow = load("res://abilities/river_daughter_2.tscn").instantiate()
	var ripple = load("res://abilities/river_daughter_3.tscn").instantiate()
	var dive = load("res://abilities/river_daughter_4.tscn").instantiate()
	var river_clone = load("res://abilities/river_daughter_5.tscn").instantiate()
	moveset.append(current)
	moveset.append(undertow)
	moveset.append(ripple)
	moveset.append(dive)
	moveset.append(river_clone)
	return moveset

	
static func psymon_moveset():
	var moveset = []
	var give_and_take = load("res://abilities/give_and_take.tscn").instantiate()
	var sample_buff_ability = load("res://abilities/burning_blood_serum.tscn").instantiate()
	var sample_multi_turn_affliction_ability = load("res://abilities/stone_bone_serum.tscn").instantiate()
	var sample_aoe_ability = load("res://abilities/rage_serum.tscn").instantiate()
	var syringe = load("res://abilities/horrifying_syringe_trap.tscn").instantiate()
	moveset.append(give_and_take)
	moveset.append(sample_buff_ability)
	moveset.append(sample_multi_turn_affliction_ability)
	moveset.append(sample_aoe_ability)
	moveset.append(syringe)
	return moveset

static func saya_moveset():
	var moveset = []
	var sample_damage_ability = load("res://abilities/handcrank.tscn").instantiate()
	var sample_buff_ability = load("res://abilities/universal_energy_conduit.tscn").instantiate()
	var sample_multi_turn_affliction_ability = load("res://abilities/saya_coil.tscn").instantiate()
	var sample_aoe_ability = load("res://abilities/spider_mines.tscn").instantiate()
	var panic = load("res://abilities/well_used_panic_button.tscn").instantiate()
	moveset.append(sample_damage_ability)
	moveset.append(sample_buff_ability)
	moveset.append(sample_multi_turn_affliction_ability)
	moveset.append(sample_aoe_ability)
	moveset.append(panic)
	return moveset

	
static func gaia_moveset():
	var moveset = []
	var sample_damage_ability = load("res://abilities/gaia_1.tscn").instantiate()
	var sample_buff_ability = load("res://abilities/gaia_2.tscn").instantiate()
	var sample_multi_turn_affliction_ability = load("res://abilities/gaia_3.tscn").instantiate()
	var sample_aoe_ability = load("res://abilities/gaia_4.tscn").instantiate()
	var gaia5 = load("res://abilities/gaia_5.tscn").instantiate()
	moveset.append(sample_damage_ability)
	moveset.append(sample_buff_ability)
	moveset.append(sample_multi_turn_affliction_ability)
	moveset.append(sample_aoe_ability)
	moveset.append(gaia5)
	return moveset

static func ayana_moveset():
	var moveset = []
	var sample_damage_ability = load("res://abilities/voice_of_light.tscn").instantiate()
	var sample_buff_ability = load("res://abilities/honor_guard.tscn").instantiate()
	var sample_multi_turn_affliction_ability = load("res://abilities/hymn_of_valor.tscn").instantiate()
	var sample_aoe_ability = load("res://abilities/hymn_of_hope.tscn").instantiate()
	var chorus = load("res://abilities/chorus.tscn").instantiate()
	moveset.append(sample_damage_ability)
	moveset.append(sample_buff_ability)
	moveset.append(sample_multi_turn_affliction_ability)
	moveset.append(sample_aoe_ability)
	moveset.append(chorus)
	return moveset

static func blackknight_moveset():
	var moveset = []
	var sample_damage_ability = load("res://abilities/oathbreaker_strike.tscn").instantiate()
	var sample_buff_ability = load("res://abilities/misery.tscn").instantiate()
	var sample_multi_turn_affliction_ability = load("res://abilities/unholy_aura.tscn").instantiate()
	var sample_aoe_ability = load("res://abilities/the_nightmare_rides.tscn").instantiate()
	var soul_cleave = load("res://abilities/soul_cleave.tscn").instantiate()
	moveset.append(sample_damage_ability)
	moveset.append(sample_buff_ability)
	moveset.append(sample_multi_turn_affliction_ability)
	moveset.append(sample_aoe_ability)
	moveset.append(soul_cleave)
	return moveset

static func _moveset():
	var moveset = []
	
	return moveset
	


static func execution_request(user, battle, ability_identifier):
	var expression = Expression.new()
	var movesets = load("res://scripts/movesets.gd")
	expression.parse("exec_" + ability_identifier + "(x, y)", ["x", "y"])
	expression.execute([user, battle], movesets)

static func targeting_request(user, battle, ability_identifier):
	var expression = Expression.new()
	var movesets = load("res://scripts/movesets.gd")
	expression.parse("tar_" + ability_identifier + "(x, y)", ["x", "y"])
	expression.execute([user, battle], movesets)

static func extra_usable(user, ability_identifier):
	pass
