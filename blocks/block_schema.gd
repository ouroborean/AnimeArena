extends RefCounted
class_name BlockSchema

# ============================================================================
# The BLOCK PALETTE — the single source of truth for what an authored ability
# may do. Everything here is DATA: a block tree is JSON, never generated code.
# That is a hard requirement, not a style choice — players author these, so a
# code-generating editor would be remote code execution the moment one saves.
#
# The palette is deliberately shaped by measurement of the existing 997-ability
# corpus (see .claude/plans/ notes): 7 Character verbs cover 2,361 call sites,
# and 10 primitives cover 50% of all call sites, 36 cover 80%. So a small, well
# chosen palette expresses most of what real characters actually do.
#
# Vocabulary:
#   ACTION ops  — what a block DOES (damage / heal / apply an effect / branch)
#   EFFECT kinds— what an "apply" op attaches, mapping 1:1 onto Effect factories
#   SELECTORS   — who a block acts on, resolved against the live targeter
#   CONDITIONS  — the `when` guard on any block
#
# Adding to the palette = adding an entry here + a case in BlockRunner. Nothing
# else in the engine changes, and no authored content can reach beyond it.
# ============================================================================

# --- selectors: who does a block act on -------------------------------------
# Resolved by BlockRunner._resolve_targets against the ability's live targeter.
const SELECTORS := {
	"target":        "the skill's target(s)",
	"user":          "the character using the skill",
	"all_enemies":   "every living enemy",
	"all_allies":    "every living ally (including the user)",
	"other_allies":  "every living ally except the user",
	"random_enemy":  "one random living enemy (seeded)",
	"random_ally":   "one random living ally (seeded)",
}

# --- CONDITION-FILTERED selectors -------------------------------------------
# SEMANTICS: each of these resolves to EVERY LIVING CHARACTER in its pool FOR WHOM THE
# ACCOMPANYING CONDITION HOLDS, evaluated ONCE PER CANDIDATE with that candidate as the
# condition's subject.
#
# That is three different things away from what already exists, which is why they are their
# own selectors rather than a flag on the old ones:
#   * the block-level `when` guard gates the WHOLE BLOCK — one evaluation, all-or-nothing.
#     These filter WHICH TARGETS ARE HIT, so one block can damage the two hurt enemies and
#     leave the healthy one alone.
#   * random_enemy / random_ally already cover "pick one"; these pick ALL THAT MATCH.
#   * all_enemies / all_allies hit the pool unconditionally.
#
# The condition is therefore MANDATORY here — the validator rejects one of these selectors
# with no `when`, which is the opposite of every other selector, where `when` is optional.
# Without it the selector is either a typo for all_enemies or a no-op, and both are worse
# than an error. `chance` is per candidate too, which is how "50% chance to hit each enemy"
# becomes authorable.
#
# They are deliberately NOT in SELECTORS: a condition's own `on`/`of`/`vs` picks a selector,
# and a filtered selector there would need a condition of its own to resolve — an infinite
# regress. The validator keeps them out of those slots.
const FILTERED_SELECTORS := {
	"any_enemy":     "every living enemy the condition holds for",
	"any_ally":      "every living ally (including the user) the condition holds for",
	"any_character": "every living character on either team the condition holds for",
}

# --- PAYLOAD selectors: addressing the event a trigger/counter just watched --------
# Legal ONLY inside a `then` payload, which is why they are a third list rather than two more
# rows in SELECTORS: outside a payload there is no event to address and they resolve to nobody.
#
# THE PROBLEM THEY SOLVE. A payload runs with the effect's APPLIER as the acting user
# (BlockRunner._build_trigger reads context.effect.user), so `user` means "whoever cast the skill
# that planted this effect" and `target` means "whoever tripped the hook". Neither of those is
# the character CARRYING the effect, so a trigger planted on an ENEMY could not aim at that enemy
# at all — "when this enemy takes damage, weaken THEM" fired backwards onto the caster.
#
# TWO selectors, not one, because the bearer and the patient are DIFFERENT characters on two
# hooks and the same character on the other thirteen:
#   * `holder`   := context.effect.target. Correct on ALL 15 hooks without exception, because
#     Character.apply_effect calls effect.set_target(target) unconditionally
#     (scripts/character_component.gd:178) — there is no hook where the bearer is unset.
#   * `affected` := context.target, the event's PATIENT. It is the VICTIM on on_damage_dealt
#     (check_damage_dealt_triggers passes the target, :1384-1392) and the healed character on the
#     healing-given hook (:1098, :1437) — on every other hook the dispatcher passes the bearer,
#     so the two agree. A single binding would have been wrong on exactly those two, in opposite
#     directions, which is why collapsing them was never an option.
#
# Both resolve to AT MOST ONE character and to NOBODY when that character is dead, banished or
# freed. They deliberately do NOT fall back to the caster: a silent fallback turns "damage the
# holder" into "damage myself" the moment the holder dies mid-payload, which is a self-kill an
# author never wrote.
const PAYLOAD_SELECTORS := {
	"holder":   "the character carrying this effect",
	"affected": "the character it happened to",
}

# Either kind of selector — what a block's `to` accepts ANYWHERE. The payload selectors are
# deliberately absent: their legality depends on WHERE the block sits, so the validator asks
# is_payload_selector separately with the in-payload flag in hand.
static func is_selector(name) -> bool:
	var k := str(name)
	return SELECTORS.has(k) or FILTERED_SELECTORS.has(k)

static func is_payload_selector(name) -> bool:
	return PAYLOAD_SELECTORS.has(str(name))

# --- POOL selectors: the ones that can answer with MORE THAN ONE character -------------------
# Everything else in the palette resolves to at most one: `user`, `random_enemy`, `random_ally`
# and both payload selectors are singular by construction, and `target` is singular for every
# single-target `target` mode (it is a pool only under all_enemies / all_allies / everyone, which
# the validator asks about separately because it is a property of the ABILITY, not of the name).
#
# The distinction exists for exactly one op today — `banish`, where hitting a whole team at once
# is not "a strong skill" but an INSTANT WIN: check_win_condition counts `banished` as eliminated
# and check_match_over runs after every executed step mid-turn, so the match ends before the
# banish can expire. See BlockSchema.OPS' banish row.
const POOL_SELECTORS := ["all_enemies", "all_allies", "other_allies"]

static func is_pool_selector(name) -> bool:
	var k := str(name)
	return k in POOL_SELECTORS or FILTERED_SELECTORS.has(k)

# ============================================================================================
# PHASE F — THE SELECTOR SYSTEM. ONE predicate language, TWO mount points.
#
#   LAYER 1 — the ability-level ELIGIBILITY object at `target`, replacing the flat six-valued mode
#             string. It decides WHO A SKILL MAY BE USED ON (stage 1: `target()` FLAGS characters;
#             the flags feed the whole interception pipeline). String-or-object: a bare string is
#             the six legacy modes (sugar); an object is {mode, shape, only, pick, measure,
#             bypass_invuln, bypass_when, exclude_self, include_dead}.
#   LAYER 2 — the block-level SELECTOR object at a block's `to`, generalising the ten string
#             selectors (which stay as sugar). It resolves WHO A BLOCK ACTS ON (stage 4, at
#             execute()): {pool, where, pick, order, bypassing, measure, count}.
#
# The two layers share one vocabulary: `only` (layer 1) and `where` (layer 2) are the SAME condition
# list evaluated with the same per-candidate subject binding (_check_condition already takes one),
# and `bypass_invuln` (layer 1) / `bypassing` (layer 2) are the SAME opt-out — the engine's own word
# for "ignore the target's invulnerability", already shipped as A2's per-block field.
# ============================================================================================

# Layer 1 `mode` — the SIDE only. Split OUT of the six flat modes: the old strings folded the side
# and the fan-out into one word, so "pick any ONE character on EITHER board" (everyone + one) was
# unreachable. `shape` carries the fan-out now.
const TARGET_OBJECT_MODES := ["enemy", "ally", "self", "everyone"]
# Layer 1 `shape` — the FAN-OUT. `one` is SINGLE (the player clicks one flagged character); `all`
# fans the click out to the whole flagged faction (ALL_FACTION for one side, ALL for everyone). It
# multiplies output at targeting time, so WIDENING it (one -> all) on a hostile side is guarded;
# narrowing (all -> one) and ally-side changes are free.
const TARGET_SHAPES := ["one", "all"]

# PICK — how a resolved candidate list is narrowed to who is actually hit. SHARED by both layers:
# layer 1 restricts ELIGIBILITY to the winners (hisoka6 flags only the weakest enemy); layer 2
# selects from the resolved pool.
#   all     — every candidate.
#   random  — Fisher-Yates over battle.roll, WITHOUT replacement, `count` of them (layer 2 only:
#             a random ELIGIBILITY set cannot be shown to the player consistently, the same re-run
#             hazard `chance` has, so layer 1 rejects it).
#   lowest  — the candidate(s) with the smallest `measure`, TIES INCLUDED (the shipped hisoka6
#             shape, abilities/hisoka6.gd:64-68 flags every enemy at the minimum HP).
#   highest — the largest `measure`, ties included.
const PICKS := ["all", "random", "lowest", "highest"]
# `measure` — the PER-CHARACTER scalar lowest/highest rank on. It reuses the compare/reading
# vocabulary but is evaluated PER-CANDIDATE (BlockRunner._char_value), NEVER folded like
# _resolve_reading, which SUMS across a selection — a fold would compare sums, not members, and
# silently pick the wrong target.
const MEASURES := ["hp", "hp_percent", "missing_hp"]

# ORDER — the list order resolved targets are handed to the targeter in. Observable, not cosmetic:
# targets are damaged IN LIST ORDER, and a mid-list death fires on-death triggers and spends seeded
# RNG before later entries. `clicked_first` leads with the primary (main_target) — the ONLY order
# that agrees with TargeterComponent.add_target making the first entry the main target; `pool` is
# roster/concatenation order.
const ORDERS := ["clicked_first", "pool"]

# Layer 2 POOLS — the base population a `to` selector object draws from, BEFORE where/pick/order. A
# NEW vocabulary distinct from the string SELECTORS (which stay as sugar), naming the populations the
# shipped roster actually varies its targets over.
const POOLS := {
	"target":        "the skill's target(s)",
	"main_target":   "the primary (clicked) target",
	"other_targets": "the target(s) other than the primary",
	"user":          "the character using the skill",
	"allies":        "every living ally (including the user)",
	"other_allies":  "every living ally except the user",
	"enemies":       "every living enemy",
	"everyone":      "every living character on either team",
	"dead_allies":   "every dead (revivable) ally",
}
# A2, MANDATORY for layer 2. Which pools must re-run the engine's own can_hostile_target /
# can_allied_target. target/main_target/other_targets came from user.targeter.targets (already
# vetted by the targeting system); `user` is self; `dead_allies` is the revive pool and would be
# emptied by can_allied_target's is_alive clause. Every other pool is a roster pool BlockRunner
# builds ITSELF, so it must be re-validated or an authored `enemies` reaches an invulnerable
# defender no hand-written kit can — exactly the split A2 exists to remove. `bypassing` is the one
# opt-out, the same word as everywhere else.
const POOL_GATED := ["allies", "other_allies", "enemies", "everyone"]
# Pools that always resolve to AT MOST ONE character — the only shapes `banish` may aim at (a banish
# that could resolve to a whole team is an instant win; see the POOL_SELECTORS note and OPS' banish
# row). Everything else needs pick:random count 1 to be banish-legal.
const POOL_SINGLE := ["main_target", "user"]

# A `target` field or a block `to` is a Layer-1/2 OBJECT when it is a Dictionary. The two live in
# different slots (mode at `target`, pool at `to`), so the key disambiguates which validator runs.
static func is_target_object(v) -> bool:
	return v is Dictionary
static func is_selector_object(v) -> bool:
	return v is Dictionary

# The base pool name behind a block `to` (string OR selector object), for the static validator
# passes (banish aim / recurring placement / passive targets) that only need the population name.
static func to_pool_name(to) -> String:
	if to is Dictionary:
		return str((to as Dictionary).get("pool", "target"))
	return str(to)

# --- conditions: the optional `when` guard on any block ----------------------
# Each is {"cond": <key>, ...args}. Evaluated by BlockRunner._check_condition.
#
# `effect` and `by` are the PRESENCE PAIR and they ship together (see PRESENCE_BY). Both are
# optional: omitting them keeps the historical reading — any effect of any type, from anybody,
# carrying that name — so no saved character changes meaning. `effect` narrows the match to one
# EffectType and `by` narrows it to the acting user's own copy, which together are the three-argument
# has_effect(name, type, user) every shipped kit calls.
const CONDITIONS := {
	"has_effect":     {"args": ["name", "effect", "by", "on"], "desc": "a named effect is present"},
	"not_has_effect": {"args": ["name", "effect", "by", "on"], "desc": "a named effect is absent"},
	"hp_below":       {"args": ["value", "on"], "desc": "HP is below a value"},
	"hp_above":       {"args": ["value", "on"], "desc": "HP is above a value"},
	# `effect` here DEFAULTS to MARK rather than to "any type". That is not the same reading the
	# other two presence conditions take, and it is deliberate: the type was HARDCODED to MARK
	# before the field existed, so defaulting to "any" would silently change what every saved
	# `stacks_at_least` matches. Naming a type widens it to the shipped idiom
	# (`has_effect(name, COST_MOD, user).stack_count()`), which marks alone could not express.
	"stacks_at_least":{"args": ["name", "effect", "by", "value", "on"], "desc": "a stack count is met"},
	"chance":         {"args": ["percent"], "desc": "a seeded random roll"},
	# RELATIONAL. Everything above asks about ONE character in isolation; `compare`
	# is the only way to phrase "the enemy team is even", "the target is healthier
	# than the user", "only one of them is left" — the shape 49 of the 174 shipped
	# characters need at least once.
	"compare":        {"args": ["of", "value", "op", "than", "vs"], "desc": "compares HP or head-count"},
	# The team-energy guard, the natural companion to `drain_energy`: "the enemy has energy worth
	# draining", or "I have the reserve this skill needs". Energy is a TEAM pool, so `of` names any
	# member and the pool is read once (the same single-read-per-team the `energy` reading does). It is
	# a first-class condition rather than only a compare+reading because a drain wants to gate its OWN
	# USABILITY on it (`requires`), and reading it as `ability.cost()` is a DIFFERENT question that
	# `cost_color_at_least` answers. `of` defaults to `all_enemies`, the drain case.
	"energy_at_least":{"args": ["value", "of"], "desc": "a team's energy pool is at least a value"},
	# THE COST-RANDOM CONDITIONAL, generalised. Reads THIS skill's OWN resolved cost — Ability.cost()
	# (ability_component.gd:284), which already folds in every COST_MOD / COST_CHANGE / COLOR_CHANGE on
	# the caster — and asks whether the `colour` component is at least `value`. The shipped idiom is
	# "if this skill costs >= 1 Random energy" (cost()[RANDOM] >= 1), true only when an enemy has taxed
	# the caster with a +Random COST_MOD: an anti-cost-increase read, the natural companion to a
	# self-cleanse of that tax. It reads the ABILITY's cost, never a team pool, which is the different
	# question `energy_at_least` answers — so it is its own row rather than a mode of that one. A
	# self-applied COST_MOD (the `cost_change` kind) is the free rider that makes it fire.
	"cost_color_at_least":{"args": ["colour", "value"], "desc": "this skill's own cost in a colour is at least a value"},
}

