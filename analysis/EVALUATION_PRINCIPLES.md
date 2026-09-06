# Anime Arena — Balance Evaluation Principles

Weighting rules for assessing character/kit power. Derived from the designer's own model.
Apply ALL of these when rating power, picking outliers, or proposing tuning. They OVERRIDE naive
"raw pips / raw damage / has-an-execute" reads.

## 1. Cost: specific color >> Random pips
A Random (Energy index 4) pip is ~"always payable" — any color pays it, so a 1-Random skill is
functionally always usable. A specific-color pip (Green/Blue/White/Red) can be **unpayable on any given
turn** (color screw). So **total pip count is a misleading cost metric.** Effective cost is driven by the
**specific-color burden**, not the raw count. A 3-pip all-Random kit is far easier to pilot than a 3-pip
mono-color kit. Rank cost by specific-color load; treat Random pips as nearly free.

## 2. Higher specific-cost JUSTIFIES higher potency
Because specific-color skills are harder to pay, they are *designed* to be more potent. Misaka is the
canonical example: her throughput skills are specific-costing, so her high damage-per-pip is partly
**paid for** by color commitment (she is color-screwable). Do not flag specific-costing potency as an
outlier without accounting for the color tax.

## 3. Cooldown tiers (CD is a real lever in a fast game)
- **CD 0** = spammable.
- **CD 1** = anti-spam only (low significance).
- **CD 2+** = a genuine tempo commitment — significant, because the board state swings fast.
Weight a skill's payoff against its *availability*. A 2-CD nuke is materially more committal than a 0/1-CD one.

## 4. Executes are mostly kill-THRESHOLDS, not true instakills
Most "execute" mechanics are conditional ("kill a target at/below X HP") — i.e. a finisher, not "delete
anyone." Only the unconditional `9999` buttons (Saitama, Ichibe) are true instant-kills. Rank an execute by
**how hard its kill condition is to reach**, NOT by the word "execute." In practice many instant-kill kits
are far weaker than the concept implies.

## 5. Weight payoff by SETUP COST / time-to-online
A 60-damage skill behind a 2-energy super-form is worth far less than a turn-1 60: you pay the form's
energy + its cooldown + a tempo turn + the telegraph. Discount gated payoffs (transformations, ramp kits,
multi-skill chains) by their setup tax. **Example — Yugi:** his instant-kill requires using 5 OTHER skills
first; compare that to what a character accomplishes in ~6 total skill uses. Heavily gated ≠ over-tuned.

## 6. Energy drain is NOT a win condition
Drain only removes energy *left in the pool*. An opponent who spends to empty is immune to next-turn drain
and regenerates normally. So drain is tempo-interference/flavor, not a strategy to build around. The
slightly stronger cousin is **cost-taxing** (raising skill costs / making them unpayable, e.g. Uraraka's
`cost_mod`), but even that is soft. Treat energy-interference as a *supporting* tool, never a primary wincon.

## 7. Stealth = act without triggering reactive harmful effects
A Stealthed character does not trigger the defender's reactive harmful effects (counters, reflects, traps —
see `stealthable_triggers()`). Anti-stealth tools are largely unnecessary and not really possible; do not
treat "no anti-stealth" as a design gap.

## 8. Nullify = reverse-Shield (OUTGOING damage), not a defensive shield
- **Shield** prevents damage dealt **TO** its holder (defensive, absorbs incoming) — `check_damage_against_shielding(…, target)`.
- **Nullify / Barrier** prevents damage dealt **BY** its holder (offensive) — `check_damage_against_barriers(…, self=attacker)`.
Putting Nullify on an enemy makes *their* attacks hit softer. Read "gives enemies Nullify" as offensive
control/debuff, not as shielding the enemy.

## 9. Read mechanics across the COMPONENT scripts, not just the ability `.gd`
Many mechanics resolve in `character_component.gd` / `ability_component.gd` (damage pipeline, effect flags
like `health_drain`, mark/boost handling, on-kill/on-death triggers, `get_true_damage`) rather than in the
skill script. Before flagging anything as "missing / unimplemented / bugged," CHECK the components. Phase-1
profiles only read ability `.gd` files, so several "bugs" (myotismon lifesteal, nobara/uranus riders,
ban/esdeath boosts, rakko's engine) are likely FALSE POSITIVES — verify in the components first.
