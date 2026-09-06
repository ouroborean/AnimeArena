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

# args = [context, source_ability, mega:bool]. Adds a stack of the active gun and, once Spirit Gun
# reaches 2 stacks, permanently swaps slot 0 (Spirit Gun) to Mega Spirit Gun (base_abilities[4]).
# The stacks ARE the damage modifier: each pile is a per-stack DAMAGE_MOD on Yusuke targeting the matching
# gun (Gon's Jajanken Stance pattern), so the engine applies the bonus and the tooltip is native. Its
# stack_count() doubles as the counter the transform + Spirit Shotgun read (Spirit Shotgun scales off the
# same piles at a different coefficient, so it reads the count rather than sharing this DAMAGE_MOD).
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
		return
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
	# Transform slot 0 once Spirit Gun reaches 2 stacks (permanent, one-way — must also survive the death cleanse).
	if spirit_gun_stacks() >= 2 and has_effect("Mega Mode", EffectType.Type.ABILITY_SWAP, self) == null:
		var swap = Effect.ability_swap_effect(4, 0, self, -1)
		swap.name_override = "Mega Mode"
		swap.cleansable = false
		swap.system = true
		swap.remove_on_death = false
		swap.set_source(moveset.base_abilities[0])   # source must be a base ability (get_active_abilities gate)
		Character.add_allied_effect(context, self, self, swap)
