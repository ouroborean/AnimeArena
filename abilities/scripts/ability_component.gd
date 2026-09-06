extends Node
class_name Ability


# Name of the mark that zeroes every one of the holder's skill costs (see the tail of cost()).
# Deliberately NOT "Fairy Star Strategy": that name is already taken by the passive's stack counter,
# which is also a MARK with user == Mavis, and she can be her own reward target.
const FREE_SKILLS_MARK = "Fairy Star Blessing"

var user
@export var _cost = {
		Energy.Type.GREEN: 0,
		Energy.Type.BLUE: 0,
		Energy.Type.WHITE: 0,
		Energy.Type.RED: 0,
		Energy.Type.RANDOM: 0
	}
@export var cooldown: int = 0
@export var ability_name = ""
@export var _target_type = TargetType.Type.SINGLE
@export var image: Texture
# THE canonical list of ability classes. It is the single source of truth: the `classes`
# dict below, from_database's rebuild, AuthoredCharacter._build_moveset and the Creator's
# class whitelist (BlockValidator._validate_classes) all derive from it, so none of them
# can drift apart. A hand-maintained second copy is how the Creator ended up rejecting
# "Invisible" and "Unstunnable" — two labels 15 shipped abilities carry — while offering
# names nothing ships. Append-only: a class string is stored verbatim in abilities_data.json.
const CLASS_NAMES := [
	"Physical",
	"Energy",
	"Mental",
	"Affliction",
	"Strategic",
	"Harmful",
	"Helpful",
	"Instant",
	"Action",
	"Control",
	"Channeled",
	"Uncounterable",
	"Bypassing",
	"Stealthed",
	"Passive",
	"Preserves Channel",
	# DISPLAY labels for two ability FLAGS rather than behaviour of their own: the engine
	# reads `invisible` (match_event_recorder) and `stunnable` (character_component
	# is_stunned), not these strings. They are classes because the shipped data writes them
	# as classes — 10 abilities are tagged Invisible, 5 Unstunnable — and the player-facing
	# skill card lists them alongside the rest.
	"Invisible",
	"Unstunnable",
	# Internal (not shown to players): set on every skill that deals damage AT THE MOMENT OF USE.
	# Damage that lands later - an applied DoT, a counter, a tick, a reactive trigger - does not
	# qualify. Silence reads this: a silenced character can only use Damaging skills.
	"Damaging",
]

# A fresh all-false class dict. Every place that needs one calls this rather than
# restating the literal.
static func default_classes() -> Dictionary:
	var d := {}
	for c in CLASS_NAMES:
		d[c] = false
	return d

@export var classes: Dictionary = default_classes()
@export var and_targeter = false
@export var selfless = false
@export var stunnable = true
@export var accurate = false
@export var mastery_image: Texture
@export var mastery_name = ""
var minimum_damage = 0
var modifier_value = 1
var cooldown_remaining = 0
# The turn number on which start_cooldown() last stamped this ability, or -1. advance_cooldowns
# reads it to tell the +1 that start_cooldown adds (bookkeeping for that same turn's decrement)
# apart from a genuine turn of cooldown progress, so a Paralyze that lands mid-turn cannot leave a
# freshly-used skill one turn longer than its printed cooldown. See start_cooldown below.
var cooldown_started_turn: int = -1
var ability_blinded = false
var counter_response_trigger = default_counter_response_trigger
var health_drain = false
var important = false
var special_targeting: bool = true
var invisible = false
# Opt out of the DEFAULT 100 damage-received cap (get_damage_cap_receive) so a stack-scaled payoff isn't
# silently clipped at 100. An EXPLICIT lower receive cap (e.g. Yoh's damage_cap_receive) still applies.
# Set from the abilities_data.json "ignore_damage_cap" flag.
var ignore_damage_cap = false
# Wall of Protection (Ainz): this skill's cost cannot be INCREASED — the passive's +Random cost-mod is
# skipped for it (cost REDUCTIONS still apply). Set from the abilities_data.json "cost_locked" flag.
var cost_locked = false
# Passive-client cost override. Populated by the battle manager's snapshot
# reconciler from the server's serialized ability.cost(). Needed because the
# passive client has no runtime _effects, so the COST_CHANGE / COST_MOD /
# COLOR_CHANGE loops in cost() all resolve to nothing locally and the base
# _cost gets returned — which is wrong whenever the acting character is
# targeted by a cost-modifying effect. cost() consults this override when
# user.battle.passive is true.
var server_cost: Dictionary = {}
var server_cost_set: bool = false

# Passive-client usable override. Same reasoning as server_cost: the effect-
# dependent gates in usable() (is_stunned, is_skill_currently_delayed,
# extra_usable for effect-reading abilities) all read from the empty _effects
# array on a passive client and so can never report disabled. The server
# evaluates ability.usable(character) at snapshot time and ships the result
# here; usable() consults it when user.battle.passive is true, layering
# client-only UI state (used_ability, waiting) on top for post-snapshot
# targeting interactions.
var server_usable: bool = true
var server_usable_set: bool = false

# Passive-client targeting override. Populated from the wire snapshot for
# every ability (not just special_targeting ones). server_targets is a list
# of canonical 0..5 character indices — the set of chairs the server says
# this ability can legally land on right now. server_target_type is the
# server-resolved target_type() (SINGLE / ALL / ALL_FACTION / SELF), since
# TARGET_CHANGE effects also only live on the server. The battle manager's
# receive_ability_use_request path walks server_targets directly instead of
# calling ability.target() on passive clients, and target_type() returns
# server_target_type instead of scanning local _effects. This covers
# invulnerability, isolation, marks, and all other effect-dependent
# targeting conditions that the passive client can't evaluate locally.
var server_targets: Array = []
var server_targets_set: bool = false
var server_target_type: int = 0
var server_target_type_set: bool = false

static func passive_ability_source(abi_name):
	var ability = load("res://abilities/ability_component.tscn").instantiate()
	ability.ability_name = abi_name
	return ability

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func split_desc():
	return []

# Authoring `target` mode -> engine TargetType. Block-authored abilities express
# targeting as a mode ("enemy"/"all_enemies"/...) rather than a raw enum ordinal.
#
# `everyone` is ALL, not ALL_FACTION: ALL_FACTION means "pick a side, hit that side"
# (the client only forwards the clicked character's half of special_targets), while ALL
# forwards every valid target on the board. 147 shipped abilities are ALL against 11
# ALL_FACTION, so leaving ALL unreachable made the roster's own commonest AoE shape
# unauthorable. TargetType.COUNT is deliberately NOT offered: nothing in this codebase
# branches on it — player_component, character_component and the web client all treat it
# exactly as SINGLE — so a `count` mode would be a dead label promising a capability the
# engine does not currently have.
static func _target_type_from_mode(mode: String) -> int:
	match mode:
		"self": return TargetType.Type.SELF
		"everyone": return TargetType.Type.ALL
		"all_enemies", "all_allies": return TargetType.Type.ALL_FACTION
		_: return TargetType.Type.SINGLE

