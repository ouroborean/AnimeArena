extends Character

# The Vessel — the campaign's player-avatar character. Unlike roster characters, its moveset is
# ASSEMBLED at battle start (in initialize(true)) from a fixed set of default abilities PLUS any
# campaign-unlocked ones. The unlocked keys are stamped onto `extra_ability_keys` by
# start_campaign_battle (from campaign_state.campaign_unlocked_abilities) before the battle manager
# calls initialize(true). See scripts/moveset_component.gd:set_base_abilities (accepts an arbitrary
# Ability[]) and components/server_connection.gd:start_campaign_battle.

const DEFAULT_ABILITY_KEYS = ["vessel1", "vessel2", "vessel3", "vessel4"]
# Every ability the Vessel can slot: the 4 defaults + selectable ALTERNATES. The campaign loadout
# picker and the server-side validator (campaign_set_vessel_skills) draw the allowed pool from this
# (plus any campaign-unlocked keys). Add new alternate ability keys here as they're authored.
const AVAILABLE_ABILITY_KEYS = ["vessel1", "vessel2", "vessel3", "vessel4", "vessel5", "vessel6"]

# Campaign-only ability keys granted via rewards encoded as `unlocks:["ability:<key>"]`.
var extra_ability_keys: Array = []
# Player-chosen skill keys (from campaign_state.vessel_loadout). Empty = the 4 defaults (+ unlocks).
var loadout: Array = []


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)


func initialize(_moveset = false):
	character_name = "Vessel"
	path_name = "vessel"
	description = "An empty vessel — the will that carries the party through the campaign. Its techniques are learned along the way."
	if _moveset:
		var kit := []
		for key in _resolve_kit_keys():
			var ab = Ability.from_database(key)
			if ab != null:   # skip an unknown/mistyped key rather than crashing the battle build
				kit.append(ab)
		if kit.is_empty():   # last-resort safety: never hand the engine an empty moveset
			for key in DEFAULT_ABILITY_KEYS:
				kit.append(Ability.from_database(key))
		moveset.set_base_abilities(kit, self)


# The 4 active ability slots the engine surfaces (MovesetComponent.display_abilities returns indices
# 0..3). Prefer the player's explicit `loadout` (filtered to the allowed pool, deduped, padded with
# defaults to keep 4 usable slots); otherwise the 4 defaults with campaign unlocks replacing trailing
# slots. Never exceeds 4 — appending beyond that would make the extra slots permanently unreachable.
func _resolve_kit_keys() -> Array:
	var allowed := AVAILABLE_ABILITY_KEYS.duplicate()
	for k in extra_ability_keys:
		if k != null and str(k) != "" and not (str(k) in allowed):
			allowed.append(str(k))
	var chosen := []
	for key in loadout:
		var k := str(key)
		if k != "" and (k in allowed) and not (k in chosen):
			chosen.append(k)
	if chosen.size() > 0:
		var keys: Array = chosen.slice(0, DEFAULT_ABILITY_KEYS.size())
		for d in DEFAULT_ABILITY_KEYS:
			if keys.size() >= DEFAULT_ABILITY_KEYS.size(): break
			if not (d in keys): keys.append(d)
		return keys
	# No explicit loadout — the 4 defaults with campaign unlocks replacing the trailing slots.
	var unlocks := []
	for key in extra_ability_keys:
		if key != null and str(key) != "":
			unlocks.append(str(key))
	var n := mini(unlocks.size(), DEFAULT_ABILITY_KEYS.size())
	if unlocks.size() > DEFAULT_ABILITY_KEYS.size():
		push_warning("[VESSEL] %d campaign unlocks exceed the 4 ability slots; extras dropped" % unlocks.size())
	return DEFAULT_ABILITY_KEYS.slice(0, DEFAULT_ABILITY_KEYS.size() - n) + unlocks.slice(0, n)


func is_unlocked(player):
	return true


func _process(delta):
	pass
