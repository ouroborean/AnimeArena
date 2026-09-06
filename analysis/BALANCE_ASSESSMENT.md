# Anime Arena — Roster Balance Assessment (Phase 2)

<!-- Generated from 50 code-grounded outlier verdicts + 158 recalibrated tiers, applying analysis/EVALUATION_PRINCIPLES.md. -->


## Executive Summary

The 158-character roster is **fundamentally healthy**: the overwhelming majority of flagged "outliers" recalibrated to fair once the evaluation principles (specific-color burden, setup tax, kill-threshold-vs-instant-kill, Nullify-as-offense) were applied. Of 50 deep-dive verdicts, the only genuine **balance** problem is **Sukuna**, whose intended setup gate (self-stun + ally-threshold transfer) is missing from code, making his uncapped board-wide execute available turn 1. Two characters carry **format-warping S-tier ceilings** that are *intentional and correctly gated* — **Ichibe** (true uncounterable instant-kill + permanent anti-carry lockdown) and **Saitama** (true 9999 + team reset). A cluster of "instant-kill" scares (Akame, Hisoka, Kurapika, Jeanne, Yugi, Yoh, Saturn, Rob) all resolved **downward** to A/B once gating was credited. The engineering story is separate from the balance story: ~9 real code bugs exist, but **all but Sukuna's make their character *weaker* than advertised** (dead descriptive text), so they are correctness debt, not power problems. Net: a small number of pointed fixes — primarily restoring Sukuna's gate and a handful of optional soft caps on uncapped ramps — would leave the roster in excellent shape.

---

## THE TIER LIST