# PHASE F — the Layer 1 eligibility object splits `mode` (the SIDE) from `shape` (the FAN-OUT),
# which the six flat strings folded into one word (so "pick any ONE character on either board" —
# everyone + one — was unreachable). This is that split, and it is the "one function" the roadmap
# names. The legacy `everyone` STRING still means ALL (shape defaults there to the fan-out it always
# had); only the OBJECT form reads `shape`, so no saved string-mode character changes meaning.
static func _target_type_from_mode_shape(mode: String, shape: String) -> int:
	match mode:
		"self": return TargetType.Type.SELF
		"everyone": return TargetType.Type.ALL if shape == "all" else TargetType.Type.SINGLE
		"enemy", "ally": return TargetType.Type.ALL_FACTION if shape == "all" else TargetType.Type.SINGLE
	return TargetType.Type.SINGLE

# The ONE entry point both build paths call (from_database and AuthoredCharacter._build_moveset),
# accepting the string-or-object `target`. A string is the legacy mapping; an object splits mode and
# shape. Centralised so the two paths cannot derive a different TargetType from the same spec.
static func _target_type_from_spec(target) -> int:
	if target is Dictionary:
		return _target_type_from_mode_shape(str(target.get("mode", "enemy")), str(target.get("shape", "one")))
	return _target_type_from_mode(str(target))

static func from_database(ability_path):
	var file = "res://abilities_data.json"
	var json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict = JSON.parse_string(json_as_text)
	if not json_as_dict.has(ability_path):
		# Defensive: an unknown key (e.g. a mistyped campaign ability reward) would otherwise crash the
		# whole battle build on the dict lookup below. Warn + return null; callers that pass arbitrary
		# keys (the Vessel loadout) must skip nulls.
		push_warning("[ABILITY] from_database: unknown ability key '%s'" % str(ability_path))
		return null
	var ability_info = json_as_dict[ability_path]
	# BLOCK-AUTHORED abilities carry a validated `blocks` tree instead of a
	# script_path. They are backed by the single ScriptedAbility class, which
	# interprets the tree with the same engine primitives hand-written abilities
	# call — so authored skills get every existing interaction for free, and no
	# authored content is ever loaded as code.
	var ability
	if ability_info.has('blocks'):
		ability = ScriptedAbility.new()
		ability.configure(ability_info)
	else:
		ability = load(ability_info['script_path']).new()
	ability.get_property_list()
	
	ability.ability_name = ability_info['name']
	var cost = {
		0: 0,
		1: 0,
		2: 0,
		3: 0,
		4: 0
	}
	if 'cost' in ability_info:
		for cost_type in ability_info['cost']:
			cost[int(cost_type)] = ability_info['cost'][cost_type]
	
	ability._cost = cost
	
	ability.cooldown = ability_info.get('cooldown', 0)
	# Authored (block) abilities may omit target_type/image; derive or skip rather
	# than hard-crashing the battle build on player-supplied content.
	if ability_info.has('target_type'):
		ability._target_type = ability_info['target_type']
	elif ability_info.has('target'):
		# string-or-object: _target_type_from_spec reads a Layer-1 eligibility object's mode/shape.
		ability._target_type = _target_type_from_spec(ability_info['target'])
	var img_path = str(ability_info.get('image_path', ''))
	if img_path != "" and ResourceLoader.exists(img_path):
		ability.image = load(img_path)
	if 'mastery_name' in ability_info:
		ability.mastery_name = ability_info['mastery_name']
	if 'mastery_image_path' in ability_info:
		ability.mastery_image = load(ability_info['mastery_image_path'])
	var classes = default_classes()
	for ability_class in ability_info['classes']:
		classes[ability_class] = true
	ability.classes = classes
	
	if 'and_targeter' in ability_info:
		ability.and_targeter = ability_info['and_targeter']
	if 'selfless' in ability_info:
		ability.selfless = ability_info['selfless']
	if 'stunnable' in ability_info:
		ability.stunnable = ability_info['stunnable']
	if 'accurate' in ability_info:
		ability.accurate = ability_info['accurate']
	if 'important' in ability_info:
		ability.important = ability_info['important']
	if 'invisible' in ability_info:
		ability.invisible = ability_info['invisible']
	if 'ignore_damage_cap' in ability_info:
		ability.ignore_damage_cap = ability_info['ignore_damage_cap']
	if 'cost_locked' in ability_info:
		ability.cost_locked = ability_info['cost_locked']
	return ability
	

func default_counter_response_trigger(target):
	pass

func delay_trigger(context):
	pass

func return_name_with_mastery(_user, force=false):
	if _user.mastery_skin_on or force:
		if mastery_name != "":
			return mastery_name
		else:
			return ability_name
	else:
		return ability_name

func return_image_with_mastery(_user, force=false):
	if _user == null:
		return image
	if (_user.mastery_skin_on or force) and mastery_image != null:
		return mastery_image
	else:
		return image

func return_description_with_mastery(_user, force=false):
	if _user.mastery_skin_on or force:
		return replace_mastery_terms(_user, describe(_user))
	else:
		return describe(_user)

func replace_mastery_terms(_user, replace_in):
	
	var replace_terms = _user.moveset.get_replacement_terms()
	
	for replacement_pairing in replace_terms:
		replace_in = replace_in.replacen(replacement_pairing[0], replacement_pairing[1])
	return replace_in

