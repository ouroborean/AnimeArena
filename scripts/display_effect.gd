extends RefCounted
class_name DisplayEffect

# Display-only effect for passive multiplayer clients. The runtime Effect class
# can't be reconstructed from a wire EffectPayload because it owns Callables
# (description, wrapup_func, conditional_func), trigger references, and mission
# hooks. DisplayEffect mimics enough of Effect's surface that the existing
# tooltip UI (effect_tooltip_display, effect_tooltip, effect_tooltip_hover_panel)
# renders without changes.

# Inner class so the storage layer doesn't need a second top-level class_name.
class DisplayEffectSource extends RefCounted:
	var ability_name: String = ""
	var user = null
	var classes: Dictionary = {
		"Physical": false,
		"Energy": false,
		"Mental": false,
		"Affliction": false,
		"Strategic": false,
		"Harmful": false,
		"Helpful": false,
		"Instant": false,
		"Action": false,
		"Control": false,
		"Channeled": false,
		"Uncounterable": false,
		"Bypassing": false,
		"Stealthed": false,
		"Passive": false,
	}

	# The hover panel calls source.replace_mastery_terms when the user has
	# mastery skin on. Mastery substitution is a per-client display preference,
	# so we apply it on the client by reusing the user's own moveset terms.
	func replace_mastery_terms(_user, replace_in: String) -> String:
		if _user == null or _user.moveset == null:
			return replace_in
		var replace_terms = _user.moveset.get_replacement_terms()
		for replacement_pairing in replace_terms:
			replace_in = replace_in.replacen(replacement_pairing[0], replacement_pairing[1])
		return replace_in


# Wire id from EffectPayload (name@user.path_name@source_basename). Stable
# across the lifetime of the effect; used for matching on EFFECT_REMOVED and
# EFFECT_TICK events.
var id: String = ""
var _name: String = ""
var effect_type: int = 0
var user = null
# Untyped because GDScript inner-class type hints in the outer class can trip
# parser ordering in some Godot 4 builds. The runtime value is always a
# DisplayEffectSource.
var source = null
var duration: int = 0
var mag: int = 0
var stacks: int = 1
var display_mag: bool = false
var display_stacks: bool = false
var invisible: bool = false
var system: bool = false
# See Effect.display_system: a system effect that is deliberately player-facing. The server only
# sends system effects when this is set, so the passive client must carry it or the value is lost.
var display_system: bool = false
var unique_render_id: int = 0
var removed: bool = false
var tooltip: Texture2D = null
var description_text: String = ""
var description: Callable

# Effect API surface read by get_effect_clusters / hover panel.
func effect_name() -> String:
	return _name

func stack_count() -> int:
	return stacks

func _init() -> void:
	description = func(eff): return eff.description_text


static func from_payload(payload: Dictionary, resolved_user) -> DisplayEffect:
	var de := DisplayEffect.new()
	de.apply_payload(payload, resolved_user)
	return de


# Mutates an existing DisplayEffect from a fresh wire payload. Used both for
# initial construction (after _init) and EFFECT_TICK updates so the same code
# path keeps name/text/mag/duration in sync.
func apply_payload(payload: Dictionary, resolved_user) -> void:
	id = payload.get("id", id)
	_name = payload.get("name", _name)
	effect_type = int(payload.get("effect_type", effect_type))
	user = resolved_user
	duration = int(payload.get("duration", duration))
	mag = int(payload.get("mag", mag))
	stacks = int(payload.get("stack_count", stacks))
	display_mag = bool(payload.get("display_mag", display_mag))
	display_stacks = bool(payload.get("display_stacks", display_stacks))
	invisible = bool(payload.get("invisible", invisible))
	system = bool(payload.get("system", system))
	display_system = bool(payload.get("display_system", display_system))
	unique_render_id = int(payload.get("unique_render_id", unique_render_id))
	description_text = payload.get("description", description_text)

	var icon_path: String = payload.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		tooltip = load(icon_path)

	if source == null:
		source = DisplayEffectSource.new()
	source.ability_name = payload.get("source_ability_name", _name)
	source.user = resolved_user
	source.classes["Physical"] = bool(payload.get("is_physical", source.classes["Physical"]))