# `compare`.value — what number is read off a character. `alive_count` USED to live here;
# it MOVED into READINGS below (one way to say "how many"), but compare still accepts it as a
# bare string for backward compatibility — see is_reading_name / the validator's compare arm.
const COMPARE_VALUES := ["hp", "hp_percent"]

# --- READINGS: a live number read off the board ------------------------------------------------
# The closed `read` enum of a reading node {read, of, name, effect}. A reading resolves to ONE
# integer (BlockRunner._resolve_reading) and mounts in THREE slots, all of which take the same
# node so an author learns one shape: a scaling `amount`'s `each` (base + per*count, Phase E), a
# `compare`.value (the relational condition reads a number off the board rather than off one HP
# bar), and `repeat`.times (a scaling repetition count — Phase B's constant form takes a reading
# for free).
#
# WHY A CLOSED ENUM AND NOT AN EXPRESSION LANGUAGE. Player-authored, so "read this, multiply, add"
# has to be DATA the validator can exhaust — `base + per*count` with a mandatory cap, never an
# evaluable string. Every member below is a number the engine already computes for its own reasons;
# the reading just names it.
#   * stacks       — SUM of stack_count() over the named effect(s) on the selection (mars1, ganta1,
#                    tamaki1: "+5 per stack"). A mark carrying one stack each counts the marked.
#   * effect_count — how many matching effects are present (semiramis3: per Shield/Invuln/HoT). This
#                    one applies the display_system VISIBILITY FILTER — counting a both-players-hidden
#                    effect would leak hidden state as a magnitude and trip the drift validator.
#   * alive_count  — living members of the selection (tanjiro5/saitama7 read the DEAD count off the
#                    complementary selector). The single-number-per-selection reading compare used to
#                    special-case; it is the same number here.
#   * dead_count   — the FALLEN members of the team named by `of` (saitama7's "+25 per dead ally").
#                    The complement of alive_count, and the ONE reading that cannot be expressed by
#                    reading the live selection: every other read folds _resolve_targets, which DROPS
#                    the dead — the very population this counts. So it builds the roster straight (valid
#                    + dead + not banished, mirroring the dead_allies pool) and `of` is restricted to a
#                    whole-TEAM pool (all_allies/other_allies/all_enemies): a dead-count over a single
#                    target or payload selector could only ever answer 0 or 1 — a per-hook lie.
#   * hp           — SUM of current HP over the selection.
#   * missing_hp   — SUM of (max_hp - hp), floored at 0 per member (nezuko2's "per damage taken").
#   * energy       — the selection's TEAM energy pool total. Energy is a team resource, so this reads
#                    the FIRST resolved member's team once rather than summing one pool per head.
#   * duration     — SUM of remaining engine duration over the matching effect(s).
#   * event        — the MAGNITUDE of the event a trigger/counter/recurring payload is reacting to:
#                    the damage received (on_damage_received), damage dealt (on_damage_dealt) or
#                    healing given (on_healing_given), read off QueryContext.value (set by
#                    from_trigger_source). PAYLOAD-ONLY — there is no event outside a reactive `then`,
#                    so the validator rejects it anywhere else (see BlockValidator._validate_reading's
#                    in_payload gate). This is what makes "reflect/counter for the amount" authorable.
#                    Ignores `of`/`name`/`effect` (it reads a scalar off the firing event, not the board).
const READINGS := ["stacks", "effect_count", "alive_count", "dead_count", "hp", "missing_hp", "energy", "duration", "event"]

# The reads that enumerate EFFECTS (and therefore honour `name`/`effect` and the visibility filter).
# The rest read a character/team scalar and ignore those fields.
const EFFECT_READS := ["stacks", "effect_count", "duration"]

static func is_reading(v) -> bool:
	return v is Dictionary and READINGS.has(str((v as Dictionary).get("read", "")))

# A bare string that names a reading — the shape `compare`.value keeps accepting for alive_count
# so no saved character breaks. Only alive_count was ever legal there as a string, so that is the
# only one widened; the richer reads need the object form (they carry `name`/`of`).
static func is_reading_name(v) -> bool:
	return v is String and str(v) == "alive_count"
# GROUP predicates fold the whole resolved list to one bool; the rest are pairwise
# against `than` (a constant) or the first character of `vs`.
const COMPARE_GROUP_OPS := ["all_equal", "any_differ"]
const COMPARE_PAIR_OPS := ["gt", "lt", "eq"]

# --- effect kinds: what `apply` attaches ------------------------------------
# `factory` names the Effect static; `fields` are the FACTORY-SPECIFIC authored fields —
# the ones that drive the factory call itself. `turns` is authored in PLAYER turns and
# converted to engine duration by BlockRunner (the engine ticks every side's turn, so
# "1 turn" == duration 2 — the single most common authoring bug in this codebase).
# EVERY kind additionally accepts `ticks` (a raw engine duration, see spec_duration) and
# the whole UNIVERSAL_EFFECT_FIELDS set below, which is why neither is listed per-kind.
#
# `hostile` is the third column and it is LOAD-BEARING, not documentation: it decides whether
# BlockRunner routes the application through Character.add_hostile_effect (is_ignoring_skill,
# shrug_off_type, can_apply_hostile_effect — the gating an attack must pass) or through
# add_allied_effect. It lives here rather than in a literal list inside the runner because a
# kind that forgets to declare it would land on targets no hand-written kit can reach, and a
# list in the runner is exactly the copy that drifts when a kind is added.
# HOSTILE_BY_SIGN is the third answer, for the kinds whose SIGN decides the side of the
# fence: +1 Random to cast is a tax, -1 is a discount.
const HOSTILE_BY_SIGN := "signed"
# ...but WHICH sign is the attack is not universal. A cost/cooldown TAX is POSITIVE (raise the
# target's cost/cooldown), so positive = hostile. A `damage_boost`'s attack is the opposite: a
# WEAKEN is a NEGATIVE amount cutting the target's damage, so its hostile side is amount < 0.
# These kinds are HOSTILE_BY_SIGN but with the polarity flipped; _is_hostile_effect reads this so a
# negative weaken routes HOSTILE (past invuln / shrug-off / skill-ignore) instead of silently allied.
const SIGN_HOSTILE_WHEN_NEGATIVE := ["damage_boost"]
# The FOURTH answer, for `counter`, whose side decides the fence. A counter watching skills used
# ON the bearer is a shield you hand somebody; a counter watching skills the bearer USES is a
# muzzle you fit them with, and the muzzle has to pass the same gating an attack does
# (is_ignoring_skill, shrug_off_type, can_apply_hostile_effect) or an outgoing counter lands on an
# invulnerable enemy — something no hand-written kit can do. It is a column value rather than a
# literal check inside the runner for the reason A4 made hostility data at all.
const HOSTILE_BY_COUNTER_SIDE := "counter_side"

