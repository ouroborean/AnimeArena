extends RefCounted
class_name BotObservation

# ============================================================================
# Human-parity observation layer for the v3 bot (see .claude/plans/bot-training-v3.md §1).
#
# This is the ONLY state accessor v3 feature extraction may touch. It wraps
# (battle, viewer_team) and exposes exactly what the WEB CLIENT renders for a
# player in that seat — nothing more:
#
#   Own side:    everything the wire ships the seat: hp, effects (incl. own
#                invisible ones, minus system except display_system), live costs, cooldown_remaining,
#                usable, legal-target sets (the same target() probe the server
#                serializes as special_targets), own energy pool.
#   Enemy side:  hp/max/dead/banished (always — hp_hidden is dead on the web
#                client), kit identity + live cost + BASE cooldown + static
#                damage hint (all inspect-panel-visible), and effects filtered
#                by the client's visibility rule. NEVER: cooldown_remaining,
#                usable, special_targets, or the enemy energy pool — the web
#                client renders none of those (abilityBar is own-side only,
#                app.js:2896; myPool() reads only the viewer's side).
#
# Effect visibility mirrors app.js effectClusters (app.js:2746-2772), which is
# the parity contract — NOT the engine's get_effect_clusters, which skips the
# alive/banished check on Toph:
#   - system effects are never visible, unless they set display_system;
#   - a non-invisible effect is visible to both sides;
#   - an invisible effect is visible only to its CASTER's side, unless the
#     viewer's team senses it: a living, unbanished Toph senses invisible
#     Physical effects; a living, unbanished Kurotsuchi bearing "Data
#     Collection" senses all invisible effects.
#
# Static game knowledge (base cooldowns, damage hints, kit lists) is parity-
# legal: a human reads the same from the inspect panel / descriptions.
# ============================================================================

var battle
var viewer_team          # Team node of the viewing side
var opponent_team        # Team node of the other side

# Reveal capabilities, computed once per construction (per decision point).
var _toph_sense := false
var _kuro_sense := false


func _init(battle_ref, viewer_team_ref, opponent_team_ref):
	battle = battle_ref
	viewer_team = viewer_team_ref
	opponent_team = opponent_team_ref
	_compute_reveal_caps()


## Convenience: build from the acting Player node (the shape perform_turn_* has).
static func for_player(battle_ref, player_node) -> BotObservation:
	var mine = player_node.team
	var other = battle_ref.enemy.team if battle_ref.player == player_node else battle_ref.player.team
	return BotObservation.new(battle_ref, mine, other)


func _compute_reveal_caps():
	# Client rule (app.js:2735-2743): the sensing character must be alive and
	# unbanished; Kurotsuchi additionally needs the "Data Collection" mark.
	for c in viewer_team.characters:
		if c.dead or c.banished:
			continue
		if c.path_name == "toph":
			_toph_sense = true
		elif c.path_name == "kurotsuchi" and c.marked_by("Data Collection"):
			_kuro_sense = true


# ---------------------------------------------------------------------------
# Characters
# ---------------------------------------------------------------------------

func own_characters() -> Array:
	return viewer_team.characters


func enemy_characters() -> Array:
	return opponent_team.characters


func is_alive(character) -> bool:
	return not (character.dead or character.banished)


func living(characters: Array) -> Array:
	var out: Array = []
	for c in characters:
		if is_alive(c):
			out.append(c)
	return out


func hp(character) -> int:
	return character.health.hp


func max_hp(character) -> int:
	return character.get_modified_max_hp()


func hp_ratio(character) -> float:
	var m = max_hp(character)
	return float(hp(character)) / float(m) if m > 0 else 0.0


## Displayed identity: the disguise path for a disguised enemy (Toga), else the
## real path_name. Matches the client's portrait_disguise handling.
func identity(character) -> String:
	for disguise in character.effects.get_effects_by_type(EffectType.Type.DISGUISE):
		return str(disguise.mag)
	return character.path_name


func is_disguised(character) -> bool:
	return character.effects.get_effects_by_type(EffectType.Type.DISGUISE).size() > 0


# ---------------------------------------------------------------------------
# Effects (the parity filter)
# ---------------------------------------------------------------------------

## Whether `effect` is visible to the viewing side under the client's rules.
func effect_visible(effect) -> bool:
	# display_system marks a system effect that IS shown to both players (Effect.display_system);
	# this view is defined as human parity, so it has to follow the same rule.
	if effect.system and not effect.display_system:
		return false
	if not effect.invisible:
		return true
	# Invisible: visible only to the caster's side…
	var caster = effect.user
	if caster != null and is_instance_valid(caster) and caster.team == viewer_team:
		return true
	# …unless the viewer senses it (Toph: Physical only; Kurotsuchi: all).
	if _kuro_sense:
		return true
	if _toph_sense and effect.source != null and effect.source.classes.get("Physical", false):
		return true
	return false


