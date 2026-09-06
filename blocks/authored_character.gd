extends Character
class_name AuthoredCharacter

# A Character whose identity AND kit come from an authored spec rather than a
# hand-written character/<name>.gd + .tscn pair. One script backs every
# player-created character; AuthoredRegistry hands it the spec.
#
# It deliberately keeps the same 7-component scene shape (and the load-bearing
# HealthComponent.died -> die connection) as every shipped character, so nothing
# downstream can tell the difference.

var spec: Dictionary = {}

func _ready():
	pass

func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)

func configure(new_spec: Dictionary) -> void:
	spec = new_spec
	initialize(true)

func initialize(_moveset = false):
	character_name = str(spec.get("name", "Authored Character"))
	path_name = str(spec.get("id", "authored"))
	description = str(spec.get("description", ""))
	var cols = spec.get("colors", [2, 3])
	if cols is Array and cols.size() > 0:
		character_colors = cols
	universe = CharacterConcept.Universe.CUSTOM
	if _moveset:
		moveset.set_base_abilities(_build_moveset(), self)

# Abilities come from the spec, not from character_ability_counts.json.
func _build_moveset() -> Array:
	var out: Array = []
	var defs = spec.get("abilities", [])
	if not defs is Array:
		return out
	# MovesetComponent.display_abilities() is a blind [0..3] slice, so anything
	# authored ahead of a visible skill would take its board slot and push it off the
	# wire entirely. Visible actives first (stable), then the Passive, then the hidden
	# skills — the engine finds passives by class, not position
	# (Character.startup_passives), and a hidden skill is reached by its moveset INDEX
	# through an ability swap, so this ordering is the whole contract.
	#
	# BlockValidator.moveset_order is that contract, and `swap`.slot/.into are
	# validated against it — so call it rather than restating it here. Two copies of
	# this ordering that disagree would make `swap` index a different skill than the
	# one the validator approved.
	for def in BlockValidator.moveset_order(defs):
		var a := ScriptedAbility.new()
		var built = def
		var dcls = def.get("classes", []) if def is Dictionary else []
		if dcls is Array and "Passive" in dcls:
			# On a COPY: `def` belongs to AuthoredRegistry's cached spec, which is also what
			# a save writes back to disk. The auto-set is a build-time reading of the spec,
			# not an edit to the author's character.
			built = def.duplicate(true)
			_make_permanent_effects_survive(built.get("blocks", []))
		a.configure(built)
		a.ability_name = str(def.get("name", "Skill"))
		a.cooldown = int(def.get("cooldown", 0))
		# string-or-object target (Phase F): _target_type_from_spec reads a Layer-1 object's mode/shape.
		a._target_type = Ability._target_type_from_spec(def.get("target", "enemy"))
		var cost := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
		var cd = def.get("cost", {})
		if cd is Dictionary:
			for k in cd.keys():
				cost[int(str(k))] = int(cd[k])
		a._cost = cost
		# Ability.default_classes() rather than a literal: a second hand-maintained copy of
		# the class list is exactly how the Creator ended up unable to express "Invisible"
		# and "Unstunnable".
		var classes := Ability.default_classes()
		for c in def.get("classes", []):
			if str(c) in classes:
				classes[str(c)] = true
		# THE CHANNEL LABEL IS DERIVED, never typed. "Channeled" and "Control" are pure display
		# strings to the engine (nothing reads classes["Channeled"]; battle_manager:1202 reads
		# "Preserves Channel"), so a skill could otherwise print the chip and channel nothing.
		# Deriving it means the card and the mechanic cannot disagree in THAT direction. The other
		# direction — the label without the mechanic — stays legal for the same reason
		# Invisible/Unstunnable do below: a class the engine does not read is a label, and banning
		# a label would be a restriction the game does not have.
		var ch_mode := str(def.get("channel", ""))
		if BlockSchema.CHANNEL_CLASSES.has(ch_mode):
			classes[str(BlockSchema.CHANNEL_CLASSES[ch_mode])] = true
		# stops_when_stunned is DERIVED into the Action class, never typed (the class chip is retired).
		# The gate reads effect.source.classes["Action"] and effect.source IS this ability, so the
		# class must sit on the ability from construction. The validator has already rejected a skill
		# whose recurring effects disagree on the setting, so a single "any recurring wants it" read is
		# unambiguous here.
		if _ability_stops_when_stunned(def.get("blocks", [])):
			classes["Action"] = true
		a.classes = classes
		# The ability-level FLAGS the engine actually reads. Without these an authored skill
		# could never be stun-immune or hidden from the opponent, which 72 shipped abilities
		# are: character_component.is_stunned() checks `ability.stunnable` and
		# match_event_recorder checks `ability.invisible` — the "Unstunnable"/"Invisible"
		# CLASS strings are only the labels the skill card prints. So the class implies the
		# flag, and an explicit field (for an author who wants the mechanic without the
		# label, or the label without the mechanic) overrides it.
		a.stunnable = bool(def.get("stunnable", not classes.get("Unstunnable", false)))
		a.invisible = bool(def.get("invisible", classes.get("Invisible", false)))
		# PHASE F: a Layer-1 eligibility object's `exclude_self` IS `selfless` (already wired end to
		# end). configure() parsed it onto target_exclude_self; default to it so the object mounts the
		# already-shipped flag rather than a second one, while an explicit top-level `selfless` still wins.
		a.selfless = bool(def.get("selfless", a.target_exclude_self))
		# NOT `and_targeter`: retired in Phase A (BlockValidator.RETIRED_ABILITY_FLAGS). It
		# only ever narrowed an AoE through Ability.and_target, which a ScriptedAbility has no
		# way to define, and it narrowed it on the BOT path only — so a flagged authored AoE
		# hit everyone for a human and only the clicked target for a bot. Left unwritten here
		# as well as rejected there, so a hand-edited file on disk cannot re-enable it.
		a.accurate = bool(def.get("accurate", false))
		out.append(a)
	return out

