extends Ability
var per_stack = 5
var black_cat_bonus = 10
var max_stacks = 6

const GATHER := "Shunko: Gather"
const SWAP_IN_NAME := "Fickle Flash"
# Render bucket for the effects the reactive APPLIES, kept apart from the standing watcher. See
# gather_trigger. Any non-zero value works; the standing brand keeps the default 0.
const FIRED_RENDER_ID := 1

# Shunko: Gather. The spine of Yoruichi's kit — a permanent punish that makes acting into her cost
# the enemy tempo, and a battery Raijin Senkei scales off. Nothing consumes it: once installed the
# reactive runs for the rest of the match, and the only ceiling is the 6-stack cap.
#
# HOSTING: check_ability_use_triggers walks the ACTING character's OWN effect list
# (character_component.gd:1319), so an ACTION_USE_TRIGGER only ever fires for the character it sits
# on. One watcher is planted per enemy — which is also exactly what gives "each enemy can be
# paralyzed once per turn" for free. hibari5.gd is the shipped shape for this.
#
# The stack MARK on Yoruichi is the single source of truth for both "is this installed" and "how
# hard does it hit"; the watchers read it live on every fire rather than caching a number, so a
# stack-up is picked up instantly by every brand already on the field.

func describe(user):
	return "Permanently, whenever an enemy uses a new skill, Yoruichi will deal 5 Piercing damage to them and Paralyze their cooldowns for 1 turn. This skill can be used while active to permanently increase its damage by 5 (Maximum of 6 stacks)."

func split_desc():
	return [
		["Permanently, an enemy that uses a new skill takes 5 Piercing damage and has their cooldowns Paralyzed for 1 turn", Color.ORANGE_RED],
		["Using this skill again permanently increases that damage by 5", Color.CADET_BLUE],
		["Maximum of 6 stacks", Color.DIM_GRAY],
	]

func gather_stacks(yoruichi) -> int:
	if yoruichi == null or not is_instance_valid(yoruichi):
		return 0
	var marker = yoruichi.has_effect(ability_name, EffectType.Type.MARK, yoruichi)
	return marker.stack_count() if marker else 0

# True exactly while Black Cat Warrior Princess's swap is up. Keyed off the swapped-in ability
# rather than a separate flag, so the buff can never desync from Fickle Flash's availability
# (gasai5.breakdown_active is the same idiom). Deliberately self-contained — reaching into
# base_abilities[2] would crash the moment a copy/steal mechanic ran this from another character.
func black_cat_active(yoruichi) -> bool:
	if yoruichi == null or not is_instance_valid(yoruichi) or yoruichi.moveset == null:
		return false
	for a in yoruichi.moveset.get_active_abilities(yoruichi):
		if a != null and a.ability_name == SWAP_IN_NAME:
			return true
	return false

func _new_stack(count: int):
	# The badge already shows the stack count; the tooltip's job is to say what the stacks BUY.
	var stack_desc = func (eff):
		return "Shunko: Gather deals " + str(trigger_damage(eff.user)) + " Piercing damage."
	var mark = Effect.mark(-1, stack_desc)
	mark.stackable = true
	mark.display_stacks = true
	mark.stacks = count
	# Machinery, not an outcome: the watchers it powers are already cleanse-proof (trigger_effect
	# sets cleansable = dur >= 0), so leaving the counter strippable would let a buff-strip quietly
	# knock Gather back to 5 damage with the reactive still running.
	mark.cleansable = false
	return mark

## The punish's current damage. Single source of truth for gather_trigger and for both tooltips, so
## a displayed number can never drift from the one that actually lands.
func trigger_damage(yoruichi) -> int:
	var stacks: int = clampi(gather_stacks(yoruichi), 1, max_stacks)
	var dmg: int = per_stack * stacks
	if black_cat_active(yoruichi):
		dmg += black_cat_bonus
	return dmg


## Tooltip for the per-enemy brand. Reads live, so a stack-up or Black Cat coming online is
## reflected on every enemy immediately.
func watcher_desc(eff):
	var yoruichi = eff.user
	var text := "The first skill this character uses each turn deals " + str(trigger_damage(yoruichi)) + " Piercing damage to them and Paralyzes their cooldowns for 1 turn."
	if black_cat_active(yoruichi):
		text += " It also Shatters them for 1 turn."
	return text


func _has_watcher(foe) -> bool:
	# Scan by TYPE and compare the source OBJECT: matching on name would also catch the live
	# Paralyze/Shatter riders, which are sourced here too and so share this ability's name.
	for eff in foe.effects.get_effects_by_type(EffectType.Type.ACTION_USE_TRIGGER):
		if eff.source == self:
			return true
	return false