func cost():
	# Passive clients have no runtime _effects, so the cost-adjusting loops
	# below would resolve to nothing and return the base _cost — which would
	# be wrong for any character currently under a COST_CHANGE / COST_MOD /
	# COLOR_CHANGE effect. The server serializes the fully-resolved cost per
	# ability in the turn/reconnect snapshot; trust it verbatim when passive.
	if server_cost_set and user != null and user.battle != null and user.battle.passive:
		return server_cost.duplicate()

	var output_dict = {
		0: 0,
		1: 0,
		2: 0,
		3: 0,
		4: 0
	}

	for element in _cost:
		if _cost[element] != 0:
			output_dict[element] = _cost[element]
	
	#Check for effects that override the entire cost of the ability
	for effect in user.effects.get_effects_by_type(EffectType.Type.COST_CHANGE):
		if not effect.user in user.team.characters and user.shrug_off_type(EffectType.Type.COST_CHANGE):
			continue
		if effect.ability_targets == []:
			output_dict = {
				0: 0,
				1: 0,
				2: 0,
				3: 0,
				4: 0
			}
			for key in effect.alternative_cost.keys():
				output_dict[key] = effect.alternative_cost[key]
		else:
			if ability_name in effect.ability_targets:
				output_dict = {
					0: 0,
					1: 0,
					2: 0,
					3: 0,
					4: 0
				}
				for key in effect.alternative_cost.keys():
					output_dict[key] = effect.alternative_cost[key]
	
	#Check for effects that modify costs up or down
	for effect in user.effects.get_effects_by_type(EffectType.Type.COST_MOD):
		if cost_locked and effect.mag > 0:
			continue   # Wall of Protection: cost cannot be increased (reductions still apply)
		if user.shrug_off_type(EffectType.Type.COST_MOD) and (user.is_hostile(effect.user) or effect.source.ability_name == "To the Extreme!!"):
			continue
		if effect.ability_targets == []:
			if effect.per_stack:
				output_dict[effect.cost_change_element] += effect.mag * effect.stack_count()
				if output_dict[effect.cost_change_element] < 0:
					output_dict[effect.cost_change_element] = 0
			else:
				output_dict[effect.cost_change_element] += effect.mag
				if output_dict[effect.cost_change_element] < 0:
					output_dict[effect.cost_change_element] = 0
		else:
			if ability_name in effect.ability_targets:
				if effect.per_stack:
					output_dict[effect.cost_change_element] += effect.mag * effect.stack_count()
					if output_dict[effect.cost_change_element] < 0:
						output_dict[effect.cost_change_element] = 0
				else:
					output_dict[effect.cost_change_element] += effect.mag
					if output_dict[effect.cost_change_element] < 0:
						output_dict[effect.cost_change_element] = 0
	
	#Check for effects that change colors to other colors
	for effect in user.effects.get_effects_by_type(EffectType.Type.COLOR_CHANGE):
		if not effect.user in user.team.characters and user.shrug_off_type(EffectType.Type.COLOR_CHANGE):
			continue
		if effect.ability_targets == []:
			var total_cost = output_dict[effect.cost_change_element]
			output_dict[effect.cost_change_element] -= total_cost
			output_dict[effect.mag] += total_cost
			if output_dict[effect.cost_change_element] < 0:
				output_dict[effect.cost_change_element] = 0
			if output_dict[effect.mag] < 0:
				output_dict[effect.mag] = 0
		else:
			if ability_name in effect.ability_targets:
				var total_cost = output_dict[effect.cost_change_element]
				output_dict[effect.cost_change_element] -= total_cost
				output_dict[effect.mag] += total_cost
				if output_dict[effect.cost_change_element] < 0:
					output_dict[effect.cost_change_element] = 0
				if output_dict[effect.mag] < 0:
					output_dict[effect.mag] = 0
	
	if ability_name == "Dark Shadow Rampage":
		if user.path_name == "tokoyami":
			var mark = user.has_effect("Black Abyss", EffectType.Type.MARK)
			if mark:
				if output_dict[Energy.Type.RANDOM] < mark.mag:
					output_dict[Energy.Type.RANDOM] = 0
				else:
					output_dict[Energy.Type.RANDOM] -= mark.mag

	# Mavis's Fairy Star Strategy, stage 4+: one mark makes EVERY skill on the holder free.
	# Checked LAST and returning outright, so it beats a COST_CHANGE override, an enemy's COST_MOD
	# tax and a COLOR_CHANGE alike - "no cost" means no cost. Being keyed on the character rather
	# than on ability names is the point: a skill swapped or copied in after the mark landed is
	# free too, which the old per-ability COST_CHANGE approach could not express.
	if user.marked_by(FREE_SKILLS_MARK):
		return {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}

	return output_dict

func reflect_trigger(context):
	var attacker = context['owner']
	var tt = attacker.used_ability.target_type()
	var bounce_to_user: bool = context['effect'].mag is int and context['effect'].mag == -1
	if tt == TargetType.Type.SINGLE:
		# Single-target: redirect the one target to the reflect destination (the
		# skill's user for a bounce, else the specific reflect target).
		attacker.targeter.targets.erase(context['target'])
		if bounce_to_user:
			attacker.targeter.targets.append(attacker)
		else:
			attacker.targeter.targets.append(context['effect'].mag)
	elif bounce_to_user and tt != TargetType.Type.SELF:
		# Any multi-target skill (ALL_FACTION / ALL / COUNT) reflected back to its
		# user: re-aim the whole skill onto the attacker's team, as though they had
		# targeted their own faction. reflect_retarget_to_team recomputes the valid
		# targets at this moment.
		var valid = reflect_retarget_to_team(attacker)
		attacker.targeter.targets = valid
		attacker.targeter.main_target = valid[0]
	else:
		# Guardian redirects to a specific character (mag != -1) on a multi-target
		# skill: unchanged — no re-aim, and the one-shot below is NOT consumed (the
		# reflect didn't actually fire).
		return
	if context.effect.source.ability_name == "Immortal Thistle":
		context.effect.user.manually_advance_mission(9, 1)
	if context['effect'].stacks != -1:
		var effect = Effect.invisible_expiration_effect(self, 2)
		effect.set_source(self)
		Character.add_allied_effect(context, context['effect'].user, context.effect.target, effect)
		context['effect'].target.effects.erase_effect(context['effect'])

# When a multi-target Harmful skill is reflected back onto its user, compute which
# of the attacker's OWN team it should now hit. Mirrors the engine's real targeting
# validity (alive + extra_targetable + invuln, bypass-aware) rather than a bare
# is_invuln — so an invuln or untargetable teammate (Sukuna "Sealed King", Jeanne
# "Iron Maiden", etc.) is spared exactly as a normal harmful AoE would spare an
# enemy, and a skill that legitimately pierces invuln still lands on invuln
# teammates. Returns a non-empty list (falls back to [attacker]) so the still-
# executing skill always has a target — an empty targeter crashes abilities that
# dereference targets[0]/main_target. Shared by the private bounce overrides too
# (gallantmon1, rob8, kitara2).
func reflect_retarget_to_team(attacker) -> Array:
	var skill = attacker.used_ability
	var pierces := _skill_pierces_invuln(attacker, skill)
	var ctx = QueryContext.from_game_state(attacker, attacker.battle)
	var valid := []
	for member in attacker.team.characters:
		if member.dead or member.banished:
			continue
		if not Condition.extra_targetable(attacker, member, skill).satisfied(ctx):
			continue
		if not pierces and member.is_invuln(skill):
			continue
		valid.append(member)
	if valid.is_empty():
		return [attacker]
	return valid

