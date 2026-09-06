extends Node
class_name BucketHandler

var current_active_buckets: Dictionary
var all_buckets: Dictionary
var universe_buckets: Dictionary
var peer_active_buckets: Dictionary
var waiting_panel
var current_max = 0
var poll_active = true
# path_name -> true for every character removed from the Nexus (permanently, via an admin round-close).
# Loaded from bucket data/removed_list.dat at boot so removals survive restarts. The names below are
# permanently excluded regardless (see PERMANENT_EXCLUDED / _is_removed).
var removed_set: Dictionary = {}
# Characters CONFIRMED for the playable roster. The Nexus is a poll for what to build next, so once a
# character is greenlit there is nothing left to vote on and they come out of the running.
# They stay in `all_chars` on purpose: the entry is what resolves an existing donation or a
# removed_list row, so deleting it would strand that history rather than retire the candidate.
const PERMANENT_EXCLUDED := ["muichiro", "shirou", "muzan", "subaru", "law", "frieza", "yoruichi", "fern", "stark",
	"nagato", "yusuke", "piccolo", "sesshomaru"]
# Characters RETIRED from the Nexus by owner request (NOT roster-greenlit — simply pulled from the running).
# Same effect as a round-close removal, but code-level so it survives restarts and can't be clobbered by a
# later round-close rewriting removed_list.dat. Entries stay in `all_chars` below to keep any existing donation
# history resolvable — same reasoning as PERMANENT_EXCLUDED above.
const OWNER_RETIRED := ["baki", "aizen", "synshenron", "accelerator"]

@export var server: ServerConnection