# --- `reserves`: THE FIFTH COLUMN, and the one that stops the palette lying ------------------
# WHICH UNIVERSAL FIELDS THIS KIND'S FACTORY ALREADY OWNS, and therefore which ones an author
# may not set. `{universal field -> the AUTHORED field the factory writes it from}`.
#
# THE DEFECT IT CLOSES. UNIVERSAL_EFFECT_FIELDS is applied to the built Effect AFTER the factory
# returns (BlockRunner._apply_universal_fields), so where a factory has already written one of
# those registers from one of its OWN arguments, the universal pass silently writes over it. Three
# measured examples, all of which validated clean and shipped:
#   * reflect  — Effect.reflect_effect stores the DESTINATION CHARACTER in `mag`
#     (scripts/effect_component.gd:312). A universal `mag: 0` replaced a live Character with an int,
#     and when the reflect fired, Ability.reflect_trigger appended that raw int into the attacker's
#     targeter: "Invalid call. Nonexistent function 'check_ability_receive_triggers' in base 'int'",
#     mid-turn, in a live match. `mag: -1` was worse because it did NOT error — it silently turned an
#     authored guardian reflect into a bounce.
#   * effect_immunity — `mag` is the EffectType being ignored (:637), so "immune to STUN" plus
#     `mag: 0` delivered immunity to EffectType 0 while the card still promised stun immunity.
#   * swap — `mag` is a Vector2(into, slot) which MovesetComponent reads as `swap.mag[0]`; an int
#     there breaks the form change the same way.
# ...plus two this table found that nobody had reported: `mark`.show_stacks and `display_stacks` are
# the SAME register, and `damage_over_time`.delayed writes `last_turn_only`.
#
# WHY A COLUMN AND NOT THREE SPECIAL CASES. Stage 3 solved exactly this for exactly one field —
# `reflect` + universal `stacks`, rejected in BlockValidator._validate_reflect with the reasoning
# "they are the same number to the engine, so setting both makes one of them silently wrong". That
# reasoning is right and it is not specific to `stacks` or to `reflect`. Phase C adds ~20 kinds
# through this same door, and a rule that lives in one kind's validate function is a rule the
# twenty-first kind will not have. Declaring the reserved registers in the same literal that
# declares the factory is what makes it impossible to add a kind and forget them.
#
# IS `mag` EVER LEGITIMATELY AUTHOR-SETTABLE? YES, and that is why this is a per-kind table rather
# than a blanket ban. The precise rule is: a universal field is reserved on a kind when the factory
# writes it FROM ANOTHER AUTHORED FIELD OF THAT KIND — i.e. when the author would have two controls
# for one register. On the ten kinds whose factory never touches `mag` at all (mark, stun,
# invulnerable, ignore_damage, silence, destructible_break, trigger, counter, paralyze, taunt) an
# authored `mag` is the only writer, and on `mark` it is a genuinely useful shape: a mark carrying a
# `mag` with `display_mag` on is the corpus's own tracker idiom (`tracker.mag += 1`,
# abilities/uzui5.gd:27; `passive.change_mag(1)`, character/madoka.gd:31), and it is exactly what the
# `adjust` op's `mag` axis was written against. Banning `mag` everywhere would delete a working
# authoring pattern to fix a collision that only exists where a second control already writes it.
#
# A DEFAULT IS NOT A RESERVATION. Several factories set a universal field with no competing authored
# field — stun_effect's `remove_on_death = false`, trigger_effect's `cleansable = dur >= 0`,
# shield_effect's `stackable`/`stack_mag`/`display_mag`, ability_swap/color_change's
# `cleansable = false`, and every factory's Callable `description`. Those stay overridable, because
# overriding a factory default is the entire purpose of the universal set ("absent means whatever the
# factory chose") and reserving them would be inventing a restriction the game does not have.
const _NAMED_EFFECT_KINDS := {
	# `stacks`/`max`/`show_stacks` turn a mark into a RESOURCE: something an authored kit
	# accumulates between casts, which is what 81 of the 174 shipped characters do and what
	# the `stacks_at_least` condition was always written for. `max` is the mark's own
	# ceiling, enforced by BlockRunner after add_effect's merge. SPENDING a stack is the
	# `remove` op with a `stacks` count — the general "take this effect away" verb, not a
	# mark-only counter poke like the deleted `stack` op was.
	"mark":              {"factory": "mark",                    "fields": ["turns", "text", "stacks", "max", "show_stacks"], "hostile": false, "reserves": {"display_stacks": "show_stacks"}},
	"damage_over_time":  {"factory": "damage_effect",           "fields": ["amount", "damage_type", "turns", "delayed"], "hostile": true, "reserves": {"mag": "amount", "last_turn_only": "delayed"}},
	"heal_over_time":    {"factory": "healing_effect",          "fields": ["amount", "turns"], "hostile": false, "reserves": {"mag": "amount"}},
	"shield":            {"factory": "shield_effect",           "fields": ["amount", "turns"], "hostile": false, "reserves": {"mag": "amount"}},
	"stun":              {"factory": "stun_effect",             "fields": ["turns", "classes", "exclude_classes"], "hostile": true, "reserves": {}},
	"invulnerable":      {"factory": "invuln_effect",           "fields": ["turns", "classes"], "hostile": false, "reserves": {}},
	"ignore_damage":     {"factory": "ignore_damage_effect",    "fields": ["turns"], "hostile": false, "reserves": {}},
	"damage_reduction":  {"factory": "damage_reduction_effect", "fields": ["amount", "turns"], "hostile": false, "reserves": {"mag": "amount"}},
	# FILTERABLE, but — unlike damage_boost below — NOT signed. A vulnerability is ALWAYS hostile (more
	# damage taken) and its `amount` is ALWAYS positive: there is no side-of-the-fence axis, so `amount`
	# stays unsigned (the shared _validate_amount / _amount pass) and `hostile` stays a plain true. The
	# ONLY new axis is the DAMAGE-TYPE filter, the SAME one get_true_damage already honours on a
	# VULNERABILITY effect's class_targets / exclusion_targets (ability_component.gd:800-811, byte-for-
	# byte the DAMAGE_MOD arm at :737-751): include_types = the mod only touches a hit whose damage_type
	# is IN it, exclude_types = it SKIPS a hit whose type is in it. nonon1 "Flute Missile" needs "+5 to
	# all NON-Affliction damage", so exclude_types is the mandatory axis (["AFFLICTION"]); include_types
	# is its complement. BOTH map to a DAMAGE-TYPE list, never an ability class. ABSENT filters = today's
	# byte-for-byte behaviour (unfiltered vulnerability) — a pure additive change reusing the damage_boost
	# machinery whole (_damage_type_list, _validate_damage_type_list, _damage_type_phrase, the
	# creatorDamageTypeList editor multi-select). The ability-NAME filter (the factory's 3rd arg) is NOT
	# exposed here, exactly as `skills` is exposed on damage_boost but deliberately withheld from this kind.
	"vulnerability":     {"factory": "vulnerability_effect",    "fields": ["amount", "turns", "include_types", "exclude_types"], "hostile": true, "reserves": {"mag": "amount"}},
	# SIGNED and FILTERABLE. `amount` is a SIGNED magnitude read straight into the effect's `mag`:
	# a POSITIVE amount is the allied damage boost this kind always was, a NEGATIVE amount is a
	# HOSTILE weaken (get_true_damage sums a negative DAMAGE_MOD off the DAMAGER, reducing what it
	# deals — the shipped ladydevimon3 shape, Effect.damage_mod_effect(-10, ...)). So the SIGN
	# decides the side of the fence exactly as it does for cost_change/cooldown_change, and this
	# kind is HOSTILE_BY_SIGN for the same reason: a discount is a gift, a tax is an attack.
	# `include_types`/`exclude_types` are the DAMAGE-TYPE filter get_true_damage already honours
	# (ability_component.gd:737-751): class_targets is an INCLUDE list (the mod only touches a hit
	# whose damage_type is in it) and exclusion_targets is an EXCLUDE list (it skips a hit whose
	# type is in it). LadyDevimon needs "all types EXCEPT Affliction", so exclude_types is the
	# mandatory axis (["AFFLICTION"]); include_types is its complement. BOTH map to a DAMAGE-TYPE
	# list, NOT an ability class — the misnamed `class_targets` register is compared against the
	# hit's damage_type, never a class. The ability-NAME filter stays `skills` (ability_targets, the
	# factory's 3rd arg). type_targets (the factory's 6th arg) is dead — get_true_damage never reads
	# it — so it is deliberately NOT exposed. ABSENT filters + a positive amount = today's byte-for-
	# byte behaviour (unfiltered allied boost); this is a pure additive change.
	"damage_boost":      {"factory": "damage_mod_effect",       "fields": ["amount", "turns", "skills", "include_types", "exclude_types"], "hostile": HOSTILE_BY_SIGN, "reserves": {"mag": "amount"}},
	"silence":           {"factory": "silence_effect",          "fields": ["turns"], "hostile": true, "reserves": {}},
	"destructible_break":{"factory": "def_negate",              "fields": ["turns"], "hostile": true, "reserves": {}},
	# WATCHES an engine hook and runs a nested block list when it fires. Was called
	# "reactive" until the rename; see KIND_ALIASES.
	# Allied by default: the effect that WATCHES is planted on whoever is meant to carry it,
	# and what its payload does is the payload's own business. `counter.on: outgoing` (Phase B)
	# is the one shape that will flip this column, which is why it is a column.
	# `scope` is the EVENT-CLASS filter (see SCOPED_TRIGGERS): the hook still fires, but the
	# payload only runs when the skill that fired it carries one of the named classes.
	"trigger":           {"factory": "__trigger__",             "fields": ["trigger", "scope", "turns", "text", "then"], "hostile": false, "reserves": {}},
	# TICKING as a KIND. Builds a TICKING_TRIGGER whose payload is a nested `then` block list, run
	# once every AUTHOR'S turn — the sibling of `trigger`/`counter`, with no new engine work because
	# TICKING_TRIGGER already has a dispatcher, a wire encoding, a client tile and a player-reorderable
	# execution slot (get_ticking_effect_information / execute_ticking_effect). This spelling exists as
	# a KIND rather than a TRIGGERS row because ticking carries five properties a hook-row cannot:
	# the tick cadence, `first` (fold the manual-first-instance idiom), `stops_when_stunned`, the
	# nested payload, and side-scoping — all of which live on the effect, not on a hook name.
	#   * `first`: RECURRING_FIRSTS — `now` fires the payload once at cast and plants 2K-1 ticks;
	#     `next` plants 2K and the first lands on the author's next turn. See recurring_duration.
	#   * `stops_when_stunned`: writes the ability-level `Action` class (whose single reader is
	#     "new multiplayer/battle_manager.gd":1225). It is the effect's own field rather than a class
	#     chip so the halved-uptime-under-stun cost has prose and a validator behind it.
	# Allied by default like `trigger`: the effect that TICKS is planted on whoever carries it, and
	# what its payload does is the payload's own business. A permanent ticker planted on an enemy is a
	# strong effect but NOT engine-restricted (the roster ships them), so its duration is author-controlled
	# like every other effect — there is no hostile-placement cap (removed per the owner ruling).
	# reserves {}: the factory writes no universal register from another authored field (its duration
	# is engine bookkeeping, never in the universal set; `first`/`stops_when_stunned`/`then` are the
	# kind's own fields).
	"recurring":         {"factory": "__recurring__",           "fields": ["turns", "first", "stops_when_stunned", "then"], "hostile": false, "reserves": {}},
	# Transformation. `into`/`slot` index the character's moveset in the SAME order
	# AuthoredCharacter._build_moveset produces (visible actives in author order,
	# then the Passive, then the hidden skills) so what the validator checks is what
	# the runner will index. `into` may name a HIDDEN skill — that is the whole point
	# of hidden skills, and how frieza5 / yoruichi5 / kid6 work on the shipped roster.
	"swap":              {"factory": "ability_swap_effect",     "fields": ["slot", "into", "turns"], "hostile": false, "reserves": {"mag": "slot and into"}},
	# INTERCEPTION, not reaction: a counter cancels the incoming skill outright.
	# `then` is a nested block list exactly like `trigger`.
	# `on` picks WHICH SIDE of the exchange it watches — see COUNTER_SIDES — and it is the one
	# field that flips this kind's hostility column, which is why that column is a value rather
	# than a literal `false`.
	# `scope` is the INCLUSION set (a disjunction — the counter fires on any skill carrying ONE of its
	# classes, [] meaning every hostile skill); `exclude` SUBTRACTS from it — a skill matched by scope
	# but ALSO carrying an excluded class is let through uncountered. Both resolve through the SAME
	# counter_classes() path (a shortcut name or a raw class list) and land in the effect's two free
	# lists (class_targets / exclusion_targets), which Condition.action_countered already reads together
	# (scripts/condition.gd ~:254-263). ABSENT `exclude` => [] => today's behaviour byte-for-byte, so
	# this is a pure additive field: it exists to spell "Harmful EXCEPT Strategic" — the shipped
	# saitama4 counter_effect(...,["Harmful"],["Strategic"]) shape — which scope alone cannot.
	"counter":           {"factory": "counter_effect",          "fields": ["scope", "exclude", "on", "turns", "then"], "hostile": HOSTILE_BY_COUNTER_SIDE, "reserves": {}},
	# BOUNCE a skill back, or catch it for somebody else. The sibling of `counter` — same class-list
	# `scope`, consulted at the same moment in the same order — but where a counter CANCELS the
	# skill outright, a reflect RE-AIMS it and lets it resolve on its new target.
	#
	# `exclude` is the SAME subtraction `counter` carries, for the same reason and through the same
	# resolution path: reflect stores class_targets AND exclusion_targets and Condition.action_countered
	# reads both on the reflect check exactly as on the counter check, so "reflect Harmful except
	# Strategic" is buildable and ABSENT `exclude` is byte-for-byte today.
	#
	# NO `then` PAYLOAD, deliberately: the trigger is the engine's own Ability.reflect_trigger, and
	# that is where both re-aim traps are already solved (a common AoE is TargetType.ALL, not
	# ALL_FACTION, and the bounced pool has to be re-validated against extra_targetable plus
	# bypass-aware invulnerability — abilities/scripts/ability_component.gd:374-433). Rebuilding
	# that as authored blocks would be a second copy of the hardest lines in the targeting system,
	# and it is the copy that would drift.
	"reflect":           {"factory": "reflect_effect",          "fields": ["scope", "exclude", "destination", "charges", "turns"], "hostile": false, "reserves": {"mag": "destination", "stacks": "charges"}},
	# MOVE part of an incoming hit to somebody else — the DAMAGE_REDIRECT the roster's guardians ship
	# (halibel3, minene3, Saturn Crystal). The sibling of `reflect`, but at the DAMAGE layer rather than
	# the whole-skill layer: a reflect re-aims the WHOLE skill before it resolves, a redirect splits the
	# DAMAGE after it lands — `amount`% of every hit the holder takes is dealt to a chosen character
	# instead, and the holder takes the rest.
	#
	# THE DESTINATION IS A PHASE F SELECTOR OBJECT (pool x where x pick), never a live Character — that
	# is the whole reason this was do-not-build until the redirect ruling: Effect.redirect_effect stores
	# a live destination Node (effect_component.gd character_target), which JSON cannot name. The author
	# writes a selector; the engine resolves it AT REDIRECT TIME (Character.check_damage_redirect), via a
	# Callable the runner captures — so "a random living ally" re-picks each hit, and a selector that now
	# resolves to a DEAD or absent character makes the redirect no-op (the hit lands normally) instead of
	# black-holing. See BlockRunner._build_redirect and check_damage_redirect.
	#
	# `amount` is the PERCENTAGE moved (mag = amount/100, the fraction the engine multiplies each hit
	# by), so it RESERVES `mag` exactly as reflect reserves it from `destination` — the factory is the
	# one writer, and a universal `mag` would clobber the fraction. hostile:false — a redirect is a
	# guard planted on whoever it protects, routed through add_allied_effect like every other buff.
	"redirect":          {"factory": "__redirect__",            "fields": ["amount", "destination", "turns"], "hostile": false, "reserves": {"mag": "amount"}},
	# `mode` picks WHICH of the engine's three cost effects this is (see COST_MODES); `from` is the
	# colour a `swap` replaces. Both are inert on the other modes, and the validator says so rather
	# than letting them render and do nothing.
	"cost_change":       {"factory": "cost_mod_effect",         "fields": ["amount", "colour", "mode", "from", "turns", "skills"], "hostile": HOSTILE_BY_SIGN, "reserves": {"mag": "amount (or, in a colour swap, colour)"}},
	"cooldown_change":   {"factory": "cooldown_mod",            "fields": ["amount", "turns", "skills"], "hostile": HOSTILE_BY_SIGN, "reserves": {"mag": "amount"}},
	"paralyze":          {"factory": "paralyze_effect",         "fields": ["turns"], "hostile": true, "reserves": {}},
	"taunt":             {"factory": "taunt_effect",            "fields": ["turns"], "hostile": true, "reserves": {}},
	"effect_immunity":   {"factory": "ignore_effect_effect",    "fields": ["turns", "effect"], "hostile": false, "reserves": {"mag": "effect"}},
	# TRANSFORMATION into an uploaded alternate portrait. A NAMED kind, NOT a SIMPLE_EFFECTS row, because
	# the effect it builds must carry two non-default universal flags the generic __simple__ arm cannot
	# set: system=true (the snapshot filters PORTRAIT_CHANGE off the wire by `system` — a system=false
	# effect would ship a junk visible tile) and cleansable=false (a transform must survive a cleanse).
	# Only portrait_change_effect (effect_component.gd:575) sets both.
	#
	# `index` is the 0-based alt-portrait slot the character transforms to. The factory stores it in the
	# NON-magnitude register `mag` (mag = portrait_num), so this row RESERVES `mag` from `index` exactly
	# as reflect reserves mag from `destination`: the factory is mag's sole writer, and a universal `mag`
	# would clobber the portrait index and point the transform at the wrong (or a nonexistent) form. The
	# index is bounded to AuthoredAssets.alt_portrait_slots().size() by the validator, hostile:false
	# (transforming yourself is a self-buff), and its duration is author-controlled like every effect
	# (-1 = permanent, the usual shape for a transform — no cap).
	"portrait_change":   {"factory": "portrait_change_effect",  "fields": ["index", "turns"], "hostile": false, "reserves": {"mag": "index"}},
}

