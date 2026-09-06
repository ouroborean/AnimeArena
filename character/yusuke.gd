extends Character

# Urameshi Yusuke (Yu Yu Hakusho). A spirit-energy striker built on two interlocking systems:
#   * STACKS: "Spirit Gun" stacks scale his gun skills; at 2 Spirit Gun stacks his Spirit Gun (slot 0)
#     permanently transforms into Mega Spirit Gun, which then builds its own (max 1) "Mega Spirit Gun"
#     stack. Both are permanent, non-cleansable, visible count-marks on Yusuke.
#   * EMPOWERED: Spirit Charge grants an "Empowered" mark consumed by his next Harmful skill, upgrading it.
# The stack-gain + slot-transform is centralised here (called from the abilities via call_unique) so the
# swap trigger can't drift between the two abilities that grant Spirit Gun stacks (yusuke1 + yusuke4).

func _ready():
	pass

func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)

func initialize(_moveset = false):
	character_colors = [1, 3]   # Blue + Red — the non-random cost colours (audit with tools/roster_colors.py)
	character_name = "Urameshi Yusuke"
	path_name = "yusuke"
	universe = CharacterConcept.Universe.YU_YU_HAKUSHO
	description = "Yusuke Urameshi is a delinquent turned Spirit Detective. After dying to save a child and earning his life back, he channels his spirit energy into the Rei Gun — concentrated blasts fired from his fingertip."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "yusuke_unlock" in player.unlocks

func _process(delta):
	pass

# ---- shared kit state ------------------------------------------------------
# The `_a = null` default lets these be called both directly and through call_unique (which passes a
# single args value). effect_name() honours name_override, so all stacks share one mark regardless of
# which ability applied them.
func spirit_gun_stacks(_a = null) -> int:
	var e = has_effect("Spirit Gun", EffectType.Type.DAMAGE_MOD, self)
	return e.stack_count() if e else 0

func mega_spirit_gun_stacks(_a = null) -> int:
	var e = has_effect("Mega Spirit Gun", EffectType.Type.DAMAGE_MOD, self)
	return e.stack_count() if e else 0

# args = [context, source_ability, mega:bool]. Adds ONE stack of the active gun (Spirit Gun caps at 2, Mega
# at 1). The transform is NOT here anymore — Spirit Gun USED at 2 stacks calls transform_to_mega (from
# yusuke1) and Mega USED at 1 stack calls revert_to_spirit_gun (from yusuke5), each consuming that gun's stacks.
# The stacks ARE the damage modifier: each pile is a per-stack DAMAGE_MOD on Yusuke targeting the matching
# gun (Gon's Jajanken Stance pattern), so the engine applies the bonus and the tooltip is native. Its
# stack_count() doubles as the counter the transform reads. Spirit Shotgun scales off the SAME piles at a
# different coefficient (+5/SG, +10/Mega) — because a single DAMAGE_MOD carries one mag, that bonus is TWO
# per_stack "Spirit Shotgun" DAMAGE_MODs (one per pile, distinguished by unique_render_id) so they display
# in the exact same per_stack/count-badge style as the gun boosts (see _add_shotgun_bonus).
func add_spirit_stack(args):
	var context = args[0]
	var source = args[1]
	var mega = args[2]
	if mega:
		if mega_spirit_gun_stacks() >= 1:
			return   # Mega Spirit Gun stacks cap at 1
		var m = Effect.damage_mod_effect(20, -1, ["Mega Spirit Gun"])
		m.name_override = "Mega Spirit Gun"
		m.per_stack = true
		m.stackable = true
		m.display_stacks = true
		m.cleansable = false
		# Permanent machinery: survive Yusuke's own death cleanse (system + remove_on_death=false), but stay
		# visible to both players (display_system) so the stack count still serializes. See [[permanent-machinery-death-cleanse]].
		m.system = true
		m.display_system = true
		m.remove_on_death = false
		m.set_source(source)
		Character.add_allied_effect(context, self, self, m)
		_add_shotgun_bonus(context, 2, 10)   # render_id 2: each Mega stack gives Spirit Shotgun +10
		return
	if spirit_gun_stacks() >= 2:
		return   # Spirit Gun stacks cap at 2 — using Spirit Gun AT 2 stacks transforms instead (transform_to_mega)
	var s = Effect.damage_mod_effect(10, -1, ["Spirit Gun"])
	s.name_override = "Spirit Gun"
	s.per_stack = true
	s.stackable = true
	s.display_stacks = true
	s.cleansable = false
	s.system = true
	s.display_system = true
	s.remove_on_death = false
	s.set_source(source)
	Character.add_allied_effect(context, self, self, s)
	_add_shotgun_bonus(context, 1, 5)   # render_id 1: each Spirit Gun stack gives Spirit Shotgun +5