# A Passive runs ONCE, at battle start (Character.startup_passives), and nothing will ever
# re-run it. So anything it applies permanently (turns/ticks -1) is machinery that has to
# outlive everything the match can do to it, or the passive is silently over for the rest of
# the match while the character still advertises it on its card. Three separate sweeps would
# end it:
#   * a buff-strip — effect_storage_component.cleanse_all_ally_effects gates purely on
#     `cleansable`;
#   * the death sweep for effects the dying character CAST — spared only when `system` is
#     true and `remove_on_death` is false (get_all_death_cleansable_effects);
#   * the death sweep for effects ON the dying character — everything `cleansable` goes
#     (Character.cleanse_death_effects), so a revive comes back without it.
# Hence all four fields rather than the two that survive a revive alone.
#
# FILLED IN, never forced: an explicit author value always wins, because the Creator does not
# enforce restrictions the game lacks and an author may genuinely want a strippable permanent
# effect. `display_system` rides along because `system` does two unrelated jobs and the second
# — hiding the effect from BOTH players — is not what permanence asked for; see
# Effect.display_system, which exists exactly to split them.
static func _make_permanent_effects_survive(blocks) -> void:
	if not blocks is Array:
		return
	const SURVIVAL := {"system": true, "display_system": true,
		"remove_on_death": false, "cleansable": false}
	for b in blocks:
		if not b is Dictionary:
			continue
		if b.get("blocks", null) is Array:
			_make_permanent_effects_survive(b["blocks"])
		# A branching group's `else` arm is applied by the same passive — its permanents survive too.
		if b.get("else", null) is Array:
			_make_permanent_effects_survive(b["else"])
		var spec = b.get("effect", null)
		if not spec is Dictionary:
			continue
		# A trigger/counter payload applies its effects later, but it is still the passive
		# applying them and still nothing that will ever be re-cast, so it gets the same read.
		if spec.get("then", null) is Array:
			_make_permanent_effects_survive(spec["then"])
		if BlockSchema.spec_duration(spec) != -1:
			continue
		for k in SURVIVAL:
			if not spec.has(k):
				spec[k] = SURVIVAL[k]

# Does any recurring effect anywhere in this ability's block tree ask to stop while its author is
# stunned? Walks bundling ops and `then` payloads (a recurring can sit inside either), because the
# Action class it drives is ability-wide wherever the effect is authored.
static func _ability_stops_when_stunned(blocks) -> bool:
	if not blocks is Array:
		return false
	for b in blocks:
		if not b is Dictionary:
			continue
		var spec = b.get("effect", null)
		if spec is Dictionary and BlockSchema.canonical_kind(spec.get("kind", "")) == "recurring" and bool(spec.get("stops_when_stunned", false)):
			return true
		if b.get("blocks", null) is Array and _ability_stops_when_stunned(b["blocks"]):
			return true
		if b.get("else", null) is Array and _ability_stops_when_stunned(b["else"]):
			return true
		if spec is Dictionary and spec.get("then", null) is Array and _ability_stops_when_stunned(spec["then"]):
			return true
	return false

func is_unlocked(player):
	# Ownership/approval gating is enforced server-side by AuthoredRegistry; a
	# character that reached a battle is already permitted to be there.
	return true

func _process(delta):
	pass