# ============================================================================================
# PHASE C — THE SIMPLE EFFECT TABLE. One build arm, N data rows.
#
# Every row here is a PURE-DATA effect kind whose engine primitive needs nothing but
# `effect_type`, a duration and (for the magnitude rows) a single scalar. BlockRunner builds all
# of them through ONE generic arm — Effect.from(EffectType.Type[row.type], {}) — never a named
# factory and never a `_build_<kind>` helper. That is only safe because every callable an Effect
# carries (wrapup_func / shield_func / barrier_func / redirect_func / conditional_func,
# effect_component.gd:41-45) defaults to a no-op, and each row below was checked, factory AND
# READER, to confirm its kind never needs a non-default one. `barrier_effect` is the pattern: it
# never sets barrier_func and character_component.gd:881 calls the default successfully.
#
# THE COLUMNS a row carries, and why each is HERE rather than derived at runtime:
#
#   `type`      — the EffectType.Type member (as a String; self_check proves it exists). The build
#                 arm indexes the enum by it.
#   `fields`    — the AUTHORED controls, and the row's whole editor story: every name here already
#                 has a render branch in webclient/app/app.js (amount:5926, turns:5932), so a row
#                 confined to {amount, turns} needs ZERO new widgets. A row wanting a control that
#                 does not render yet is DEFERRED, not shipped invisible (see TARGET_CHANGE below).
#   `hostile`   — A4, as DATA. A hostile row that forgot to say so would route through
#                 add_allied_effect and land on targets no hand-written kit can reach (past
#                 is_ignoring_skill / shrug_off_type / can_apply_hostile_effect). The side of each
#                 row was read off its READER: a debuff you drop on an enemy is hostile, a guard you
#                 give yourself/an ally is not. _op_apply still only takes the hostile path when
#                 user.is_hostile(t), so a self-cast of a hostile-tagged kind still lands allied.
#   `reserves`  — the mag-register guard, exactly as on _NAMED_EFFECT_KINDS. A magnitude row's build
#                 arm writes `mag` FROM the author's `amount`, so `mag` is reserved: an author must
#                 not also set it in the advanced card, or one of the two is silently overwritten.
#                 A pure-flag row's reader never reads `mag`, nothing writes it, so it reserves {}.
#   `mag`       — the NORMALISATION convention (see below). Only "retained" bends the number;
#                 "flat" writes amount straight through.
#   `tip`       — the in-battle tooltip (holder voice), a `.format` template. Written from the
#                 READER's semantics, NEVER the factory string — HEAL_CUT's own factory tip claims
#                 "% less healing" off a register that stores % RETAINED, so trusting it would print
#                 the inverse of what happens.
#   `prose`     — the generated ability-card clause (action voice), a `.format` template consumed by
#                 ScriptedAbility._describe_effect. This is the CONTRACT; describe() is irrelevant.
#   `limits`    — the per-row balance guard, and every one names its abuse case in a comment. These
#                 are the OWNER's numbers to set; a conservative default sits here meanwhile.
#
# THE ONE mag CONVENTION, chosen with the table. Three incompatible ones ship in the engine:
# PERCENT_DR's mag is the percent REMOVED (character_component.gd:1003), HEAL_CUT's the percent
# RETAINED (:1073), and the 0..1 float kinds cannot even pass _amount's clampi. The author sees
# exactly ONE: `amount` is a 0..100 whole number where BIGGER ALWAYS MEANS A STRONGER EFFECT — the
# percent an effect BLOCKS / STRIPS, or the chance it FIRES. The build arm converts:
#   * PERCENT_DR   reader wants % removed  -> mag = amount            ("flat")
#   * DODGE_CHANCE reader wants the chance -> mag = amount            ("flat")
#   * HEAL_CUT     reader wants % RETAINED -> mag = 100 - amount      ("retained")  <- the only bend
# The prose and tip are then written from the reader, so "amount: 40" reads as "40% less healing"
# on the card AND removes 40% of healing in the match, with no third number to reconcile.
const SIMPLE_EFFECTS := {
	# --- percentage / magnitude rows (author sets `amount`, build arm writes `mag`) -------------
	# PERCENT_DR: reader multiplies incoming damage by (100 - mag)/100 (character_component.gd:1003),
	# so mag is the percent REMOVED. Hostile: a reduction you slap on the character taking the hit —
	# but it lives on the DEFENDER, so an author drops it on an ally (allied path) or, less usually,
	# it is the enemy's own; tagged hostile because "take less damage" placed on an ENEMY would be the
	# only reason to gate it, and a self/ally cast still routes allied via user.is_hostile.
	"percent_dr": {
		"type": "PERCENT_DR", "fields": ["amount", "turns"], "hostile": false,
		"reserves": {"mag": "amount"}, "mag": "flat",
		"tip": "This character has {amount}% Damage Reduction.",
		"prose": "Reduces the damage {who} takes by {amount}% {dur}",
		# ABUSE: mag > 100 makes (100-mag)/100 NEGATIVE, so the "reduction" HEALS the attacker's target
		# for a share of the hit. Capped at 100 (= immune) which is the reader's own ceiling.
		"limits": {"amount_max": 100}},
	# HEAL_CUT: reader multiplies healing by mag/100 (character_component.gd:1073) — mag is % RETAINED.
	# Author gives % CUT, build arm inverts. Hostile: a healing debuff you put on an enemy.
	"heal_cut": {
		"type": "HEAL_CUT", "fields": ["amount", "turns"], "hostile": true,
		"reserves": {"mag": "amount"}, "mag": "retained",
		"tip": "This character receives {amount}% less healing.",
		"prose": "Reduces the healing {who} receives by {amount}% {dur}",
		# ABUSE: amount > 100 would push mag (=100-amount) negative, turning a heal into damage. Capped
		# at 100 (= no healing at all), the strongest the reader can express.
		"limits": {"amount_max": 100}},
	# HEALTH_CAP: reader caps effective max HP at mag (character_component.gd:1678). Hostile debuff
	# (Crush Card Virus). mag = the ceiling.
	"health_cap": {
		"type": "HEALTH_CAP", "fields": ["amount", "turns"], "hostile": true,
		"reserves": {"mag": "amount"}, "mag": "flat",
		"tip": "This character's maximum health is capped at {amount}.",
		"prose": "Caps {poss} maximum health at {amount} {dur}",
		"limits": {}},
	# DAMAGE_CAP: reader caps the HOLDER's OUTGOING per-hit damage at mag (character_component.gd:554).
	# Hostile: a muzzle on an enemy's damage. mag = the ceiling.
	"damage_cap": {
		"type": "DAMAGE_CAP", "fields": ["amount", "turns"], "hostile": true,
		"reserves": {"mag": "amount"}, "mag": "flat",
		"tip": "This character cannot deal more than {amount} damage in a single hit.",
		"prose": "Caps the damage {who} deals at {amount} per hit {dur}",
		"limits": {}},
	# DAMAGE_CAP_RECEIVE: reader caps the HOLDER's INCOMING per-hit damage at mag
	# (character_component.gd:561). Defensive buff you give yourself/an ally. mag = the ceiling.
	"damage_cap_receive": {
		"type": "DAMAGE_CAP_RECEIVE", "fields": ["amount", "turns"], "hostile": false,
		"reserves": {"mag": "amount"}, "mag": "flat",
		"tip": "This character cannot receive more than {amount} damage in a single hit.",
		"prose": "Caps the damage {who} takes at {amount} per hit {dur}",
		"limits": {}},
	# DODGE_CHANCE: reader rolls d100 <= greatest mag (character_component.gd:1931). Defensive buff.
	# mag = the percent chance.
	"dodge_chance": {
		"type": "DODGE_CHANCE", "fields": ["amount", "turns"], "hostile": false,
		"reserves": {"mag": "amount"}, "mag": "flat",
		"tip": "This character has a {amount}% chance to fully dodge new harmful skills.",
		"prose": "Gives {who} a {amount}% chance to dodge harmful skills {dur}",
		# ABUSE: a chance above 100 is meaningless (already a guaranteed dodge at 100). Capped at 100.
		"limits": {"amount_max": 100}},
	# HEALING_RECEIVED_MOD: reader adds mag to every heal the holder receives
	# (character_component.gd:1100). Allied buff. mag = the flat bonus.
	"healing_received_mod": {
		"type": "HEALING_RECEIVED_MOD", "fields": ["amount", "turns"], "hostile": false,
		"reserves": {"mag": "amount"}, "mag": "flat",
		"tip": "This character will receive {amount} more healing.",
		"prose": "Increases the healing {who} receives by {amount} {dur}",
		"limits": {}},
	# BARRIER / Nullify: reader absorbs the HOLDER's OUTGOING damage, mag points of it, before it
	# lands (character_component.gd:876-899). It is OFFENSIVE SUPPRESSION, not a shield — the prose
	# says "damage {who} deals", or an author prices it as protection and gets it backwards. Hostile.
	# Generic arm leaves stackable/display_mag at their engine defaults: a single Nullify still
	# absorbs correctly; an author who wants a stacking, pip-shown one sets those in the advanced card.
	"barrier": {
		"type": "BARRIER", "fields": ["amount", "turns"], "hostile": true,
		"reserves": {"mag": "amount"}, "mag": "flat",
		"tip": "This character has {amount} points of Nullify.",
		"prose": "Absorbs the next {amount} damage {who} deals {dur}",
		"limits": {}},
	# DELAY: reader pushes back the HOLDER's own next skills by mag turns (ability_component.gd:617).
	# Hostile tempo debuff. mag = how many turns of delay. Generic arm leaves stackable off, so the
	# delay applies for its whole DURATION rather than being spent per skill — a duration-bounded
	# "your skills come out mag turns late", which is the base shape.
	"delay": {
		"type": "DELAY", "fields": ["amount", "turns"], "hostile": true,
		"reserves": {"mag": "amount"}, "mag": "flat",
		"tip": "This character's skills will be delayed by {amount} turn(s).",
		"prose": "Delays {poss} next skills by {amount} turn(s) {dur}",
		"limits": {}},
	# DELAY_RECEIVE: reader pushes back skills that TARGET the holder by mag turns
	# (ability_component.gd:637). Protective — you place it on an ally to slow attacks aimed at them.
	# mag = turns of delay.
	"delay_receive": {
		"type": "DELAY_RECEIVE", "fields": ["amount", "turns"], "hostile": false,
		"reserves": {"mag": "amount"}, "mag": "flat",
		"tip": "Skills that target this character will be delayed by {amount} turn(s).",
		"prose": "Delays skills that target {who} by {amount} turn(s) {dur}",
		"limits": {}},
	# --- pure-flag rows (no magnitude; reader keys on presence, so `mag` is NOT reserved) --------
	# ISOLATE: reader cuts the holder off from every ally-targeted skill (is_isolated,
	# character_component.gd:1883). INVISIBLE in the damage math, so the prose must SPELL OUT what it
	# removes. Hostile.
	"isolate": {
		"type": "ISOLATE", "fields": ["turns"], "hostile": true, "reserves": {},
		"tip": "This character is Isolated.",
		"prose": "Isolates {who} {dur} — cutting them off from healing, shields, cleanse and every ally-targeted buff",
		# BALANCE NOTE (NOT a cap): a PERMANENT all_enemies isolate deletes healing/shields/cleanse/
		# ally-buffs for the whole match, and none of it shows up in damage numbers — a strong effect an
		# APPROVER weighs, not a restriction the engine enforces (Yubel shipped a permanent ISOLATE). The
		# earlier {max_turns:3, forbid_permanent} was an invented balance cap and is removed per the owner
		# ruling: duration is author-controlled like every other effect.
		"limits": {}},
	# IGNORE_NON_DAMAGE: reader shrugs off every NEGATIVE non-damage effect type except DAMAGE / MARK /
	# the counter notification (shrug_off_type, character_component.gd:1739). Defensive buff. Same
	# invisible-in-damage-math abuse as isolate: a permanent one is immunity to all debuffs forever.
	"ignore_non_damage": {
		"type": "IGNORE_NON_DAMAGE", "fields": ["turns"], "hostile": false, "reserves": {},
		"tip": "This character will ignore negative non-damage effects.",
		"prose": "Makes {who} ignore all negative non-damage effects {dur}",
		# BALANCE NOTE (NOT a cap): a permanent one is a character no stun/silence/isolate/DR-strip/
		# cost-tax can touch. That is an approver's call, not the engine's — the shipped roster ticks
		# permanent IGNORE_NON_DAMAGE (Yubel's passive). The earlier {max_turns:3, forbid_permanent} was
		# an invented balance cap, removed per the owner ruling; duration stays author-controlled.
		"limits": {}},
	# BLIND: reader makes the holder's harmful skills able to miss (blind_check,
	# character_component.gd:2093). Hostile control. Empty class list = every skill blinded.
	"blind": {
		"type": "BLIND", "fields": ["turns"], "hostile": true, "reserves": {},
		"tip": "This character is blinded.",
		"prose": "Blinds {who} {dur}",
		"limits": {}},
	# IMMORTALITY: reader is a bare presence check with NO exclusion list at all (is_immortal,
	# character_component.gd:1907). Allied (you make yourself/an ally unkillable).
	"immortality": {
		"type": "IMMORTALITY", "fields": ["turns"], "hostile": false, "reserves": {},
		"tip": "This character cannot be killed.",
		"prose": "Makes {who} unkillable {dur}",
		# BALANCE NOTE (NOT a cap): a permanent immortality on a whole team could stall a match, the same
		# way a permanent invuln can — is_immortal consults nothing. That is exactly the kind of thing an
		# APPROVER catches before release, not a rule the engine has (Stark ships an IMMORTALITY). The
		# earlier {max_turns:2, forbid_permanent} was an invented balance cap and is removed per the owner
		# ruling; duration is author-controlled like every other effect.
		"limits": {}},
	# IGNORE_COUNTER: reader makes the holder's skills ignore Counter and Reflect (reflect_check /
	# countered, character_component.gd:396). Allied buff. Empty list = all their skills.
	"ignore_counter": {
		"type": "IGNORE_COUNTER", "fields": ["turns"], "hostile": false, "reserves": {},
		"tip": "This character's skills will ignore Counter and Reflect skills.",
		"prose": "Makes {poss} skills ignore Counter and Reflect {dur}",
		"limits": {}},
	# IGNORE_HEALING: reader blocks all healing on the holder (heal_blocked,
	# character_component.gd:1689). Hostile debuff.
	"ignore_healing": {
		"type": "IGNORE_HEALING", "fields": ["turns"], "hostile": true, "reserves": {},
		"tip": "This character will ignore all healing effects.",
		"prose": "Stops {who} from being healed {dur}",
		"limits": {}},
	# IGNORE_CLEANSE: reader makes the holder's effects un-cleansable (checked in the cleanse path).
	# Allied buff — you protect your OWN debuffs-on-them / your marks from being stripped.
	# HOSTILE, not allied: the shipped canonical use is Kurotsuchi's Deadly Gas dropping this on an
	# ENEMY via add_hostile_effect (abilities/kurotsuchi6.gd:30) so the enemy cannot cleanse your
	# debuffs off themselves (effect_storage_component.gd:109). Tagged allied it would route through
	# add_allied_effect, landing ungated on invuln/shrug targets no hand-written kit can reach — the
	# exact A4 mis-routing this table's hostile column exists to prevent.
	"ignore_cleanse": {
		"type": "IGNORE_CLEANSE", "fields": ["turns"], "hostile": true, "reserves": {},
		"tip": "This character cannot be cleansed.",
		"prose": "Stops {who} from being cleansed {dur}",
		"limits": {}},
	# IGNORE_SKILL: reader fully negates the next harmful skill the holder receives (is_ignoring_skill,
	# character_component.gd:1836), consumed once. Defensive buff. Empty exclusion = any harmful class.
	"ignore_skill": {
		"type": "IGNORE_SKILL", "fields": ["turns"], "hostile": false, "reserves": {},
		"tip": "This character will ignore the next harmful skill they receive.",
		"prose": "Lets {who} ignore the next harmful skill they receive {dur}",
		"limits": {}},
	# STEALTH: reader stops the holder's skills from triggering enemy reactive effects (stealthed,
	# character_component.gd:1287). Allied buff.
	"stealth": {
		"type": "STEALTH", "fields": ["turns"], "hostile": false, "reserves": {},
		"tip": "This character's skills will not trigger enemy effects.",
		"prose": "Keeps {poss} skills from triggering enemy effects {dur}",
		"limits": {}},
	# NO_BOOST: reader makes the holder unable to INCREASE the damage it deals (can_boost,
	# character_component.gd:1823). Hostile debuff (Trap of Argalia).
	"no_boost": {
		"type": "NO_BOOST", "fields": ["turns"], "hostile": true, "reserves": {},
		"tip": "This character cannot increase the damage it deals with any effect.",
		"prose": "Stops {who} from increasing the damage it deals {dur}",
		"limits": {}},
	# SHARPSHOOTER: reader makes the holder unmissable and un-dodgeable (dodge_check/miss_check,
	# character_component.gd:1916). Allied buff.
	"sharpshooter": {
		"type": "SHARPSHOOTER", "fields": ["turns"], "hostile": false, "reserves": {},
		"tip": "This character cannot Miss or be Dodged.",
		"prose": "Makes {who} unable to miss or be dodged {dur}",
		"limits": {}},
	# FALSE_STUN: reader makes effects and skills TREAT the holder as stunned (has_stuns,
	# character_component.gd:1700) without a real stun. Hostile control.
	"false_stun": {
		"type": "FALSE_STUN", "fields": ["turns"], "hostile": true, "reserves": {},
		"tip": "Effects and skills will consider this character to be stunned.",
		"prose": "Makes the game treat {who} as stunned {dur}",
		"limits": {}},
	# CHAIN_NULLIFY: reader zeroes both the damage the holder DEALS and the healing they GIVE
	# (character_component.gd:593 / :1047). No factory exists — Effect.from is the ONLY constructor,
	# which is exactly the shape gilgamesh2.gd:28 already uses. Hostile debuff.
	"chain_nullify": {
		"type": "CHAIN_NULLIFY", "fields": ["turns"], "hostile": true, "reserves": {},
		"tip": "This character's skills and effects cannot deal damage or give healing.",
		"prose": "Stops {poss} skills and effects from dealing damage or giving healing {dur}",
		"limits": {}},
	# DAMAGE_REVERSE: reader turns damage the holder WOULD take into healing instead
	# (character_component.gd:652). No factory — Effect.from only. Defensive buff.
	"damage_reverse": {
		"type": "DAMAGE_REVERSE", "fields": ["turns"], "hostile": false, "reserves": {},
		"tip": "Damage this character would take heals them instead.",
		"prose": "Turns damage {who} would take into healing {dur}",
		"limits": {}},
}