signal change_active_buckets(buckets)
signal request_universe_buckets()
signal request_character_buckets(universe_name)
signal send_character_buckets(current_max, info_sets)
signal send_universe_buckets(info_sets)
signal broadcast_active_buckets(buckets)
signal broadcast_player_contribution(path_name, amount)
signal broadcast_leaderboard_sets(sets)
signal client_disconnected()
var all_chars = {
	"baki": CharacterConcept.create("Baki Hanma", "baki", load("res://assets/images/Baki Hanma/bakiprof.png"), "t", CharacterConcept.Universe.BAKI),
	"jackhanma": CharacterConcept.create("Jack Hanma", "jackhanma", load("res://assets/images/Jack Hanma/jackhanmaprof.png"), "t", CharacterConcept.Universe.BAKI),
	"yujirohanma": CharacterConcept.create("Yujiro Hanma", "yujirohanma", load("res://assets/images/Yujiro Hanma/yujirohanmaprof.png"), "t", CharacterConcept.Universe.BAKI),
	"retsu": CharacterConcept.create("Retsu Kaioh", "retsu", load("res://assets/images/Retsu Kaioh/retsuprof.png"), "t", CharacterConcept.Universe.BAKI),
	"hanayama": CharacterConcept.create("Kaoru Hanayama", "hanayama", load("res://assets/images/Kaoru Hanayama/hanayamaprof.png"), "t", CharacterConcept.Universe.BAKI),
	"biscuit": CharacterConcept.create("Biscuit Oliva", "biscuit", load("res://assets/images/Biscuit Oliva/biscuitprof.png"), "t", CharacterConcept.Universe.BAKI),
	"chris": CharacterConcept.create("Chris Yukine", "chris", load("res://assets/images/Chris Yukine/chrisprof.png"), "t", CharacterConcept.Universe.SYMPHOGEAR),
	"maria": CharacterConcept.create("Maria Cadenzavna Eve", "maria", load("res://assets/images/Maria Cadenzavna Eve/mariaprof.png"), "t", CharacterConcept.Universe.SYMPHOGEAR),
	"kirika": CharacterConcept.create("Kirika Akatsuki", "kirika", load("res://assets/images/Kirika Akatsuki/kirikaprof.png"), "t", CharacterConcept.Universe.SYMPHOGEAR),
	"shirabe": CharacterConcept.create("Shirabe Tsukumo", "shirabe", load("res://assets/images/Shirabe Tsukumo/shirabeprof.png"), "t", CharacterConcept.Universe.SYMPHOGEAR),
	"skullgreymon": CharacterConcept.create("SkullGreymon", "skullgreymon", load("res://assets/images/SkullGreymon/skullgreymonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"excalibur": CharacterConcept.create("Excalibur", "excalibur", load("res://assets/images/Excalibur/excaliburprof.png"), "t", CharacterConcept.Universe.SOUL_EATER),
	"kiba": CharacterConcept.create("Kiba Inuzuka", "kiba", load("res://assets/images/Kiba Inuzuka/kibaprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"shino": CharacterConcept.create("Shino Aburame", "shino", load("res://assets/images/Shino Aburame/shinoprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"shikamaru": CharacterConcept.create("Shikamaru Nara", "shikamaru", load("res://assets/images/Shikamaru Nara/shikamaruprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"ino": CharacterConcept.create("Ino Yamanaka", "ino", load("res://assets/images/Ino Yamanaka/inoprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"choji": CharacterConcept.create("Choji Akimichi", "choji", load("res://assets/images/Choji Akimichi/chojiprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"neji": CharacterConcept.create("Neji Hyuga", "neji", load("res://assets/images/Neji Hyuga/nejiprof.jpg"), "t", CharacterConcept.Universe.NARUTO),
	"tenten": CharacterConcept.create("Tenten", "tenten", load("res://assets/images/Tenten/tentenprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"lee": CharacterConcept.create("Rock Lee", "lee", load("res://assets/images/Rock Lee/leeprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"temari": CharacterConcept.create("Temari", "temari", load("res://assets/images/Temari/temariprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"kankuro": CharacterConcept.create("Kankuro", "kankuro", load("res://assets/images/Kankuro/kankuroprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"gaara": CharacterConcept.create("Gaara", "gaara", load("res://assets/images/Gaara/gaaraprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"kakashi": CharacterConcept.create("Kakashi Hatake", "kakashi", load("res://assets/images/Kakashi Hatake/kakashiprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"akainu": CharacterConcept.create("Akainu", "akainu", load("res://assets/images/Akainu/akainuprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"amajiki": CharacterConcept.create("Tamaki Amajiki", "amajiki", load("res://assets/images/Tamaki Amajiki/amajikiprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"arachne": CharacterConcept.create("Arachne Gorgon", "arachne", load("res://assets/images/Arachne Gorgon/arachneprof.png"), "t", CharacterConcept.Universe.SOUL_EATER),
	"as": CharacterConcept.create("As Nodt", "as", load("res://assets/images/As Nodt/asprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"asuma": CharacterConcept.create("Asuma Sarutobi", "asuma", load("res://assets/images/Asuma Sarutobi/asumaprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"bambietta": CharacterConcept.create("Bambietta Basterbine", "bambietta", load("res://assets/images/Bambietta Basterbine/bambiettaprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"barragan": CharacterConcept.create("Barragan Luisenbarn", "barragan", load("res://assets/images/Barragan Luisenbarn/barraganprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"bg9": CharacterConcept.create("BG-9", "bg9", load("res://assets/images/BG-9/bg9prof.png"), "t", CharacterConcept.Universe.BLEACH),
	"blackbeard": CharacterConcept.create("Marshall D. Teach", "blackbeard", load("res://assets/images/Marshall D. Teach/blackbeardprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"candice": CharacterConcept.create("Candice Catnipp", "candice", load("res://assets/images/Candice Catnipp/candiceprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"cang": CharacterConcept.create("Cang Du", "cang", load("res://assets/images/Cang Du/cangprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"chad": CharacterConcept.create("Yasutora Sado", "chad", load("res://assets/images/Yasutora Sado/chadprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"chopper": CharacterConcept.create("Tony Tony Chopper", "chopper", load("res://assets/images/Tony Tony Chopper/chopperprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"deidara": CharacterConcept.create("Deidara", "deidara", load("res://assets/images/Deidara/deidaraprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"doflamingo": CharacterConcept.create("Donquixote Doflamingo", "doflamingo", load("res://assets/images/Donquixote Doflamingo/doflamingoprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"endeavor": CharacterConcept.create("Endeavor", "endeavor", load("res://assets/images/Endeavor/endeavorprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"enel": CharacterConcept.create("Enel", "enel", load("res://assets/images/Enel/enelprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"eraser": CharacterConcept.create("Eraser Head", "eraser", load("res://assets/images/Eraser Head/eraserprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"eruka": CharacterConcept.create("Eruka Frog", "eruka", load("res://assets/images/Eruka Frog/erukaprof.png"), "t", CharacterConcept.Universe.SOUL_EATER),
	"eustass": CharacterConcept.create("Eustass Kid", "eustass", load("res://assets/images/Eustass Kid/eustassprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"franky": CharacterConcept.create("Franky", "franky", load("res://assets/images/Franky/frankyprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"fujitora": CharacterConcept.create("Fujitora", "fujitora", load("res://assets/images/Fujitora/fujitoraprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"gandlb": CharacterConcept.create("Gentle and La Brava", "gandlb", load("res://assets/images/Gentle and La Brava/gandlbprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"genryuusai": CharacterConcept.create("Yamamoto Genryuusai", "genryuusai", load("res://assets/images/Yamamoto Genryuusai/genryuusaiprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"grimmjow": CharacterConcept.create("Grimmjow Jaegerjaquez", "grimmjow", load("res://assets/images/Grimmjow Jaegerjaquez/grimmjowprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"guy": CharacterConcept.create("Might Guy", "guy", load("res://assets/images/Might Guy/guyprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"hawks": CharacterConcept.create("Hawks", "hawks", load("res://assets/images/Hawks/hawksprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"hiyori": CharacterConcept.create("Hiyori Sarugaki", "hiyori", load("res://assets/images/Hiyori Sarugaki/hiyoriprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"ichimaru": CharacterConcept.create("Ichimaru Gin", "ichimaru", load("res://assets/images/Ichimaru Gin/ichimaruprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"ida": CharacterConcept.create("Tenya Ida", "ida", load("res://assets/images/Tenya Ida/idaprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"ikkaku": CharacterConcept.create("Ikkaku Madarame", "ikkaku", load("res://assets/images/Ikkaku Madarame/ikkakuprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"jeanist": CharacterConcept.create("Best Jeanist", "jeanist", load("res://assets/images/Best Jeanist/jeanistprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"kabuto": CharacterConcept.create("Yakushi Kabuto", "kabuto", load("res://assets/images/Yakushi Kabuto/kabutoprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"kaien": CharacterConcept.create("Shiba Kaien", "kaien", load("res://assets/images/Shiba Kaien/kaienprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"kakuzu": CharacterConcept.create("Kakuzu", "kakuzu", load("res://assets/images/Kakuzu/kakuzuprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"kamui": CharacterConcept.create("Kamui Woods", "kamui", load("res://assets/images/Kamui Woods/kamuiprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"kensei": CharacterConcept.create("Kensei Muguruma", "kensei", load("res://assets/images/Kensei Muguruma/kenseiprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"killerbee": CharacterConcept.create("Killer Bee", "killerbee", load("res://assets/images/Killer Bee/killerbeeprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"kirio": CharacterConcept.create("Kirio Hikifune", "kirio", load("res://assets/images/Kirio Hikifune/kirioprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"kisame": CharacterConcept.create("Hoshigaki Kisame", "kisame", load("res://assets/images/Hoshigaki Kisame/kisameprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"kishin": CharacterConcept.create("Kishin", "kishin", load("res://assets/images/Kishin/kishinprof.png"), "t", CharacterConcept.Universe.SOUL_EATER),
	"kizaru": CharacterConcept.create("Kizaru", "kizaru", load("res://assets/images/Kizaru/kizaruprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"komamura": CharacterConcept.create("Komamura Sajin", "komamura", load("res://assets/images/Komamura Sajin/komamuraprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"konan": CharacterConcept.create("Konan", "konan", load("res://assets/images/Konan/konanprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"kuma": CharacterConcept.create("Bartholomew Kuma", "kuma", load("res://assets/images/Bartholomew Kuma/kumaprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"kurenai": CharacterConcept.create("Yuhi Kurenai", "kurenai", load("res://assets/images/Yuhi Kurenai/kurenaiprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"kyouraku": CharacterConcept.create("Shunsui Kyouraku", "kyouraku", load("res://assets/images/Shunsui Kyouraku/kyourakuprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"law": CharacterConcept.create("Trafalgar Law", "law", load("res://assets/images/Trafalgar Law/lawprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"liltotto": CharacterConcept.create("Liltotto Lamperd", "liltotto", load("res://assets/images/Liltotto Lamperd/liltottoprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"luppi": CharacterConcept.create("Luppi Antenor", "luppi", load("res://assets/images/Luppi Antenor/luppiprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"madara": CharacterConcept.create("Uchiha Madara", "madara", load("res://assets/images/Uchiha Madara/madaraprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"mashiro": CharacterConcept.create("Mashiro Kuna", "mashiro", load("res://assets/images/Mashiro Kuna/mashiroprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"mask": CharacterConcept.create("Mask de Masculine", "mask", load("res://assets/images/Mask de Masculine/maskprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"mei": CharacterConcept.create("Mei Terumi", "mei", load("res://assets/images/Mei Terumi/meiprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"meihatsume": CharacterConcept.create("Mei Hatsume", "meihatsume", load("res://assets/images/Mei Hatsume/meihatsumeprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"mic": CharacterConcept.create("Present Mic", "mic", load("res://assets/images/Present Mic/micprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"midnight": CharacterConcept.create("Midnight", "midnight", load("res://assets/images/Midnight/midnightprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"mifune": CharacterConcept.create("Mifune", "mifune", load("res://assets/images/Mifune/mifuneprof.png"), "t", CharacterConcept.Universe.SOUL_EATER),
	"mihawk": CharacterConcept.create("Dracule Mihawk", "mihawk", load("res://assets/images/Dracule Mihawk/mihawkprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"mirko": CharacterConcept.create("Mirko", "mirko", load("res://assets/images/Mirko/mirkoprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"mtlady": CharacterConcept.create("Mt Lady", "mtlady", load("res://assets/images/Mt Lady/mtladyprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"nagato": CharacterConcept.create("Nagato", "nagato", load("res://assets/images/Nagato/nagatoprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"nami": CharacterConcept.create("Nami", "nami", load("res://assets/images/Nami/namiprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"nejire": CharacterConcept.create("Nejire Hado", "nejire", load("res://assets/images/Nejire Hado/nejireprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"nidaime": CharacterConcept.create("Tobirama Senju", "nidaime", load("res://assets/images/Tobirama Senju/nidaimeprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"nighteye": CharacterConcept.create("Nighteye", "nighteye", load("res://assets/images/Nighteye/nighteyeprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"obito": CharacterConcept.create("Uchiha Obito", "obito", load("res://assets/images/Uchiha Obito/obitoprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"oonoki": CharacterConcept.create("Oonoki", "oonoki", load("res://assets/images/Oonoki/oonokiprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"orochimaru": CharacterConcept.create("Orochimaru", "orochimaru", load("res://assets/images/Orochimaru/orochimaruprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"perona": CharacterConcept.create("Perona", "perona", load("res://assets/images/Perona/peronaprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"redriot": CharacterConcept.create("Eijiro Kirishima", "redriot", load("res://assets/images/Eijiro Kirishima/redriotprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"renji": CharacterConcept.create("Abarai Renji", "renji", load("res://assets/images/Abarai Renji/renjiprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"robin": CharacterConcept.create("Nico Robin", "robin", load("res://assets/images/Nico Robin/robinprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"rose": CharacterConcept.create("Rose Otoribashi", "rose", load("res://assets/images/Rose Otoribashi/roseprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"sabo": CharacterConcept.create("Sabo", "sabo", load("res://assets/images/Sabo/saboprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"sai": CharacterConcept.create("Sai", "sai", load("res://assets/images/Sai/saiprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"sanji": CharacterConcept.create("Sanji", "sanji", load("res://assets/images/Sanji/sanjiprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"sasori": CharacterConcept.create("Sasori", "sasori", load("res://assets/images/Sasori/sasoriprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"senjumaru": CharacterConcept.create("Senjumaru Shutara", "senjumaru", load("res://assets/images/Senjumaru Shutara/senjumaruprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"shinji": CharacterConcept.create("Shinji Hirako", "shinji", load("res://assets/images/Shinji Hirako/shinjiprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"shinso": CharacterConcept.create("Hitoshi Shinso", "shinso", load("res://assets/images/Hitoshi Shinso/shinsoprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"smoker": CharacterConcept.create("Smoker", "smoker", load("res://assets/images/Smoker/smokerprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"soifon": CharacterConcept.create("Soi Fon", "soifon", load("res://assets/images/Soi Fon/soifonprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"stain": CharacterConcept.create("Stain", "stain", load("res://assets/images/Stain/stainprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"starrk": CharacterConcept.create("Coyote Starrk", "starrk", load("res://assets/images/Coyote Starrk/starrkprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"szayel": CharacterConcept.create("Szayel Aporro Granz", "szayel", load("res://assets/images/Szayel Aporro Granz/szayelprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"toshiro": CharacterConcept.create("Toshiro Hitsugaya", "toshiro", load("res://assets/images/Toshiro Hitsugaya/toshiroprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"tousen": CharacterConcept.create("Kaname Tousen", "tousen", load("res://assets/images/Kaname Tousen/tousenprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"tsunade": CharacterConcept.create("Tsunade", "tsunade", load("res://assets/images/Tsunade/tsunadeprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"ukitake": CharacterConcept.create("Juushiro Ukitake", "ukitake", load("res://assets/images/Juushiro Ukitake/ukitakeprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"unohana": CharacterConcept.create("Retsu Unohana", "unohana", load("res://assets/images/Retsu Unohana/unohanaprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"wonderweiss": CharacterConcept.create("Wonderweiss Margera", "wonderweiss", load("res://assets/images/Wonderweiss Margera/wonderweissprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"yachiru": CharacterConcept.create("Yachiru Kusajishi", "yachiru", load("res://assets/images/Yachiru Kusajishi/yachiruprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"yammy": CharacterConcept.create("Yammy Riyalgo", "yammy", load("res://assets/images/Yammy Riyalgo/yammyprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"yaoyorozu": CharacterConcept.create("Momo Yaoyorozu", "yaoyorozu", load("res://assets/images/Momo Yaoyorozu/yaoyorozuprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"yumichika": CharacterConcept.create("Yumichika Ayasegawa", "yumichika", load("res://assets/images/Yumichika Ayasegawa/yumichikaprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"zommari": CharacterConcept.create("Zommari Leroux", "zommari", load("res://assets/images/Zommari Leroux/zommariprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"akaza": CharacterConcept.create("Akaza", "akaza", load("res://assets/images/Akaza/akazaprof.png"), "t", CharacterConcept.Universe.DEMON_SLAYER),
	"allforone": CharacterConcept.create("All For One", "allforone", load("res://assets/images/All For One/allforoneprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"annie": CharacterConcept.create("Annie Leonhart", "annie", load("res://assets/images/Annie Leonhart/annieprof.png"), "t", CharacterConcept.Universe.ATTACK_ON_TITAN),
	"armin": CharacterConcept.create("Armin Arlert", "armin", load("res://assets/images/Armin Arlert/arminprof.png"), "t", CharacterConcept.Universe.ATTACK_ON_TITAN),
	"bertolt": CharacterConcept.create("Bertolt Hoover", "bertolt", load("res://assets/images/Bertolt Hoover/bertoltprof.png"), "t", CharacterConcept.Universe.ATTACK_ON_TITAN),
	"bickslow": CharacterConcept.create("Bickslow", "bickslow", load("res://assets/images/Bickslow/bickslowprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"boros": CharacterConcept.create("Boros", "boros", load("res://assets/images/Boros/borosprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"cana": CharacterConcept.create("Cana Alberona", "cana", load("res://assets/images/Cana Alberona/canaprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"childemperor": CharacterConcept.create("Child Emperor", "childemperor", load("res://assets/images/Child Emperor/childemperorprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"choso": CharacterConcept.create("Choso", "choso", load("res://assets/images/Choso/chosoprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"compress": CharacterConcept.create("Mr Compress", "compress", load("res://assets/images/Mr Compress/compressprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"curious": CharacterConcept.create("Curious", "curious", load("res://assets/images/Curious/curiousprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"dabi": CharacterConcept.create("Dabi", "dabi", load("res://assets/images/Dabi/dabiprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"daki": CharacterConcept.create("Daki", "daki", load("res://assets/images/Daki/dakiprof.png"), "t", CharacterConcept.Universe.DEMON_SLAYER),
	"deathgatling": CharacterConcept.create("Death Gatling", "deathgatling", load("res://assets/images/Death Gatling/deathgatlingprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"driveknight": CharacterConcept.create("Drive Knight", "driveknight", load("res://assets/images/Drive Knight/driveknightprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"elfman": CharacterConcept.create("Elfman", "elfman", load("res://assets/images/Elfman/elfmanprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"enmu": CharacterConcept.create("Enmu", "enmu", load("res://assets/images/Enmu/enmuprof.png"), "t", CharacterConcept.Universe.DEMON_SLAYER),
	"erwin": CharacterConcept.create("Erwin Smith", "erwin", load("res://assets/images/Erwin Smith/erwinprof.png"), "t", CharacterConcept.Universe.ATTACK_ON_TITAN),
	"feitan": CharacterConcept.create("Feitan", "feitan", load("res://assets/images/Feitan/feitanprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"flashy": CharacterConcept.create("Flashy Flash", "flashy", load("res://assets/images/Flashy Flash/flashyprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"franklin": CharacterConcept.create("Franklin Bordeau", "franklin", load("res://assets/images/Franklin Bordeau/franklinprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"freed": CharacterConcept.create("Freed Justine", "freed", load("res://assets/images/Freed Justine/freedprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"gabi": CharacterConcept.create("Gabi Braun", "gabi", load("res://assets/images/Gabi Braun/gabiprof.png"), "t", CharacterConcept.Universe.ATTACK_ON_TITAN),
	"gamefowl": CharacterConcept.create("Game Fowl", "gamefowl", load("res://assets/images/Game Fowl/gamefowlprof.png"), "t", CharacterConcept.Universe.DEADMAN_WONDERLAND),
	"genthru": CharacterConcept.create("Genthru", "genthru", load("res://assets/images/Genthru/genthruprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"genya": CharacterConcept.create("Genya Shinazugawa", "genya", load("res://assets/images/Genya Shinazugawa/genyaprof.png"), "t", CharacterConcept.Universe.DEMON_SLAYER),
	"gigantomachia": CharacterConcept.create("Gigantomachia", "gigantomachia", load("res://assets/images/Gigantomachia/gigantomachiaprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"gildarts": CharacterConcept.create("Gildarts Clive", "gildarts", load("res://assets/images/Gildarts Clive/gildartsprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"gotoh": CharacterConcept.create("Gotoh", "gotoh", load("res://assets/images/Gotoh/gotohprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"gyokko": CharacterConcept.create("Gyokko", "gyokko", load("res://assets/images/Gyokko/gyokkoprof.png"), "t", CharacterConcept.Universe.DEMON_SLAYER),
	"gyutaro": CharacterConcept.create("Gyutaro", "gyutaro", load("res://assets/images/Gyutaro/gyutaroprof.png"), "t", CharacterConcept.Universe.DEMON_SLAYER),
	"hanami": CharacterConcept.create("Hanami", "hanami", load("res://assets/images/Hanami/hanamiprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"hantengu": CharacterConcept.create("Hantengu", "hantengu", load("res://assets/images/Hantengu/hantenguprof.png"), "t", CharacterConcept.Universe.DEMON_SLAYER),
	"homura": CharacterConcept.create("Homura Akemi", "homura", load("res://assets/images/Homura Akemi/homuraprof.png"), "t", CharacterConcept.Universe.MADOKA_MAGICA),
	"kyoko": CharacterConcept.create("Kyoko Sakura", "kyoko", load("res://assets/images/Kyoko Sakura/kyokoprof.png"), "t", CharacterConcept.Universe.MADOKA_MAGICA),
	"hummingbird": CharacterConcept.create("Hummingbird", "hummingbird", load("res://assets/images/Hummingbird/hummingbirdprof.png"), "t", CharacterConcept.Universe.DEADMAN_WONDERLAND),
	"jellal": CharacterConcept.create("Jellal Fernandez", "jellal", load("res://assets/images/Jellal Fernandez/jellalprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"juvia": CharacterConcept.create("Juvia Lockser", "juvia", load("res://assets/images/Juvia Lockser/juviaprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"kamo": CharacterConcept.create("Noritoshi Kamo", "kamo", load("res://assets/images/Noritoshi Kamo/kamoprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"kastro": CharacterConcept.create("Kastro", "kastro", load("res://assets/images/Kastro/kastroprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"kenny": CharacterConcept.create("Kenny Ackerman", "kenny", load("res://assets/images/Kenny Ackerman/kennyprof.png"), "t", CharacterConcept.Universe.ATTACK_ON_TITAN),
	"kento": CharacterConcept.create("Kento Nanami", "kento", load("res://assets/images/Kento Nanami/kentoprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"kingopm": CharacterConcept.create("King (One Punch Man)", "kingopm", load("res://assets/images/King (One Punch Man)/kingopmprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"kite": CharacterConcept.create("Kite", "kite", load("res://assets/images/Kite/kiteprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"knov": CharacterConcept.create("Knov", "knov", load("res://assets/images/Knov/knovprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"knuckle": CharacterConcept.create("Knuckle Bine", "knuckle", load("res://assets/images/Knuckle Bine/knuckleprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"kurogiri": CharacterConcept.create("Kurogiri", "kurogiri", load("res://assets/images/Kurogiri/kurogiriprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"mahito": CharacterConcept.create("Mahito", "mahito", load("res://assets/images/Mahito/mahitoprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"maizenin": CharacterConcept.create("Mai Zen'in", "maizenin", load("res://assets/images/Mai Zen'in/maizeninprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"maki": CharacterConcept.create("Maki Zen'in", "maki", load("res://assets/images/Maki Zen'in/makiprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"mechamaru": CharacterConcept.create("Kokichi Muta", "mechamaru", load("res://assets/images/Kokichi Muta/mechamaruprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"meimei": CharacterConcept.create("Mei Mei", "meimei", load("res://assets/images/Mei Mei/meimeiprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"menthuthuyoup": CharacterConcept.create("Menthuthuyoup", "menthuthuyoup", load("res://assets/images/Menthuthuyoup/menthuthuyoupprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"meredy": CharacterConcept.create("Meredy", "meredy", load("res://assets/images/Meredy/meredyprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"meruem": CharacterConcept.create("Meruem", "meruem", load("res://assets/images/Meruem/meruemprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"metalbat": CharacterConcept.create("Metal Bat", "metalbat", load("res://assets/images/Metal Bat/metalbatprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"minerva": CharacterConcept.create("Minerva Orland", "minerva", load("res://assets/images/Minerva Orland/minervaprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"mirajane": CharacterConcept.create("Mirajane Strauss", "mirajane", load("res://assets/images/Mirajane Strauss/mirajaneprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"mitsuri": CharacterConcept.create("Mitsuri Kanroji", "mitsuri", load("res://assets/images/Mitsuri Kanroji/mitsuriprof.png"), "t", CharacterConcept.Universe.DEMON_SLAYER),
	"miwa": CharacterConcept.create("Kasumi Miwa", "miwa", load("res://assets/images/Kasumi Miwa/miwaprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"mockingbird": CharacterConcept.create("Mockingbird", "mockingbird", load("res://assets/images/Mockingbird/mockingbirdprof.png"), "t", CharacterConcept.Universe.DEADMAN_WONDERLAND),
	"morel": CharacterConcept.create("Morel Mackernasey", "morel", load("res://assets/images/Morel Mackernasey/morelprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"muscular": CharacterConcept.create("Muscular", "muscular", load("res://assets/images/Muscular/muscularprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"naobito": CharacterConcept.create("Naobito Zenin", "naobito", load("res://assets/images/Naobito Zenin/naobitoprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"netero": CharacterConcept.create("Isaac Netero", "netero", load("res://assets/images/Isaac Netero/neteroprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"nishimiya": CharacterConcept.create("Momo Nishimiya", "nishimiya", load("res://assets/images/Momo Nishimiya/nishimiyaprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"nobunaga": CharacterConcept.create("Nobunaga Hazama", "nobunaga", load("res://assets/images/Nobunaga Hazama/nobunagaprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"orochi": CharacterConcept.create("Orochi", "orochi", load("res://assets/images/Orochi/orochiprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"panda": CharacterConcept.create("Panda", "panda", load("res://assets/images/Panda/pandaprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"phinks": CharacterConcept.create("Phinks Magcub", "phinks", load("res://assets/images/Phinks Magcub/phinksprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"pieck": CharacterConcept.create("Pieck Finger", "pieck", load("res://assets/images/Pieck Finger/pieckprof.png"), "t", CharacterConcept.Universe.ATTACK_ON_TITAN),
	"porco": CharacterConcept.create("Porco Galliard", "porco", load("res://assets/images/Porco Galliard/porcoprof.png"), "t", CharacterConcept.Universe.ATTACK_ON_TITAN),
	"razor": CharacterConcept.create("Razor", "razor", load("res://assets/images/Razor/razorprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"redestro": CharacterConcept.create("Re-Destro", "redestro", load("res://assets/images/Re-Destro/redestroprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"reiner": CharacterConcept.create("Reiner Braun", "reiner", load("res://assets/images/Reiner Braun/reinerprof.png"), "t", CharacterConcept.Universe.ATTACK_ON_TITAN),
	"rogue": CharacterConcept.create("Rogue Cheney", "rogue", load("res://assets/images/Rogue Cheney/rogueprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"rui": CharacterConcept.create("Rui", "rui", load("res://assets/images/Rui/ruiprof.png"), "t", CharacterConcept.Universe.DEMON_SLAYER),
	"shaiapouf": CharacterConcept.create("Shaiapouf", "shaiapouf", load("res://assets/images/Shaiapouf/shaiapoufprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"shalnark": CharacterConcept.create("Shalnark Ryusei", "shalnark", load("res://assets/images/Shalnark Ryusei/shalnarkprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"shizuku": CharacterConcept.create("Shizuku Murasaki", "shizuku", load("res://assets/images/Shizuku Murasaki/shizukuprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"shoot": CharacterConcept.create("Shoot McMahon", "shoot", load("res://assets/images/Shoot McMahon/shootprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"spinner": CharacterConcept.create("Spinner", "spinner", load("res://assets/images/Spinner/spinnerprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"sting": CharacterConcept.create("Sting Eucliffe", "sting", load("res://assets/images/Sting Eucliffe/stingprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"suguru": CharacterConcept.create("Suguru Geto", "suguru", load("res://assets/images/Suguru Geto/suguruprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"twice": CharacterConcept.create("Twice", "twice", load("res://assets/images/Twice/twiceprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"ultear": CharacterConcept.create("Ultear Milkovich", "ultear", load("res://assets/images/Ultear Milkovich/ultearprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"uvogin": CharacterConcept.create("Uvogin", "uvogin", load("res://assets/images/Uvogin/uvoginprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"yuta": CharacterConcept.create("Yuta Okkotsu", "yuta", load("res://assets/images/Yuta Okkotsu/yutaprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"zazan": CharacterConcept.create("Zazan", "zazan", load("res://assets/images/Zazan/zazanprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"zeke": CharacterConcept.create("Zeke Yaeger", "zeke", load("res://assets/images/Zeke Yaeger/zekeprof.png"), "t", CharacterConcept.Universe.ATTACK_ON_TITAN),
	"zeref": CharacterConcept.create("Zeref Dragneel", "zeref", load("res://assets/images/Zeref Dragneel/zerefprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"zombieman": CharacterConcept.create("Zombieman", "zombieman", load("res://assets/images/Zombieman/zombiemanprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"achilles": CharacterConcept.create("Achilles", "achilles", load("res://assets/images/Achilles/achillesprof.png"), "t", CharacterConcept.Universe.FATE),
	"acnologia": CharacterConcept.create("Acnologia", "acnologia", load("res://assets/images/Acnologia/acnologiaprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"akitaru": CharacterConcept.create("Akitaru Obi", "akitaru", load("res://assets/images/Akitaru Obi/akitaruprof.png"), "t", CharacterConcept.Universe.FIRE_FORCE),
	"angel": CharacterConcept.create("Angel", "angel", load("res://assets/images/Angel/angelprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"arthursds": CharacterConcept.create("Arthur Pendragon", "arthursds", load("res://assets/images/Arthur Pendragon/arthursdsprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"atalanta": CharacterConcept.create("Atalanta", "atalanta", load("res://assets/images/Atalanta/atalantaprof.png"), "t", CharacterConcept.Universe.FATE),
	"ayato": CharacterConcept.create("Ayato Kirishima", "ayato", load("res://assets/images/Ayato Kirishima/ayatoprof.png"), "t", CharacterConcept.Universe.TOKYO_GHOUL),
	"azuma": CharacterConcept.create("Azuma", "azuma", load("res://assets/images/Azuma/azumaprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"bacchus": CharacterConcept.create("Bacchus Groh", "bacchus", load("res://assets/images/Bacchus Groh/bacchusprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"basil": CharacterConcept.create("Basil", "basil", load("res://assets/images/Basil/basilprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"belphegor": CharacterConcept.create("Belphegor", "belphegor", load("res://assets/images/Belphegor/belphegorprof.png"), "Belphegor, also known as Bel, is an assassin working for the Varia, the independent assassination squad of the Vongola Famiglia.", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"benimaruff": CharacterConcept.create("Benimaru Shinmon", "benimaruff", load("res://assets/images/Benimaru Shinmon/benimaruffprof.png"), "t", CharacterConcept.Universe.FIRE_FORCE),
	"bluebeard": CharacterConcept.create("Bluebeard", "bluebeard", load("res://assets/images/Bluebeard/bluebeardprof.png"), "t", CharacterConcept.Universe.FATE),
	"bluebell": CharacterConcept.create("Bluebell", "bluebell", load("res://assets/images/Bluebell/bluebellprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"bors": CharacterConcept.create("Bors", "bors", load("res://assets/images/Bors/borsprof.png"), "t", CharacterConcept.Universe.AKAME_GA_KILL),
	"byakuran": CharacterConcept.create("Byakuran", "byakuran", load("res://assets/images/Byakuran/byakuranprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"caprico": CharacterConcept.create("Caprico", "caprico", load("res://assets/images/Caprico/capricoprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"carrion": CharacterConcept.create("Carrion", "carrion", load("res://assets/images/Carrion/carrionprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	"chandler": CharacterConcept.create("Chandler", "chandler", load("res://assets/images/Chandler/chandlerprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"charlotte": CharacterConcept.create("Charlotte Roselei", "charlotte", load("res://assets/images/Charlotte Roselei/charlotteprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"charmy": CharacterConcept.create("Charmy Pappitson", "charmy", load("res://assets/images/Charmy Pappitson/charmyprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"charon": CharacterConcept.create("Charon", "charon", load("res://assets/images/Charon/charonprof.png"), "t", CharacterConcept.Universe.FIRE_FORCE),
	"clayman": CharacterConcept.create("Clayman", "clayman", load("res://assets/images/Clayman/claymanprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	"cobra": CharacterConcept.create("Cobra", "cobra", load("res://assets/images/Cobra/cobraprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"crimson": CharacterConcept.create("Guy Crimson", "crimson", load("res://assets/images/Guy Crimson/crimsonprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	"cusack": CharacterConcept.create("Cusack", "cusack", load("res://assets/images/Cusack/cusackprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"daidara": CharacterConcept.create("Daidara", "daidara", load("res://assets/images/Daidara/daidaraprof.png"), "t", CharacterConcept.Universe.AKAME_GA_KILL),
	"daisy": CharacterConcept.create("Daisy", "daisy", load("res://assets/images/Daisy/daisyprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"dante": CharacterConcept.create("Dante Zogratis", "dante", load("res://assets/images/Dante Zogratis/danteprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"demonking": CharacterConcept.create("Demon King", "demonking", load("res://assets/images/Demon King/demonkingprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"derieri": CharacterConcept.create("Derieri", "derieri", load("res://assets/images/Derieri/derieriprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"diarmuid": CharacterConcept.create("Diarmuid Ua Duibhne", "diarmuid", load("res://assets/images/Diarmuid Ua Duibhne/diarmuidprof.png"), "t", CharacterConcept.Universe.FATE),
	"dino": CharacterConcept.create("Dino Cavallone", "dino", load("res://assets/images/Dino Cavallone/dinoprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"doppelganger": CharacterConcept.create("Doppelganger", "doppelganger", load("res://assets/images/Doppelganger/doppelgangerprof.png"), "t", CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN),
	"doranbolt": CharacterConcept.create("Doranbolt", "doranbolt", load("res://assets/images/Doranbolt/doranboltprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"dorothy": CharacterConcept.create("Dorothy Unsworth", "dorothy", load("res://assets/images/Dorothy Unsworth/dorothyprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"drole": CharacterConcept.create("Drole", "drole", load("res://assets/images/Drole/droleprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"elaine": CharacterConcept.create("Elaine", "elaine", load("res://assets/images/Elaine/elaineprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"elizabeth": CharacterConcept.create("Elizabeth Liones", "elizabeth", load("res://assets/images/Elizabeth Liones/elizabethprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"estarossa": CharacterConcept.create("Estarossa", "estarossa", load("res://assets/images/Estarossa/estarossaprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"fraudrin": CharacterConcept.create("Fraudrin", "fraudrin", load("res://assets/images/Fraudrin/fraudrinprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"fuegoleon": CharacterConcept.create("Fuegoleon", "fuegoleon", load("res://assets/images/Fuegoleon/fuegoleonprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"gabiru": CharacterConcept.create("Gabiru", "gabiru", load("res://assets/images/Gabiru/gabiruprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	"galand": CharacterConcept.create("Galand", "galand", load("res://assets/images/Galand/galandprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"gamma": CharacterConcept.create("Lightning Gamma", "gamma", load("res://assets/images/Lightning Gamma/gammaprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"genkishi": CharacterConcept.create("Genkishi", "genkishi", load("res://assets/images/Genkishi/genkishiprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"ghost": CharacterConcept.create("Ghost", "ghost", load("res://assets/images/Ghost/ghostprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"gilthunder": CharacterConcept.create("Gilthunder", "gilthunder", load("res://assets/images/Gilthunder/gilthunderprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"gloxinia": CharacterConcept.create("Gloxinia", "gloxinia", load("res://assets/images/Gloxinia/gloxiniaprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"gowther": CharacterConcept.create("Gowther", "gowther", load("res://assets/images/Gowther/gowtherprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"grayroad": CharacterConcept.create("Grayroad", "grayroad", load("res://assets/images/Grayroad/grayroadprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"griamore": CharacterConcept.create("Griamore", "griamore", load("res://assets/images/Griamore/griamoreprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"guila": CharacterConcept.create("Guila", "guila", load("res://assets/images/Guila/guilaprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"hades": CharacterConcept.create("Precht Gaebolg", "hades", load("res://assets/images/Precht Gaebolg/hadesprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"hassan": CharacterConcept.create("Hassan of the Hundred Faces", "hassan", load("res://assets/images/Hassan of the Hundred Faces/hassanprof.png"), "t", CharacterConcept.Universe.FATE),
	"helbram": CharacterConcept.create("Helbram", "helbram", load("res://assets/images/Helbram/helbramprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"hendrickson": CharacterConcept.create("Hendrickson", "hendrickson", load("res://assets/images/Hendrickson/hendricksonprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"hercules": CharacterConcept.create("Hercules", "hercules", load("res://assets/images/Hercules/herculesprof.png"), "t", CharacterConcept.Universe.FATE),
	"howzer": CharacterConcept.create("Howzer", "howzer", load("res://assets/images/Howzer/howzerprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"iris": CharacterConcept.create("Iris", "iris", load("res://assets/images/Iris/irisprof.png"), "t", CharacterConcept.Universe.FIRE_FORCE),
	"ishtar": CharacterConcept.create("Ishtar", "ishtar", load("res://assets/images/Ishtar/ishtarprof.png"), "t", CharacterConcept.Universe.FATE),
	"iskander": CharacterConcept.create("Iskander", "iskander", load("res://assets/images/Iskander/iskanderprof.png"), "t", CharacterConcept.Universe.FATE),
	"jacktheripper": CharacterConcept.create("Jack the Ripper (Black Clover)", "jacktheripper", load("res://assets/images/Jack the Ripper (Black Clover)/jacktheripperprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"jericho": CharacterConcept.create("Jericho", "jericho", load("res://assets/images/Jericho/jerichoprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"joker": CharacterConcept.create("Joker", "joker", load("res://assets/images/Joker/jokerprof.png"), "t", CharacterConcept.Universe.FIRE_FORCE),
	"julius": CharacterConcept.create("Julius Nova Chrono", "julius", load("res://assets/images/Julius Nova Chrono/juliusprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"jura": CharacterConcept.create("Jura Neekis", "jura", load("res://assets/images/Jura Neekis/juraprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"kagura": CharacterConcept.create("Kagura Mikazuchi", "kagura", load("res://assets/images/Kagura Mikazuchi/kaguraprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"karna": CharacterConcept.create("Karna", "karna", load("res://assets/images/Karna/karnaprof.png"), "t", CharacterConcept.Universe.FATE),
	"kikyo": CharacterConcept.create("Kikyo", "kikyo", load("res://assets/images/Kikyo/kikyoprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"kongou": CharacterConcept.create("Kongou Mitsuko", "kongou", load("res://assets/images/Kongou Mitsuko/kongouprof.png"), "t", CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN),
	"kyoka": CharacterConcept.create("Kyoka", "kyoka", load("res://assets/images/Kyoka/kyokaprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"lalmirch": CharacterConcept.create("Lal Mirch", "lalmirch", load("res://assets/images/Lal Mirch/lalmirchprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"leonardo": CharacterConcept.create("Leonardo Burns", "leonardo", load("res://assets/images/Leonardo Burns/leonardoprof.png"), "t", CharacterConcept.Universe.FIRE_FORCE),
	"leonidas": CharacterConcept.create("Leonidas", "leonidas", load("res://assets/images/Leonidas/leonidasprof.png"), "t", CharacterConcept.Universe.FATE),
	"leviathan": CharacterConcept.create("Levi A Than", "leviathan", load("res://assets/images/Levi A Than/leviathanprof.png"), "Levi A Than, also known as Levi, is an assassin working for the Varia, the independent assassination squad of the Vongola Famiglia. He was chosen as the tenth generation Lightning Guardian candidate along with Lambo.", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"licht": CharacterConcept.create("Licht", "licht", load("res://assets/images/Licht/lichtprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"luck": CharacterConcept.create("Luck Voltia", "luck", load("res://assets/images/Luck Voltia/luckprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"ludociel": CharacterConcept.create("Ludociel", "ludociel", load("res://assets/images/Ludociel/ludocielprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"lussuria": CharacterConcept.create("Lussuria", "lussuria", load("res://assets/images/Lussuria/lussuriaprof.png"), "Lussuria, is an assassin working for the Varia, the independent assassination squad of the Vongola Famiglia.", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"lyon": CharacterConcept.create("Lyon Vastia", "lyon", load("res://assets/images/Lyon Vastia/lyonprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"magna": CharacterConcept.create("Magna Swing", "magna", load("res://assets/images/Magna Swing/magnaprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"makiff": CharacterConcept.create("Maki Oze", "makiff", load("res://assets/images/Maki Oze/makiffprof.png"), "t", CharacterConcept.Universe.FIRE_FORCE),
	"mammon": CharacterConcept.create("Mammon", "mammon", load("res://assets/images/Mammon/mammonprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"mardgeer": CharacterConcept.create("Mard Geer", "mardgeer", load("res://assets/images/Mard Geer/mardgeerprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"medusafate": CharacterConcept.create("Medusa (Rider)", "medusafate", load("res://assets/images/Medusa (Rider)/medusafateprof.png"), "t", CharacterConcept.Universe.FATE),
	"mereoleona": CharacterConcept.create("Mereoleona Vermillion", "mereoleona", load("res://assets/images/Mereoleona Vermillion/mereoleonaprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"merlin": CharacterConcept.create("Merlin", "merlin", load("res://assets/images/Merlin/merlinprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"midnightft": CharacterConcept.create("Midnight (Fairy Tail)", "midnightft", load("res://assets/images/Midnight (Fairy Tail)/midnightftprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"mitori": CharacterConcept.create("Kouzaku Mitori", "mitori", load("res://assets/images/Kouzaku Mitori/mitoriprof.png"), "t", CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN),
	"monspeet": CharacterConcept.create("Monspeet", "monspeet", load("res://assets/images/Monspeet/monspeetprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"mordred": CharacterConcept.create("Mordred", "mordred", load("res://assets/images/Mordred/mordredprof.png"), "t", CharacterConcept.Universe.FATE),
	"nishio": CharacterConcept.create("Nishio Nishiki", "nishio", load("res://assets/images/Nishio Nishiki/nishioprof.png"), "t", CharacterConcept.Universe.TOKYO_GHOUL),
	"nozel": CharacterConcept.create("Nozel Silva", "nozel", load("res://assets/images/Nozel Silva/nozelprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"nyau": CharacterConcept.create("Nyau", "nyau", load("res://assets/images/Nyau/nyauprof.png"), "t", CharacterConcept.Universe.AKAME_GA_KILL),
	"oomori": CharacterConcept.create("Yakumo Oomori", "oomori", load("res://assets/images/Yakumo Oomori/oomoriprof.png"), "t", CharacterConcept.Universe.TOKYO_GHOUL),
	"orga": CharacterConcept.create("Orga Nanagear", "orga", load("res://assets/images/Orga Nanagear/orgaprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"quetzalcoatl": CharacterConcept.create("Quetzalcoatl", "quetzalcoatl", load("res://assets/images/Quetzalcoatl/quetzalcoatlprof.png"), "t", CharacterConcept.Universe.FATE),
	"racer": CharacterConcept.create("Racer", "racer", load("res://assets/images/Racer/racerprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"rasiel": CharacterConcept.create("Rasiel", "rasiel", load("res://assets/images/Rasiel/rasielprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"sariel": CharacterConcept.create("Sariel", "sariel", load("res://assets/images/Sariel/sarielprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"seilah": CharacterConcept.create("Seilah", "seilah", load("res://assets/images/Seilah/seilahprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"serena": CharacterConcept.create("God Serena", "serena", load("res://assets/images/God Serena/serenaprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"sherria": CharacterConcept.create("Sherria Blendy", "sherria", load("res://assets/images/Sherria Blendy/sherriaprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"shizuri": CharacterConcept.create("Mugino Shizuri", "shizuri", load("res://assets/images/Mugino Shizuri/shizuriprof.png"), "t", CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN),
	"shou": CharacterConcept.create("Shou Kusakabe", "shou", load("res://assets/images/Shou Kusakabe/shouprof.png"), "t", CharacterConcept.Universe.FIRE_FORCE),
	"shuu": CharacterConcept.create("Shuu Tsukiyama", "shuu", load("res://assets/images/Shuu Tsukiyama/shuuprof.png"), "t", CharacterConcept.Universe.TOKYO_GHOUL),
	"sieg": CharacterConcept.create("Sieg", "sieg", load("res://assets/images/Sieg/siegprof.png"), "t", CharacterConcept.Universe.FATE),
	"silver": CharacterConcept.create("Silver Fullbuster", "silver", load("res://assets/images/Silver Fullbuster/silverprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"susanoo": CharacterConcept.create("Susano'o", "susanoo", load("res://assets/images/Susano'o/susanooprof.png"), "t", CharacterConcept.Universe.AKAME_GA_KILL),
	"takehisa": CharacterConcept.create("Takehisa Hinawa", "takehisa", load("res://assets/images/Takehisa Hinawa/takehisaprof.png"), "t", CharacterConcept.Universe.FIRE_FORCE),
	"tarmiel": CharacterConcept.create("Tarmiel", "tarmiel", load("res://assets/images/Tarmiel/tarmielprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"touma": CharacterConcept.create("Kamijou Touma", "touma", load("res://assets/images/Kamijou Touma/toumaprof.png"), "t", CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN),
	"uni": CharacterConcept.create("Uni", "uni", load("res://assets/images/Uni/uniprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"ushiwakamaru": CharacterConcept.create("Ushiwakamaru", "ushiwakamaru", load("res://assets/images/Ushiwakamaru/ushiwakamaruprof.png"), "t", CharacterConcept.Universe.FATE),
	"vlad": CharacterConcept.create("Vlad the Impaler", "vlad", load("res://assets/images/Vlad the Impaler/vladprof.png"), "t", CharacterConcept.Universe.FATE),
	"william": CharacterConcept.create("William Vangeance", "william", load("res://assets/images/William Vangeance/williamprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"yami": CharacterConcept.create("Yami Sukehiro", "yami", load("res://assets/images/Yami Sukehiro/yamiprof.png"), "t", CharacterConcept.Universe.BLACK_CLOVER),
	"yukino": CharacterConcept.create("Yukino Eucliffe", "yukino", load("res://assets/images/Yukino Eucliffe/yukinoprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"yukinori": CharacterConcept.create("Yukinori Shinohara", "yukinori", load("res://assets/images/Yukinori Shinohara/yukinoriprof.png"), "t", CharacterConcept.Universe.TOKYO_GHOUL),
	"zakuro": CharacterConcept.create("Zakuro", "zakuro", load("res://assets/images/Zakuro/zakuroprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"zancrow": CharacterConcept.create("Zancrow", "zancrow", load("res://assets/images/Zancrow/zancrowprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"zaratras": CharacterConcept.create("Zaratras", "zaratras", load("res://assets/images/Zaratras/zaratrasprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"zeldris": CharacterConcept.create("Zeldris", "zeldris", load("res://assets/images/Zeldris/zeldrisprof.png"), "t", CharacterConcept.Universe.SEVEN_DEADLY_SINS),
	"agumon": CharacterConcept.create("Agumon", "agumon", load("res://assets/images/Agumon/agumonprof.png"), "Tai Kamiya’s digimon", CharacterConcept.Universe.DIGIMON),
	"gabumon": CharacterConcept.create("Gabumon", "gabumon", load("res://assets/images/Gabumon/gabumonprof.png"), "Matt Ishida’s digimon", CharacterConcept.Universe.DIGIMON),
	"biyomon": CharacterConcept.create("Biyomon", "biyomon", load("res://assets/images/Biyomon/biyomonprof.png"), "Sora Takenouchi’s digimon", CharacterConcept.Universe.DIGIMON),
	"tentomon": CharacterConcept.create("Tentomon", "tentomon", load("res://assets/images/Tentomon/tentomonprof.png"), "Izzy Izumi’s digimon", CharacterConcept.Universe.DIGIMON),
	"palmon": CharacterConcept.create("Palmon", "palmon", load("res://assets/images/Palmon/palmonprof.png"), "Mimi Tachikawa’s digimon", CharacterConcept.Universe.DIGIMON),
	"gomamon": CharacterConcept.create("Gomamon", "gomamon", load("res://assets/images/Gomamon/gomamonprof.png"), "Joe Kido’s digimon", CharacterConcept.Universe.DIGIMON),
	"patamon": CharacterConcept.create("Patamon", "patamon", load("res://assets/images/Patamon/patamonprof.png"), "T.K. Takaishi’s digimon", CharacterConcept.Universe.DIGIMON),
	"devimon": CharacterConcept.create("Devimon", "devimon", load("res://assets/images/Devimon/devimonprof.png"), "Digimon Adventure villain", CharacterConcept.Universe.DIGIMON),
	"etemon": CharacterConcept.create("Etemon", "etemon", load("res://assets/images/Etemon/etemonprof.png"), "Digimon Adventure villain", CharacterConcept.Universe.DIGIMON),
	"apocalymon": CharacterConcept.create("Apocalymon", "apocalymon", load("res://assets/images/Apocalymon/apocalymonprof.png"), "Digimon Adventure villain", CharacterConcept.Universe.DIGIMON),
	"metalseadramon": CharacterConcept.create("MetalSeadramon", "metalseadramon", load("res://assets/images/MetalSeadramon/metalseadramonprof.png"), "Digimon Adventure Dark Master", CharacterConcept.Universe.DIGIMON),
	"puppetmon": CharacterConcept.create("Puppetmon", "puppetmon", load("res://assets/images/Puppetmon/puppetmonprof.png"), "Digimon Adventure Dark Master", CharacterConcept.Universe.DIGIMON),
	"piedmon": CharacterConcept.create("Piedmon", "piedmon", load("res://assets/images/Piedmon/piedmonprof.png"), "Digimon Adventure Dark Master", CharacterConcept.Universe.DIGIMON),
	"sailormoon": CharacterConcept.create("Sailor Moon", "sailormoon", load("res://assets/images/Sailor Moon/sailormoonprof.png"), "Sailor Moon", CharacterConcept.Universe.SAILOR_MOON),
	"sailorneptune": CharacterConcept.create("Sailor Neptune", "sailorneptune", load("res://assets/images/Sailor Neptune/sailorneptuneprof.png"), "Minako Aino aka Sailor Venus", CharacterConcept.Universe.SAILOR_MOON),
	"sailorpluto": CharacterConcept.create("Sailor Pluto", "sailorpluto", load("res://assets/images/Sailor Pluto/sailorplutoprof.png"), "Sailor Pluto", CharacterConcept.Universe.SAILOR_MOON),
	"tuxedomask": CharacterConcept.create("Tuxedo Mask", "tuxedomask", load("res://assets/images/Tuxedo Mask/tuxedomaskprof.png"), "Tuxedo Mask", CharacterConcept.Universe.SAILOR_MOON),
	"atomic": CharacterConcept.create("Atomic Samurai", "atomic", load("res://assets/images/Atomic Samurai/atomicprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"crocodile": CharacterConcept.create("Crocodile", "crocodile", load("res://assets/images/Crocodile/crocodileprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"deepseaking": CharacterConcept.create("Deep Sea King", "deepseaking", load("res://assets/images/Deep Sea King/deepseakingprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"evilnaturalwater": CharacterConcept.create("Evil Natural Water", "evilnaturalwater", load("res://assets/images/Evil Natural Water/evilnaturalwaterprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"garou": CharacterConcept.create("Garou", "garou", load("res://assets/images/Garou/garouprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	#"homelessemperor": CharacterConcept.create("Homeless Emperor", "homelessemperor", load("res://assets/images/Homeless Emperor/homelessemperorprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"jogo": CharacterConcept.create("Jogo", "jogo", load("res://assets/images/Jogo/jogoprof.png"), "t", CharacterConcept.Universe.JUJUTSU_KAISEN),
	"juuzou": CharacterConcept.create("Juuzou Suzuya", "juuzou", load("res://assets/images/Juuzou Suzuya/juuzouprof.png"), "t", CharacterConcept.Universe.TOKYO_GHOUL),
	"kureo": CharacterConcept.create("Kureo Mado", "kureo", load("res://assets/images/Kureo Mado/kureoprof.png"), "t", CharacterConcept.Universe.TOKYO_GHOUL),
	"max": CharacterConcept.create("Lightning Max", "max", load("res://assets/images/Lightning Max/maxprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"puripuri": CharacterConcept.create("Puri Puri Prisoner", "puripuri", load("res://assets/images/Puri Puri Prisoner/puripuriprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"rize": CharacterConcept.create("Rize Kamishiro", "rize", load("res://assets/images/Rize Kamishiro/rizeprof.png"), "t", CharacterConcept.Universe.TOKYO_GHOUL),
	#"silverfang": CharacterConcept.create("Silver Fang", "silverfang", load("res://assets/images/Silver Fang/silverfangprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"urahara": CharacterConcept.create("Urahara Kisuke", "urahara", load("res://assets/images/Urahara Kisuke/uraharaprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"watchdog": CharacterConcept.create("Watchdog", "watchdog", load("res://assets/images/Watchdog/watchdogprof.png"), "t", CharacterConcept.Universe.ONE_PUNCH_MAN),
	"naruha": CharacterConcept.create("Sakuragi Naruha", "naruha", load("res://assets/images/Sakuragi Naruha/naruhaprof.png"), "t", CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN),
	"frenda": CharacterConcept.create("Frenda Seivelun", "frenda", load("res://assets/images/Frenda Seivelun/frendaprof.png"), "t", CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN),
	"accelerator": CharacterConcept.create("Accelerator", "accelerator", load("res://assets/images/Accelerator/acceleratorprof.png"), "t", CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN),
	"chu": CharacterConcept.create("Chu Chulainn", "chu", load("res://assets/images/Chu Chulainn/chuprof.png"), "t", CharacterConcept.Universe.FATE),
	"medea": CharacterConcept.create("Medea", "medea", load("res://assets/images/Medea/medeaprof.png"), "t", CharacterConcept.Universe.FATE),
	"shigaraki": CharacterConcept.create("Tomura Shigaraki", "shigaraki", load("res://assets/images/Tomura Shigaraki/shigarakiprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"mirio": CharacterConcept.create("Togata Mirio", "mirio", load("res://assets/images/Togata Mirio/mirioprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"rukia": CharacterConcept.create("Rukia Kuchiki", "rukia", load("res://assets/images/Rukia Kuchiki/rukiaprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"aizen": CharacterConcept.create("Aizen Sosuke", "aizen", load("res://assets/images/Aizen Sosuke/aizenprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"angstrom": CharacterConcept.create("Angstrom Levy", "angstrom", load("res://assets/images/Angstrom Levy/angstromprof.png"), "Angstrom Levy", CharacterConcept.Universe.INVINCIBLE),
	"thragg": CharacterConcept.create("Thragg", "thragg", load("res://assets/images/Thragg/thraggprof.png"), "Grand Regent Thragg", CharacterConcept.Universe.INVINCIBLE),
	"kidomniman": CharacterConcept.create("Kid Omni-Man", "kidomniman", load("res://assets/images/Kid Omni-Man/kidomnimanprof.png"), "Oliver Grayson", CharacterConcept.Universe.INVINCIBLE),
	"conquest": CharacterConcept.create("Conquest", "conquest", load("res://assets/images/Conquest/conquestprof.png"), "Conquest", CharacterConcept.Universe.INVINCIBLE),
	"darkwing2": CharacterConcept.create("Darkwing II", "darkwing2", load("res://assets/images/Darkwing II/darkwing2prof.png"), "Darkwing II", CharacterConcept.Universe.INVINCIBLE),
	"rex": CharacterConcept.create("Rex Splode", "rex", load("res://assets/images/Rex Splode/rexprof.png"), "Rex Splode", CharacterConcept.Universe.INVINCIBLE),
	"immortal": CharacterConcept.create("Immortal", "immortal", load("res://assets/images/Immortal/immortalprof.png"), "Immortal", CharacterConcept.Universe.INVINCIBLE),
	"robot": CharacterConcept.create("Robot", "robot", load("res://assets/images/Robot/robotprof.png"), "Robot", CharacterConcept.Universe.INVINCIBLE),
	"monstergirl": CharacterConcept.create("Monster Girl", "monstergirl", load("res://assets/images/Monster Girl/monstergirlprof.png"), "Monster Girl", CharacterConcept.Universe.INVINCIBLE),
	"duplikate": CharacterConcept.create("Dupli-Kate", "duplikate", load("res://assets/images/DupliKate/duplikateprof.png"), "Dupli-Kate", CharacterConcept.Universe.INVINCIBLE),
	"multipaul": CharacterConcept.create("Multi-Paul", "multipaul", load("res://assets/images/MultiPaul/multipaulprof.png"), "Multi-Paul", CharacterConcept.Universe.INVINCIBLE),
	"powerplex": CharacterConcept.create("Powerplex", "powerplex", load("res://assets/images/Powerplex/powerplexprof.png"), "Powerplex", CharacterConcept.Universe.INVINCIBLE),
	"battlebeast": CharacterConcept.create("Battle Beast", "battlebeast", load("res://assets/images/Battle Beast/battlebeastprof.png"), "Battle Beast", CharacterConcept.Universe.INVINCIBLE),
	"allen": CharacterConcept.create("Allen the Alien", "allen", load("res://assets/images/Allen/allenprof.png"), "Allen the Alien", CharacterConcept.Universe.INVINCIBLE),
	"cecil": CharacterConcept.create("Cecil Stedman", "cecil", load("res://assets/images/Cecil Stedman/cecilprof.png"), "t", CharacterConcept.Universe.INVINCIBLE),
	"killcannon": CharacterConcept.create("Killcannon", "killcannon", load("res://assets/images/Killcannon/killcannonprof.png"), "t", CharacterConcept.Universe.INVINCIBLE),
	"shapesmith": CharacterConcept.create("Shapesmith", "shapesmith", load("res://assets/images/Shapesmith/shapesmithprof.png"), "t", CharacterConcept.Universe.INVINCIBLE),
	"maulertwins": CharacterConcept.create("The Mauler Twins", "maulertwins", load("res://assets/images/Maulers/maulertwinsprof.png"), "t", CharacterConcept.Universe.INVINCIBLE),
	"wormmon": CharacterConcept.create("Wormmon", "wormmon", load("res://assets/images/Wormmon/wormmonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"veemon": CharacterConcept.create("Veemon", "veemon", load("res://assets/images/Veemon/veemonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"susanoomon": CharacterConcept.create("Susanoomon", "susanoomon", load("res://assets/images/Susanoomon/susanoomonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"monodramon": CharacterConcept.create("Monodramon", "monodramon", load("res://assets/images/Monodramon/monodramonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"meicoomon": CharacterConcept.create("Meicoomon", "meicoomon", load("res://assets/images/Meicoomon/meicoomonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"magnamon": CharacterConcept.create("Magnamon", "magnamon", load("res://assets/images/Magnamon/magnamonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"lobomon": CharacterConcept.create("Lobomon", "lobomon", load("res://assets/images/Lobomon/lobomonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"leomon": CharacterConcept.create("Leomon", "leomon", load("res://assets/images/Leomon/leomonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"kumamon": CharacterConcept.create("Kumamon", "kumamon", load("res://assets/images/Kumamon/kumamonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"kudamon": CharacterConcept.create("Kudamon", "kudamon", load("res://assets/images/Kudamon/kudamonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"kimeramon": CharacterConcept.create("Kimeramon", "kimeramon", load("res://assets/images/Kimeramon/kimeramonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"keramon": CharacterConcept.create("Keramon", "keramon", load("res://assets/images/Keramon/keramonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"kazemon": CharacterConcept.create("Kazemon", "kazemon", load("res://assets/images/Kazemon/kazemonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"gankoomon": CharacterConcept.create("Gankoomon", "gankoomon", load("res://assets/images/Gankoomon/gankoomonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"ebonwumon": CharacterConcept.create("Ebonwumon", "ebonwumon", load("res://assets/images/Ebonwumon/ebonwumonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"dynasmon": CharacterConcept.create("Dynasmon", "dynasmon", load("res://assets/images/Dynasmon/dynasmonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"duskmon": CharacterConcept.create("Duskmon", "duskmon", load("res://assets/images/Duskmon/duskmonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"duftmon": CharacterConcept.create("Duftmon", "duftmon", load("res://assets/images/Duftmon/duftmonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"crusadermon": CharacterConcept.create("Crusadermon", "crusadermon", load("res://assets/images/Crusadermon/crusadermonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"beetlemon": CharacterConcept.create("Beetlemon", "beetlemon", load("res://assets/images/Beetlemon/beetlemonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"baihumon": CharacterConcept.create("Baihumon", "baihumon", load("res://assets/images/Baihumon/baihumonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"armadillomon": CharacterConcept.create("Armadillomon", "armadillomon", load("res://assets/images/Armadillomon/armadillomonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"agunimon": CharacterConcept.create("Agunimon", "agunimon", load("res://assets/images/Agunimon/agunimonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"zarbon": CharacterConcept.create("Zarbon", "zarbon", load("res://assets/images/Zarbon/zarbonprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"yamcha": CharacterConcept.create("Yamcha", "yamcha", load("res://assets/images/Yamcha/yamchaprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"tien": CharacterConcept.create("Tien", "tien", load("res://assets/images/Tien/tienprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"tao": CharacterConcept.create("Tao", "tao", load("res://assets/images/Tao/taoprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"supremekai": CharacterConcept.create("Supreme Kai", "supremekai", load("res://assets/images/Supreme Kai/supremekaiprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"roshi": CharacterConcept.create("Roshi", "roshi", load("res://assets/images/Roshi/roshiprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"recoome": CharacterConcept.create("Recoome", "recoome", load("res://assets/images/Recoome/recoomeprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"raditz": CharacterConcept.create("Raditz", "raditz", load("res://assets/images/Raditz/raditzprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"pikkon": CharacterConcept.create("Pikkon", "pikkon", load("res://assets/images/Pikkon/pikkonprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"pan": CharacterConcept.create("Pan", "pan", load("res://assets/images/Pan/panprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"nappa": CharacterConcept.create("Nappa", "nappa", load("res://assets/images/Nappa/nappaprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"kingcold": CharacterConcept.create("King Cold", "kingcold", load("res://assets/images/King Cold/kingcoldprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"kidtrunks": CharacterConcept.create("Kid Trunks", "kidtrunks", load("res://assets/images/Kid Trunks/kidtrunksprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"kidgoku": CharacterConcept.create("Kid Goku", "kidgoku", load("res://assets/images/Kid Goku/kidgokuprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"jeice": CharacterConcept.create("Jeice", "jeice", load("res://assets/images/Jeice/jeiceprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"janemba": CharacterConcept.create("Janemba", "janemba", load("res://assets/images/Janemba/janembaprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"hirudegarn": CharacterConcept.create("Hirudegarn", "hirudegarn", load("res://assets/images/Hirudegarn/hirudegarnprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"hercule": CharacterConcept.create("Hercule", "hercule", load("res://assets/images/Hercule/herculeprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"guldo": CharacterConcept.create("Guldo", "guldo", load("res://assets/images/Guldo/guldoprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"goten": CharacterConcept.create("Goten", "goten", load("res://assets/images/Goten/gotenprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"gotenks": CharacterConcept.create("Gotenks", "gotenks", load("res://assets/images/Gotenks/gotenksprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"ginyu": CharacterConcept.create("Ginyu", "ginyu", load("res://assets/images/Ginyu/ginyuprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"gero": CharacterConcept.create("Gero", "gero", load("res://assets/images/Gero/geroprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"garlicjr": CharacterConcept.create("Garlic Jr", "garlicjr", load("res://assets/images/Garlic Jr/garlicjrprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"dodoria": CharacterConcept.create("Dodoria", "dodoria", load("res://assets/images/Dodoria/dodoriaprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"dabura": CharacterConcept.create("Dabura", "dabura", load("res://assets/images/Dabura/daburaprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"chiaotzu": CharacterConcept.create("Chiaotzu", "chiaotzu", load("res://assets/images/Chiaotzu/chiaotzuprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"burter": CharacterConcept.create("Burter", "burter", load("res://assets/images/Burter/burterprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"bojack": CharacterConcept.create("Bojack", "bojack", load("res://assets/images/Bojack/bojackprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"blue": CharacterConcept.create("Blue", "blue", load("res://assets/images/Blue/blueprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"bardock": CharacterConcept.create("Bardock", "bardock", load("res://assets/images/Bardock/bardockprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"babidi": CharacterConcept.create("Babidi", "babidi", load("res://assets/images/Babidi/babidiprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"android19": CharacterConcept.create("Android 19", "android19", load("res://assets/images/Android 19/android19prof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"android18": CharacterConcept.create("Android 18", "android18", load("res://assets/images/Android 18/android18prof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"android16": CharacterConcept.create("Android 16", "android16", load("res://assets/images/Android 16/android16prof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"android13": CharacterConcept.create("Android 13", "android13", load("res://assets/images/Android 13/android13prof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"android8": CharacterConcept.create("Android 8", "android8", load("res://assets/images/Android 8/android8prof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"zuko": CharacterConcept.create("Zuko", "zuko", load("res://assets/images/Zuko/zukoprof.png"), "t", CharacterConcept.Universe.AVATAR),
	"mako": CharacterConcept.create("Mako", "mako", load("res://assets/images/Mako/makoprof.png"), "t", CharacterConcept.Universe.AVATAR),
	"ozai": CharacterConcept.create("Ozai", "ozai", load("res://assets/images/Ozai/ozaiprof.png"), "t", CharacterConcept.Universe.AVATAR),
	"iroh": CharacterConcept.create("Iroh", "iroh", load("res://assets/images/Iroh/irohprof.png"), "t", CharacterConcept.Universe.AVATAR),
	"bolin": CharacterConcept.create("Bolin", "bolin", load("res://assets/images/Bolin/bolinprof.png"), "t", CharacterConcept.Universe.AVATAR),
	"azula": CharacterConcept.create("Azula", "azula", load("res://assets/images/Azula/azulaprof.png"), "t", CharacterConcept.Universe.AVATAR),
	"amon": CharacterConcept.create("Amon", "amon", load("res://assets/images/Amon/amonprof.png"), "t", CharacterConcept.Universe.AVATAR),
	"jeannefate": CharacterConcept.create("Jeanne D'arc", "jeannefate", load("res://assets/images/Jeanne D'arc/jeannefateprof.png"), "t", CharacterConcept.Universe.FATE),
	"wendy": CharacterConcept.create("Wendy Marvell", "wendy", load("res://assets/images/Wendy Marvell/wendyprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"kurome": CharacterConcept.create("Kurome", "kurome", load("res://assets/images/Kurome/kuromeprof.png"), "t", CharacterConcept.Universe.AKAME_GA_KILL),
	"seryu": CharacterConcept.create("Seryu Ubiquitas", "seryu", load("res://assets/images/Seryu Ubiquitas/seryuprof.png"), "t", CharacterConcept.Universe.AKAME_GA_KILL),
	"chelsea": CharacterConcept.create("Chelsea", "chelsea", load("res://assets/images/Chelsea/chelseaprof.png"), "t", CharacterConcept.Universe.AKAME_GA_KILL),
	"leone": CharacterConcept.create("Leone", "leone", load("res://assets/images/Leone/leoneprof.png"), "t", CharacterConcept.Universe.AKAME_GA_KILL),
	"raba": CharacterConcept.create("Raba", "raba", load("res://assets/images/Raba/rabaprof.png"), "t", CharacterConcept.Universe.AKAME_GA_KILL),
	"gokudera": CharacterConcept.create("Hayato Gokudera", "gokudera", load("res://assets/images/Hayato Gokudera/gokuderaprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	"lambo": CharacterConcept.create("Lambo", "lambo", load("res://assets/images/Lambo/lamboprof.png"), "t", CharacterConcept.Universe.KATEKYO_HITMAN_REBORN),
	#"shuna": CharacterConcept.create("Shuna", "shuna", load("res://assets/images/Shuna/shunaprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	#"shizu": CharacterConcept.create("Shizu Izawa", "shizu", load("res://assets/images/Shizu Izawa/shizuprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	#"shion": CharacterConcept.create("Shion", "shion", load("res://assets/images/Shion/shionprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	#"ranga": CharacterConcept.create("Ranga", "ranga", load("res://assets/images/Ranga/rangaprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	#"milim": CharacterConcept.create("Milim Nava", "milim", load("res://assets/images/Milim Nava/milimprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	#"luminas": CharacterConcept.create("Luminas Valentine", "luminas", load("res://assets/images/Luminas Valentine/luminasprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	#"houei": CharacterConcept.create("Houei", "houei", load("res://assets/images/Houei/houeiprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	#"hakurou": CharacterConcept.create("Hakurou", "hakurou", load("res://assets/images/Hakurou/hakurouprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	#"geld": CharacterConcept.create("Geld", "geld", load("res://assets/images/Geld/geldprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	#"diablo": CharacterConcept.create("Diablo", "diablo", load("res://assets/images/Diablo/diabloprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	#"benimaru": CharacterConcept.create("Benimaru", "benimaru", load("res://assets/images/Benimaru/benimaruprof.png"), "t", CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME),
	"thomas": CharacterConcept.create("Thomas Andre", "thomas", load("res://assets/images/Thomas Andre/thomasprof.png"), "t", CharacterConcept.Universe.SOLO_LEVELING),
	"stark": CharacterConcept.create("Stark", "stark", load("res://assets/images/Stark/starkprof.png"), "t", CharacterConcept.Universe.FRIEREN),
	"ryoh": CharacterConcept.create("Ryoh Grantz", "ryoh", load("res://assets/images/Ryoh Grantz/ryohprof.png"), "t", CharacterConcept.Universe.MASHLE),
	"rayne": CharacterConcept.create("Rayne Ames", "rayne", load("res://assets/images/Rayne Ames/rayneprof.png"), "t", CharacterConcept.Universe.MASHLE),
	"rakan": CharacterConcept.create("Rakan", "rakan", load("res://assets/images/Rakan/rakanprof.png"), "t", CharacterConcept.Universe.SOLO_LEVELING),
	"popstep": CharacterConcept.create("Pop Step", "popstep", load("res://assets/images/Pop Step/popstepprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"orter": CharacterConcept.create("Orter Madl", "orter", load("res://assets/images/Orter Madl/orterprof.png"), "t", CharacterConcept.Universe.MASHLE),
	"min": CharacterConcept.create("Min Byung-gyu", "min", load("res://assets/images/Min Byung-gyu/minprof.png"), "t", CharacterConcept.Universe.SOLO_LEVELING),
	"lemon": CharacterConcept.create("Lemon Irvine", "lemon", load("res://assets/images/Lemon Irvine/lemonprof.png"), "t", CharacterConcept.Universe.MASHLE),
	"lance": CharacterConcept.create("Lance Crown", "lance", load("res://assets/images/Lance Crown/lanceprof.png"), "t", CharacterConcept.Universe.MASHLE),
	"kuin": CharacterConcept.create("Kuin Hachisuka", "kuin", load("res://assets/images/Kuin Hachisuka/kuinprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	#"crawler": CharacterConcept.create("Crawler", "crawler", load("res://assets/images/Crawler/crawlerprof.png"), "t", CharacterConcept.Universe.MY_HERO_ACADEMIA),
	"kaldo": CharacterConcept.create("Kaldo Gehenna", "kaldo", load("res://assets/images/Kaldo Gehenna/kaldoprof.png"), "t", CharacterConcept.Universe.MASHLE),
	"irism": CharacterConcept.create("Iris Midgar", "irism", load("res://assets/images/Iris Midgar/irisprof.png"), "t", CharacterConcept.Universe.EMINENCE_IN_SHADOW),
	"innocent": CharacterConcept.create("Innocent Zero", "innocent", load("res://assets/images/Innocent Zero/innocentprof.png"), "t", CharacterConcept.Universe.MASHLE),
	"himmel": CharacterConcept.create("Himmel", "himmel", load("res://assets/images/Himmel/himmelprof.png"), "t", CharacterConcept.Universe.FRIEREN),
	"finn": CharacterConcept.create("Finn Ames", "finn", load("res://assets/images/Finn Ames/finnprof.png"), "t", CharacterConcept.Universe.MASHLE),
	"fern": CharacterConcept.create("Fern", "fern", load("res://assets/images/Fern/fernprof.png"), "t", CharacterConcept.Universe.FRIEREN),
	"dot": CharacterConcept.create("Dot Barret", "dot", load("res://assets/images/Dot Barret/dotprof.png"), "t", CharacterConcept.Universe.MASHLE),
	"delta": CharacterConcept.create("Delta", "delta", load("res://assets/images/Delta/deltaprof.png"), "t", CharacterConcept.Universe.EMINENCE_IN_SHADOW),
	"cid": CharacterConcept.create("Cid Kagenou", "cid", load("res://assets/images/Cid Kagenou/cidprof.png"), "t", CharacterConcept.Universe.EMINENCE_IN_SHADOW),
	"choi": CharacterConcept.create("Choi Jon-in", "choi", load("res://assets/images/Choi Jon-in/choiprof.png"), "t", CharacterConcept.Universe.SOLO_LEVELING),
	"cha": CharacterConcept.create("Cha Hae-in", "cha", load("res://assets/images/Cha Hae-in/chaprof.png"), "t", CharacterConcept.Universe.SOLO_LEVELING),
	"cellwar": CharacterConcept.create("Cell War", "cellwar", load("res://assets/images/Cell War/cellwarprof.png"), "t", CharacterConcept.Universe.MASHLE),
	"beatrix": CharacterConcept.create("Beatrix", "beatrix", load("res://assets/images/Beatrix/beatrixprof.png"), "t", CharacterConcept.Universe.EMINENCE_IN_SHADOW),
	"baek": CharacterConcept.create("Baek Yoon-ho", "baek", load("res://assets/images/Baek Yoon-ho/baekprof.png"), "t", CharacterConcept.Universe.SOLO_LEVELING),
	#"alpha": CharacterConcept.create("Alpha", "alpha", load("res://assets/images/Alpha/Alphaprof.png"), "t", CharacterConcept.Universe.EMINENCE_IN_SHADOW),
	"alexia": CharacterConcept.create("Alexia Midgar", "alexia", load("res://assets/images/Alexia Midgar/alexiaprof.png"), "t", CharacterConcept.Universe.EMINENCE_IN_SHADOW),
	"razorabyss": CharacterConcept.create("Abyss Razor", "razorabyss", load("res://assets/images/Abyss Razor/razorprof.png"), "t", CharacterConcept.Universe.MASHLE),
	"abel": CharacterConcept.create("Abel Walker", "abel", load("res://assets/images/Abel Walker/abelprof.png"), "A third-year student at Easton Magic Academy, Abel is the leader of Magia Lupus. His magic allows him control the people around him as puppets.", CharacterConcept.Universe.MASHLE),
	"chrollo": CharacterConcept.create("Chrollo Lucilfer", "chrollo", load("res://assets/images/Chrollo Lucilfer/chrolloprof.png"), "t", CharacterConcept.Universe.HUNTER_X_HUNTER),
	"makima": CharacterConcept.create("Makima", "makima", load("res://assets/images/Makima/makimaprof.png"), "t", CharacterConcept.Universe.CHAINSAW_MAN),
	"kobeni": CharacterConcept.create("Higashiyama Kobeni", "kobeni", load("res://assets/images/Higashiyama Kobeni/kobeniprof.png"), "t", CharacterConcept.Universe.CHAINSAW_MAN),
	"beam": CharacterConcept.create("Beam", "beam", load("res://assets/images/Beam/beamprof.png"), "t", CharacterConcept.Universe.CHAINSAW_MAN),
	"reze": CharacterConcept.create("Reze", "reze", load("res://assets/images/Reze/rezeprof.png"), "t", CharacterConcept.Universe.CHAINSAW_MAN),
	"aki": CharacterConcept.create("Hayakawa Aki", "aki", load("res://assets/images/Hayakawa Aki/akiprof.png"), "t", CharacterConcept.Universe.CHAINSAW_MAN),
	"angeldevil": CharacterConcept.create("Angel Devil", "angeldevil", load("res://assets/images/Angel Devil/angeldevilprof.png"), "t", CharacterConcept.Universe.CHAINSAW_MAN),
	"borushiki": CharacterConcept.create("Uzumaki Borushiki", "borushiki", load("res://assets/images/Uzumaki Borushiki/borushikiprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"takizawa": CharacterConcept.create("Takizawa Seido", "takizawa", load("res://assets/images/Takizawa Seido/takizawaprof.png"), "A former Rank 2 Ghoul Investigator, Takizawa inherited the Ukaku from Yoshimura and became a half-ghoul. His abilities cause a significant degradation to his mental state.", CharacterConcept.Universe.TOKYO_GHOUL),
	"furuta": CharacterConcept.create("Furuta Nimura", "furuta", load("res://assets/images/Furuta Nimura/furutaprof.png"), "Also known as Kichimura Washuu, Furuta is a half-ghoul who also served as a ghoul investigator and even the head of the Commission of Counter Ghoul. ", CharacterConcept.Universe.TOKYO_GHOUL),
	"eto": CharacterConcept.create("Eto Yoshimura", "eto", load("res://assets/images/Eto Yoshimura/etoprof.png"), "The founding leader of Aogiri Tree, Eto Yoshimura is a half-ghoul known as the One-Eyed Owl. Her control over her Ukaku far surpasses most other ghouls, sporting a versatile set of appendages and attacks. ", CharacterConcept.Universe.TOKYO_GHOUL),
	"ira": CharacterConcept.create("Gamagori Ira", "ira", load("res://assets/images/Gamagori Ira/iraprof.png"), "t", CharacterConcept.Universe.KILL_LA_KILL),
	"nui": CharacterConcept.create("Harime Nui", "nui", load("res://assets/images/Harime Nui/nuiprof.png"), "t", CharacterConcept.Universe.KILL_LA_KILL),
	"yukio": CharacterConcept.create("Yukio Okumura", "yukio", load("res://assets/images/Yukio Okumura/yukioprof.png"), "Despite being the son of Satan, and Rin's twin brother, Yukio Okumura was born fully human, inheriting none of his father's demonic traits or aptitudes.", CharacterConcept.Universe.AO_NO_EXORCIST),
	"rin": CharacterConcept.create("Rin Okumura", "rin", load("res://assets/images/Rin Okumura/rinprof.png"), "Rin Okumura is the main protagonist of Ao no Exorcist. The son of Satan and twin brother of Yukio Okumura, he trains at a special Academy in the hopes of defeating his father.", CharacterConcept.Universe.AO_NO_EXORCIST),
	"joey": CharacterConcept.create("Joey Wheeler", "joey", load("res://assets/images/Joey Wheeler/joeyprof.png"), "t", CharacterConcept.Universe.YUGIOH),
	"bakura": CharacterConcept.create("Bakura Ryou", "bakura", load("res://assets/images/Bakura Ryou/bakuraprof.png"), "t", CharacterConcept.Universe.YUGIOH),
	"marik": CharacterConcept.create("Marik Ishtar", "marik", load("res://assets/images/Marik Ishtar/marikprof.png"), "t", CharacterConcept.Universe.YUGIOH),
	"sesshomaru": CharacterConcept.create("Sesshomaru", "sesshomaru", load("res://assets/images/Sesshomaru/sesshomaruprof.png"), "t", CharacterConcept.Universe.INUYASHA),
	"kenpachi": CharacterConcept.create("Kenpachi Zaraki", "kenpachi", load("res://assets/images/Kenpachi Zaraki/kenpachiprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"rudo": CharacterConcept.create("Rudo Surebrec", "rudo", load("res://assets/images/Rudo Surebrec/rudoprof.png"), "t", CharacterConcept.Universe.GACHIAKUTA),
	"nnoitra": CharacterConcept.create("Nnoitra Gilga", "nnoitra", load("res://assets/images/Nnoitra Gilga/nnoitraprof.png"), "t", CharacterConcept.Universe.BLEACH),
	"guilmon": CharacterConcept.create("Guilmon", "guilmon", load("res://assets/images/Guilmon/guilmonprof.png"), "t", CharacterConcept.Universe.DIGIMON),
	"lubu": CharacterConcept.create("Lu Bu", "lubu", load("res://assets/images/Lu Bu/lubuprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"kojiro": CharacterConcept.create("Sasaki Kojiro", "kojiro", load("res://assets/images/Sasaki Kojiro/kojiroprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"jackror": CharacterConcept.create("Jack the Reaper", "jackror", load("res://assets/images/Jack the Ripper (ROR)/jackrorprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"raiden": CharacterConcept.create("Tameemon Raiden", "raiden", load("res://assets/images/Tameemon Raiden/raidenprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"buddha": CharacterConcept.create("Buddha", "buddha", load("res://assets/images/Buddha/buddhaprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"huang": CharacterConcept.create("Qin Shi Huang", "huang", load("res://assets/images/Qin Shi Huang/huangprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"tesla": CharacterConcept.create("Nikola Tesla", "tesla", load("res://assets/images/Nikola Tesla/teslaprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"leonidasror": CharacterConcept.create("Leonidas", "leonidasror", load("res://assets/images/Leonidas (ROR)/leonidasrorprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"hayha": CharacterConcept.create("Simo Hayha", "hayha", load("res://assets/images/Simo Hayha/hayhaprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"okita": CharacterConcept.create("Soji Okita", "okita", load("res://assets/images/Soji Okita/okitaprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"zeus": CharacterConcept.create("Zeus", "zeus", load("res://assets/images/Zeus/zeusprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"thor": CharacterConcept.create("Thor", "thor", load("res://assets/images/Thor/thorprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"poseidon": CharacterConcept.create("Poseidon", "poseidon", load("res://assets/images/Poseidon/poseidonprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"heracles": CharacterConcept.create("Heracles", "heracles", load("res://assets/images/Heracles/heraclesprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"shiva": CharacterConcept.create("Shiva", "shiva", load("res://assets/images/Shiva/shivaprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"zerofuku": CharacterConcept.create("Zerofuku", "zerofuku", load("res://assets/images/Zerofuku/zerofukuprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"hadesror": CharacterConcept.create("Hades", "hadesror", load("res://assets/images/Hades (ROR)/hadesrorprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"beelzebub": CharacterConcept.create("Beelzebub", "beelzebub", load("res://assets/images/Beelzebub/beelzebubprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"apollo": CharacterConcept.create("Apollo", "apollo", load("res://assets/images/Apollo/apolloprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"susanooror": CharacterConcept.create("Susanoo no Mikoto", "susanooror", load("res://assets/images/Susanoo no Mikoto/susanoororprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"loki": CharacterConcept.create("Loki", "loki", load("res://assets/images/Loki/lokiprof.png"), "t", CharacterConcept.Universe.RECORD_OF_RAGNAROK),
	"seiya": CharacterConcept.create("Seiya", "seiya", load("res://assets/images/Seiya/seiyaprof.png"), "t", CharacterConcept.Universe.SAINT_SEIYA),
	"ikki": CharacterConcept.create("Ikki", "ikki", load("res://assets/images/Ikki/ikkiprof.png"), "t", CharacterConcept.Universe.SAINT_SEIYA),
	"shiryuu": CharacterConcept.create("Shiryuu", "shiryuu", load("res://assets/images/Shiryuu/shiryuuprof.png"), "t", CharacterConcept.Universe.SAINT_SEIYA),
	"hyouga": CharacterConcept.create("Hyouga", "hyouga", load("res://assets/images/Hyouga/hyougaprof.png"), "t", CharacterConcept.Universe.SAINT_SEIYA),
	"shun": CharacterConcept.create("Shun", "shun", load("res://assets/images/Shun/shunprof.png"), "t", CharacterConcept.Universe.SAINT_SEIYA),
	"geminisaga": CharacterConcept.create("Gemini Saga", "geminisaga", load("res://assets/images/Gemini Saga/geminisagaprof.png"), "t", CharacterConcept.Universe.SAINT_SEIYA),
	"yusuke": CharacterConcept.create("Urameshi Yusuke", "yusuke", load("res://assets/images/Urameshi Yusuke/yusukeprof.png"), "t", CharacterConcept.Universe.YU_YU_HAKUSHO),
	"kuwabara": CharacterConcept.create("Kuwabara Kazuma", "kuwabara", load("res://assets/images/Kuwabara Kazuma/kuwabaraprof.png"), "t", CharacterConcept.Universe.YU_YU_HAKUSHO),
	"kurama": CharacterConcept.create("Kurama", "kurama", load("res://assets/images/Kurama/kuramaprof.png"), "t", CharacterConcept.Universe.YU_YU_HAKUSHO),
	"hiei": CharacterConcept.create("Hiei", "hiei", load("res://assets/images/Hiei/hieiprof.png"), "t", CharacterConcept.Universe.YU_YU_HAKUSHO),
	"genkai": CharacterConcept.create("Genkai", "genkai", load("res://assets/images/Genkai/genkaiprof.png"), "t", CharacterConcept.Universe.YU_YU_HAKUSHO),
	"shinobu": CharacterConcept.create("Sensui Shinobu", "shinobu", load("res://assets/images/Sensui Shinobu/shinobuprof.png"), "t", CharacterConcept.Universe.YU_YU_HAKUSHO),
	"toguro": CharacterConcept.create("Toguro", "toguro", load("res://assets/images/Toguro/toguroprof.png"), "t", CharacterConcept.Universe.YU_YU_HAKUSHO),
	"karasu": CharacterConcept.create("Karasu", "karasu", load("res://assets/images/Karasu/karasuprof.png"), "t", CharacterConcept.Universe.YU_YU_HAKUSHO),
	"yomi": CharacterConcept.create("Yomi", "yomi", load("res://assets/images/Yomi/yomiprof.png"), "t", CharacterConcept.Universe.YU_YU_HAKUSHO),
	"chuu": CharacterConcept.create("Chuu", "chuu", load("res://assets/images/Chuu/chuuprof.png"), "t", CharacterConcept.Universe.YU_YU_HAKUSHO),
	"duke": CharacterConcept.create("Duke Devlin", "duke", load("res://assets/images/Duke Devlin/dukeprof.png"), "t", CharacterConcept.Universe.YUGIOH),
	"mai": CharacterConcept.create("Mai Valentine", "mai", load("res://assets/images/Mai Valentine/maiprof.png"), "t", CharacterConcept.Universe.YUGIOH),
	"ishizu": CharacterConcept.create("Ishizu Ishtar", "ishizu", load("res://assets/images/Ishizu Ishtar/ishizuprof.png"), "t", CharacterConcept.Universe.YUGIOH),
	"keith": CharacterConcept.create("Bandit Keith", "keith", load("res://assets/images/Bandit Keith/keithprof.png"), "t", CharacterConcept.Universe.YUGIOH),
	"akiza": CharacterConcept.create("Akiza Izinski", "akiza", load("res://assets/images/Akiza Izinski/akizaprof.png"), "t", CharacterConcept.Universe.YUGIOH),
	"clare": CharacterConcept.create("Clare", "clare", load("res://assets/images/Clare/clareprof.png"), "t", CharacterConcept.Universe.CLAYMORE),
	"teresa": CharacterConcept.create("Teresa", "teresa", load("res://assets/images/Teresa/teresaprof.png"), "t", CharacterConcept.Universe.CLAYMORE),
	"piccolo": CharacterConcept.create("Piccolo", "piccolo", load("res://assets/images/Piccolo/piccoloprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"majinbuu": CharacterConcept.create("Majin Buu", "majinbuu", load("res://assets/images/Majin Buu/majinbuuprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"kidbuu": CharacterConcept.create("Kid Buu", "kidbuu", load("res://assets/images/Kid Buu/kidbuuprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"eisshenron": CharacterConcept.create("Eis Shenron", "eisshenron", load("res://assets/images/Eis Shenron/eisshenronprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"nuovashenron": CharacterConcept.create("Nuova Shenron", "nuovashenron", load("res://assets/images/Nuova Shenron/nuovashenronprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"synshenron": CharacterConcept.create("Syn Shenron", "synshenron", load("res://assets/images/Syn Shenron/synshenronprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"miroku": CharacterConcept.create("Miroku", "miroku", load("res://assets/images/Miroku/mirokuprof.png"), "t", CharacterConcept.Universe.INUYASHA),
	"kohaku": CharacterConcept.create("Kohaku", "kohaku", load("res://assets/images/Kohaku/kohakuprof.png"), "t", CharacterConcept.Universe.INUYASHA),
	"kagome": CharacterConcept.create("Kagome", "kagome", load("res://assets/images/Kagome/kagomeprof.png"), "t", CharacterConcept.Universe.INUYASHA),
	"shiki": CharacterConcept.create("Shiki Ichinose", "shiki", load("res://assets/images/Shiki Ichinose/shikiprof.png"), "t", CharacterConcept.Universe.TOUGEN_ANKI),
	"yukiteru": CharacterConcept.create("Yukiteru Amano", "yukiteru", load("res://assets/images/Yukiteru Amano/yukiteruprof.png"), "t", CharacterConcept.Universe.MIRAI_NIKKI),
	"takao": CharacterConcept.create("Takao Hiyama", "takao", load("res://assets/images/Takao Hiyama/takaoprof.png"), "t", CharacterConcept.Universe.MIRAI_NIKKI),
	"kasugano": CharacterConcept.create("Tsubaki Kasugano", "kasugano", load("res://assets/images/Tsubaki Kasugano/kasuganoprof.png"), "t", CharacterConcept.Universe.MIRAI_NIKKI),
	"reisuke": CharacterConcept.create("Reisuke Houjou", "reisuke", load("res://assets/images/Reisuke Houjou/reisukeprof.png"), "t", CharacterConcept.Universe.MIRAI_NIKKI),
	"keigo": CharacterConcept.create("Keigo Kurusu", "keigo", load("res://assets/images/Keigo Kurusu/keigoprof.png"), "t", CharacterConcept.Universe.MIRAI_NIKKI),
	"ikusuba": CharacterConcept.create("Marco Ikusuba", "ikusuba", load("res://assets/images/Marco Ikusuba/ikusubaprof.png"), "t", CharacterConcept.Universe.MIRAI_NIKKI),
	"ai": CharacterConcept.create("Ai Mikami", "ai", load("res://assets/images/Ai Mikami/aiprof.png"), "t", CharacterConcept.Universe.MIRAI_NIKKI),
	"rika": CharacterConcept.create("Rika Kawai", "rika", load("res://assets/images/Rika Kawai/rikaprof.png"), "A washed-up former child idol with a caustic tongue and a self-destructive streak, weighed down by guilt over a devoted fan who took her own life. One of the girls fighting through the Wonder Egg world.", CharacterConcept.Universe.WONDER_EGG_PRIORITY),
	"neiru": CharacterConcept.create("Neiru Aonuma", "neiru", load("res://assets/images/Neiru Aonuma/neiruprof.png"), "A brilliant, emotionally guarded teenage company president who approaches the Wonder Egg world with detached, analytical calm - all to bring back her late sister, Airu.", CharacterConcept.Universe.WONDER_EGG_PRIORITY),
	"kamado": CharacterConcept.create("Kamado Ueshita", "kamado", load("res://assets/images/Kamado Ueshita/kamadoprof.png"), "t", CharacterConcept.Universe.MIRAI_NIKKI),
	"karyuudo": CharacterConcept.create("Karyuudo Tsukishima", "karyuudo", load("res://assets/images/Karyuudo Tsukishima/karyuudoprof.png"), "t", CharacterConcept.Universe.MIRAI_NIKKI),
	"johnbacchus": CharacterConcept.create("John Bacchus", "johnbacchus", load("res://assets/images/John Bacchus/johnbacchusprof.png"), "t", CharacterConcept.Universe.MIRAI_NIKKI),
	"yomotsu": CharacterConcept.create("Yomotsu Hirasaka", "yomotsu", load("res://assets/images/Yomotsu Hirasaka/yomotsuprof.png"), "t", CharacterConcept.Universe.MIRAI_NIKKI),
	"emilia": CharacterConcept.create("Emilia", "emilia", load("res://assets/images/Emilia/emiliaprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"rem": CharacterConcept.create("Rem", "rem", load("res://assets/images/Rem/remprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"ram": CharacterConcept.create("Ram", "ram", load("res://assets/images/Ram/ramprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"beatrice": CharacterConcept.create("Beatrice", "beatrice", load("res://assets/images/Beatrice/beatriceprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"roswaal": CharacterConcept.create("Roswaal L Mathers", "roswaal", load("res://assets/images/Roswaal L Mathers/roswaalprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"garfiel": CharacterConcept.create("Garfiel Tinsel", "garfiel", load("res://assets/images/Garfiel Tinsel/garfielprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"frederica": CharacterConcept.create("Frederica Baumann", "frederica", load("res://assets/images/Frederica Baumann/fredericaprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"felt": CharacterConcept.create("Felt", "felt", load("res://assets/images/Felt/feltprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"reinhard": CharacterConcept.create("Reinhard van Astrea", "reinhard", load("res://assets/images/Reinhard van Astrea/reinhardprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"crusch": CharacterConcept.create("Crusch Karsten", "crusch", load("res://assets/images/Crusch Karsten/cruschprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"priscilla": CharacterConcept.create("Priscilla Barielle", "priscilla", load("res://assets/images/Priscilla Barielle/priscillaprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"al": CharacterConcept.create("Aldebaran", "al", load("res://assets/images/Aldebaran/alprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"euclius": CharacterConcept.create("Julius Euclius", "euclius", load("res://assets/images/Julius Euclius/eucliusprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"echidna": CharacterConcept.create("Echidna", "echidna", load("res://assets/images/Echidna/echidnaprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"satella": CharacterConcept.create("Satella", "satella", load("res://assets/images/Satella/satellaprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"petelgeuse": CharacterConcept.create("Petelgeuse Romanee-Conti", "petelgeuse", load("res://assets/images/Petelgeuse Romanee-Conti/petelgeuseprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"regulus": CharacterConcept.create("Regulus Corneas", "regulus", load("res://assets/images/Regulus Corneas/regulusprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"capella": CharacterConcept.create("Capella Emerada Lugunica", "capella", load("res://assets/images/Capella Emerada Lugunica/capellaprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"sirius": CharacterConcept.create("Sirius", "sirius", load("res://assets/images/Sirius/siriusprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"lye": CharacterConcept.create("Lye Batenkaitos", "lye", load("res://assets/images/Lye Batenkaitos/lyeprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"elsa": CharacterConcept.create("Elsa Granhiert", "elsa", load("res://assets/images/Elsa Granhiert/elsaprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"meili": CharacterConcept.create("Meili Portroute", "meili", load("res://assets/images/Meili Portroute/meiliprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	"pandora": CharacterConcept.create("Pandora", "pandora", load("res://assets/images/Pandora/pandoraprof.png"), "t", CharacterConcept.Universe.RE_ZERO),
	# --- Nexus update: Fairy Tail + One Piece / Dragon Ball / Naruto / Inuyasha concept buckets ---
	"laxus": CharacterConcept.create("Laxus Dreyar", "laxus", load("res://assets/images/Laxus Dreyar/laxusprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"mystogan": CharacterConcept.create("Mystogan", "mystogan", load("res://assets/images/Mystogan/mystoganprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"gajeel": CharacterConcept.create("Gajeel Redfox", "gajeel", load("res://assets/images/Gajeel Redfox/gajeelprof.png"), "t", CharacterConcept.Universe.FAIRY_TAIL),
	"kaidou": CharacterConcept.create("Kaidou", "kaidou", load("res://assets/images/Kaidou/kaidouprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"bigmom": CharacterConcept.create("Big Mom", "bigmom", load("res://assets/images/Big Mom/bigmomprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"katakuri": CharacterConcept.create("Charlotte Katakuri", "katakuri", load("res://assets/images/Charlotte Katakuri/katakuriprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"whitebeard": CharacterConcept.create("Whitebeard", "whitebeard", load("res://assets/images/Whitebeard/whitebeardprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"aokiji": CharacterConcept.create("Aokiji", "aokiji", load("res://assets/images/Aokiji/aokijiprof.png"), "t", CharacterConcept.Universe.ONE_PIECE),
	"beerus": CharacterConcept.create("Beerus", "beerus", load("res://assets/images/Beerus/beerusprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"jiren": CharacterConcept.create("Jiren", "jiren", load("res://assets/images/Jiren/jirenprof.png"), "t", CharacterConcept.Universe.DRAGON_BALL),
	"kaguya": CharacterConcept.create("Kaguya", "kaguya", load("res://assets/images/Kaguya/kaguyaprof.png"), "t", CharacterConcept.Universe.NARUTO),
	"kikyoinuyasha": CharacterConcept.create("Kikyo", "kikyoinuyasha", load("res://assets/images/Kikyo/kikyoinuyashaprof.png"), "t", CharacterConcept.Universe.INUYASHA),
	# --- Nexus update: Gachiakuta + Sailor Moon + Sword Art Online concept buckets ---
	"zodyl": CharacterConcept.create("Zodyl", "zodyl", load("res://assets/images/Zodyl/zodylprof.png"), "Zodyl", CharacterConcept.Universe.GACHIAKUTA),
	"amo": CharacterConcept.create("Amo", "amo", load("res://assets/images/Amo/amoprof.png"), "Amo", CharacterConcept.Universe.GACHIAKUTA),
	"enjin": CharacterConcept.create("Enjin", "enjin", load("res://assets/images/Enjin/enjinprof.png"), "Enjin", CharacterConcept.Universe.GACHIAKUTA),
	"riyo": CharacterConcept.create("Riyo", "riyo", load("res://assets/images/Riyo/riyoprof.png"), "Riyo", CharacterConcept.Universe.GACHIAKUTA),
	"tamsy": CharacterConcept.create("Tamsy", "tamsy", load("res://assets/images/Tamsy/tamsyprof.png"), "Tamsy", CharacterConcept.Universe.GACHIAKUTA),
	"semiu": CharacterConcept.create("Semiu", "semiu", load("res://assets/images/Semiu/semiuprof.png"), "Semiu", CharacterConcept.Universe.GACHIAKUTA),
	"zanka": CharacterConcept.create("Zanka", "zanka", load("res://assets/images/Zanka/zankaprof.png"), "Zanka", CharacterConcept.Universe.GACHIAKUTA),
	"jabber": CharacterConcept.create("Jabber", "jabber", load("res://assets/images/Jabber/jabberprof.png"), "Jabber", CharacterConcept.Universe.GACHIAKUTA),
	"chibimoon": CharacterConcept.create("Sailor Chibi Moon", "chibimoon", load("res://assets/images/Sailor Chibi Moon/chibimoonprof.png"), "Sailor Chibi Moon", CharacterConcept.Universe.SAILOR_MOON),
	"ceres": CharacterConcept.create("Sailor Ceres", "ceres", load("res://assets/images/Sailor Ceres/ceresprof.png"), "Sailor Ceres", CharacterConcept.Universe.SAILOR_MOON),
	"nehellenia": CharacterConcept.create("Queen Nehellenia", "nehellenia", load("res://assets/images/Queen Nehellenia/nehelleniaprof.png"), "Queen Nehellenia", CharacterConcept.Universe.SAILOR_MOON),
	"starfighter": CharacterConcept.create("Sailor Star Fighter", "starfighter", load("res://assets/images/Sailor Star Fighter/starfighterprof.png"), "Sailor Star Fighter", CharacterConcept.Universe.SAILOR_MOON),
	"starmaker": CharacterConcept.create("Sailor Star Maker", "starmaker", load("res://assets/images/Sailor Star Maker/starmakerprof.png"), "Sailor Star Maker", CharacterConcept.Universe.SAILOR_MOON),
	"starhealer": CharacterConcept.create("Sailor Star Healer", "starhealer", load("res://assets/images/Sailor Star Healer/starhealerprof.png"), "Sailor Star Healer", CharacterConcept.Universe.SAILOR_MOON),
	"kirito": CharacterConcept.create("Kirito", "kirito", load("res://assets/images/Kirito/kiritoprof.png"), "Kirito", CharacterConcept.Universe.SWORD_ART_ONLINE),
	"asuna": CharacterConcept.create("Asuna", "asuna", load("res://assets/images/Asuna/asunaprof.png"), "Asuna", CharacterConcept.Universe.SWORD_ART_ONLINE),
	"heathcliff": CharacterConcept.create("Heathcliff", "heathcliff", load("res://assets/images/Heathcliff/heathcliffprof.png"), "Heathcliff", CharacterConcept.Universe.SWORD_ART_ONLINE),
	"klein": CharacterConcept.create("Klein", "klein", load("res://assets/images/Klein/kleinprof.png"), "Klein", CharacterConcept.Universe.SWORD_ART_ONLINE),
	"yui": CharacterConcept.create("Yui", "yui", load("res://assets/images/Yui/yuiprof.png"), "Yui", CharacterConcept.Universe.SWORD_ART_ONLINE),
}

# Called when the node enters the scene tree for the first time.
func _ready():
	if DisplayServer.get_name() == "headless":
		initialize_buckets()

func notify_disconnect():
	#print("DC'd from server!")
	#multiplayer.multiplayer_peer.close()
	#client_disconnected.emit()
	pass

func start_reconnect(packages):
	pass

func initialize_buckets():
	all_buckets = {
		CharacterConcept.Universe.NARUTO: {},
		CharacterConcept.Universe.BLEACH: {},
		CharacterConcept.Universe.ONE_PIECE: {},
		CharacterConcept.Universe.MY_HERO_ACADEMIA: {},
		CharacterConcept.Universe.BLACK_CLOVER: {},
		CharacterConcept.Universe.MADOKA_MAGICA: {},
		CharacterConcept.Universe.FAIRY_TAIL: {},
		CharacterConcept.Universe.SOUL_EATER: {},
		CharacterConcept.Universe.AVATAR: {},
		CharacterConcept.Universe.AKAME_GA_KILL: {},
		CharacterConcept.Universe.DEMON_SLAYER: {},
		CharacterConcept.Universe.SEVEN_DEADLY_SINS: {},
		CharacterConcept.Universe.KATEKYO_HITMAN_REBORN: {},
		CharacterConcept.Universe.ATTACK_ON_TITAN: {},
		CharacterConcept.Universe.ONE_PUNCH_MAN: {},
		CharacterConcept.Universe.FIRE_FORCE: {},
		CharacterConcept.Universe.HUNTER_X_HUNTER: {},
		CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN: {},
		CharacterConcept.Universe.FATE: {},
		CharacterConcept.Universe.KILL_LA_KILL: {},
		CharacterConcept.Universe.DEADMAN_WONDERLAND: {},
		CharacterConcept.Universe.TOKYO_GHOUL: {},
		CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME: {},
		CharacterConcept.Universe.JUJUTSU_KAISEN: {},
		CharacterConcept.Universe.DIGIMON: {},
		CharacterConcept.Universe.SAILOR_MOON: {},
		CharacterConcept.Universe.INVINCIBLE: {},
		CharacterConcept.Universe.DRAGON_BALL: {},
		CharacterConcept.Universe.MASHLE: {},
		CharacterConcept.Universe.EMINENCE_IN_SHADOW: {},
		CharacterConcept.Universe.FRIEREN: {},
		CharacterConcept.Universe.SOLO_LEVELING: {},
		CharacterConcept.Universe.CHAINSAW_MAN: {},
		CharacterConcept.Universe.AO_NO_EXORCIST: {},
		CharacterConcept.Universe.YUGIOH: {},
		CharacterConcept.Universe.INUYASHA: {},
		CharacterConcept.Universe.FULL_METAL_ALCHEMIST: {},
		CharacterConcept.Universe.KONOSUBA: {},
		CharacterConcept.Universe.SERAPH_OF_THE_END: {},
		CharacterConcept.Universe.GACHIAKUTA: {},
		CharacterConcept.Universe.SHAMAN_KING: {},
		CharacterConcept.Universe.ASSASSINATION_CLASSROOM: {},
		CharacterConcept.Universe.RECORD_OF_RAGNAROK: {},
		CharacterConcept.Universe.SAINT_SEIYA: {},
		CharacterConcept.Universe.YU_YU_HAKUSHO: {},
		CharacterConcept.Universe.TOUGEN_ANKI: {},
		CharacterConcept.Universe.MIRAI_NIKKI: {},
		CharacterConcept.Universe.RE_ZERO: {},
		CharacterConcept.Universe.BAKI: {},
		CharacterConcept.Universe.SYMPHOGEAR: {},
		CharacterConcept.Universe.WONDER_EGG_PRIORITY: {},
		CharacterConcept.Universe.CLAYMORE: {},
		CharacterConcept.Universe.SWORD_ART_ONLINE: {},
		CharacterConcept.Universe.OVERLORD: {}
	}
	_load_removed_list()
	for path_name in all_chars:
		if _is_removed(path_name):
			continue   # removed characters never re-enter the Nexus (survives restart via removed_list.dat)
		var concept = all_chars[path_name]
		var ap = get_bucket_data(concept)
		if ap == -1:
			continue
		if ap > current_max:
			current_max = ap
		all_buckets[concept.universe][concept.path_name] = CharacterBucket.new_character_bucket(ap, null, concept, 1.0)
	


func get_bucket_list():
	var output = []
	for universe in all_buckets.keys():
		var uni_buckets = all_buckets[universe]
		for path_name in uni_buckets.keys():
			if _is_removed(path_name):
				continue
			output.append(uni_buckets[path_name])
	return output

func get_all_bucket_sets():
	# [current_max, [[path_name, ap, universe], ...]] for every character bucket (muichiro/shirou
	# excluded by get_bucket_list). The universe (enum key name, e.g. "NARUTO") lets the web client
	# group EVERY bucket by universe — its roster.json only covers the playable subset, so without
	# this the per-universe view can't place the many non-playable concept buckets.
	var sets = []
	var uni_names = CharacterConcept.Universe.keys()
	for bucket in get_bucket_list():
		sets.append([bucket.character_concept.path_name, bucket.ap, uni_names[int(bucket.character_concept.universe)]])
	return [current_max, sets]

func has_character_bucket(path_name):
	if _is_removed(path_name):
		return false
	if not all_chars.has(path_name):
		return false
	var uni = all_chars[path_name].universe
	return all_buckets.has(uni) and all_buckets[uni].has(path_name)

func get_poll_state(p_poll_active):
	poll_active = p_poll_active

func check_poll_active():
	server.check_poll_active()

func receive_character_bucket_information(max_ap, bucket_information_sets):
	print("Processing character bucket information from server information sets!")
	var buckets = []
	current_max = max_ap
	#Bucket information should be like
	#universe
	#path name
	#current progress
	#current max
	for bucket_information in bucket_information_sets:
		if _is_removed(bucket_information[1]):
			continue
		var bucket = CharacterBucket.new_character_bucket(bucket_information[2], null, all_chars[bucket_information[1]], 1.0)
		bucket.maximum = current_max
		buckets.append(bucket)
	set_active_buckets(buckets)
	
func receive_universe_bucket_information(bucket_information_sets):
	var buckets = []
	for bucket_information in bucket_information_sets:
		var bucket = UniverseBucket.new_universe_bucket(bucket_information[2], null, bucket_information[0], 1.0, bucket_information[1])
		buckets.append(bucket)
	set_active_buckets(buckets)
	
func receive_character_buckets_request(universe):
	var bucket_info_sets = []
	for bucket in all_buckets[universe]:
		var info_set = [universe, all_buckets[universe][bucket].character_concept.path_name, all_buckets[universe][bucket].ap, current_max]
		bucket_info_sets.append(info_set)
	return [current_max, bucket_info_sets]

func receive_universe_buckets_request():
	var bucket_info_sets = []
	for uni in universe_buckets.keys():
		var info_set = [uni, universe_buckets[uni].ap, universe_buckets[uni].max]
		bucket_info_sets.append(info_set)
	send_universe_buckets.emit(bucket_info_sets)

func receive_bucket_update_client(bucket_name, ap_amount):
	print("Player bucket handler received contribution!")
	broadcast_player_contribution.emit(bucket_name, ap_amount)

func receive_update_from_server(bucket_path_name, amount, new_max):
	print("Got bucket update from server for bucket " + bucket_path_name)
	if current_max != new_max:
		print("Updating max!")
		set_new_max(new_max)
	if bucket_path_name in current_active_buckets.keys():
		print("Changing active bucket AP amount")
		current_active_buckets[bucket_path_name].ap = amount
	if waiting_panel != null:
		print("attempting to update waiting panel!")
		waiting_panel.update_all_bucket_displays()
	
func set_new_max(max):
	for bucket_name in current_active_buckets.keys():
		current_active_buckets[bucket_name].maximum = max

func process_bucket_update(bucket_name, ap_amount):
	var universe = all_chars[bucket_name].universe
	var bucket = all_buckets[universe][bucket_name]
	bucket.add_ap(ap_amount)
	save_bucket_value(bucket_name)
	if bucket.ap > current_max:
		current_max = bucket.ap
	return [bucket_name, bucket.ap, current_max]

func save_bucket_value(bucket_name):
	var bucket_file = FileAccess.open("bucket data/" + bucket_name + ".dat", FileAccess.WRITE)
	bucket_file.store_line(str(all_buckets[all_chars[bucket_name].universe][bucket_name].ap))
	
func get_bucket_data(character_concept):
	if not FileAccess.file_exists("bucket data/" + character_concept.path_name + ".dat"):
		var file = FileAccess.open("bucket data/" + character_concept.path_name + ".dat", FileAccess.WRITE)
		FileAccess.get_open_error()
		file.store_line("0")
	var bucket_file = FileAccess.open("bucket data/" + character_concept.path_name + ".dat", FileAccess.READ)
	var ap_value = int(bucket_file.get_line())
	return ap_value

func _removed_list_path() -> String:
	return "bucket data/removed_list.dat"

func _is_removed(path_name) -> bool:
	return path_name in PERMANENT_EXCLUDED or path_name in OWNER_RETIRED or removed_set.has(path_name)

func _load_removed_list() -> void:
	removed_set = {}
	if not FileAccess.file_exists(_removed_list_path()):
		return
	var f = FileAccess.open(_removed_list_path(), FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line != "":
			removed_set[line] = true

func _save_removed_list() -> void:
	var f = FileAccess.open(_removed_list_path(), FileAccess.WRITE)
	if f == null:
		push_warning("BucketHandler: could not write " + _removed_list_path())
		return
	for path_name in removed_set.keys():
		f.store_line(str(path_name))

# Admin: close a Nexus voting round.
#  1. Remove the top `n` characters by AP — they leave the Nexus entirely, are persisted to
#     removed_list.dat (so they stay out across restarts) and donations to them are rejected
#     (has_character_bucket -> false via _is_removed).
#  2. Halve every remaining bucket's AP (floor) so standings ORDER is preserved but the field is
#     easier to catch, then recompute current_max.
# Returns { removed: [path...], remaining: int, current_max: int } for the caller to broadcast/log.
func close_nexus_round(n: int) -> Dictionary:
	var ranked = get_bucket_list()   # already excludes removed/permanent
	ranked.sort_custom(func (a, b): return a.ap > b.ap)
	n = clampi(n, 0, ranked.size())
	var removed_paths: Array = []
	for i in range(n):
		var concept = ranked[i].character_concept
		removed_paths.append(concept.path_name)
		removed_set[concept.path_name] = true
		if all_buckets.has(concept.universe):
			all_buckets[concept.universe].erase(concept.path_name)
	if n > 0:
		_save_removed_list()
	# Halve everyone still standing (int division floors for the non-negative AP values we store).
	current_max = 0
	var remaining = get_bucket_list()
	for bucket in remaining:
		bucket.ap = int(bucket.ap / 2)
		save_bucket_value(bucket.character_concept.path_name)
		if bucket.ap > current_max:
			current_max = bucket.ap
	print("[NEXUS] Round closed: removed ", removed_paths, " | halved ", remaining.size(), " remaining | new max ", current_max)
	return {"removed": removed_paths, "remaining": remaining.size(), "current_max": current_max}

# Admin: multiply every active bucket's AP by `multiplier` (a decimal below 1 divides), rounding to the
# nearest integer. Mirrors close_nexus_round's rescale-and-persist loop; excludes removed/permanent
# buckets the same way. Returns how many were scaled + the new current_max.
func scale_all_buckets(multiplier: float) -> Dictionary:
	current_max = 0
	var buckets = get_bucket_list()
	for bucket in buckets:
		bucket.ap = max(0, int(round(bucket.ap * multiplier)))
		save_bucket_value(bucket.character_concept.path_name)
		if bucket.ap > current_max:
			current_max = bucket.ap
	print("[NEXUS] Scaled ", buckets.size(), " buckets by ", multiplier, " | new max ", current_max)
	return {"scaled": buckets.size(), "current_max": current_max}

func get_universe_buckets(panel):
	waiting_panel = panel
	waiting_panel.close_panel.connect
	request_universe_buckets.emit()

func close_waiting_panel():
	waiting_panel = null
	clear_active_buckets()

func get_character_buckets(panel, universe_name):
	waiting_panel = panel
	waiting_panel.change_panel.connect(intercept_change_panel)
	waiting_panel.close_panel.connect(close_waiting_panel)
	print("Bucket handler received character bucket request! Talking to Server!")
	request_character_buckets.emit(universe_name)

func intercept_change_panel(panel):
	waiting_panel = panel

func clear_active_buckets():
	current_active_buckets = {}

func set_active_buckets(buckets):
	print("Setting active buckets!")
	current_active_buckets = {}
	for bucket in buckets:
		current_active_buckets[bucket.character_concept.path_name] = bucket
	waiting_panel.accept_buckets(buckets)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func get_top_5():
	var output = []
	var bucket_list = get_bucket_list()
	var sort_func = func (a, b):
		return a.ap > b.ap
	
	bucket_list.sort_custom(sort_func)
	
	for i in range(5):
		var concept = bucket_list[i].character_concept
		output.append(concept)
	return output

func get_leaderboard_concepts():
	server.send_leaderboard_request()

func process_leaderboard_request():
	var leaderboard_concept_sets = []
	
	for concept in get_top_5():
		var ap = all_buckets[concept.universe][concept.path_name].ap
		var path_name = concept.path_name
		leaderboard_concept_sets.append([path_name, ap])
	
	return leaderboard_concept_sets

func process_leaderboard_sets(leaderboard_concept_sets):
	var output = []
	for set in leaderboard_concept_sets:
		var ap = set[1]
		var concept = all_chars[set[0]]
		output.append([concept, ap])
	broadcast_leaderboard_sets.emit(output)