# Does `skill` currently pierce invulnerability? Two ways a skill can bypass:
# (a) the "Bypassing" class (e.g. byakuya7) — checked directly; and (b) the
# `bypassing` arg its own target() passes into the targeting helper (e.g. mine2's
# Genius Sniper), which isn't a stored flag — so detect that the way
# _drop_invuln_targets does: re-run target() (snapshotting/restoring the `targeted`
# flags, its only side effect) and see whether it legally marked an invuln enemy.
# (b) is only observable when an invuln enemy exists, so (a) is the primary signal.
func _skill_pierces_invuln(attacker, skill) -> bool:
	if skill.classes.get("Bypassing", false):
		return true
	var chars = attacker.battle.all_characters()
	var saved := []
	for c in chars:
		saved.append(c.targeted)
		c.targeted = false
	skill.target(attacker, attacker.battle)
	var pierces := false
	for c in chars:
		if c.targeted and attacker.is_hostile(c) and c.is_invuln(skill):
			pierces = true
			break
	for i in range(chars.size()):
		chars[i].targeted = saved[i]
	return pierces

func target_type():
	# Passive clients can't resolve TARGET_CHANGE effects locally (empty
	# _effects), so the snapshot carries the server-resolved type for
	# all abilities. Trust it when set.
	if server_target_type_set and user != null and user.battle != null and user.battle.passive:
		return server_target_type
	var tt = _target_type

	for effect in user.effects.get_effects_by_type(EffectType.Type.TARGET_CHANGE):
		if effect.ability_targets == []:
			tt = TargetType.Type.values()[effect.mag]
		else:
			if ability_name in effect.ability_targets:
				tt = TargetType.Type.values()[effect.mag]

	return tt

func describe(user):
	pass

# Silence gate: a silenced character can only use Damaging skills (skills that deal damage at the
# moment of use). Deliberately NOT routed through is_stunned() - silence must ignore every
# stun-interaction escape hatch: the `stunnable` flag (Unstunnable class), shrug_off_type(STUN),
# a stun effect's exclusion_targets / ability_targets class filters, and Erza's Clear Heart Clothing.
# is_silenced() still honours shrug_off_type(SILENCE), which is silence's own counterplay.
# classes.get() rather than classes[]: an Ability whose dict predates the "Damaging" key must read
# false, not crash.
func is_silenced_out(user) -> bool:
	return user.is_silenced() and not classes.get("Damaging", false)


# Skill seal: a MARK carrying skill_seal makes the holder's skills unusable. Deliberately NOT a stun -
# it consults none of the six stun escape hatches (the `stunnable` flag / Unstunnable class,
# shrug_off_type(STUN), Erza's Clear Heart Clothing, COST_STUN, a stun's own class filters, Gunha's
# application-time veto), which is what "cannot be ignored" means for Itachi's Totsuka Blade. (Mahapadma
# and Swords of Revealing Light used to seal this way too; they are now NON-ignorable STUNs - see
# Effect.ignorable / is_stunned - so they also register with is_stunned and pause Action skills.)
#
# Filters, in the order they resolve, all three lists free per-effect:
#   exclusion_targets - ability NAMES exempted outright. Named exemptions win over every other filter.
#                       NOTE: is_stunned and is_invuln read their exclusion_targets as CLASS names; the
#                       seal reads NAMES. Nothing reads both. (A stun's parallel name exemption is
#                       Effect.exclusion_names, read only by is_stunned - e.g. Swords' Dark Magician.)
#   ability_targets   - ability NAMES sealed (Totsuka Blade's shipped shape when non-empty).
#   class_targets     - ability CLASSES sealed.
#   all three empty   - seal everything (Totsuka Blade).
# A seal that names a class filter and does not match it seals NOTHING - it must not fall through to
# the unfiltered "seal everything" case, which is why the class branch continues rather than breaks.
#
# ONE function, called from BOTH usable() and authoritative_usable(): the first drives the local
# skill card, the second the `usable` flag in the wire snapshot. Duplicating the logic is how the
# client and the server end up disagreeing about which buttons are greyed out.
func is_sealed_out(user) -> bool:
	for seal in user.effects.get_effects_by_type(EffectType.Type.MARK):
		if not seal.skill_seal:
			continue
		if ability_name in seal.exclusion_targets:
			continue
		if ability_name in seal.ability_targets:
			return true
		if not seal.class_targets.is_empty():
			for cls in seal.class_targets:
				# .get(), never classes[cls]: an Ability whose dict predates a class name
				# (or an authored one built short) must read false, not crash.
				if classes.get(cls, false):
					return true
			continue
		if seal.ability_targets.is_empty():
			return true
	return false


func usable(user):
	if server_usable_set and user != null and user.battle != null and user.battle.passive:
		if user.battle.waiting_for_turn and not user.bot_character:
			return false
		if user.used_ability != null or user.waiting:
			return false
		if not user.team.energy.can_afford(cost()):
			return false
		return server_usable
	var energy_pool = user.team.energy
	if not energy_pool.can_afford(cost()):
		return false
	if user.is_skill_currently_delayed(self):
		return false
	if user.battle.waiting_for_turn and not user.bot_character:
		return false
	if cooldown_remaining > 0:
		return false
	# is_stunned already honours the stunnable flag for ordinary stuns; a NON-ignorable stun (Mahapadma /
	# Swords of Revealing Light) is meant to lock even Unstunnable skills, so no extra `and stunnable`.
	if user.is_stunned(self):
		return false
	if is_silenced_out(user):
		return false
	if user.used_ability != null or user.waiting:
		return false
	if user.banished:
		return false
	var relinquished_mark = user.marked_by("Relinquished")
	if relinquished_mark and ability_name in relinquished_mark.ability_targets:
		return false
	if is_sealed_out(user):
		return false
	if not extra_usable(user):
		return false
	return true