# ============================================================================================
# portrait_change (EffectType.PORTRAIT_CHANGE) — IMPLEMENTED as a NAMED kind above, not a
# SIMPLE_EFFECTS row (see that row's comment for why it CANNOT be one: it needs system=true and
# cleansable=false, which only portrait_change_effect sets, not the generic __simple__ arm).
#
# The alt-portrait ART PLUMBING the deferral once waited on now exists end to end:
#   1. AuthoredAssets.ALT_PORTRAIT_SLOTS ("alt1".."alt4") give an author upload slots for the
#      transformed forms; ability_slots() explicitly excludes them so an alt is never a skill icon.
#   2. The authored art is rendered CLIENT-SIDE — the snapshot ships only the int index
#      (battle_manager portrait_alt), and app.js resolves it via authoredArtUrl(id, "alt"+(N+1)). The
#      server's alt_portraits[] stays empty (no headless renderer serializes it) and
#      character_component's active_portrait has a bounds guard so an empty array can never crash.
#   3. The index<->slot contract (0-based index N -> slot "alt"+(N+1)) is defined ONCE in
#      AuthoredAssets.alt_slot_for_index and mirrored in app.js's render/upload/labels.
# creator_effect_table_probe now asserts PRESENCE (portrait_change wired) and its precondition (the
# alt slots exist), the flip of what it once asserted.

# The merged palette the whole engine reads: the hand-written named-factory kinds PLUS every Simple
# Effect row, each folded down to the four columns the runner / validator / editor consult. Kept a
# derived static var (not a second hand-written literal) so a Simple Effect row is authored in ONE
# place — SIMPLE_EFFECTS above — and self_check still walks the merged result. `__simple__` is the
# factory sentinel: nothing dispatches on `factory` (the runner matches on the kind string), it only
# tells a reader "this kind is built by the generic arm", the way `__trigger__` marks the trigger kind.
static var EFFECT_KINDS: Dictionary = _merge_effect_kinds()

static func _merge_effect_kinds() -> Dictionary:
	var merged: Dictionary = _NAMED_EFFECT_KINDS.duplicate(true)
	for k in SIMPLE_EFFECTS.keys():
		var row: Dictionary = SIMPLE_EFFECTS[k]
		merged[str(k)] = {
			"factory": "__simple__",
			"fields": (row["fields"] as Array).duplicate(),
			"hostile": row["hostile"],
			"reserves": (row["reserves"] as Dictionary).duplicate(),
		}
	return merged

# --- BACKWARDS-COMPATIBILITY ALIASES — DO NOT DELETE ------------------------
# `trigger` was called `reactive` until the rename. Characters authored before it are
# JSON FILES ON DISK under authored/ (auth_testchar.json is one), they are RE-VALIDATED
# ON EVERY LOAD, and we deliberately do not rewrite player data — so deleting this alias
# would silently make every one of them fail validation and vanish from its author's list.
# It is READ-SIDE ONLY: canonical_kind is called wherever a `kind` is interpreted, and
# nothing anywhere ever writes "reactive" again (the editor, the validator's messages and
# the generated prose all say "trigger").
const KIND_ALIASES := {
	"reactive": "trigger",
}

static func canonical_kind(kind) -> String:
	var k := str(kind)
	return str(KIND_ALIASES[k]) if KIND_ALIASES.has(k) else k

# --- the reserved-register lookup -------------------------------------------------------------
# The ONE reader of the `reserves` column, so the validator (which refuses the field), the runner
# (which skips it on a hand-edited file that never met the validator) and the palette export
# (which is what stops the editor drawing the control at all) cannot disagree about what is
# reserved. Takes a raw kind so callers do not each have to remember canonical_kind.
static func reserved_fields(kind) -> Dictionary:
	var k := canonical_kind(kind)
	if not EFFECT_KINDS.has(k):
		return {}
	var r = EFFECT_KINDS[k].get("reserves", null)
	return r if r is Dictionary else {}

static func is_reserved_field(kind, field) -> bool:
	return reserved_fields(kind).has(str(field))

# Every kind's reserved map, for the palette export. Built rather than exported as a slice of
# EFFECT_KINDS because the editor needs it keyed by kind and nothing else in that row.
static func reserved_by_kind() -> Dictionary:
	var out: Dictionary = {}
	for k in EFFECT_KINDS.keys():
		out[str(k)] = reserved_fields(k)
	return out

# --- SCHEMA SELF-CHECK ------------------------------------------------------------------------
# The palette is a hand-written literal, and three of its rows are only correct if they AGREE with
# something else: a kind's `reserves` must name real universal fields and real authored fields of
# that kind, and a TRIGGERS row must name a real EffectType member. None of those can be caught by
# reading one table. Returns a list of drift errors ([] == consistent).
#
# Called from training/tests/advreview_phaseb_probe.gd, which is the point: Phase C and D add rows
# to exactly these tables, and a row that is wrong here validates, renders, exports to the palette
# and misbehaves at runtime with the whole suite green. It is deliberately NOT called per-validate
# — this is a constant-vs-constant check, so it can only change when the source changes.
static func self_check() -> Array:
	var errs: Array = []
	for k in EFFECT_KINDS.keys():
		var row: Dictionary = EFFECT_KINDS[k]
		# The column is REQUIRED, exactly as `hostile` is. An absent one reads as "reserves
		# nothing", which is the fail-OPEN half of the guess — the whole failure mode this table
		# exists to stop — so a kind that omits it is an error rather than a default.
		if not row.has("reserves"):
			errs.append("effect kind '%s' declares no 'reserves' — list the universal fields its factory writes ({} if none)" % str(k))
			continue
		if not row["reserves"] is Dictionary:
			errs.append("effect kind '%s': 'reserves' must be a {universal field -> authored field} map" % str(k))
			continue
		var own: Array = row.get("fields", []) as Array
		for f in (row["reserves"] as Dictionary).keys():
			if not UNIVERSAL_EFFECT_FIELDS.has(str(f)):
				errs.append("effect kind '%s' reserves '%s', which is not a universal effect field" % [str(k), str(f)])
			if str(f) in own:
				# Then it is not reserved, it is AUTHORED: a field a kind lists in `fields` is
				# already skipped by the universal pass, and naming it here would reject the
				# author's own control for that kind.
				errs.append("effect kind '%s' reserves '%s', but also offers it as an authored field — one or the other" % [str(k), str(f)])
			var owner := str((row["reserves"] as Dictionary)[f])
			if owner.is_empty():
				errs.append("effect kind '%s' reserves '%s' with no owning field named — the error message has nothing to point the author at" % [str(k), str(f)])
	for t in TRIGGERS.keys():
		var member := str(TRIGGERS[t])
		if not EffectType.Type.has(member):
			errs.append("trigger '%s' names EffectType.%s, which does not exist" % [str(t), member])
	for t in SCOPED_TRIGGERS:
		if not TRIGGERS.has(str(t)):
			errs.append("SCOPED_TRIGGERS names '%s', which is not a trigger hook" % str(t))
	for t in EVENT_TRIGGERS:
		if not TRIGGERS.has(str(t)):
			errs.append("EVENT_TRIGGERS names '%s', which is not a trigger hook" % str(t))
	for t in TRIGGER_IMPLIED_CLASS.keys():
		if not TRIGGERS.has(str(t)):
			errs.append("TRIGGER_IMPLIED_CLASS names '%s', which is not a trigger hook" % str(t))
		elif not str(TRIGGER_IMPLIED_CLASS[t]) in Ability.CLASS_NAMES:
			errs.append("TRIGGER_IMPLIED_CLASS['%s'] names '%s', which is not an ability class" % [str(t), str(TRIGGER_IMPLIED_CLASS[t])])
	# The Simple Effect Table's own constant-vs-constant checks: a row's `type` must name a real
	# EffectType member (the generic build arm indexes the enum by it — a typo would be a runtime
	# "invalid index" the moment the effect is authored), and a magnitude row that bends its mag must
	# say so with the ONE recognised convention. The reserves/fields halves are already covered above,
	# because SIMPLE_EFFECTS is folded into EFFECT_KINDS and this loop walks the merged result.
	for k in SIMPLE_EFFECTS.keys():
		var srow: Dictionary = SIMPLE_EFFECTS[k]
		if not srow.has("type") or not EffectType.Type.has(str(srow.get("type", ""))):
			errs.append("simple effect '%s' names EffectType.%s, which does not exist" % [str(k), str(srow.get("type", ""))])
		var conv := str(srow.get("mag", "flat"))
		if not conv in ["flat", "retained"]:
			errs.append("simple effect '%s' declares mag convention '%s' — must be 'flat' or 'retained'" % [str(k), conv])
		# A magnitude row (build arm writes mag from amount) MUST reserve mag, and a pure-flag row
		# (no `amount` control) must NOT — the two have to agree or the editor draws the wrong control.
		var has_amount := "amount" in (srow.get("fields", []) as Array)
		var reserves_mag := (srow.get("reserves", {}) as Dictionary).has("mag")
		if has_amount != reserves_mag:
			errs.append("simple effect '%s': a row with an `amount` control must reserve `mag` (build arm writes it) and one without must not — amount=%s reserves_mag=%s" % [str(k), str(has_amount), str(reserves_mag)])
	return errs

# --- UNIVERSAL effect fields ------------------------------------------------
# Fields valid on EVERY effect in an `apply` block, whatever its kind. They are applied to
# the constructed Effect AFTER the factory returns and BEFORE it is applied, by one shared
# helper (BlockRunner._apply_universal_fields) — so a new effect kind gets the whole set for
# free and there is no per-kind list to keep in sync. That is the entire point: the only
# per-kind lists left are the FACTORY arguments.
#
# A field a kind declares in its own `fields` is FACTORY-OWNED and is not re-applied here
# (today that is only `mark`.stacks, which the factory clamps to the mark's `max` — letting
# the universal pass write it again would step over that ceiling).
#
# DERIVED FROM scripts/effect_component.gd — this is that class's `var` block, minus:
#   * CALLABLES (trigger, wrapup_func, shield_func, barrier_func, redirect_func,
#     conditional_func). Exposing one would be code-in-data: a player-authored string or
#     block tree would have to become an executable, which is exactly the guarantee the
#     whole Creator is built to keep. Not negotiable.
#   * OBJECT REFERENCES (user, target, source, character_target, tooltip, breaker,
#     delay_targets, delay_main_target, delay_skill). JSON has no way to name a live Node,
#     and the engine sets all of them itself (set_source, add_effect).
#   * ENGINE BOOKKEEPING (id, removed, effect_type, duration, triggered, waiting,
#     fresh_stack, twin_priority). `duration` is already authored as turns/ticks; the rest
#     are runtime state the engine writes during resolution, and an authored value would be
#     overwritten or would corrupt the effect's own state machine.
#   * NON-SCALAR fields (cancel_effects, ability_targets, character_targets,
#     exclusion_targets, class_targets, type_targets, storage, alternative_cost). The
#     universal set is scalar by design — bool/int/String is what the validator can
#     type-check. Where a kind needs one of these lists it exposes it as a factory field
#     with a named vocabulary (`skills`, `classes`, `exclude_classes`, `scope`, and — the
#     counter/reflect subtraction that also writes exclusion_targets — `exclude`).
#   * ENUM-CODED ints (element, cost_change_element, cost_color_required). The palette's job
#     is to give an enum a NAME (COST_COLOURS, DAMAGE_TYPES); shipping the raw int would be
#     authoring by magic number. `cost_change_element` is already reachable as
#     cost_change.colour.
#   * skill_seal, which without its companion filter lists can only express the unbounded "seal
#     every skill" form. It SHIPPED as the first-class `seal` OP (see OPS' seal row) with its own
#     vocabulary — classes / skills / exclude_skills — rather than a bare universal bool, which is
#     why it stays out of this scalar set.
#   * DEAD fields the engine never reads back (bleed, serum, action, cancel, channel,
#     use_source_damage). Offering an author a switch wired to nothing is worse than not
#     offering it.
#
# The value is the type the validator enforces and the runner coerces to.
const UNIVERSAL_EFFECT_FIELDS := {
	# stacking + magnitude
	"stacks":                   "int",     # starting stack count
	"stackable":                "bool",    # re-application MERGES instead of replacing (see below)
	"stack_mag":                "bool",    # a merge also adds the incoming `mag`
	"per_stack":                "bool",    # the effect ticks once per stack
	"mag":                      "int",     # raw magnitude; every kind with an `amount` sets this from it
	# presentation
	"invisible":                "bool",    # not drawn, but still on the wire
	"display_mag":              "bool",    # show the magnitude on the effect pip
	"display_stacks":           "bool",    # show the stack counter
	"unique_render_id":         "int",     # splits same-named effects into separate render clusters
	"name_override":            "string",  # see the collision note below
	"description":              "string",  # the tooltip text (engine accepts a plain String)
	# survival
	"system":                   "bool",    # survives cleanses AND is hidden from both players
	"display_system":           "bool",    # ...keep the cleanse semantics, but still serialize it
	"cleansable":               "bool",
	"remove_on_death":          "bool",
	"tick_during_banish":       "bool",
	# interaction
	"bypassing":                "bool",    # keeps ticking/applying through the target's invulnerability
	"health_drain":             "bool",    # damage it deals heals the source
	"ability_only":             "bool",    # only reacts to damage from an ABILITY, not from another effect
	"last_turn_only":           "bool",    # fires once, on its final tick
	"trigger_once":             "bool",
	"remove_once_triggered":    "bool",
	"full_remove_once_triggered":"bool",
}

# WHY name_override matters enough to be called out: add_effect dedups on
# (effect_name, effect_type, user), and effect_name() falls back to the SOURCE ABILITY'S
# NAME. So one ability applying two same-typed effects gives them the same name and the
# second silently merges into (or replaces) the first — the shipped Mavis passive hits this
# exact wall. Setting name_override on one of them is the fix, and it is also what makes an
# emergent stack ("same name + same type + same user") a deliberate choice rather than an
# accident.