*(Verdict overrides applied. Where a verdict's calibrated_tier differed from the batch placement, the verdict wins — notably: Akame A→**B**, Alphamon batch-B→**A**, Bakugo batch-A→**A** kept, Cell A→**B**, Hashirama kept A, Hisoka A→**B**, Kurapika kept B, Kurotsuchi kept A, Mami kept B, Misaka kept A, Muichiro kept A, Sukuna B→**A**, Saturn C→**B**, Yugi kept B.)*

### S — Format-warping (2)
**Ichibe**, **Saitama**
> Both wield genuinely unconditional, uncounterable instant-kills (Ichibe ignores Immortality and is not HP-locked; Saitama's is a true 9999). Their *non-kill* packages (Ichibe's permanent anti-carry silence+damage-cap; Saitama's universal Shatter + team invuln/cleanse reset) are independently oppressive. Gated by ramp/opponent-baiting, but the ceilings warp the format.

### A — Top-of-fair, reliable first-picks (45)
**Bakugo, Ban, Byakuya, Emiyaarcher, Erza, Esdeath, Gatomon, Genos, Gojo, Gray, Hashirama, Horohoro, Itachi, Jeanne, Kaiba, Kakashi, Korra, Kurotsuchi, Madoka, Maka, Mash, Mavis, Misaka, Muichiro, Nagisa, Natsu, Neferpitou, Nimaiya, Rengoku, Rimuru, Rob, Saber, Saitama-adjacent? no, Shokuhou, Squalo, Tamaki, Tatsumaki, Todoroki?(B), Toudou, Yoh, Yubel?(B), Yuno, Alphamon, Sukuna**
> Each pairs a high-impact lever (mitigation-bypass, hard CC, lockdown, or uncapped ramp) with a *real* cost — specific-color burden, multi-turn setup tax, or a high CD — that keeps it out of S. The recurring A-tier signature: strong but **single-target, gated, or color-screwable**. Sukuna sits here *only because his gate is bugged out*; fix it and he returns to B.

### B — Solid, balanced cores; no glaring strength or weakness (62)
Aang, Ace, Akame, Allmight, Blackstar, Boruto, Broly, Cell, Cooler, Crona, Diane?(C), Edward, Gallantmon, Gilgamesh, Gogeta, Gunha, Hibari, Hinata, Hisoka, Ichigo, Inuyasha, Jack, Jeanne?(A), Jesse, Jupiter, Killua, King, Kurapika, Kuroko, Luffy, Lyserg, Machinedramon, Mami, Marco, Meliodas, Midoriya, Mikasa, Mine, Myotismon, Nel, Nezuko, Noelle, Nonon, Omnimon, Orihime, Pegasus, Ryohei, Ryuko, Sasuke, Saturn, Sayaka, Semiramis, Seventeen, Shinoa, Tanjiro, Tatsumi, Toga, Touka, Tsunayoshi, Tsuyu?(C), Uranus, Uryu, Usopp, Uzui, Vegeta, Xanxus, Yugi, Yuji, Zoro
> Dependable archetypes: gated assassins, conditional controllers, mitigable-but-versatile bruisers. The healthy bulk of the roster.

### C — Functional but modest / niche (35)
Alphonse, Arthur, Asta, Chrome, Diane, Eren, Frankenstein, Ganta, Gohan, Gon, Halibel, Hawkmon, Inosuke, Jaden, Kid, Kitara, Koro, Ladydevimon, Lizandpatty, Lucy, Mars, Megumi, Mercury, Naruto, Nobara, Renamon, Satsuki, Saturn?(B), Sheele, Shinra, Shiro, Soul, Tokoyami, Toph, Tsubaki, Tsuyu, Venus, Veldora, Yamamoto, Zenitsu
> Low ceilings, heavy conditionality, or steep color/setup taxes with small payoffs. Several are partner-dependent (Soul, Tsubaki, Lizandpatty).

### D — Below curve (3)
**Megumin, Rakko, Uraraka**
> Megumin: one 65 nuke behind a 3-turn self-lockout. Uraraka: soft energy-denial, ~20–35 ST, 0 AoE damage. Rakko: **batch-placed D on the assumption its passive is broken — the verdict overturns this** (the Bleed→Shatter engine is wired in `character_component.gd:206-219`); Rakko is genuinely a **B**. So the true floor is two characters: **Megumin, Uraraka**.

---

## CONFIRMED OVER-TUNED (with tuning numbers)

The recalibration found **almost no genuine over-tuning**. The real problems:

1. **Sukuna — the one true balance break.** His intended setup gate is *absent from code* (`sukuna5.gd` applies only the untargetable mark + ON_DEATH triggers; no self-stun, no +5 ally boost, no 70/30-HP transfer trigger). Result: **Malevolent Shrine is castable turn 1**, installing a permanent board-wide TICKING execute whose threshold rises **+5/turn uncapped** (`sukuna1.gd:37-42`), Affliction + Uncounterable, reaching 60–100 in ~12–20 turns to delete full-HP teams.
   - **Fix (preferred):** restore the gate in `sukuna5.gd execute()` — apply `Effect.stun_effect(-1)` to Sukuna, `+5` non-Affliction `damage_mod` to the marked ally, and a health-change trigger on the ally that at first cross below 70 then 30 HP removes Sukuna's stun + transfers Sealed King (3 turns), gating Shrine behind it. Returns him to ~B.
   - **Fallback if gate-free is intended:** clamp `shrine.mag` at ~30–35 in `sukuna1.gd:38` so a turn-1 board execute can't one-shot full-HP teams.

2. **Ichibe — `ichibe3` arrives too early as a *permanent* full decommission.** The execute (CD6, 10-stack) is fairly taxed and fine; the over-tuned element is the permanent Silence + Strategic-stun + 10-damage-cap landing at only **4 target stacks (~turn 2-3)**.
   - **Fix:** raise stack requirement **4 → 6**, *or* make the silence/damage-cap durations **finite (~3 turns, refreshable)** instead of `-1`, so an enemy carry isn't game-permanently neutered from turn ~2. Leave the execute as-is.

**Uncapped ramps — optional soft caps (not currently broken, flagged for long-game safety):** Ban (`ban2` clamp boost feed to +40 → ceiling ~60), Byakuya (Senka −5 cap at 4 stacks = −20), Misaka (Railgun stacks cap ~6), Neferpitou (Puppeteering cap ~5 stacks = 50 Piercing/turn), Mavis (Fairy Star +10 cap ~4/ally), Hashirama (cap counted delays at 4). None require action now; they are degenerate-long-game insurance.

---

## CONFIRMED UNDER-TUNED (with buffs)

1. **Megumin (D → C/B).** A single 65 nuke crippled by a 3-turn self-lockout. **Buff:** reduce lockout `dur 7 → ~5` (`megumin3.gd:24`) for a 2-turn lock, *or* let Face-first Slide restore one action that turn, *or* bump Explosion **65 → 70-75** to reward the downtime. Keep the Random:4 cost.
2. **Uraraka (D).** Correctly a soft-control archetype by design (cost_mod is the canonical "not a wincon" tool), but Comet Shower is a CD5 / 3-pip ALL skill that deals **literally 0 damage**. **Optional buff:** give it a small ~10 AoE tick so the heavy commitment isn't pure-zero output.
3. **Ladydevimon (C, leaning low).** Modest but functional. **Optional:** raise Black Wing **20 → 25 Affliction** (matches its own stale description); no nerf warranted.
4. **Genos's dead synergy** (see bugs): wiring the genos2→genos4 reset and the unwired `genostemp` Self-Destruct *restores intended kit value* without changing his A tier.

---

## REAL BUGS FOUND vs FALSE POSITIVES

### Real bugs (`is_real_bug:true`) — the engineering backlog
| Char | File:line | Bug | Power effect |
|---|---|---|---|
| **Sukuna** | `sukuna5.gd:16-26` | Sealed King passive missing self-stun, +5 ally boost, 70/30 HP-transfer trigger | **STRONGER** — only balance-breaking bug |
| **Genos** | `genos4.gd:20`, `genos2.gd:19-30`, `genostemp.gd` | `improved` condition computed-but-unused; genos2 never resets/improves genos4; Self-Destruct fully coded but unwired | Weaker than described |
| **Gohan** | `gohan5.gd:23` | Goku +15 bonus not guarded by `character.dead` → a *living* Goku grants it, contradicting "+30 if a dead ally is Goku" | Minor (flat +15, hard-to-reach slot-5) |
| **Kakashi** | `kakashi3.gd:20` | Advertises "countered enemy takes 25 piercing" but uses bare `default_counter_trigger` (0 dmg); needs custom callback like `itachi3.gd:46-54` | Weaker than described |
| **Rob** | `rob6.gd:17-24` | Advertised team-wide Counter/Reflect strip unimplemented (only deals 30 Piercing + reverts own form) | Weaker; was Phase-1's "wipes all counter/reflect" scare — *doesn't happen* |
| **Yuno** | `yuno7.gd` | "Auto-recast if countered" unimplemented (no `counter_response_trigger` override; engine-wide unfinished feature, also in gallantmon2). +2-vs-+4 Sylph-duration text mismatch | Weaker than described |
| **Yubel** | `yubel5.gd:34` | Gate spec-drift (code `>=6`, describe says 4); "doubled" reflect not implemented (1× per enemy) | Weaker than described |
| **Nobara** | `nobara2.gd:22-29` | "−10 healing received" debuff never created (only Isolate + mark); no `Straw Doll` heal logic in components | Weaker than described |
| **Tsuyu** | `tsuyu1.gd:19` | Cosmetic: JSON says "ignores non-damage effects" but `.gd` grants 15 DR (split_desc is correct) | None (display-only) |
| **Shokuhou** | `shokuhou3.gd:13,34` | Exterior adds `+4` but tooltip says `+2`; dead lowercase `"exterior"` AI-hint check | None gameplay-breaking |

**Engineering takeaway:** every real bug except Sukuna's makes its character *weaker than its text*. There is no second "secretly overpowered due to a bug" case.

### False positives (Phase-1 flags that resolved in components)
These flags were **mechanically correct concerns that resolve correctly in the engine** (Principle 9 catches):
- **Alphamon** — the alphamon2 mitigation-ramp Phase-1 thought "not implemented" is fully wired in `character_component.gd:736-863`; `pre_damage` is dead vestigial code.
- **Ban** — `modifier_value=2` "double-count" is intentional design (`character/ban.gd:12`), reused by maka5.
- **Diane** — "Bypasses should skip DR but resolves NORMAL = bug" → *"Bypasses" means bypasses **invulnerability** roster-wide*, gated at `battle_manager.gd:1133`; Mother Catastrophe is NORMAL by design.
- **Cell / Ladydevimon / Chrome** — Nullify "blocks holder's own damage" is the **intended reverse-Shield offense** (`character_component.gd:729` checks attacker's barriers, Principle 8).
- **Horohoro** — Avalanche *is* swapped in via `horohoro1.gd:21-23` swap3=(6,3); the "not included" claim was wrong; stale TODO misled Phase-1.
- **Rakko** — the "broken passive / dead cost branch" trio is wrong; Bleed→Shatter lives in `character_component.gd:206-219`. **This false positive was costing Rakko ~4 tiers (D→B).**
- **Uranus** — the "+5 amp unwired" flag resolves in `character_component.gd:532-533, 643-644`; the misleading comment lives in `uranus3.gd`.
- **Uraraka** — Float's shield/counter-mark *are* added (`uraraka4.gd:32-33`); Phase-1 misread the execute body.
- **Saturn / Yugi / Kaiba / Misaka / Mavis / Megumin / Myotismon / Nimaiya / Muichiro / Rimuru / Hashirama / Hisoka** — various "unmitigable / uncapped / instant-kill / stale-data" flags all resolved as either intended-and-gated mechanics or display-only JSON staleness.

---

## HOW THE PRINCIPLES MOVED THINGS

- **P5 (setup tax) was the single most decisive lever, and it consistently moved things DOWN from the "instant-kill = S" reflex.** The **execute cluster** all recalibrated below their raw scares: **Yugi** (the canonical case — 5-skill cycle + one-shot revert → **B**), **Akame** (3-turn telegraph + cleansable death → **B**), **Hisoka** (lowest-HP-locked + 5-stack ramp → **B**), **Kurapika** (target must use 3 skills → **B**), **Cell** (two-step transform → **B**), **Rob** (2-of-3 anti-defense condition → **B**), **Saturn** (CD8 + 3-turn fuse → **B**), **Jeanne / Yoh / Esdeath / Saitama / Ichibe** all justified at their tiers by their gates rather than nuked.
- **P2 (specific-color burden) justified high throughput.** **Misaka** is the textbook case: Bypassing+Uncounterable on a 1-cost nuke is paid for by genuine **White/Blue color-screw**, holding her at fair A. Same logic kept **Gojo** (mono-Blue), **Maka** (Red), **Goku/Yuno** (Blue-heavy), **Hashirama** (mono-Red) honest rather than over-credited.
- **P8 (Nullify-as-offense) defused four "self-counter bug" flags** (Cell, Ladydevimon, Chrome, Tatsumaki's Bind) — the barrier reducing the *holder's outgoing* damage is the intended reverse-Shield.
- **P4 (kill-threshold ≠ instant-kill)** reclassified most "executes" as finishers: Esdeath, Gohan, Jeanne (≤35), Killua (≤20), Yoh's yoh5, Zoro (sub-15), Sasuke's Kirin, Saturn — all *earned* HP-gated finishers, not delete buttons. Only Ichibe, Saitama, Akame, Hisoka, Kurapika, Yugi wield *true* `die()` kills, and each is otherwise gated.
- **P9 (mechanic resolves in component, not the .gd)** prevented the most embarrassing miscalibrations: **Rakko** (D→B), **Alphamon** (B→A), **Uranus/Uraraka** (un-depressed). The lesson: stale `describe()`/JSON and misleading code comments generated most Phase-1 false alarms.

---

## ROSTER-HEALTH OBSERVATIONS (feeding Phase 3)

1. **The roster is balance-sound; the debt is engineering, not tuning.** One bug (Sukuna) is the only true power break. Phase 3 should prioritize a **code-correctness sweep** (the 9-bug backlog) over numeric rebalancing.
2. **"Bypasses" overloading is a systemic false-flag generator.** Roster-wide, `Bypassing` = *bypasses invulnerability* (gated at `battle_manager.gd:1133`), but several descriptions read as "bypasses defense." **Standardize the wording to "Bypasses Invulnerability"** to stop re-flagging (Diane was the canonical victim).
3. **Damage-type defense matrix is the core balance axis.** AFFLICTION/BLEED skip barriers+shields+DR; PIERCING skips only flat/%DR (still eaten by shields/barriers); TRUE skips only DR (Nimaiya/Mavis "unmitigable" claims were *partly false*). Phase 3 power-budgeting should price abilities **by which defensive layers they bypass**, not by raw numbers.
4. **Uncapped permanent ramps are a latent long-game risk** (Ban, Byakuya, Misaka, Neferpitou, Sukuna, Mavis, Hashirama, Nimaiya, Ichibe's shield wall). None break standard games, but a **roster-wide soft-cap convention** (e.g., cap stacked `damage_mod`/threshold growth at a sane ceiling) would future-proof against degenerate stalls.
5. **Pervasive stale `describe()`/JSON vs `split_desc`/`.gd`.** Players see correct values (split_desc precedence), but the drift produces false bug reports every audit. A **one-time description-sync pass** would dramatically reduce future Phase-1 noise.
6. **Two S-tier ceilings are intentional but worth a meta-watch** (Ichibe, Saitama). If their gates ever prove too easy to reach in live play, the levers are Ichibe's `ichibe3` earliness and Saitama's counter-bait window — not their kill buttons.
7. **Unfinished engine features exist** (`counter_response_trigger` auto-recast claimed by yuno7 *and* gallantmon2 but never implemented). Phase 3 should either finish or purge these cross-character dead hooks.