func authoritative_usable(user, ignore_energy: bool = false):
	# ignore_energy: skip the affordability check. The wire snapshot passes true so
	# the client-reported `usable` covers only NON-energy conditions (cooldown,
	# stun, silence, seals…); each client tracks its own energy pool (incl. a
	# pending 2-for-1 exchange the server hasn't seen yet) and checks affordability
	# itself, so baking energy into this flag wrongly disabled exchange-funded skills.
	var energy_pool = user.team.energy
	if not ignore_energy and not energy_pool.can_afford(cost()):
		return false
	if user.is_skill_currently_delayed(self):
		return false
	if cooldown_remaining > 0:
		return false
	# see usable(): is_stunned already accounts for stunnable; a non-ignorable stun must lock Unstunnable
	# skills too, so drop the redundant `and stunnable`.
	if user.is_stunned(self):
		return false
	if is_silenced_out(user):
		return false
	if user.banished:
		return false
	var relinquished_mark = user.marked_by("Relinquished")
	if relinquished_mark and ability_name in relinquished_mark.ability_targets:
		return false
	if is_sealed_out(user):
		return false
	if not extra_usable(user):
		return false
	return true

func extra_usable(user):
	return true

func delay_execution(user, battle, length):
	var context = QueryContext.from_game_state(user, battle)
	var delayed_skill = Effect.delayed_skill_eff(self, user.targeter.targets, user.targeter.main_target, 1 + (2 * length))
	delayed_skill.set_source(self)
	Character.add_allied_effect(context, user, user, delayed_skill, true)
	
	for target in user.targeter.targets:
		var skill_marker = Effect.delay_target_marker(self, 1 + (2 * length))
		skill_marker.set_source(self)
		Character.add_allied_effect(context, user, target, skill_marker, true)

func is_delayed():
	var highest_mag = 0
	for delay_eff in user.get_delay_effects():
		if not delay_eff.user in user.team.characters and user.shrug_off_type(EffectType.Type.DELAY):
			continue
		if delay_eff.ability_targets == []:
			if delay_eff.stackable:
				delay_eff.consume_stack(1)
			if delay_eff.mag > highest_mag:
				highest_mag = delay_eff.mag

		else:
			for target in delay_eff.ability_targets:
				if classes[target]:
					if delay_eff.stackable:
						delay_eff.consume_stack(1)
					if delay_eff.mag > highest_mag:
						highest_mag = delay_eff.mag
					break
	for character in user.targeter.targets:
		for receive_delay in character.effects.get_effects_by_type(EffectType.Type.DELAY_RECEIVE):
			if not receive_delay.user in user.team.characters and user.shrug_off_type(EffectType.Type.DELAY_RECEIVE):
				continue
			if receive_delay.source.ability_name == "Wood Clone":
				receive_delay.source.user.manually_advance_mission(8, 1)
			if receive_delay.ability_targets == []:
				if receive_delay.stackable:
					receive_delay.consume_stack(1)
				if receive_delay.mag > highest_mag:
					highest_mag = receive_delay.mag
			else:
				for target in receive_delay.ability_targets:
					if classes[target]:
						if receive_delay.stackable:
							receive_delay.consume_stack(1)
						if receive_delay.mag > highest_mag:
							highest_mag = receive_delay.mag
						break
	return highest_mag

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)

func modify_damage_by_stats(damager, target, damage, offense_stat, defense_stat):
	var mod_damage = damage
	mod_damage = damager.stats.modify_outgoing_damage_by_stat(mod_damage, offense_stat, damager)
	mod_damage = target.stats.modify_incoming_damage_by_stat(mod_damage, defense_stat, target)
	return mod_damage

func start_cooldown():
	
	var mods = user.get_cooldown_mods()
	var cooldown_mod = 0
	for mod in mods:
		if not mod.user in user.team.characters and user.shrug_off_type(EffectType.Type.COOLDOWN_MOD):
			continue
		if mod.ability_targets == []:
			if mod.per_stack:
				cooldown_mod += (mod.mag * mod.stack_count())
			else:
				cooldown_mod += mod.mag
		else:
			if ability_name in mod.ability_targets:
				if mod.per_stack:
					cooldown_mod += (mod.mag * mod.stack_count())
				else:
					cooldown_mod += mod.mag
	# ALWAYS +1. advance_cooldowns runs for the acting team at the end of this same turn and takes
	# it straight back off, so the skill settles on exactly its printed cooldown.
	#
	# This used to read `if user.paralyzed(): start_mod = 0` — pre-compensating for the decrement
	# that Paralyze was going to skip. That only worked when the Paralyze was ALREADY on the user at
	# this moment, and it is routinely applied later in the very same action: execute_ability calls
	# start_cooldown() (battle_manager.gd:1190) well before check_ability_use_triggers()
	# (battle_manager.gd:1203), which is what fires reactives like Shunko: Gather. The result was
	# cooldown + 1 on every skill a mid-action Paralyze caught — most visibly a cooldown-0 skill
	# stuck on 1 — and the mirror case (Paralyze cleansed before end of turn) handed out a free
	# cooldown - 1. Stamping the turn here and deciding in advance_cooldowns fixes both directions.
	cooldown_started_turn = -1
	if user != null and is_instance_valid(user) and user.battle != null and is_instance_valid(user.battle):
		cooldown_started_turn = int(user.battle.current_turn_number)
	cooldown_remaining = cooldown + 1 + cooldown_mod