# `counter`.scope -> the ability CLASSES the counter watches for. counter_effect
# stores these in class_targets, and Condition.action_countered treats an empty
# list as "every hostile skill" (see scripts/condition.gd).
#
# These three are NAMED SHORTCUTS, not the whole vocabulary: `scope` also accepts a raw
# list of class names, because class_targets is a free list and nine shipped counters
# filter by a class no shortcut spells — korra1 ["Affliction"], korra2 ["Mental"],
# korra3 ["Physical"], korra4 ["Energy"], uzui3/maka4 ["Physical"], tokoyami3
# ["Strategic"] and ["Strategic","Mental"], tsunayoshi2 ["Energy","Affliction"].
const COUNTER_SCOPES := {
	"harmful":  ["Harmful"],
	"damaging": ["Damaging"],
	"any":      [],
}

# `counter`.on — WHICH SIDE of the exchange the counter watches. Character.countered() reads two
# separate effect types in one pass (scripts/character_component.gd:406-448) and the palette only
# ever reached one of them:
#   incoming (COUNTER_RECEIVE, the default and the only shape before this) sits on a DEFENDER and
#     eats a skill aimed at them — "the next Harmful skill used on this character is countered".
#   outgoing (COUNTER_USE) sits on the ATTACKER and eats the skill THEY use — the muzzle shape
#     (kakashi5's Sharingan Cancel, hidan1, mercury3), which had no spelling at all.
# The distinction is not cosmetic in either direction: an outgoing counter is a hostile
# application (see HOSTILE_BY_COUNTER_SIDE), and it fires in countered()'s FIRST loop, before the
# defender's own counters get a look.
#
# NOTE FOR ANYONE GREPPING: check_counter_use_effects / check_counter_receive_effects
# (:1515, :1521) look like the wiring for this and are DEAD — zero callers repo-wide. The live
# path is countered() and the cancel is `if not char.countered(...)` in
# "new multiplayer/battle_manager.gd":1204.
const COUNTER_SIDES := ["incoming", "outgoing"]

static func counter_side_id(side) -> int:
	return EffectType.Type.COUNTER_USE if str(side) == "outgoing" else EffectType.Type.COUNTER_RECEIVE

# `reflect`.destination — where the re-aimed skill goes. A TWO-VALUE ENUM and never a character
# name, which is what keeps it inside [[What Cannot Be Built Yet]]'s payload rule by construction:
# an authored value can never designate a live Character, so there is no way to write "reflect it
# at whoever I pick" and no reference for the runner to resolve against a stale board.
#   attacker — the classic bounce: Ability.reflect_trigger reads mag == -1 and sends the skill back
#     at whoever used it, re-aiming a multi-target skill onto the attacker's OWN team through
#     reflect_retarget_to_team (gallantmon1, marco3, rob8, king4).
#   applier  — the guardian: the skill lands on whoever CAST the reflect instead. The runner
#     supplies that Character itself, so the author names a role and never a node (eren2, mash4,
#     saber3, tamaki4, kitara2 all pass their own `user` here).
const REFLECT_DESTINATIONS := ["attacker", "applier"]

# `reflect`.charges — how many skills it eats. TWO LEGAL VALUES, and the bound is the engine's,
# not an invented one: Ability.reflect_trigger consumes the WHOLE effect the moment it fires unless
# `stacks` is exactly -1 (ability_component.gd:401-406), so "3" would behave identically to "1".
# Offering an arbitrary count would be a number that renders, validates and does nothing — the
# `trigger_once` failure mode this palette keeps having.
const REFLECT_UNLIMITED := -1
const REFLECT_CHARGES := [-1, 1]

# `cost_change`.mode — WHICH of the engine's three cost effects an authored cost change is. All
# three are read by Ability.cost() in this order (ability_component.gd:284-345) and they are
# genuinely different mechanics, not degrees of one:
#   add  — COST_MOD. The default and the only shape before this: +N/-N of one colour, floored at 0.
#   set  — COST_CHANGE. OVERRIDES the whole cost with `amount` of `colour` and nothing else, which
#     is the only way to author "this skill now costs nothing" (amount 0) or a flat re-price.
#   swap — COLOR_CHANGE. Moves whatever the skill costs in `from` over to `colour` — a transform's
#     re-colouring, and the one shape where the total is unchanged.
const COST_MODES := ["add", "set", "swap"]

# The ability-level `channel` flag: which of the engine's two cancel holders a skill plants over
# everything it applied. Both end the lot when the user is stunned, killed, banished or sealed out
# of the skill (Character.check_cancels); `channel` ALSO ends when the user takes any other action
# that is not Preserves Channel (Character.cancel_channels, called from battle_manager:1202).
# A STRING and not two bools, because a skill is one or the other and never both.
const CHANNEL_MODES := ["control", "channel"]

# The CLASS each channel mode implies. Derived from the flag rather than typed by the author, so a
# skill that says "Channeled" on its card is a skill that actually channels. Both strings are pure
# LABELS to the engine — nothing reads classes["Channeled"] or classes["Control"], exactly as
# nothing reads classes["Invisible"] — so, following the same reading AuthoredCharacter already
# applies to Invisible/Unstunnable, an author may still tick the label alone. What they cannot do
# is get the MECHANIC without the label.
const CHANNEL_CLASSES := {"control": "Control", "channel": "Channeled"}

# A presence condition's `.by` — WHOSE copy of a named effect counts.
#   any  — anybody's (the default, and what every presence condition did before this).
#   mine — only the one this skill's user applied. That is the question 81 of the 174 shipped
#     characters actually ask: `user.has_effect("Sage Chakra Gather", MARK, user)` is the shipped
#     idiom, and without it "do I have my own mark?" answered true off an ENEMY's same-named mark.
# It SHIPS WITH `.effect` and is meaningless without it: effect_storage_component.has_effect
# (:67-71) matches name AND type AND user in one pass, and there is no name+user-without-type
# entry point anywhere in the engine to fall back on.
const PRESENCE_BY := ["any", "mine"]

# Resolve a `counter`.scope — a shortcut name or a literal class list — to class_targets.
static func counter_classes(scope) -> Array:
	if scope is Array:
		var out: Array = []
		for c in scope:
			out.append(str(c))
		return out
	var key := str(scope)
	if COUNTER_SCOPES.has(key):
		return (COUNTER_SCOPES[key] as Array).duplicate()
	return ["Harmful"]

# The authorable EffectType names, DERIVED from the engine enum rather than hand-listed.
# `effect_immunity`.effect names the type it resists; `remove`.effect names the type it matches.
# ONE derivation for both, on purpose: two hand-kept copies is exactly how the old nine-name
# whitelist ended up rejecting SHIELD (aiohto1, bakugo2, jaden6 x2) and COUNTER_RECEIVE /
# COUNTER_USE (kakashi5) — types the roster genuinely immunises against — while offering five
# (PARALYZE, TAUNT, ISOLATE, VULNERABILITY, COOLDOWN_MOD) that ship zero uses.
# Effect.ignore_effect_effect takes any EffectType, so the only exclusion left is the
# MISSION_TRIGGER_* family: those are mission/achievement bookkeeping hooks, not battle effects
# a character could meaningfully resist or would ever hand-remove.
static func immunity_effects() -> Array:
	var out: Array = []
	for k in EffectType.Type.keys():
		if not str(k).begins_with("MISSION_TRIGGER_"):
			out.append(str(k))
	return out

# Cost modifiers may name Random (the classic "+1 Random to cast" tax); energy
# GAIN may not — the pool only holds the four real colours, and Random there is
# what the un-coloured `gain_energy` already does by rolling.
const COST_COLOURS := ["random", "green", "blue", "white", "red"]
const GAIN_COLOURS := ["green", "blue", "white", "red"]

# --- trigger hooks: which engine hook a "trigger" effect listens on ----------
# The payload is ITSELF a block list (`then`), which is what lets the 277
# trigger_effect sites in the existing corpus be expressed as data rather than
# as callbacks. BlockRunner binds a Callable that walks those blocks.
#
# THE VALUES ARE EffectType MEMBER NAMES, AND THEY ARE LIVE. trigger_hook_id derives the enum
# value from this table (EffectType.Type[<the name>]) instead of restating the mapping in a
# `match`. It used to be a duplicated match, which made this whole table DEAD DECORATION: the
# editor palette, the validator's whitelist and the generated prose all read the table while the
# runtime read the match, and nothing asserted the two agreed. A hook row could therefore
# validate, render, export to the palette and listen on the WRONG engine hook with the entire
# suite green — the exact shape Phase C and D will be adding rows to. Deriving is what makes a
# typo here a self_check() failure (the member does not exist) rather than a silent -1 at runtime.
const TRIGGERS := {
	"on_harmful_received": "HARMFUL_RECEIVE_TRIGGER",
	"on_damage_received":  "DAMAGE_RECEIVE_TRIGGER",
	"on_damage_dealt":     "DAMAGE_DEALT_TRIGGER",
	"on_turn_start":       "START_OF_TURN_TRIGGER",
	"on_turn_end":         "END_OF_TURN_TRIGGER",
	"on_death":            "ON_DEATH_TRIGGER",
	"on_skill_used":       "ACTION_USE_TRIGGER",
	# HEALTH_CHANGE_TRIGGER fires from receive_damage AND receive_healing
	# (scripts/character_component.gd:531, :1112) — every HP move, up or down, including a heal
	# the clamp reduced to zero. That last part is why an authored payload on this hook is
	# latched against re-entry in BlockRunner._build_trigger; see the note there.
	"on_hp_changed":       "HEALTH_CHANGE_TRIGGER",
	"on_stunned":          "STUN_RECEIVED_TRIGGER",
	"on_skill_received":   "ACTION_RECEIVE_TRIGGER",
	# Fires on the HEALER when a heal they gave lands (check_healing_given_triggers,
	# scripts/character_component.gd:1445, dispatched from receive_healing at :1119). The dispatcher
	# passes the HEALED character as context.target, so B's `affected` addresses them (the same
	# on_damage_dealt shape, where `affected` is the victim). E's readings ride for free. It uses
	# from_trigger_source with the healing Ability/Effect as `source`, so — unlike the four
	# from_effect_end hooks — the event-class filter CAN read a class off it; hence it joins
	# SCOPED_TRIGGERS below rather than being rejected there.
	"on_healing_given":    "HEALING_GIVEN_TRIGGER",
}

# WHICH HOOKS THE EVENT-CLASS FILTER CAN READ. `trigger`.scope asks "what CLASS was the skill
# that fired this hook?", and the answer lives in QueryContext.source. On these six the
# dispatcher puts the triggering Ability there (or an Effect whose `source` is one):
#   on_harmful_received / on_skill_received  <- from_trigger_source(received_ability, ...)
#   on_skill_used                            <- from_trigger_source(ability, ...)
#   on_stunned                               <- from_trigger_source(stun.source, ...)
#   on_damage_received / on_damage_dealt     <- from_trigger_source(damage_source, ...)
# On the other four the dispatcher uses QueryContext.from_effect_end, which sets `source` to
# THE TRIGGER EFFECT ITSELF (scripts/query_context.gd:43) — so the filter would be comparing the
# authored ability against its own classes and would read the same way forever. That is the
# `trigger_once` failure mode (a control that renders, validates and does nothing), so the
# validator rejects `scope` there rather than letting it render inert.
const SCOPED_TRIGGERS := [
	"on_harmful_received", "on_damage_received", "on_damage_dealt",
	"on_skill_used", "on_skill_received", "on_stunned",
	# on_healing_given carries the HEALING SKILL in QueryContext.source (from_trigger_source, not
	# from_effect_end), so "when I heal with a <class> skill" is a real filter, not an inert control —
	# it belongs here, and leaving it out would make the validator's "does not fire from a skill"
	# rejection a lie (the per-hook-lies hazard, from the wrong side).
	"on_healing_given",
]

# WHICH HOOKS CARRY A MAGNITUDE the `event` reading can read. `event` resolves to QueryContext.value,
# and value is 0 on every hook whose dispatcher does NOT thread a number into it — so an `event` read
# outside this set is the exact "per-hook lie" the roadmap warns about: a card that says "reflect the
# amount I just took" doing NOTHING because it silently read 0.
#
# These three are precisely the hooks whose check_* dispatcher passes a fourth qvalue argument to
# QueryContext.from_trigger_source (scripts/character_component.gd):
#   on_damage_dealt     <- check_damage_dealt_triggers(..., damage)   (:1414, DAMAGE_DEALT_TRIGGER)
#   on_damage_received  <- check_damage_taken_triggers(..., damage)   (:1455, DAMAGE_RECEIVE_TRIGGER)
#   on_healing_given    <- check_healing_given_triggers(..., healing) (:1465, HEALING_GIVEN_TRIGGER)
# Every OTHER trigger hook calls from_trigger_source with no qvalue (value defaults to 0) or uses
# from_effect_end (which never sets value at all) — on_harmful_received, on_skill_used, on_stunned,
# on_skill_received, on_turn_start/end, on_death, on_hp_changed. A `counter` payload
# (from_counter_check) and a `recurring`/turn/death payload (from_effect_end) likewise carry no
# magnitude, so both reject `event` wholesale (they are not in this list and never name a hook here).
# This is the value-side twin of SCOPED_TRIGGERS: same "reject the field where the hook cannot back it".
const EVENT_TRIGGERS := [
	"on_damage_dealt", "on_damage_received", "on_healing_given",
]

# THE CLASS A HOOK ALREADY GUARANTEES. HARMFUL_RECEIVE_TRIGGER is dispatched only for skills that
# are Harmful, so naming Harmful in that hook's `scope` narrows nothing: the resolved class list is
# an OR (BlockRunner._scope_matches returns true on the FIRST match), so a list containing Harmful
# is satisfied by every skill that can reach the hook at all.
#
# It exists for the PROSE. The generated sentence for this hook already contains the word
# "harmful", so printing the class adjective in front of it produced "when a Harmful harmful skill
# is used on them" from a perfectly legal spec. Suppressing an adjective the sentence has already
# said is not a cosmetic trim — it is the only wording that is also CORRECT, because the scope in
# that case genuinely filters nothing. A scope naming any OTHER class still prints ("when a
# Physical harmful skill is used on them"), because that one does narrow.
#
# A table rather than an `if` inside the renderer, and next to the hook list rather than inside
# scripted_ability.gd, so a Phase C hook with the same shape declares it where it declares the hook.
const TRIGGER_IMPLIED_CLASS := {
	"on_harmful_received": "Harmful",
}