## All effects on `character` the viewer can see.
func visible_effects(character) -> Array:
	var out: Array = []
	for effect in character.effects._effects:
		if effect_visible(effect):
			out.append(effect)
	return out


## Visible effects on `character` cast by the viewer's team ("my marks on them").
func visible_effects_from_viewer(character) -> Array:
	var out: Array = []
	for effect in visible_effects(character):
		var caster = effect.user
		if caster != null and is_instance_valid(caster) and caster.team == viewer_team:
			out.append(effect)
	return out


## Visible debuff/buff proxy: an effect is a "debuff" when its caster is hostile
## to the character carrying it (the client offers no harm classification, so a
## human judges the same way — by who cast it).
func visible_debuffs(character) -> Array:
	var carrier_team = character.team
	var out: Array = []
	for effect in visible_effects(character):
		var caster = effect.user
		if caster != null and is_instance_valid(caster) and caster.team != carrier_team:
			out.append(effect)
	return out


func visible_buffs(character) -> Array:
	var carrier_team = character.team
	var out: Array = []
	for effect in visible_effects(character):
		var caster = effect.user
		if caster == null or not is_instance_valid(caster) or caster.team == carrier_team:
			out.append(effect)
	return out


# ---------------------------------------------------------------------------
# Own side: full action surface (what the seat's client would let you do)
# ---------------------------------------------------------------------------

## Candidate actions for one of MY characters: every active ability with its
## usability and legal-target list (the same probe the server serializes to
## players as special_targets — parity, not cheating). Targets are Character
## refs; dead/invuln/isolation filtering is whatever target() itself applies.
## Uses authoritative_usable(ignore_energy=true) — NOT usable(), whose baked-in
## affordability check would hide unaffordable candidates entirely and make
## exchange planning impossible (the wire ships `usable` without the energy
## check for the same reason). Each candidate carries an `affordable` flag.
func own_candidates(character) -> Array:
	var out: Array = []
	if not is_alive(character) or character.acted:
		return out
	for ability in character.moveset.get_active_abilities(character):
		if not ability.authoritative_usable(character, true):
			continue
		if not ability.extra_usable(character):
			continue
		var targets = _probe_targets(ability, character)
		if targets.is_empty():
			continue
		var cost = ability.cost()
		out.append({
			"ability": ability,
			"cost": cost,
			"affordable": viewer_team.energy.can_afford(cost),
			"target_type": ability.target_type(),
			"targets": targets,
		})
	return out


## Run the ability's real target() and collect flagged characters, restoring
## every `targeted` flag afterwards (mirrors BattleManager._compute_special_targets,
## battle_manager.gd:2307-2326 — the exact data players receive each snapshot).
func _probe_targets(ability, character) -> Array:
	var chars: Array = viewer_team.characters + opponent_team.characters
	var saved: Array = []
	for c in chars:
		saved.append(c.targeted)
		c.targeted = false
	ability.target(character, battle)
	var result: Array = []
	for c in chars:
		if c.targeted:
			result.append(c)
	for i in range(chars.size()):
		chars[i].targeted = saved[i]
	return result


## The viewer's own energy pool (net of promised reservations), keyed by
## Energy.Type color. The enemy pool is deliberately NOT exposed.
func own_energy() -> Dictionary:
	return viewer_team.energy.true_pool()


func own_energy_total() -> int:
	var total := 0
	for k in own_energy().values():
		total += k
	return total


# ---------------------------------------------------------------------------
# Enemy side: inspect-panel surface only
# ---------------------------------------------------------------------------

## The enemy kit as the inspect panel shows it: identity, live cost, BASE
## cooldown, static damage hint. NO cooldown_remaining / usable / targets.
## A disguised enemy exposes an empty kit (`disguised` flag set): the real
## slots must not leak (app.js:2659-2662); the disguise's static kit is
## client-visible but not engine-instantiated, so v1 under-informs here —
## strictly less than a human sees, never more.
func enemy_kit(character) -> Array:
	if is_disguised(character):
		return []
	var out: Array = []
	for ability in character.moveset.get_active_abilities(character):
		out.append({
			"ability_name": ability.ability_name,
			"cost": ability.cost(),
			"base_cooldown": ability.cooldown,
			"damage_hint": ability.bot_damage_hint(),
		})
	return out


## Max static damage hint across a living enemy's kit — the parity-legal
## "how hard can this character hit" threat proxy.
func enemy_threat(character) -> int:
	var best := 0
	for entry in enemy_kit(character):
		best = max(best, int(entry["damage_hint"]))
	return best


# ---------------------------------------------------------------------------
# Global
# ---------------------------------------------------------------------------

func turn_number() -> int:
	return battle.current_turn_number


func turn_progress() -> float:
	return minf(float(battle.current_turn_number) / 30.0, 1.0)