func get_true_damage(damager, target, damage, source = null, damage_type = DamageType.Type.NORMAL):
	var mod_damage = damage
	#Get specific damage boosting effects from the user
	#TODO: Add "no boost" check
	var damage_boosties = damager.effects.get_effects_by_type(EffectType.Type.DAMAGE_MOD)
	var source_name = ""
	
	if source != null:
		source_name = source.source.ability_name
	elif damager.used_ability != null:
		source_name = damager.used_ability.ability_name
	
	var boost_allowed = damager.can_boost()
	for boost in damage_boosties:
		# Trap of Argalia (NO_BOOST): the damager cannot INCREASE its damage with any effect, so skip
		# positive DAMAGE_MOD boosts. Negative mods (reductions/debuffs on the damager) still apply.
		if not boost_allowed and boost.mag > 0:
			continue
		if not boost.user in user.team.characters and user.shrug_off_type(EffectType.Type.DAMAGE_MOD):
			continue
		if boost.class_targets != []:
			if damage_type not in boost.class_targets:
				continue
			
			#var fail = true
			#for class_target in boost.class_targets:
			#	var class_target_name = DamageType.get_damage_type_name(class_target, true)
			#	
			#	if classes[class_target_name] and damage_type == class_target:
			#		fail = false
			#if fail:
			#	continue
		if boost.exclusion_targets != []:
			if damage_type in boost.exclusion_targets:
				continue
			#var fail = false
			#for class_target in boost.exclusion_targets:
			#	var class_target_name = DamageType.get_damage_type_name(class_target, true)
			#	if classes[class_target]:
			#		fail = true
			#if fail:
			#	continue
		#if boost.type_targets != []:
		#	var fail = true
		#	for type_target in boost.type_targets:
		#		if damage_type == type_target:
		#			fail = false
		#	if fail:
		#		continue
		var boost_mag = 0
		if boost.ability_targets == []:
			if boost.per_stack:
				boost_mag = boost.mag * boost.stack_count()
				if boost_mag < 0 and damage_type == DamageType.Type.TRUE:
					boost_mag = 0
				mod_damage += boost_mag * modifier_value
			else:
				boost_mag = boost.mag
				if boost_mag < 0 and damage_type == DamageType.Type.TRUE:
					boost_mag = 0
				mod_damage += boost_mag * modifier_value
		else:
			if source_name in boost.ability_targets:
				if boost.per_stack:
					boost_mag = boost.mag * boost.stack_count()
					if boost_mag < 0 and damage_type == DamageType.Type.TRUE:
						boost_mag = 0
					mod_damage += boost_mag * modifier_value
				else:
					boost_mag = boost.mag
					if boost_mag < 0 and damage_type == DamageType.Type.TRUE:
						boost_mag = 0
					mod_damage += boost_mag * modifier_value
		if boost_mag < 0:
			#TODO do damage reduced missions
			boost.user.check_hostile_damage_reducing_mission_triggers(boost, user, boost_mag * -1)
	if mod_damage < 0:
		mod_damage = 0

	var vulnerabilities = target.effects.get_effects_by_type(EffectType.Type.VULNERABILITY)
	for vuln in vulnerabilities:
		if not vuln.user in user.team.characters and user.shrug_off_type(EffectType.Type.VULNERABILITY):
			continue
		if vuln.class_targets != []:
			if damage_type not in vuln.class_targets:
				continue
			#var fail = true
			#for class_target in vuln.class_targets:
			#	if classes[class_target]:
			#		fail = false
			#if fail:
			#	continue
		if vuln.exclusion_targets != []:
			if damage_type in vuln.exclusion_targets:
				continue
			#var fail = false
			#for class_target in vuln.exclusion_targets:
			#	if classes[class_target]:
			#		fail = true
			#if fail:
			#	continue
		#if vuln.type_targets != []:
		#	var fail = true
		#	for type_target in vuln.type_targets:
		#		if damage_type == type_target:
		#			fail = false
		#	if fail:
		#		continue
		if vuln.ability_targets == []:
			if vuln.per_stack:
				mod_damage += (vuln.mag * vuln.stack_count())
			else:
				mod_damage += vuln.mag
		else:
			if source_name in vuln.ability_targets:
				if vuln.per_stack:
					mod_damage += (vuln.mag * vuln.stack_count())
				else:
					mod_damage += vuln.mag
	
	mod_damage = extra_damage_calc(damager, target, mod_damage)
	return mod_damage

func extra_damage_calc(damager, target, damage):
	return damage

## Bot AI hint: typical single-target damage; default reads `base_damage`.
## Override for AoE-split or multi-hit cases where it doesn't apply per-target.
func bot_damage_hint() -> float:
	if "base_damage" in self:
		return float(get("base_damage"))
	return 0.0

func and_target(character):
	return false

func on_kill(target):
	pass

func get_true_healing(healer, target, healing):
	var mod_healing = healing
	
	#TODO: Get specific healing boosts
	
	return mod_healing

func get_true_shielding(shielder, target, shielding):
	var mod_shielding = shielding
	
	#TODO: get specific shielding boosts
	
	return mod_shielding

func check_hostile_target(user, target, context, bypassing=false):
	if Condition.can_hostile_target(user, target, self, bypassing).satisfied(context):
		target.set_targeted()

func check_allied_target(user, target, context, bypassing=false):
	if Condition.can_allied_target(user, target, bypassing).satisfied(context):
		target.set_targeted()

func default_hostile_target_function(user, battle, bypassing=false, mark_req = null):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if mark_req == null or character.has_effect(mark_req, EffectType.Type.MARK, user):
			check_hostile_target(user, character, context, bypassing)

func default_allied_target_function(user, battle, bypassing = false, mark_req = null):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if selfless and character == user:
			continue
		if mark_req == null or character.has_effect(mark_req, EffectType.Type.MARK, user):
			check_allied_target(user, character, context, bypassing)

func default_self_target_function(user, battle, bypassing = false):
	var context = QueryContext.from_game_state(user, battle)
	check_allied_target(user, user, context, true)

func default_counter_timeout(context):
	var effect = Effect.invisible_expiration_effect(self)
	effect.set_source(self)
	Character.add_allied_effect(context, context['effect'].user, context['target'], effect)

func default_defend(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var eff = Effect.invuln_effect(2)
	eff.set_source(self)
	Character.add_allied_effect(context, user, user, eff)

func default_counter_trigger(context):
	var countered_target = context['owner']
	var counter_eff_target = context['effect'].target
	var counter_user = context['effect'].user
	var notification_effect = Effect.counter_notification_effect(self)
	notification_effect.set_source(self)
	Character.add_hostile_effect(context, counter_user, countered_target, notification_effect, true)
	
	counter_eff_target.effects.remove_effect(context['effect'].source.ability_name, context['effect'].effect_type, context['effect'].user)


func default_persistent_counter_trigger(context):
	var countered_target = context['owner']
	var counter_eff_target = context['target']
	var counter_user = context['effect'].user
	
	var notification_effect = Effect.counter_notification_effect(self)
	notification_effect.set_source(self)
	Character.add_hostile_effect(context, counter_user, countered_target, notification_effect)

## Shorthand for creating a QueryContext from the current game state.
func make_context(battle):
	return QueryContext.from_game_state(user, battle)

## Deals damage to all targets. Used by the ~200 abilities that just loop and deal damage.
func deal_damage_to_targets(context, damage, damage_type = DamageType.Type.NORMAL):
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, damage_type)

## Applies an effect to a hostile target, automatically setting this ability as the source.
## Returns the effect for chaining (e.g. cancel tracking).
func apply_hostile(context, target, effect, bypass_dd = false):
	effect.set_source(self)
	Character.add_hostile_effect(context, user, target, effect, bypass_dd)
	return effect

## Applies an effect to an allied target, automatically setting this ability as the source.
## Returns the effect for chaining (e.g. cancel tracking).
func apply_allied(context, target, effect, bypass_dd = false):
	effect.set_source(self)
	Character.add_allied_effect(context, user, target, effect, bypass_dd)
	return effect

