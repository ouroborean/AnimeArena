extends Character

# Sung Jin-woo — a pre-match "Summon" character. Like the Vessel, his moveset is ASSEMBLED at battle
# start (initialize(true)) rather than loaded by count: he equips one of 4 summons before the match,
# which is stamped onto `summon_form` by Match._apply_jinwoo_form (from the queue payload's
# "form:<color>" token). That choice selects which of 5 key-prefixed ability sets becomes his kit;
# an empty summon_form is the basic, all-Random default kit. See components/match.gd:_apply_jinwoo_form
# and scripts/moveset_component.gd:set_base_abilities (accepts an arbitrary Ability[]).

# Each form is its own ability-key prefix so the client (charAbilities) and server both surface ONLY
# the equipped form's skills. Color forms list 5 keys: index 4 is the hidden swap-in that the slot-2
# Summon pulls in (display_abilities only ever surfaces indices 0-3). Unbuilt forms fall back to the
# basic kit, so picking a not-yet-implemented color simply plays as default Jin-woo.
const FORM_KITS := {
	"": ["jinwoo1", "jinwoo2", "jinwoo3", "jinwoo4"],
	"red": ["jinwoored1", "jinwoored2", "jinwoored3", "jinwoored4", "jinwoored5"],
	"green": ["jinwoogreen1", "jinwoogreen2", "jinwoogreen3", "jinwoogreen4", "jinwoogreen5"],
	"white": ["jinwoowhite1", "jinwoowhite2", "jinwoowhite3", "jinwoowhite4", "jinwoowhite5"],
	"blue": ["jinwooblue1", "jinwooblue2", "jinwooblue3", "jinwooblue4", "jinwooblue5"],
}
const DEFAULT_KEYS := ["jinwoo1", "jinwoo2", "jinwoo3", "jinwoo4"]


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)


func initialize(_moveset = false):
	character_colors = []
	character_name = "Sung Jin-woo"
	path_name = "jinwoo"
	universe = CharacterConcept.Universe.SOLO_LEVELING
	description = "The Shadow Monarch. Once the world's weakest hunter, Sung Jin-woo's System lets him grow without limit and raise a legion of shadow soldiers — Igris, Beru, Tank, and Tusk among them."
	if _moveset:
		var keys = FORM_KITS.get(str(summon_form), DEFAULT_KEYS)
		var kit := []
		for key in keys:
			var ab = Ability.from_database(key)
			if ab != null:   # skip an unbuilt/mistyped key rather than crashing the battle build
				kit.append(ab)
		if kit.is_empty():   # unknown/not-yet-authored form — fall back to the basic kit
			for key in DEFAULT_KEYS:
				var ab = Ability.from_database(key)
				if ab != null:
					kit.append(ab)
		moveset.set_base_abilities(kit, self)
		# Blue form's Hymn of Fire (hidden index 4) Stuns its original target when the skill is Countered.
		# execute() does not run on a countered skill, so the reaction rides counter_response_trigger.
		if str(summon_form) == "blue" and moveset.base_abilities.size() > 4:
			moveset.base_abilities[4].counter_response_trigger = hymn_counter_response


# If Hymn of Fire is Countered, Stun the original target (the counter-holder) for 1 turn.
func hymn_counter_response(target):
	if battle == null or target == null or target.dead:
		return
	var context = QueryContext.from_game_state(self, battle)
	var stun = Effect.stun_effect(2)
	stun.set_source(moveset.base_abilities[4])
	Character.add_hostile_effect(context, self, target, stun)


func is_unlocked(player):
	return true


func _process(delta):
	pass