# Spirit Gun USED at 2 stacks: swap slot 0 to Mega Spirit Gun and CONSUME the 2 Spirit Gun stacks (remove the
# "Spirit Gun" DAMAGE_MOD). One-way display swap, death-durable. (The Spirit-Shotgun-from-Spirit-Gun bonus is
# left intact — it is a separate accumulating pile the request did not name.)
func transform_to_mega(args):
	var context = args[0]
	if has_effect("Mega Mode", EffectType.Type.ABILITY_SWAP, self) == null:
		var swap = Effect.ability_swap_effect(4, 0, self, -1)
		swap.name_override = "Mega Mode"
		swap.cleansable = false
		swap.system = true
		swap.remove_on_death = false
		swap.set_source(moveset.base_abilities[0])   # source must be a base ability (get_active_abilities gate)
		Character.add_allied_effect(context, self, self, swap)
	effects.remove_effect("Spirit Gun", EffectType.Type.DAMAGE_MOD, self)   # consume the 2 Spirit Gun stacks

# Mega Spirit Gun USED at 1 stack: remove the Mega Mode swap (slot 0 shows Spirit Gun again) and CONSUME the
# Mega stack (remove the "Mega Spirit Gun" DAMAGE_MOD).
func revert_to_spirit_gun(_args = null):
	effects.remove_effect("Mega Mode", EffectType.Type.ABILITY_SWAP, self)
	effects.remove_effect("Mega Spirit Gun", EffectType.Type.DAMAGE_MOD, self)   # consume the Mega stack

# Spirit Shotgun's stack bonus mirrors the gun boosts EXACTLY — per_stack DAMAGE_MODs on Yusuke targeting
# ["Spirit Shotgun"] with display_stacks, so each shows a count badge + the native "…deal N more damage"
# tooltip. Because a lone DAMAGE_MOD carries one mag but the two piles pay differently (+5/Spirit Gun stack,
# +10/Mega stack), it is TWO effects — kept as distinct icons by a unique_render_id per pile. They are
# NON-stackable (so add_effect coexists them under the one shared name instead of merging), and we bump the
# matching pile's stack count by hand on each gain. Same permanent/death-durable flags as the gun stacks.
func _add_shotgun_bonus(context, render_id, amount):
	for e in effects.get_effects_by_type(EffectType.Type.DAMAGE_MOD):
		if e.effect_name() == "Spirit Shotgun" and e.unique_render_id == render_id and e.user == self:
			e.stacks += 1
			e.effect_updated.emit(e)   # re-serialize the new stack count to the client
			return
	var b = Effect.damage_mod_effect(amount, -1, ["Spirit Shotgun"])
	b.name_override = "Spirit Shotgun"
	b.per_stack = true
	b.display_stacks = true
	b.unique_render_id = render_id
	b.cleansable = false
	b.system = true
	b.display_system = true
	b.remove_on_death = false
	# Icon from the pile's OWN gun (Spirit Gun for render_id 1, Mega Spirit Gun for 2) so the two same-named
	# "Spirit Shotgun" mods always show DISTINCT art — otherwise, when both stacks are gained via Spirit Charge,
	# both would source from yusuke4 and render as visually identical icons. base_abilities[0]/[4] are the
	# underlying guns regardless of the Mega Mode display swap; name_override keeps the title "Spirit Shotgun".
	b.set_source(moveset.base_abilities[0] if render_id == 1 else moveset.base_abilities[4])
	Character.add_allied_effect(context, self, self, b)
