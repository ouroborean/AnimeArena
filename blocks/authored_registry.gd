extends RefCounted
class_name AuthoredRegistry

# ============================================================================
# Server-side store for player-authored characters.
#
# One JSON file per character under authored/, cached in a static dict. Every
# spec carries an author and a status; the status is what gates where the
# character may be used:
#
#   draft      — being edited; only the author sees it
#   testing    — playable by its AUTHOR ONLY, in bot matches and private matches
#   submitted  — author asked for review; still author-only until acted on
#   approved   — usable by anyone, everywhere
#   rejected   — back to the author with a note
#
# Nothing here trusts the client: the author is taken from the authenticated
# session, status transitions to `approved` are admin-only, and every spec is
# re-validated with BlockValidator on save AND on load (a file edited on disk
# must not be able to smuggle un-validated blocks into a match).
# ============================================================================

const DIR := "res://authored/"
const STATUSES := ["draft", "testing", "submitted", "approved", "rejected"]

static var _cache: Dictionary = {}
static var _loaded := false

# --- storage ----------------------------------------------------------------
static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))

static func load_all(force := false) -> void:
	if _loaded and not force:
		return
	_loaded = true
	_cache.clear()
	_ensure_dir()
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR + f))
		if not parsed is Dictionary:
			push_warning("[authored] %s is not valid JSON — skipped" % f)
			continue
		# The `icon` binding names a file on disk, so scrub it before anything
		# reads it — the server is its only legitimate writer, but this file may
		# have been hand-edited. Coerce rather than reject: failing validation
		# here would leave the character unloadable AND undeletable (delete_spec
		# goes through get_spec), stranding its assets forever.
		_sanitize_icons(parsed)
		# Re-validate on load: a hand-edited file must not bypass the validator.
		var errs := validate_character(parsed)
		if not errs.is_empty():
			push_warning("[authored] %s failed validation, not loaded: %s" % [f, str(errs.slice(0, 3))])
			continue
		_cache[str(parsed.get("id", ""))] = parsed
	print("[authored] loaded %d authored character(s)" % _cache.size())

static func get_spec(id: String):
	load_all()
	return _cache.get(id, null)

static func all_specs() -> Array:
	load_all()
	return _cache.values()

static func specs_for_author(username: String) -> Array:
	var out: Array = []
	for s in all_specs():
		if str(s.get("author", "")) == username:
			out.append(s)
	return out

static func approved_specs() -> Array:
	var out: Array = []
	for s in all_specs():
		if str(s.get("status", "")) == "approved":
			out.append(s)
	return out

# Force every ability's `icon` to a real ability slot or "". Runs on load and before
# save, so no client-supplied string can ever reach AuthoredAssets.asset_path. Also
# de-dupes: two abilities sharing a slot would silently render the same picture.
static func _sanitize_icons(spec) -> void:
	if not spec is Dictionary:
		return
	var abilities = spec.get("abilities", [])
	if not abilities is Array:
		return
	var allowed := AuthoredAssets.ability_slots()
	var taken := {}
	for a in abilities:
		if not a is Dictionary:
			continue
		var slot := str(a.get("icon", ""))
		if slot.is_empty():
			continue
		if not slot in allowed or taken.has(slot):
			a["icon"] = ""
		else:
			taken[slot] = true

# Which slot a fresh skill-icon upload should land in. Reuses the ability's own
# binding when it has one, so re-uploading overwrites in place instead of leaking
# a file; otherwise hands out the lowest slot nobody references.
static func allocate_icon_slot(spec: Dictionary, ability_index: int) -> String:
	var abilities = spec.get("abilities", [])
	if not abilities is Array or ability_index < 0 or ability_index >= abilities.size():
		return ""
	var mine = abilities[ability_index]
	if not mine is Dictionary:
		return ""
	var allowed := AuthoredAssets.ability_slots()
	var existing := str(mine.get("icon", ""))
	if existing in allowed:
		return existing
	var taken := {}
	for a in abilities:
		if a is Dictionary:
			taken[str(a.get("icon", ""))] = true
	for slot in allowed:
		if not taken.has(slot):
			return slot
	return ""

static func save_spec(spec: Dictionary) -> Array:
	_sanitize_icons(spec)
	var errs := validate_character(spec)
	if not errs.is_empty():
		return errs
	load_all()
	_ensure_dir()
	var id := str(spec.get("id", ""))
	var f := FileAccess.open(DIR + id + ".json", FileAccess.WRITE)
	if f == null:
		return ["could not write authored character to disk"]
	f.store_string(JSON.stringify(spec, "\t"))
	f.close()
	_cache[id] = spec
	return []

static func delete_spec(id: String, requester: String, is_admin: bool) -> Array:
	var spec = get_spec(id)
	if spec == null:
		return ["no such character"]
	if not is_admin and str(spec.get("author", "")) != requester:
		return ["not your character"]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + id + ".json"))
	_cache.erase(id)
	return []