# Idempotent: brands every enemy who does not already carry a watcher, and is safe to call on
# every cast. It has to run repeatedly, because can_apply_hostile_effect ALWAYS includes an
# is_alive term — the bypassing flag only waives the invulnerability check — so an enemy who is
# dead or banished at one cast silently receives nothing. Planting once would leave them exempt
# from the punish until the next full re-install (a real line: Semiramis banishes herself before
# turn 1, which is exactly when Gather is the natural opener).
func _plant_watchers(context, user):
	for foe in context['enemy_team'].characters:
		if _has_watcher(foe):
			continue
		var watcher = Effect.trigger_effect(Trigger.always(gather_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1,
			watcher_desc)
		watcher.set_source(self)
		# system so the brand survives clear_non_system_effects, which strips a dead holder every
		# turn — otherwise a revived enemy would come back permanently immune to the punish.
		watcher.system = true
		# ...but system also strips an effect from the wire, and this one is the whole point of the
		# skill from the defender's side: it changes what acting costs them. display_system keeps the
		# cleanse-survival and puts it back on both players' screens (Effect.display_system).
		watcher.display_system = true
		# -1 rather than 0: mag is the "last turn this fired" stamp, and turn numbering starts at 0.
		watcher.mag = -1
		# 5th arg bypassing: an enemy who happens to be Invulnerable when she flares must not get
		# to dodge the install.
		Character.add_hostile_effect(context, user, foe, watcher, true)

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var marker = user.has_effect(ability_name, EffectType.Type.MARK, user)
	if marker != null:
		# Already installed — this is a "use while active" stack-up.
		if marker.stack_count() < max_stacks:
			apply_allied(context, user, _new_stack(1))
		_plant_watchers(context, user)   # ...and repair anyone who was absent at an earlier cast
		return

	# First cast counts as stack 1.
	apply_allied(context, user, _new_stack(1))
	_plant_watchers(context, user)

func gather_trigger(context):
	var eff = context['effect']
	var yoruichi = eff.user
	var enemy = context['owner']      # from_trigger_source: the character who just acted
	if yoruichi == null or not is_instance_valid(yoruichi) or yoruichi.dead or yoruichi.banished:
		return
	if enemy == null or not is_instance_valid(enemy) or enemy.dead or enemy.banished:
		return
	if yoruichi.battle == null or not is_instance_valid(yoruichi.battle):
		return
	# Fail closed. Nothing in the kit uninstalls the reactive any more, but a counter-less watcher is
	# still reachable (Yoruichi's death cleanse strips everything she cast, and a revive could leave a
	# brand behind), and it would otherwise keep hitting for a phantom 5. Retire the orphan.
	var marker = yoruichi.has_effect(ability_name, EffectType.Type.MARK, yoruichi)
	if marker == null:
		enemy.effects.erase_effect(eff)
		return
	# One fire per enemy per turn, stamped by turn number rather than the engine's `triggered`
	# latch. The engine clears that latch in tick_all_effects_durations, which battle_manager
	# SKIPS entirely for a banished character — so a latched watcher on someone who gets banished
	# comes back still set, and the dispatch drops the payload before it can ever unset itself,
	# handing that enemy one free skill. A turn stamp cannot go stale.
	var turn: int = yoruichi.battle.current_turn_number
	if int(eff.mag) == turn:
		return
	eff.mag = turn

	# The trigger context is oriented on the ACTING ENEMY, so its ally_team/enemy_team are inverted
	# from Yoruichi's point of view. Build a fresh one rather than reusing it.
	var qc = QueryContext.from_game_state(yoruichi, yoruichi.battle)
	var empowered := black_cat_active(yoruichi)
	var dmg: int = trigger_damage(yoruichi)
	# resolve_effect_damage, not resolve_damage: the latter reads context['owner'].used_ability, and
	# owner here is the enemy — the hit would be scaled by and credited to THEIR skill.
	Character.resolve_effect_damage(qc, eff, enemy, dmg, DamageType.Type.PIERCING)
	if enemy.dead or enemy.banished:
		return
	var para = Effect.paralyze_effect(2)
	para.set_source(self)
	# The client clusters a character's effects by (name, unique_render_id), and everything this
	# ability applies carries the name "Shunko: Gather" — so without a distinct id the Paralyze and
	# the Shatter would merge into the same panel as the permanent watcher that fired them, and the
	# enemy would get no visible signal that it had gone off at all. FIRED_RENDER_ID splits the
	# consequences off into their own cluster while leaving the standing brand where it was.
	para.unique_render_id = FIRED_RENDER_ID
	Character.add_hostile_effect(qc, yoruichi, enemy, para)
	if empowered:
		var shatter = Effect.def_negate(2)
		shatter.set_source(self)
		shatter.unique_render_id = FIRED_RENDER_ID
		Character.add_hostile_effect(qc, yoruichi, enemy, shatter)

# Nothing left to gain once the battery is full — unless some living enemy is still unbranded, in
# which case re-casting is the only way to repair them.
func extra_usable(user):
	if gather_stacks(user) < max_stacks:
		return true
	if user.battle == null or not is_instance_valid(user.battle):
		return false
	for foe in user.battle.get_team_factions_from_character(user)[1].characters:
		if not (foe.dead or foe.banished) and not _has_watcher(foe):
			return true
	return false

func custom_behavior(context):
	var variations = []
	var stacks := gather_stacks(context['owner'])
	if stacks >= max_stacks:
		variations.append([0, [user, "PASS", []]])
		return variations
	# Getting it installed at all is worth far more than any marginal stack.
	var score: int = 90 if stacks == 0 else 60 - stacks * 5
	variations.append([score, [user, self, [user]]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