# ── Tier 1: Direct Helpers ──────────────────────────────────────────────────

## Deal damage to each target and apply one hostile effect to each.
func damage_and_apply(context, damage, damage_type, effect, bypass_dd = false):
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, damage_type)
		var eff = effect.duplicate() if user.targeter.targets.size() > 1 else effect
		apply_hostile(context, target, eff, bypass_dd)

## Deal damage to each target and apply multiple hostile effects to each.
func damage_and_apply_many(context, damage, damage_type, effects: Array, bypass_dd = false):
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, damage_type)
		for effect in effects:
			var eff = effect.duplicate() if user.targeter.targets.size() > 1 else effect
			apply_hostile(context, target, eff, bypass_dd)

## Apply one or more effects to self.
func buff_self(context, effects: Array):
	for effect in effects:
		apply_allied(context, user, effect)

## Deal damage to targets, then apply effects to self.
func damage_then_buff(context, damage, damage_type, self_effects: Array):
	deal_damage_to_targets(context, damage, damage_type)
	buff_self(context, self_effects)

## Deal damage to targets and heal self.
func damage_and_heal_self(context, damage, damage_type, heal_amount):
	deal_damage_to_targets(context, damage, damage_type)
	Character.resolve_healing(context, user, heal_amount)

## Heal each target.
func heal_targets(context, heal_amount):
	for target in user.targeter.targets:
		Character.resolve_healing(context, target, heal_amount)

## AoE with main target distinction — more damage to main target, less to others.
func damage_splash(context, main_damage, splash_damage, damage_type):
	for target in user.targeter.targets:
		if target == user.targeter.main_target:
			Character.resolve_damage(context, target, main_damage, damage_type)
		else:
			Character.resolve_damage(context, target, splash_damage, damage_type)

# ── Tier 2: Trigger & DOT Helpers ───────────────────────────────────────────

## Create and apply a ticking trigger to a hostile target. Returns the effect.
func apply_ticking_trigger(context, target, callback, duration, desc_func = null):
	var trigger = Trigger.from_condition(Condition.always(), callback)
	var eff = Effect.trigger_effect(trigger, EffectType.Type.TICKING_TRIGGER, duration, desc_func)
	apply_hostile(context, target, eff)
	return eff

## Create and apply a damage-receive trigger. Allied if allied=true. Returns the effect.
func apply_damage_receive_trigger(context, target, callback, duration, desc_func = null, allied = false):
	var trigger = Trigger.from_condition(Condition.always(), callback)
	var eff = Effect.trigger_effect(trigger, EffectType.Type.DAMAGE_RECEIVE_TRIGGER, duration, desc_func)
	if allied:
		apply_allied(context, target, eff)
	else:
		apply_hostile(context, target, eff)
	return eff

## Create and apply an action-use trigger to a target. Returns the effect.
func apply_action_trigger(context, target, callback, duration, desc_func = null):
	var trigger = Trigger.from_condition(Condition.always(), callback)
	var eff = Effect.trigger_effect(trigger, EffectType.Type.ACTION_USE_TRIGGER, duration, desc_func)
	apply_hostile(context, target, eff)
	return eff

## Apply a DOT (damage over time) to each target.
func apply_dot_to_targets(context, damage, damage_type, duration):
	for target in user.targeter.targets:
		apply_hostile(context, target, Effect.damage_effect(damage, damage_type, duration))

## Deal immediate damage AND apply a DOT to each target.
func damage_and_dot(context, hit_damage, hit_type, dot_damage, dot_type, dot_duration):
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, hit_damage, hit_type)
		apply_hostile(context, target, Effect.damage_effect(dot_damage, dot_type, dot_duration))

## Set up a counter on the target. Returns the counter effect.
func setup_counter(context, target, counter_callback, timeout_callback, duration, desc, classes = [], exclude_classes = []):
	var trigger = Trigger.from_condition(Condition.always(), counter_callback)
	var counter = Effect.counter_effect(trigger, EffectType.Type.COUNTER_RECEIVE, duration, desc, classes, exclude_classes)
	counter.wrapup_func = timeout_callback
	apply_allied(context, target, counter)
	return counter

## Track effects for control cancellation (cancelled on stun).
func track_cancellable(context, duration, effects: Array):
	var cancel = Effect.control_cancel(duration, ability_name, effects)
	apply_allied(context, user, cancel)

# ── Tier 3: Conditional Helpers ──────────────────────────────────────────────

## Get stack count of an effect on this ability's user (or another character). Returns 0 if absent.
func get_stacks(effect_name, effect_type, check_user = null):
	var check = check_user if check_user else user
	var eff = user.effects.has_effect(effect_name, effect_type, check)
	if eff:
		return eff.stack_count()
	return 0

## Get magnitude of an effect on this ability's user (or another character). Returns 0 if absent.
func get_mag(effect_name, effect_type, check_user = null):
	var check = check_user if check_user else user
	var eff = user.effects.has_effect(effect_name, effect_type, check)
	if eff:
		return eff.mag
	return 0

## Check if user has a mark. Shorthand for user.marked_by().
func has_mark(mark_name, check_user = null):
	var check = check_user if check_user else user
	return user.marked_by(mark_name, check)

# ── Tier 4: Ability Swap Helpers ─────────────────────────────────────────────

## Swap an ability slot. swap_in = index of ability to swap in, slot = slot to replace.
func swap_ability(context, swap_in, slot, duration = -1):
	apply_allied(context, user, Effect.ability_swap_effect(swap_in, slot, user, duration))

## Swap multiple ability slots at once. swaps = {slot: swap_in_index, ...}.
func swap_abilities(context, swaps: Dictionary, duration = -1):
	for slot in swaps:
		swap_ability(context, swaps[slot], slot, duration)