# --- permissions ------------------------------------------------------------
# May `username` put this character on a team?
# OWNER RULING (2026): authored characters are ADMIN-ONLY to field right now — approved OR not. The
# approval/roster plumbing that would let a normal player pick an approved authored character is
# DEFERRED, so until it lands only an admin may seat one on a team (in any match kind). is_admin is
# computed at the call site (ServerConnection._is_admin) and threaded in, rather than importing the
# server layer here. `is_private_or_bot` is retained for signature stability but is no longer consulted:
# a non-admin can never field authored content anywhere, so the old author-in-bot/private carve-out and
# the approved-is-public rule are both suspended (not deleted — the status data is still on disk for when
# the normal-player pipeline is re-enabled).
static func can_use(id: String, username: String, is_private_or_bot: bool, is_admin: bool = false) -> bool:
	var spec = get_spec(id)
	if spec == null:
		return false
	return is_admin

static func is_authored(id: String) -> bool:
	return get_spec(id) != null

# APPROVED means live/public — the same gate char-select (approved_specs) and fielding (can_use)
# already answer to. The public asset fetch uses this so an opponent can only pull art for content
# that is actually in play; an author pulling their OWN unapproved work rides a separate author-owner
# check in the handler, not this one.
static func is_approved(id: String) -> bool:
	var spec = get_spec(id)
	return spec != null and str(spec.get("status", "")) == "approved"

# Who authored `id` (or "" if unknown). Lets the asset handler answer an author fetching their own
# UNAPPROVED art (the editor preview) without widening the public gate to everyone.
static func author_of(id: String) -> String:
	var spec = get_spec(id)
	return str(spec.get("author", "")) if spec != null else ""

# --- construction -----------------------------------------------------------
static func build_character(id: String):
	var spec = get_spec(id)
	if spec == null:
		return null
	var c = load("res://blocks/authored_character.tscn").instantiate()
	c.configure(spec)
	return c