# --- THE ONE SCOPE RENDERER -------------------------------------------------------------------
# `counter`.scope, `reflect`.scope and `trigger`.scope are one authored value with one vocabulary
# (a named shortcut, or a raw list of ability classes), and they were being worded THREE different
# ways: ScriptedAbility._scope_noun joined a raw list with " and ", ScriptedAbility._scope_phrase
# resolved the shortcut to CLASS NAMES and joined with " or ", and BlockRunner._scope_text did a
# third thing for the in-battle tooltip. The same spec therefore read two ways on one card.
#
# Returns the ADJECTIVE TEXT ONLY, and "" when the scope filters nothing — every caller decides
# whether to hang " skill" or a trailing space off it. "" rather than the literal "any" is the
# load-bearing part: "any" resolves to an EMPTY class list, so printing the word describes a filter
# that is not there ("The next any skill used on this character will be countered").
#
# " or ", never " and ": _scope_matches returns true on the first class that matches, so a list is
# a disjunction. "and" told the player the opposite of what the engine does.
# A shortcut prints AS THE SHORTCUT WORD ("harmful", "damaging"), not as its resolved class names,
# because that is the word the author typed and the word the card has always shown.
static func scope_words(scope) -> String:
	if scope == null:
		return ""
	if scope is Array:
		var names: Array = []
		for c in scope:
			names.append(str(c))
		return " or ".join(names)
	var key := str(scope)
	if COUNTER_SCOPES.has(key) and (COUNTER_SCOPES[key] as Array).is_empty():
		return ""                          # "any" — present, but names nothing
	return key

# --- action ops -------------------------------------------------------------
# THE OPS THAT MUST RE-VALIDATE THEIR OWN POOLS.
#
# A block that says `to: "target"` acts on characters the TARGETING system chose, so they
# have already been through can_hostile_target / can_allied_target and, for invulnerability
# gained mid-turn, battle_manager's invuln-target drop filter. Every other selector builds
# its pool inside BlockRunner, and for these four ops the engine primitive underneath asks
# nothing: Character.resolve_damage never consults is_invuln, shatter_shields /
# shatter_barrier check nothing at all, and cleanse_all_enemy_effects is gated only on
# IGNORE_CLEANSE + `cleansable`. So an authored `to: "all_enemies"` used to reach through an
# invulnerable defender — something no hand-written kit can do — and BlockRunner re-applies
# the targeting predicates itself (see BlockRunner._legal_pool).
#
# `apply` and `heal` are DELIBERATELY ABSENT: Character.add_hostile_effect /
# add_allied_effect and resolve_healing already run their own gating, so re-filtering their
# pools here would apply the check twice and, worse, add targeting-only restrictions
# (Iron Maiden, Gibbet, Sealed King) that the application path has never had.
# `execute` is in the list for exactly the reason `damage` is: instant_kill
# (scripts/character_component.gd:1995) checks Embrace Pain and Sealed Nightmare and NOTHING ELSE —
# not invulnerability, not isolation. A hand-written execute kit only ever reaches a target the
# targeting system already vetted (can_hostile_target drops the invulnerable), so an authored
# `to: "all_enemies"` execute would otherwise kill an invulnerable defender no shipped skill can
# touch. It carries `bypassing` (below) as the one opt-out, the same word every revalidated op uses.
const REVALIDATED_OPS := ["damage", "break", "cleanse", "remove", "adjust", "execute"]
const OPS := {
	# `bypassing` is the author's single opt-out from REVALIDATED_OPS' pool check. THE WORD IS
	# NOT NEGOTIABLE: it is the engine's own name for "ignore the target's invulnerability" —
	# the third positional parameter of Character.add_hostile_effect / add_allied_effect and of
	# the default_*_target_function helpers, the `apply` op has carried it since before this
	# check existed, and the ability CLASS that declares the same intent is spelled "Bypassing".
	# "Pierce" is a DIFFERENT, REAL mechanic in this game — DamageType.Type.PIERCING, which
	# ignores damage REDUCTION and has nothing to do with invulnerability
	# (scripts/character_component.gd:699, :834) — so naming this field after it would collide
	# with the `damage_type` picker sitting on the very same block.
	# Offered on exactly the four ops that re-validate: a control that renders, validates and
	# does nothing is the failure mode this palette keeps having.
	# The ability-level "Bypassing" class sets the DEFAULT for every block; this field overrides
	# it in both directions (see BlockRunner._bypass_gate).
	"damage":       {"fields": ["amount", "damage_type", "to", "bypassing"]},
	"heal":         {"fields": ["amount", "to"]},
	"apply":        {"fields": ["effect", "to", "bypassing"]},
	"gain_energy":  {"fields": ["amount", "colour"]},
	"cleanse":      {"fields": ["to", "name", "scope", "count", "bypassing"]},
	# NO `stack` OP. Stacking is not an operation and is not a mark-only concept — it is
	# EMERGENT: effect_storage_component.add_effect merges a new effect into a present one
	# whenever the stored effect's `stackable` is true and the two share a NAME, a TYPE and
	# a user, whatever kind they are. `stackable` is now universal (see
	# UNIVERSAL_EFFECT_FIELDS), so any effect can be a stacking resource by declaring it,
	# and the `stacks_at_least` condition reads the result. The old op only ever poked a
	# MARK's counter, which made stacking look like a property of marks.
	# THE MIRROR OF `apply`, and the only way to SPEND a stack or take one named effect away —
	# both of which shipped kits do constantly (shiro5 spends a Ganta Fever stack; naruto1 and
	# naruto2 consume the Sage Chakra Gather mark; 59 ability scripts call remove_effect).
	#
	# `remove` IS NOT `cleanse`. Cleanse is the CLEANSE MECHANIC: it bails wholesale on
	# IGNORE_CLEANSE and only touches effects whose `cleansable` is true, because cleansing is
	# something the game does TO an effect from the outside. `remove` is the author's own
	# surgical bookkeeping — the direct remove_effect / consume_stack call those 59 scripts make
	# on their own marks AND on enemy effects without ever consulting `cleansable`. Gating it on
	# that flag would invent a restriction the game does not have, so the two ops stay separate
	# verbs and neither is expressible in terms of the other.
	"remove":       {"fields": ["name", "effect", "stacks", "to", "bypassing"]},
	# REACH INSIDE an effect that is already on the board. Same addressing as `remove` — match on
	# effect_name(), an optional `effect` type to disambiguate, collect before mutating — and the
	# same one-instance rule for the same reason: a second match is a DIFFERENT caster's copy of a
	# same-named effect, so charging the author's delta against each would apply it several times.
	#
	# DELTA FORM ONLY, and that is enforced BY CONSTRUCTION rather than by a check: there is no
	# `set`/`to_value` field, and the unknown-field rejection in BlockValidator._validate_block
	# turns one into an error. The abuse case a `set` form invites is an unbounded ramp — "set this
	# mark to 99 stacks" reaches, in one cast, a number no amount of stacking could earn, and every
	# `stacks_at_least` gate downstream reads it. A delta is the shape the corpus actually uses
	# (`dot.duration += 2` in character/toji.gd:118, `tracker.mag += 1` in abilities/uzui5.gd:27,
	# `passive.change_mag(1)` in character/madoka.gd:31).
	#
	# `turns` is a delta in AUTHOR turns and goes through turns_to_delta's 2N convention, NOT
	# turns_to_duration: "+1 turn" is "+2 ticks" and "-1 turn" must be "-2 ticks", where
	# turns_to_duration would read the negative as PERMANENT.
	#
	# IN REVALIDATED_OPS, and for exactly the reason `remove` is: nothing underneath asks anything.
	# Writing `eff.duration` / `eff.stacks` / `eff.mag` consults no targeting predicate at all, so an
	# authored `to: "all_enemies"` would reach inside an effect on an INVULNERABLE defender —
	# something no hand-written kit can do. It carries `bypassing` for the same reason `remove` does:
	# that check is the author's one opt-out, in both directions.
	"adjust":       {"fields": ["name", "effect", "to", "turns", "stacks", "mag", "bypassing"]},
	"break":        {"fields": ["what", "to", "bypassing"]},
	# REMOVE A CHARACTER FROM THE BOARD for a while. An OPS row and NOT an effect kind, because a
	# BANISH Effect is inert: tick_durations, check_win_condition, every targeting helper and
	# BlockRunner._alive all read the raw `character.banished` BOOL, and only
	# Character.banish_character (scripts/character_component.gd:260) ever writes it.
	# (Character.is_banished derives it from the EFFECT instead, and it has exactly ONE caller — the
	# A6 correctness check inside banish_character itself, scripts/character_component.gd:283, which
	# is the line that stops a REFUSED banish from reading as an elimination. It is live code: delete
	# it and a banish that add_hostile_effect dropped sets `banished` anyway, and check_win_condition
	# — which runs mid-turn — reads the last living enemy as dead.)
	#
	# NO `bypassing` FIELD, deliberately: banish_character routes through add_hostile_effect /
	# add_allied_effect, which do their own gating, so this is in the same family as `apply` and
	# `heal` rather than in REVALIDATED_OPS. Since A6 the `banished` flag is only set when that
	# application SUCCEEDS, so a refused banish no longer leaves a character flagged eliminated.
	#
	# POOL SELECTORS ARE FORBIDDEN on this op (BlockSchema.is_pool_selector, enforced by the
	# validator and again by the runner): a banish aimed at a whole team is an instant win — and,
	# aimed at your own team, an instant loss.
	"banish":       {"fields": ["to", "turns"]},
	# A `when`-guarded bundle. `else` turns it into an EITHER/OR: the `when` is rolled ONCE and exactly
	# one branch fires — `blocks` when it holds, `else` when it does not. ONE roll is the whole point:
	# a `chance` guard evaluated twice (once as the block's own gate, once inside the op) would
	# double-fire, so a group carrying an `else` opts out of _run_block's pre-dispatch `when` gate and
	# evaluates the condition itself, exactly once. Without an `else` the `when` stays the ordinary
	# whole-block gate. `_count_blocks` recurses into `else` (its blocks execute), and a group with an
	# `else` but no `when` is rejected — the else branch would be unreachable (the inert-control trap).
	"group":        {"fields": ["blocks", "else"]},
	# A `group` WITH A COUNT, so it composes with everything instead of being a per-op flag.
	#
	# REPEATING A HIT IS NOT ONE BIGGER HIT, which is why this is a real op and not a spelling of
	# a larger `amount`: shields absorb per instance, damage reduction and the minimum-damage floor
	# apply per instance, and every receive-trigger fires per instance. Ten shipped abilities loop a
	# constant this way (gatomon11 runs range(9), emiya7/impmon3/renamon3/shokuhou1-2 range(4)).
	#
	# `times` carries its own limit (LIMITS.max_repeat_times) AND multiplies the body inside
	# BlockValidator._count_blocks — see that function for why plain recursion is not enough.
	"repeat":       {"fields": ["times", "blocks"]},
	# INSTANT KILL — the shipped outcome 16 abilities reach through Character.instant_kill
	# (scripts/character_component.gd:1995) and execute_attempt (:524). Both immunities ride for
	# free BY GOING THROUGH THE ENGINE: instant_kill returns early under the "Embrace Pain" mark and
	# under a "Sealed Nightmare" IGNORE_DAMAGE effect, and execute_attempt calls instant_kill, so the
	# thresholded shape honours them too.
	#
	# TWO SHAPES, one op. Unconditional (no `hp_below`) calls instant_kill directly; thresholded
	# (`hp_below: N`) calls execute_attempt(N-1) so it kills a target AT OR BELOW N HP — the roster
	# carries both (aizen/ryuk are unconditional, the "finisher below X" shape is thresholded). It is
	# PER-TARGET, not a block `when`: a `when` fires once for the whole block, so on an `all_enemies`
	# execute it would kill everyone the moment ANY enemy is low. `hp_below` tests each target itself.
	#
	# `bypassing` because it is in REVALIDATED_OPS (see that list): instant_kill checks no
	# invulnerability of its own, so without the pool re-validation an authored AoE reaches through it.
	# NO forced cost/cooldown: those are authorable balance fields, and the standing rule is the
	# Creator invents no restriction the game lacks — the unconditional instant kill is already a
	# shipped, castable outcome.
	"execute":      {"fields": ["to", "hp_below", "bypassing"]},
	# BRING A DEAD ALLY BACK — the jeanne4 idiom (abilities/jeanne4.gd:19-22): dead = false,
	# health.set_health(amount), update.emit(). The ONLY op that acts on the dead, and the whole
	# reason the `dead_allies` pool exists (it deliberately skips _alive; every other pool drops the
	# dead). Its default `to` reads the targeter WITHOUT the _alive filter so it reaches the dead ally
	# that Layer-1 `include_dead` flagged in — the targeting half F shipped, of which this is the
	# acting half. `amount` is the revive HP and must be >= 1 (a 0-HP revive is instantly dead again).
	"revive":       {"fields": ["amount", "to"]},
	# DIRECT COOLDOWN CONTROL — reduce (negative) or lengthen (positive) the `cooldown_remaining` of
	# named skills on the selected characters. Matched BY NAME (`skills`), NEVER by index: a copied or
	# stolen skill runs from a caster whose slot order differs, and an index would reset the wrong one
	# (abilities/stark1.gd documents this exact failure).
	#
	# > THE SELF-RESET INFINITE-CAST EXPLOIT. execute_ability writes start_cooldown()
	# (new multiplayer/battle_manager.gd:1199) BEFORE it calls execute() (:1208-1214), so a skill that
	# reduces its OWN cooldown lands after the write and is instantly usable again — an unbounded cast.
	# The ordering is fixed, so there is no safe version: the validator refuses a negative cooldown op
	# that names (or, with an empty `skills`, implicitly includes) the ability containing it, and
	# BlockRunner refuses the same write independently (a hand-edited file never met the validator).
	# Lengthening your own, or touching ANY OTHER skill, is fine.
	"cooldown":     {"fields": ["to", "skills", "amount"]},
	# DRAIN THE TARGET TEAM'S ENERGY, optionally STEALING it. Energy is a TEAM pool
	# (scripts/team_component.gd), so two things the naive shape gets wrong:
	#   * DEDUPE BY TEAM. Draining two enemies drains the ONE shared pool once per point, not twice —
	#     BlockRunner collects the distinct teams behind the resolved targets and drains each once.
	#   * COUNT WHAT WAS ACTUALLY REMOVED. lose_energy (team_component.gd:99) silently pays what the
	#     pool can and charges the rest against the team's NEXT generation (denied_energy_generation)
	#     — a denial with NO cleanse answer. So a `steal` grants only the cash actually taken, measured
	#     before/after, never the nominal amount.
	# `amount` is a loop count inside lose_energy (range(val)), so it answers to max_energy_gain, the
	# same loop guard `gain_energy` uses. NO `bypassing`/revalidation: like `banish` this hits a team
	# resource, not a character, so a per-character invulnerability was never in the path (a shipped
	# drain reaches the pool behind an invulnerable defender too).
	"drain_energy": {"fields": ["amount", "to", "steal"]},
	# SKILL SEAL as a first-class op — the promise UNIVERSAL_EFFECT_FIELDS' skill_seal exclusion note
	# makes. Phase A shipped skill_seal as the MECHANIC (a MARK flag read by Ability.is_sealed_out,
	# abilities/scripts/ability_component.gd — Itachi's Totsuka Blade; Esdeath's Mahapadma and Yugi's
	# Swords used it too, but are now NON-ignorable STUNs — see Effect.ignorable), but the only
	# authorable shape was the unbounded "seal every skill" one. This exposes the three filter lists
	# is_sealed_out already reads, with a NAMED vocabulary:
	#   `classes`       -> class_targets   : seal only skills carrying one of these ability classes.
	#   `skills`        -> ability_targets : seal these skills BY NAME (a copied/stolen skill runs from
	#                      a caster whose slot order differs, so names, never indices).
	#   `exclude_skills`-> exclusion_targets: names EXEMPTED outright — beats every other filter.
	# All three empty is the shipped "seal everything" form (Totsuka Blade). It is NOT a stun: the seal
	# branch consults none of the stun escape hatches, which is exactly why an author who wants an
	# un-ignorable lockout reaches for it. Applied through Character.add_hostile_effect (it seals
	# ENEMIES), so like `apply`/`banish` it self-gates and is NOT in REVALIDATED_OPS; `bypassing` is
	# the same add_*_effect opt-out `apply` carries. `turns` is the author-facing duration.
	"seal":         {"fields": ["to", "turns", "classes", "skills", "exclude_skills", "bypassing"]},
}