func get_target_variation_priorities(context, bot_difficulty):
	
	if not usable(context['owner']):
		return [0, [user, "PASS", []]]
	else:
		var priorities = custom_behavior(context)
		for priority_set in priorities:
			priority_set[0] += randi_range(-bot_difficulty, bot_difficulty)
		var sort_func = func (a, b):
			return a[0] > b[0]
		priorities.sort_custom(sort_func)
		while len(priorities) > 0:
			var best_priority = priorities.pop_front()
			if best_priority[1][1] is String:
				return best_priority
			for c in user.battle.all_characters():
				c.set_untargeted()
			target(user, user.battle)
			var targets = best_priority[1][2].duplicate()
			for prio_target in targets:
				if not prio_target.targeted:
					best_priority[1][2].erase(prio_target)
			for c in user.battle.all_characters():
				c.set_untargeted()
			user.battle.targeting_reset_needed.emit()
			if len(best_priority[1][2]) > 0:
				return best_priority
			
		return [0, [user, "PASS", []]]

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func behavior_single_target_damage(context, base_mod = 0, missing_ratio = 1.0, bypass = false):
	var variations = []
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self) or bypass) and not (character.dead or character.banished):
			var missing_hp = 100 - character.health.hp
			variations.append([100 + int(missing_hp * missing_ratio) + base_mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations

func behavior_single_target_selfless_helpful(context, base_mod = 0, missing_ratio = 1.0, bypass = false):
	var variations = []
	for character in context['ally_team'].characters:
		#TODO: add isolation check
		if (not character.is_isolated() or bypass) and not (character.dead or character.banished) and not character == context['owner']:
			variations.append([100 + base_mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func behavior_single_target_hostile(context, base_mod = 0, bypass = false):
	var variations = []
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self) or bypass) and not (character.dead or character.banished):
			variations.append([100 + base_mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func behavior_single_target_stun(context, base_mod = 0, bypass = false):
	var variations = []
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self) or bypass) and not (character.dead or character.banished) and not character.ignoring_effect_type(EffectType.Type.STUN):
			variations.append([100 + base_mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations
	
func behavior_hostile_spread_out(context, marker_name, marker_type, base_mod = 0, exclusion_mod = 0.0, bypass = false):
	var variations = []
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self) or bypass) and not (character.dead or character.banished):
			var exclusion = 1.0
			if character.has_effect(marker_name, marker_type, context['owner']):
				exclusion = exclusion_mod
			variations.append([(100 + base_mod) * exclusion, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func behavior_hostile_single_require_mark(context, marker_name, marker_type, base_mod = 0, per_mark=false, bypass = false):
	var variations = []
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self) or bypass) and not (character.dead or character.banished):
			if character.has_effect(marker_name, marker_type, context['owner']):
				var char_mod = base_mod
				if per_mark:
					char_mod = base_mod * character.has_effect(marker_name, marker_type, context['owner']).stack_count()
				
				variations.append([100 + base_mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations
	
func behavior_helpful_single_require_mark(context, marker_name, marker_type, base_mod = 0, per_mark=false, bypass = false):
	var variations = []
	for character in context['ally_team'].characters:
		if (not character.is_isolated() or bypass) and not (character.dead or character.banished):
			if character.has_effect(marker_name, marker_type, context['owner']):
				var char_mod = base_mod
				if per_mark:
					char_mod = base_mod * character.has_effect(marker_name, marker_type, context['owner']).stack_count()
				
				variations.append([100 + base_mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func behavior_hostile_aoe_damage(context, base_mod = 0, missing_ratio = 1.0, bypass = false):
	var variations = []
	var targets = []
	var mod = 0
	var missing_hp = 0
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self) or bypass) and not (character.dead or character.banished):
			targets.append(character)
			missing_hp += (100 - character.health.hp)
			mod += base_mod
	if len(targets) == 0:
		variations.append([0, [user, "PASS", []]])
	else:
		variations.append([mod + (missing_hp * missing_ratio), [user, self, targets]])
	
	return variations

func behavior_helpful_aoe_aid(context, base_mod = 0, missing_ratio = 1.0, bypass = false):
	var variations = []
	var targets = []
	var mod = 0
	var missing_hp = 0
	for character in context['ally_team'].characters:
		if (not character.is_isolated() or bypass) and not (character.dead or character.banished):
			targets.append(character)
			missing_hp += (100 - character.health.hp)
			mod += base_mod
	if len(targets) == 0:
		variations.append([0, [user, "PASS", []]])
	else:
		variations.append([mod + (missing_hp * missing_ratio), [user, self, targets]])
	
	return variations

func behavior_all_target(context, base_mod = 0, bypass = false):
	var variations = []
	var targets = []
	var mod = 0
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self) or bypass) and not (character.dead or character.banished):
			targets.append(character)
			mod += base_mod
	for character in context['ally_team'].characters:
		if (not character.is_isolated() or bypass) and not (character.dead or character.banished):
			targets.append(character)
			mod += base_mod
	if len(targets) == 0:
		variations.append([0, [user, "PASS", []]])
	else:
		variations.append([mod, [user, self, targets]])
	return variations

func behavior_hostile_splash_aoe(context, base_mod = 0, missing_ratio = 1.0, bypass = false):
	var variations = []
	var targets = []
	var mod = 0
	var missing_hp = 0
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self) or bypass) and not (character.dead or character.banished):
			targets.append(character)
			missing_hp += (100 - character.health.hp)
			mod += base_mod
	if len(targets) == 0:
		variations.append([0, [user, "PASS", []]])
	else:
		var main_index = context['battle'].roll(0, len(targets) - 1)
		var main_target = targets[main_index]
		var final_targets = [main_target]
		for target in targets:
			if not target == main_target:
				final_targets.append(target)
		variations.append([mod + (missing_hp * missing_ratio), [user, self, final_targets]])
	return variations
	
func behavior_self_panic_button(context, base_mod = 0, panic_mod = 1.0):
	var variations = []
	variations.append([-30 + base_mod + ( (100 - context['owner'].health.hp) * panic_mod ), [user, self, [user]]])
	return variations

func behavior_single_target_heal(context, base_mod=0, missing_ratio=1.0, bypass=false):
	var variations = []
	for character in context['ally_team'].characters:
		if character.health.hp == 100:
			continue
		if (not character.is_isolated() or bypass) and not (character.dead or character.banished):
			var missing_hp = 100 - character.health.hp
			variations.append([100 + int(missing_hp * missing_ratio) + base_mod, [user, self, [character]]])
		
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations

func behavior_any_target(context, base_mod = 0, bypass = false):
	var variations = []
	for character in context['ally_team'].characters:
		#TODO: add isolation check
		if (not character.is_isolated() or bypass) and not (character.dead or character.banished):
			variations.append([100 + base_mod, [user, self, [character]]])
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self) or bypass) and not (character.dead or character.banished):
			variations.append([100 + base_mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations

func behavior_single_target_helpful(context, base_mod = 0, bypass = false):
	var variations = []
	for character in context['ally_team'].characters:
		#TODO: add isolation check
		if (not character.is_isolated() or bypass) and not (character.dead or character.banished):
			variations.append([100 + base_mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