# --- validation -------------------------------------------------------------
static func validate_character(spec) -> Array:
	if not spec is Dictionary:
		return ["character must be an object"]
	var errs: Array = []

	# SECURITY, not design: the id becomes a filename under authored/ and a key in the asset
	# path. Prefix + length + charset are what keep path traversal and collisions out.
	var id := str(spec.get("id", ""))
	if not id.begins_with("auth_") or id.length() < 8 or id.length() > 40:
		errs.append("id must be 'auth_' followed by 3-35 characters")
	elif not _is_safe_id(id):
		errs.append("id may only contain letters, numbers and underscores")

	# The roster's longest name is 36 characters — "The Thompson Sisters (Liz and Patty)" —
	# which the old 32 could not even hold. Doubled rather than nudged to 36.
	var name := str(spec.get("name", "")).strip_edges()
	if name.is_empty() or name.length() > 64:
		errs.append("character name must be 1-64 characters")

	if str(spec.get("author", "")).strip_edges().is_empty():
		errs.append("author is required")

	var status := str(spec.get("status", "draft"))
	if not status in STATUSES:
		errs.append("unknown status '%s'" % status)

	# A length bound on a stored, broadcast string. The longest shipped description is 407
	# characters (kurotsuchi), so this is comfortable headroom rather than a ceiling anyone
	# writing a real character will meet.
	if str(spec.get("description", "")).length() > 1000:
		errs.append("description must be 1000 characters or fewer")

	# `colors` only drives draft/colour-balance hints, and five shipped characters (jinwoo,
	# minene, shiro, toga, usopp) declare NONE at all — AuthoredCharacter.initialize already
	# guards `cols.size() > 0` and falls back. So an empty list is legal. The value range
	# mirrors Energy.Type, all FIVE members: blackwargreymon ships [3, 4], and 4 is RANDOM.
	var colors = spec.get("colors", [])
	if not colors is Array or colors.size() > 5:
		errs.append("colors must be a list of up to 5 energy colours")
	else:
		for c in colors:
			if int(c) < 0 or int(c) > 4:
				errs.append("colour %s is not 0-4" % str(c))

	var abilities = spec.get("abilities", [])
	if not abilities is Array:
		errs.append("abilities must be a list")
		return errs
	var max_abilities: int = BlockSchema.LIMITS["max_abilities"]
	if abilities.size() < 1 or abilities.size() > max_abilities:
		errs.append("a character needs 1-%d abilities" % max_abilities)
	var visible := 0
	var names := {}
	for i in range(abilities.size()):
		var a = abilities[i]
		# Pass the whole moveset: blocks that name a SIBLING skill (an ability `swap`)
		# can only be checked with the rest of the character in hand.
		errs.append_array(BlockValidator.validate_ability(a, abilities).map(func(e): return "ability %d: %s" % [i + 1, e]))
		if a is Dictionary:
			# GROUNDED: named-skill targeting (damage_boost.skills, cost_change.skills,
			# cooldown_change.skills) resolves by ability_name, so two skills sharing a name
			# would make every one of those modifiers ambiguous. No real shipped character
			# repeats a name either.
			var an := str(a.get("name", ""))
			if names.has(an):
				errs.append("two abilities are both named '%s'" % an)
			names[an] = true
			# RESERVED NAMES. Same class of error as the duplicate above: a name that makes the
			# engine do the wrong thing. Effect.effect_name() is `name_override` or the source
			# ability's name, and Character.marked_by() asks only for a MARK with a given name
			# from ANY source — so an ability called "Plasmantle" that self-marks takes zero
			# Harmful damage, in two blocks. Checked against the ABILITY name and against every
			# `name_override` anywhere in its block tree, because either one becomes the string
			# the engine compares. See Character.RESERVED_EFFECT_NAMES for what each one buys.
			for n in _reserved_names_used(a):
				errs.append("ability %d: '%s' is a name the battle engine itself watches for (%s) — rename it" % [i + 1, n, Character.RESERVED_EFFECT_NAMES[n]])
			# Only skills that want a board slot are counted: a Passive never occupies
			# one, and a hidden skill is deliberately off the board until a swap or a
			# form change brings it in.
			#
			# The COUNT of passives is deliberately unbounded: Character.startup_passives
			# iterates every Passive-classed ability in the moveset and nothing anywhere
			# assumes there is one, and two shipped characters run two (gatomon9 + gatomon14,
			# aiohto5 + aiohto6).
			# Read the key ONCE into a local. The previous form was
			#     a.get("classes", []) is Array and "Passive" in a["classes"]
			# which looks safe and is not: the guard passes (the DEFAULT `[]` is an Array), and then
			# the subscript hits a key that is not there. In GDScript that aborts validate_character
			# outright, so the function returned an EMPTY error list — i.e. any spec omitting
			# `classes` on any ability validated CLEAN. That silently disarmed the reserved-name
			# check (A1), the id path-safety check, and every block check, and save_spec writes
			# DIR + id + ".json" on an empty error list. Pre-existing; found while verifying A1.
			var a_classes = a.get("classes", [])
			if not (a_classes is Array and "Passive" in a_classes) and not bool(a.get("hidden", false)):
				visible += 1
	# The battle UI has exactly four SLOTS — it does not have exactly four skills.
	# 137 of the 173 shipped characters carry more than four abilities; the extras
	# are hidden and are surfaced by an ability swap or a form change. So what has
	# to be exactly right is the number of skills that want a slot, and a hidden
	# skill (like a Passive) does not want one.
	var slots: int = BlockSchema.LIMITS["visible_skill_slots"]
	if visible != slots:
		errs.append("a character needs exactly %d visible active skills (has %d) — a Passive or a hidden skill doesn't take a slot" % [slots, visible])
	# Deliberately NOT checked: whether every hidden skill is reachable by some swap.
	# A form change can surface one without any `swap` block naming it, and rejecting
	# an unreferenced hidden skill would block a half-built draft mid-edit.
	return errs

# Every reserved string this ability would put in front of the engine, de-duplicated and in
# discovery order. Two sources, because effect_name() has exactly two: the ability's own name
# (the fallback) and any `name_override` (the winner).
#
# COMPARED EXACTLY, never stripped or case-folded. effect_name() hands the raw stored string to
# `==`, so " Plasmantle" cannot collide with anything and rejecting it would be inventing a
# restriction the game does not have.
static func _reserved_names_used(ability) -> Array:
	var hits := {}
	if not ability is Dictionary:
		return []
	if Character.RESERVED_EFFECT_NAMES.has(str(ability.get("name", ""))):
		hits[str(ability["name"])] = true
	_collect_reserved_overrides(ability.get("blocks", []), hits)
	return hits.keys()

# Mirrors BlockValidator._count_blocks' recursion exactly — a `group`'s `blocks` and an effect's
# `then` payload — so a name buried in a nested reactive is caught alongside a top-level one.
static func _collect_reserved_overrides(blocks, hits: Dictionary) -> void:
	if not blocks is Array:
		return
	for b in blocks:
		if not b is Dictionary:
			continue
		if b.get("blocks", null) is Array:
			_collect_reserved_overrides(b["blocks"], hits)
		var spec = b.get("effect", null)
		if spec is Dictionary:
			var ov := str(spec.get("name_override", ""))
			if Character.RESERVED_EFFECT_NAMES.has(ov):
				hits[ov] = true
			if spec.get("then", null) is Array:
				_collect_reserved_overrides(spec["then"], hits)

static func _is_safe_id(id: String) -> bool:
	for ch in id:
		if not (ch.is_valid_identifier() or ch == "_" or (ch >= "0" and ch <= "9") or (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z")):
			return false
	return true