# `remove`.stacks — the sentinel that means "the whole effect", as opposed to a count of stacks
# to spend. It is the DEFAULT, so the plain "take this away" form needs no number at all.
const REMOVE_ALL := "all"

# `cleanse`.scope. "hostile" is the historical (and default) behaviour — strip what
# the enemy put on you. "own" is a buff-strip.
const CLEANSE_SCOPES := ["hostile", "own", "any"]
# GROUNDED: shatter_shields and shatter_barrier are the engine's only two teardown entry
# points, and going through them (rather than erase_effect) is what fires the shipped
# "when my shield breaks" contingencies. Complete coverage — nothing to raise.
const BREAK_TARGETS := ["shield", "barrier", "both"]

# GROUNDED: an exact, complete mirror of DamageType.Type (scripts/types/damage_type.gd).
# All 7 members, no omissions — this whitelist cannot exclude anything the engine has.
const DAMAGE_TYPES := ["NORMAL", "PIERCING", "AFFLICTION", "BLEED", "TRUE", "PHYSICAL", "ENERGY"]

# Safety envelope for authored content. These are not balance knobs — they are
# the bounds that keep a malicious or broken block tree from hanging or
# corrupting a live match. Anything here that is merely "a number somebody had to
# write down" is set FAR above the shipped roster's maximum on purpose: a bound
# pinned to today's maximum is wrong the next time a character is added, and an
# authored character that cannot equal a shipped one is second-class by construction.
const LIMITS := {
	# RUNAWAY GUARD. The tree is walked on every cast inside turn resolution, so an
	# unbounded one would stall a live match. Counted recursively (nested `then`/`group`
	# payloads included). Real kits are an order of magnitude under this.
	"max_blocks_per_ability": 40,
	# RECURSION GUARD. A trigger whose payload applies a trigger is the one shape that
	# can recurse without bound at runtime; a payload is charged +2 so ~2 levels of
	# trigger nesting are reachable. BlockRunner enforces the same number independently
	# (defence in depth) — the validator can be bypassed by a hand-edited file, the runner
	# cannot.
	"max_nesting_depth": 4,
	# Pure sanity clamp on a magnitude, not a balance knob: a 500-damage block was already
	# lethal several times over, so a tight number bought no safety while making
	# "absurdly large on purpose" unauthorable.
	"max_amount": 9999,
	# SIGNED TURN-DELTA sanity envelope — NOT a duration cap. This bounds a *change* of ±N turns
	# (the `cooldown` op's amount, `adjust`.turns), which is a different quantity from an effect's
	# absolute duration. EFFECT DURATIONS are author-controlled and UNBOUNDED: `turns`/`ticks` accept
	# any integer including -1 (permanent) — see turns_to_duration / spec_duration and _validate_duration,
	# which no longer clamps them (the old `max_turns` duration cap was an invented limit, removed per the
	# owner ruling; many shipped effects tick forever). This delta bound only stops an int-overflow-scale
	# typo on a signed +/- turns field; ±99 is ~10x the roster's longest cooldown.
	"max_turn_delta": 99,
	# HOT-PATH GUARD. A trigger payload runs on an engine hook that can fire many times
	# per turn, so it is the hottest authored code path.
	"max_trigger_then_blocks": 12,
	# Stack ceilings are AUTHOR-controlled. Effect has no max_stacks field at all
	# (scripts/effect_component.gd: `var stacks = 1`), and 12 shipped abilities do a bare
	# `stacks += 1` with no ceiling whatsoever — astolfo1's Trap of Argalia is permanent and
	# gains +5 damage per use forever. These numbers only exist so a typo cannot produce an
	# effectively infinite counter.
	"max_stacks": 99,
	# LOOP GUARD on _op_gain_energy: gain_bonus_energy/gain_random_energy each grant one
	# point, so the amount is a loop count.
	"max_energy_gain": 25,
	# `repeat`.times. ITS OWN LIMIT, independent of max_amount, because a repeat is not a
	# magnitude: each repetition is a SEPARATE resolution, so it re-pays the minimum-damage floor,
	# re-tests damage reduction, and re-fires every receive-trigger on the target — including
	# another authored payload. A number that is merely "large" as damage is a hot loop as a
	# repetition count. Set above the roster's own maximum (gatomon11's range(9)) on purpose:
	# an authored character that cannot equal a shipped one is second-class by construction.
	# The 40-block ceiling bounds the PRODUCT independently (see _count_blocks), so nesting two
	# repeats cannot multiply past it.
	"max_repeat_times": 12,
	# The battle UI has FOUR slots, not four skills. 137 of the 173 shipped
	# characters carry more than four abilities; the extras are HIDDEN and reached
	# by an ability swap or a form change (frieza5, yoruichi5, kid6 are all hidden
	# swap-in targets). So the authored rule is "4 VISIBLE actives", and the total is
	# generous headroom over the roster's own maximum (14, ash/gatomon) rather than equal
	# to it. AuthoredAssets.SLOTS is sized from this and must grow with it.
	"max_abilities": 32,
	# GROUNDED, not invented: MovesetComponent.display_abilities() is a hard [0..3] slice
	# and server_active_abilities is only honoured at size()==4, so a fifth board skill
	# would simply never reach the wire. All 156 shipped ability_swap_effect calls replace
	# slot 0-3 and none replaces a higher one.
	"visible_skill_slots": 4,
	# NOTE: the AoE PRODUCT CEILING (max_aoe_product) and MAX_RESOLVABLE_FACTION are GONE. Widening a
	# skill's `shape` to "all" (a whole-faction AoE) multiplies its damage by the faction size — but "a
	# 100-damage AoE should be designable, it just would not be approved" (owner ruling). That is a
	# balance judgment for the approver, not a cap the engine enforces, so it is removed. The structural
	# work-ceilings (max_blocks_per_ability, max_repeat_times, _count_blocks' times*body product) still
	# bound COMPUTE independently, which is the only thing a shape:"all" cannot walk past.
}

static func damage_type_id(name: String) -> int:
	match name:
		"NORMAL": return DamageType.Type.NORMAL
		"PIERCING": return DamageType.Type.PIERCING
		"AFFLICTION": return DamageType.Type.AFFLICTION
		"BLEED": return DamageType.Type.BLEED
		"TRUE": return DamageType.Type.TRUE
		"PHYSICAL": return DamageType.Type.PHYSICAL
		"ENERGY": return DamageType.Type.ENERGY
	return DamageType.Type.NORMAL

# DERIVED from TRIGGERS, not a second copy of it. See the note on that table.
# -1 for an unknown hook name (a hand-edited file) and for a row whose EffectType member does not
# exist — self_check() is what turns the second case into a loud failure at authoring time.
static func trigger_hook_id(name: String) -> int:
	if not TRIGGERS.has(name):
		return -1
	var member := str(TRIGGERS[name])
	if not EffectType.Type.has(member):
		return -1
	return int(EffectType.Type[member])

static func energy_colour_id(name: String) -> int:
	match name:
		"green": return Energy.Type.GREEN
		"blue": return Energy.Type.BLUE
		"white": return Energy.Type.WHITE
		"red": return Energy.Type.RED
		"random": return Energy.Type.RANDOM
	return -1

static func immunity_effect_id(name: String) -> int:
	if name.begins_with("MISSION_TRIGGER_"):
		return -1
	for k in EffectType.Type.keys():
		if str(k) == name:
			return int(EffectType.Type[k])
	return -1

# Authored "N player turns" -> engine duration. The engine ticks durations on
# EVERY side's turn, so a duration of 2 lasts one of the holder's turns. A
# `delayed` DoT (fires once, N turns from now) needs the odd form.
static func turns_to_duration(turns: int, delayed := false) -> int:
	if turns < 0:
		return -1                      # permanent
	if delayed:
		return 2 * max(turns, 1) + 1
	return 2 * max(turns, 1)

# A DELTA in author turns -> a delta in engine ticks, for `adjust`.turns.
#
# DELIBERATELY NOT turns_to_duration. That function reads a negative as PERMANENT (-1) and floors
# the magnitude at 1, both of which are exactly wrong for a delta: "-1 turn" has to mean "two ticks
# less", not "forever". Only the sign handling differs — the 2N convention is the same one, and it
# is the same arithmetic the corpus writes by hand ("+2 duration = +1 player-facing turn",
# character/toji.gd:113-121; abilities/uzui5.gd:27; character/madoka.gd:31).
static func turns_to_delta(turns: int) -> int:
	return 2 * turns

# RAW engine duration, the escape hatch from the 2N convention. turns_to_duration can only
# ever produce an EVEN number, and the roster is full of odd ones — toudou1's counter is 3,
# broly2's is 5, rimuru2's paralyze is 3, kurotsuchi6/ganta5 tick for 9, alphonse5's
# def_negate is 1 — so roughly half the duration space was unreachable no matter what an
# author typed. `ticks` is the same plain int every shipped Effect factory takes, and it
# WINS over `turns` when present. Every effect kind accepts it; the friendly `turns` form
# stays the default.
static func spec_duration(spec, delayed := false) -> int:
	if spec is Dictionary and spec.has("ticks"):
		var raw := int(spec["ticks"])
		return -1 if raw < 0 else raw
	var turns := int(spec.get("turns", 1)) if spec is Dictionary else 1
	return turns_to_duration(turns, delayed)

# The swap-shaped sibling: `ticks` is raw either way, only the `turns` conversion differs.
static func spec_swap_duration(spec) -> int:
	if spec is Dictionary and spec.has("ticks"):
		var raw := int(spec["ticks"])
		return -1 if raw < 0 else raw
	return swap_turns_to_duration(int(spec.get("turns", 1)) if spec is Dictionary else 1)

# An ABILITY_SWAP is the one effect whose "N turns" is 2N+1 rather than 2N. It is
# applied on the caster's OWN turn and immediately eats a tick there, so 2N would
# expire it at the START of the author's Nth turn — one turn short of what the
# tooltip promises. Every shipped swap ships the odd form (gasai2 and yoruichi3
# both pass 7 for "3 turns"); this is separate from turns_to_duration on purpose,
# so nobody has to remember that `delayed` happens to compute the same number.
static func swap_turns_to_duration(turns: int) -> int:
	if turns < 0:
		return -1                      # permanent form change
	return 2 * max(turns, 1) + 1

# `recurring`.first — WHEN the first tick lands. `now` fires the payload once at cast; `next`
# waits for the author's next turn. Two values, and both are needed: the tick set is FROZEN at
# "new multiplayer/battle_manager.gd":1622 before start_round_loop() at :1640, so an effect planted
# this turn cannot appear in this turn's tick batch — `now` is the only way to make the payload land
# on the cast turn, and it does it the way every shipped kit does (a manual first instance).
const RECURRING_FIRSTS := ["next", "now"]

# The ENGINE DURATION a `recurring` plants, folding the manual-first-instance idiom the corpus
# hand-codes (abilities/fern3.gd:72-79, stark3.gd:53-58). tick_durations decrements EVERY effect on
# EVERY turn boundary (battle_manager.gd:1316), so a TICKING_TRIGGER loses 2 duration per full round
# while it fires once — on the author's turn — and never on the turn it was planted (the tick set is
# frozen before the round loop; see RECURRING_FIRSTS). A ticker planted with no manual instance
# therefore fires floor((D-1)/2) times. So for K author-turns of ticks:
#   * `now`  — BlockRunner fires the payload ONCE by hand at cast, and duration 2K-1 supplies the
#     other K-1 (floor((2K-2)/2) = K-1). Total K, starting this turn. This is the odd form fern3's
#     measured [10,10,10] ships (dur 5 for K=3).
#   * `next` — no manual instance; duration 2K+1 supplies all K (floor(2K/2) = K), the first on the
#     author's NEXT turn. This is fern3's own documented no-manual form: "Planting dur 7 with no
#     manual instance instead gives [0, 10, 10, 10]" — dur 7 = 2*3+1 for K=3. (2K would be a turn
#     SHORT — floor((2K-1)/2) = K-1 fires — which is exactly the "prose is a turn off" bug `first`
#     exists to close, so the roadmap's "2K" is corrected to 2K+1 here against the shipped evidence.)
# `ticks` stays the raw escape hatch (spec_duration honours it for every kind) and WINS over this,
# because an author who typed a raw tick count meant exactly that number; `first` then only decides
# whether the manual cast-turn instance also fires.
static func recurring_duration(spec) -> int:
	if spec is Dictionary and spec.has("ticks"):
		var raw := int(spec["ticks"])
		return -1 if raw < 0 else raw
	var turns := int(spec.get("turns", 1)) if spec is Dictionary else 1
	if turns < 0:
		return -1                      # permanent (author-controlled, like every effect duration)
	if str(spec.get("first", "next")) == "now":
		return 2 * max(turns, 1) - 1
	return 2 * max(turns, 1) + 1

# NOTE: there is NO recurring hostile-placement duration cap. A permanent recurring planted on an
# ENEMY is per-round damage for one cast — a strong effect an APPROVER weighs, not a restriction the
# engine has (the roster ships permanent enemy-facing tickers, e.g. Mayuri's drug rotation). The
# earlier RECURRING_HOSTILE_MAX_TURNS / recurring_hostile_cap_ticks and their validator+runner clamps
# were an invented balance cap, removed per the owner ruling: recurring durations are author-controlled
# exactly like every other effect duration.
