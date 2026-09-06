# Character Tips — New-Player Corpus (Draft v1)

Brief tips for playing **with** and **against** each playable character, to surface at random in battle (a "playing as" tip when a character is on the board; a "playing against" tip between your turns). Generated from each character's live kit; **draft for review and refinement.**

- **Characters:** 168 &nbsp;·&nbsp; **"Playing as" tips:** 629 &nbsp;·&nbsp; **"Playing against" tips:** 543
- **Threat flags** used below: `counter` `trap` `invisible` `stealth` `transform` `execute` `stun-lock` `invuln` `burst` `sustain` `aoe` `dot` `disruption`
- Structured backing data (for the in-game feature) lives in [`character_tips.json`](character_tips.json).

---

## Aang
*Avatar: The Last Airbender* &nbsp;·&nbsp; `aang` &nbsp;·&nbsp; `transform` `aoe` `dot` `disruption` `burst`

**Core:** Elemental alignment cycling: using a skill that matches his current element empowers it and advances the loop Air->Water->Earth->Fire, and each skill also chains a bonus when used the turn after a specific other skill. Completing the full cycle grants Aang Avatar State.

**▶ Playing as Aang**
- Start Air-aligned and use the skill matching your current element to cycle Air->Water->Earth->Fire toward Aang Avatar State.
- Aligned skills gain bonus damage and effects, so line up your alignment with the skill you actually want to fire.
- Chain combos: Fire Kick after Air Sphere adds team affliction that Bypasses Invulnerability, and Water Whip after Earth Pillars stuns three skill schools.
- Earth Pillars after Fire Kick adds a per-turn affliction tick, and Air Sphere after Water Whip cuts the target's damage by 20.

**⚔ Playing against Aang**
- Track his alignment: matching-element skills hit harder and completing the Air->Water->Earth->Fire cycle grants him Aang Avatar State.
- After Air Sphere expect team-wide affliction that Bypasses Invulnerability; after Earth Pillars expect Water Whip's multi-school stun.
- Earth Pillars caps your next skill's damage at 10 (two skills if he is Earth-aligned), so don't dump a big hit into it.

---

## Adam
*Record of Ragnarok* &nbsp;·&nbsp; `adam` &nbsp;·&nbsp; `counter` `invisible`

**Core:** Adam runs on Divine Counter, an Invisible counter enemies can't see coming, plus Eye Strain, a passive that banks a stack every time an enemy uses a Harmful skill and grants a permanent +5 damage at 5 stacks.

**▶ Playing as Adam**
- Set Divine Counter early; it's Invisible, so opponents can't tell it's armed before they swing into it.
- Let enemies keep attacking, since each Harmful skill builds Eye Strain toward a permanent +5 damage ramp.
- Plan around the 5-stack Blind, because you can't gain Eye Strain while Blinded and lose all stacks.
- Lead with Divine Power Replication when you need a play that simply cannot be countered.

**⚔ Playing against Adam**
- Beware Divine Counter: it's an Invisible counter, so assume it may be up and avoid feeding it a big attack.
- Don't spam Harmful skills into Adam, since every one stacks Eye Strain and permanently raises his damage.
- Don't waste a counter on Divine Power Replication, which is Uncounterable.

---

## Agatsuma Zenitsu
*Demon Slayer* &nbsp;·&nbsp; `zenitsu` &nbsp;·&nbsp; `counter` `invuln`

**Core:** Buff-stacking setup: Speed of Thunder and Thunder Release permanently raise his damage and, until each is re-used, load First Form: Thunderclap and Flash with a defensive or punish effect; with both active First Form becomes two piercing hits instead of one.

**▶ Playing as Agatsuma Zenitsu**
- Open with Speed of Thunder and Thunder Release; both permanently add 5 damage to First Form and Thunder Release.
- With both buffs active, First Form: Thunderclap and Flash splits into two 15-piercing hits instead of a single 30.
- Speed of Thunder's First Form makes you invulnerable to non-Strategic skills for a turn; keep Falling Maneuver for a full 1-turn invulnerability.

**⚔ Playing against Agatsuma Zenitsu**
- Respect his invulnerability windows: Falling Maneuver and Speed of Thunder's First Form each block damage for a turn, so don't burn key attacks into them.
- Thunder Release loads a permanent piercing punish onto enemies who use new non-Strategic skills on him, so pressure him with Strategic skills instead.
- His piercing damage climbs permanently as he re-uses his setup skills, so deny him free setup turns.

---

## Ai Ohto
*Wonder Egg Priority* &nbsp;·&nbsp; `aiohto` &nbsp;·&nbsp; `execute` `dot` `sustain` `invuln` `burst`

**Core:** A Piercing self-sustain carry: Pen-Light Charges adds Affliction and heals off all her damage, while Now I'm Mad! is a snowballing finisher that heals, grants Immortal, and resets its own cooldown on a kill.

**▶ Playing as Ai Ohto**
- Fire Weapon: Pen-Lights to strip a target's Shields, which also cheapens Now I'm Mad! by turning its Green cost to Random.
- Kill with Now I'm Mad! to trigger Ai Reset — you heal, gain Immortal, and its cooldown resets for another swing.
- Lean on Pen-Light Charges: every hit adds 5 Affliction and heals Ai, so keep dealing damage to stay topped up.
- Cast Weapon: Gymnastics Ribbon before diving to gain damage reduction and punish attackers with 10 Piercing.

**⚔ Playing against Ai Ohto**
- Respect Now I'm Mad!'s uncounterable 30 Piercing — a kill heals Ai, makes her Immortal, and resets it to fire again, so deny the kill.
- Don't rely on Shields: Weapon: Pen-Lights makes targets ignore them and her Piercing cuts through anyway.
- Attacking Ai under Gymnastics Ribbon backfires with 10 Piercing and a permanent damage-taken increase, so wait it out.
- I KICK IT HOW I WANNA KICK IT gives her Invulnerability — bait it before committing lethal.

---

## Akame
*Akame ga Kill* &nbsp;·&nbsp; `akame` &nbsp;·&nbsp; `execute` `invuln`

**Core:** Mark-and-execute: Red-Eyed Killer marks a target so One Cut Killing can hit it, and once One Cut Killing lands the target dies two turns later. Little War Horn removes the mark requirement so One Cut Killing can hit anyone.

**▶ Playing as Akame**
- Mark with Red-Eyed Killer, then land One Cut Killing to plant a kill that triggers two turns later.
- Little War Horn lets One Cut Killing hit any target and grants Physical invulnerability for 2 turns, a flexible execute window.
- Use Rapid Deflection's 1-turn invulnerability to stall safely while your delayed kill counts down.

**⚔ Playing against Akame**
- One Cut Killing is a delayed EXECUTE: once it connects, that target dies two turns later, so race Akame down or protect the victim.
- Red-Eyed Killer's mark is the usual tell, but Little War Horn bypasses it entirely, so no ally is safe during those turns.
- She has invulnerability from Rapid Deflection and Physical-immunity from Little War Horn, so don't waste key hits into them.

---

## All Might
*My Hero Academia* &nbsp;·&nbsp; `allmight` &nbsp;·&nbsp; `burst` `sustain`

**Core:** Self-damaging piercing bruiser: Texas Smash and United States of Smash deal large Uncounterable piercing damage at the cost of self-affliction, while United Resolve turns being under 40 HP into an Immortal turn plus a damage spike.

**▶ Playing as All Might**
- Texas Smash and United States of Smash are Uncounterable piercing nukes, but each self-inflicts affliction, so watch your own HP.
- Under 40 HP, United Resolve makes you Immortal for a turn and boosts next-turn damage (+20 if you took new damage), a comeback swing.
- Declare Successor is a one-time buff giving an ally One For All and cheaper Random costs; pick your key attacker, since it also raises your self-affliction.

**⚔ Playing against All Might**
- Don't rely on counters: Texas Smash and United States of Smash are Uncounterable and pierce straight through.
- Below 40 HP he is most dangerous, since United Resolve grants Immortality for a turn plus a big damage boost, so burst him past it or wait out the Immortal turn.
- Every big hit self-inflicts affliction, so chip and damage-over-time can finish him after he swings.

---

## Alphamon
*Digimon* &nbsp;·&nbsp; `alphamon` &nbsp;·&nbsp; `invuln` `aoe` `disruption` `burst`

**Core:** A mitigation-punisher: Blade of the Dragon King permanently grows stronger whenever it's shielded, damage-reduced, or Nullified, while Digitalize of Soul plants a self-fueling tick engine that chips enemies every turn.

**▶ Playing as Alphamon**
- Land Digitalize of Soul early to plant permanent Shield on yourself and Nullify on enemies, turning both into per-turn chip damage.
- Fire Blade of the Dragon King straight into shields or damage reduction — every point mitigated permanently raises its damage.
- Use AlphaBlast to Shatter a target before committing, and don't fear counters: Alpha inForce refunds the energy and heals 15.
- Save inForce Avoidance's one-turn Invulnerability to skip a lethal enemy turn or their biggest burst window.

**⚔ Playing against Alphamon**
- Never shield, damage-reduce, or Nullify against Blade of the Dragon King — mitigating it permanently boosts its damage forever.
- Do not counter his skills: Alpha inForce refunds his spent energy and heals him 15 on every countered cast.
- Respect the inForce Avoidance Invulnerability turn — bait it out before you commit your team's damage.
- Digitalize of Soul quietly ticks 10 to your whole team plus 20 per lingering Nullify each turn, so end the game before it snowballs.

---

## Alphonse Elric
*Fullmetal Alchemist* &nbsp;·&nbsp; `alphonse` &nbsp;·&nbsp; `aoe` `disruption`

**Core:** A setup-gated tank: Transmutation Circle unlocks Weapon Alchemy and Destruction Alchemy Strike and swaps itself into the AoE Ground Pillars, while Golem Armor stacks endless permanent damage reduction.

**▶ Playing as Alphonse Elric**
- Open with Transmutation Circle to gain energy, unlock your offense, and convert the skill into the AoE Ground Pillars.
- Refresh Golem Armor over time to keep 30 Shield up and stack permanent damage reduction into an unkillable frontline.
- Destruction Alchemy Strike deals affliction, strips a random energy, and marks — but you can't re-hit a marked target, so spread it around.
- Buff an ally with Weapon Alchemy for a free 15 piercing hit, remembering you can't stack it on an already-affected ally.

**⚔ Playing against Alphonse Elric**
- Pressure him during setup — his offense is offline until Transmutation Circle resolves.
- Burst him down before Golem Armor's damage reduction stacks make him unkillable, since it grows every refresh.
- Ground Pillars hits your entire team and Shatters them, so don't lean on shields the turn he can fire it.
- Expect Destruction Alchemy Strike to strip a random energy and mark your character for 2 turns.

---

## Android 17
*Dragon Ball* &nbsp;·&nbsp; `seventeen` &nbsp;·&nbsp; `dot` `aoe` `disruption` `burst`

**Core:** A random-energy scaling snowball: Infinite Energy Cycling ramps his skills' random-energy cost each cast, and every offensive skill hits harder the more random energy it costs — until he casts a 3-energy skill to reset the stacks.

**▶ Playing as Android 17**
- Let Infinite Energy Cycling ramp — each skill adds random energy and raises future costs, supercharging everything you cast.
- Fire Hell Breaker and Photon Flash while costs are high for extra permanent affliction stacks and extra random AoE targets.
- Deliberately cast a 3-energy skill to wipe the stacks before costs spiral unpayable, then rebuild the ramp.
- Use Android Assault to tax an enemy's skill costs, and feed it random energy to stretch the debuff longer.

**⚔ Playing against Android 17**
- Kill or cleanse him before Hell Breaker's permanent Affliction stacks pile up — that damage ignores mitigation.
- Photon Flash Bypasses your defenses and Invulnerability, and splashes extra random targets as his energy ramps.
- The longer his Infinite Energy Cycling snowballs, the bigger his burst — deny him the ramp or race it.
- Android Assault inflates your skill costs by random energy, so plan for tighter turns after he hits you.

---

## Arthur Boyle
*Fire Force* &nbsp;·&nbsp; `arthur` &nbsp;·&nbsp; `invisible` `transform` `execute` `burst` `disruption`

**Core:** An Invisible setup burst with a life-or-death threshold: Plasmantle and Nirvana convert incoming and outgoing damage into Shield/Nullify that Violet Flash consumes for a spike, and below 50 HP Star Ring transforms Violet Flash into the uncounterable, suicidal execute Moon Splitting Violet Flash.

**▶ Playing as Arthur Boyle**
- Pre-load Plasmantle so an enemy's Harmful hit becomes Shield, then dump that Shield into Violet Flash for a huge strike.
- Cast Nirvana on the enemy's main threat: it converts their next damage into Nullify that Violet Flash then consumes for bonus damage.
- Below 50 HP, Star Ring transforms Violet Flash into Moon Splitting Violet Flash — an uncounterable 45 affliction nuke that executes sub-20 targets but kills Arthur.
- All your setup is Invisible, so bait the enemy into committing before they realize your defenses and marks are live.

**⚔ Playing against Arthur Boyle**
- His Plasmantle, Nirvana, and Star Ring are all Invisible — assume defenses and marks are up even when you see nothing.
- Below 50 HP he transforms via Star Ring into Moon Splitting Violet Flash, an uncounterable execute on sub-20 HP targets, so keep low allies clear.
- Don't feed Plasmantle: a Harmful hit the turn it's up just converts your damage into his Shield.
- Nirvana turns your attacker's damage into Nullify, wasting your turn — play around the mark before swinging.

---

## Asakura Yoh
*Shaman King* &nbsp;·&nbsp; `yoh` &nbsp;·&nbsp; `execute` `transform` `sustain` `disruption`

**Core:** Over Soul stance-stacking: layering Amidamaru Over Soul on top of Spirit of Sword or White Swan upgrades his Halo Blade into either Grand Halo Blade (an execute) or The Absence of Ignorance (an uncounterable HP-drain).

**▶ Playing as Asakura Yoh**
- Open with Amidamaru Over Soul to double Halo Blade and start the per-turn healing, then stack a second stance.
- Combine Amidamaru + Spirit of Sword so Halo Blade becomes Grand Halo Blade, executing any enemy at or below 40 HP.
- Combine Amidamaru + White Swan for The Absence of Ignorance, which cuts an enemy's HP by Yoh's own current HP, so stay high.
- Remember Spirit of Sword and White Swan lock each other out, so commit to one stance line per matchup.

**⚔ Playing against Asakura Yoh**
- Respect Grand Halo Blade's EXECUTE once he's stacked Amidamaru + Spirit of Sword; don't leave an ally at or below 40 HP.
- The Absence of Ignorance is Uncounterable and isn't damage, so defenses won't stop it; burst Yoh down before it resolves.
- During Spirit of Sword he ignores Harmful non-damage effects, so stuns and debuffs won't stick.
- White Swan caps his incoming damage to 20 and heals him off Halo Blade, so chip him rather than feeding big hits.

---

## Asta
*Black Clover* &nbsp;·&nbsp; `asta` &nbsp;·&nbsp; `counter` `sustain` `disruption`

**Core:** A sword-swapping auto-attacker: Liebe Unite fires a free 15-damage end-of-turn strike for the rest of the game, and the equipped sword reshapes that hit; HP thresholds unlock a counter (below 70) and dual-wielding (below 40).

**▶ Playing as Asta**
- Activate Liebe Unite early so the free 15-damage end-of-turn attack runs every turn for the rest of the game.
- Swap swords to shape that auto-attack: Demon-Slayer marks, Demon-Dweller heals or shields, Demon-Destroyer adds +10 damage.
- Mark with Demon-Slayer, then hit a marked enemy with a different sword to consume the mark and taunt them.
- Once below 40 HP, dual-wield to pair Demon-Destroyer's damage with Demon-Dweller's sustain.

**⚔ Playing against Asta**
- Below 70 HP Asta gains a COUNTER, hitting the first to target him each turn for 10, so don't poke him carelessly.
- Liebe Unite deals unavoidable end-of-turn damage every turn, so race it or heal through the chip.
- Watch the Demon-Slayer mark; it sets up a TAUNT that locks one of your characters onto him for a turn.
- Dropping him below 40 HP lets him dual-wield and spike output, so burst clean through the threshold or finish him.

---

## Astolfo
*Fate* &nbsp;·&nbsp; `astolfo` &nbsp;·&nbsp; `invisible` `invuln` `aoe` `disruption`

**Core:** A durable disruption support with no burst engine: he layers self-protection (stun-immune, uncounterable Invulnerability, passive Damage Reduction) with AoE Silence/Isolate, damage-boost denial, and a hidden pre-emptive nullify.

**▶ Playing as Astolfo**
- Cast Casseur de Logistille early on yourself or an ally — it's Invisible until it eats the next Harmful non-Physical skill.
- Use La Black Luna to hit the whole enemy team for 15 damage plus a Silence and Isolate.
- Spam Trap of Argalia on a damage dealer to lock their damage-boosts while its +5-per-use scaling climbs.
- Akhilleus Kosmos gives uncounterable, unstunnable Invulnerability — use it to walk through a counter or stun turn.

**⚔ Playing against Astolfo**
- Casseur de Logistille is an Invisible nullify that ignores your next non-Physical Harmful skill, so probe with Physical skills first.
- Akhilleus Kosmos makes Astolfo Invulnerable and can't be stunned or countered, so never dump burst into that turn.
- His Hippogriff passive gives 15 Damage Reduction and stun immunity while untouched, so keep chipping him each turn.
- La Black Luna can Silence and Isolate your entire team — respect his AoE setup turn.

---

## Asui Tsuyu (Froppy)
*My Hero Academia* &nbsp;·&nbsp; `tsuyu` &nbsp;·&nbsp; `invuln` `dot` `disruption`

**Core:** A flexible control-support who uses Tongue Lash as a setup: whichever target it's on, Great Leap follows up to either stun an enemy or make an ally Invulnerable, backed by strong self-invuln uptime.

**▶ Playing as Asui Tsuyu (Froppy)**
- Tongue Lash an enemy, then Great Leap to add damage and stun them for a turn.
- Or Tongue Lash an ally, then Great Leap to make that ally Invulnerable for a turn.
- Frog Mucus softens an enemy's damage or hardens an ally, while Camouflage is your emergency 1-turn Invulnerability.
- Great Leap already makes Tsuyu invulnerable to non-Strategic skills, so chain it with Camouflage to dodge burst turns.

**⚔ Playing against Asui Tsuyu (Froppy)**
- Expect the Tongue Lash into Great Leap combo, which stuns whichever enemy she marked.
- She has heavy INVULN uptime between Great Leap and Camouflage, so save big hits for turns she isn't protected.
- Tongue Lash on her ally telegraphs an incoming Great Leap Invulnerability, so pressure a different target instead.

---

## Bakugo Katsuki
*My Hero Academia* &nbsp;·&nbsp; `bakugo` &nbsp;·&nbsp; `burst` `aoe` `disruption` `dot` `invuln`

**Core:** Nitroglycerin Storage snowball: every non-Strategic skill permanently adds +5 damage, growing his piercing hits each turn, while Stun Grenade briefly unlocks the big Hauser Impact payoff (which resets those stacks).

**▶ Playing as Bakugo Katsuki**
- Use a non-Strategic skill every turn to keep stacking Nitroglycerin Storage's permanent +5 damage.
- AP Shot ignores invulnerability and Shatters the target, stripping Shields, so use it to punch through defenses.
- Cast Stun Grenade to lock enemy Strategic skills and unlock Hauser Impact as a one-turn burst finisher.
- Explosive Dash gives a 1-turn Invulnerability to survive burst turns; time Hauser Impact carefully since it resets your stacks.

**⚔ Playing against Bakugo Katsuki**
- AP Shot ignores invulnerability and Shatters you, so don't rely on Shields or invuln to block Bakugo.
- Nitroglycerin Storage permanently grows his damage each turn, so end the fight before his hits balloon.
- Stun Grenade locks all your Strategic skills for a turn and sets up Hauser Impact, so expect the BURST after.
- Detonating Touch punishes using a new non-strategic skill with 10 affliction, so consider a defensive turn instead.

---

## Ban
*Seven Deadly Sins* &nbsp;·&nbsp; `ban`

**Core:** The kit text supplies no ability descriptions, so no special engine is discernible; the class tags show a straightforward Harmful damage kit across Energy, Physical, and Mental, with one Bypassing skill (Banishing Kill) and an undescribed Passive (Undead Ban).

**▶ Playing as Ban**
- Save Banishing Kill for enemies who go Invulnerable — its Bypassing class punches straight through invuln turns.
- The rest is plain Harmful damage across Energy, Physical, and Mental, so lead with whichever energy color you have banked.
- You also carry a Passive, Undead Ban; treat it as an always-on threat and keep applying pressure while it works.

**⚔ Playing against Ban**
- Invulnerability will not save you against Ban — Banishing Kill Bypasses it, so do not burn an invuln turn expecting to blank his hit.
- Beyond that, his shown kit is ordinary Harmful damage with no counters or traps revealed, so trade normally and respect his Passive, Undead Ban.

---

## Black Star
*Soul Eater* &nbsp;·&nbsp; `blackstar` &nbsp;·&nbsp; `counter` `invuln` `disruption` `dot`

**Core:** Black Star runs two toggles: re-casting Speed Star enhances him with a self-invuln and makes Black Star Big Wave Uncounterable, while Tsubaki: Enchanted Sword Mode taunts and amplifies his follow-ups, all backing a heavy counter-punish core in The Unexplored Path.

**▶ Playing as Black Star**
- Open with Speed Star, then re-cast it next turn for the invuln and to unlock Big Wave's Uncounterable stun.
- Throw The Unexplored Path at Counter holders — it is Uncounterable and deals +10 to counter effects and +10 to Enchanted-Sword targets, stacking.
- Use Tsubaki: Enchanted Sword Mode to Taunt, gain 5 DR, and set up bonus damage from The Unexplored Path and Shadow Star.
- Tsubaki: Smoke Bomb buys a free invuln turn and, with Enchanted Sword Mode up, makes your next-turn skills Bypass.

**⚔ Playing against Black Star**
- Do not hold Counter effects — The Unexplored Path is Uncounterable and hits counter holders for an extra 10 damage.
- Respect his invuln windows from enhanced Speed Star and Tsubaki: Smoke Bomb — do not dump burst into them.
- Tsubaki: Enchanted Sword Mode Taunts you onto him behind 5 DR, and Shadow Star punishes you for hitting him while enchanted.
- Expect an Uncounterable 1-turn stun from Black Star Big Wave once Speed Star is active.

---

## BlackWarGreymon
*Digimon* &nbsp;·&nbsp; `blackwargreymon` &nbsp;·&nbsp; `disruption` `invuln` `burst`

**Core:** A tempo-denial and anti-defense bruiser: Black Tornado taxes Strategic energy and punishes acting, Dragon Crusher caps enemy damage, and Terra Destroyer strips all Shields/Nullify while scaling off them.

**▶ Playing as BlackWarGreymon**
- Open with Black Tornado to tax enemy Strategic skills and chip anyone who uses a new skill over its 4 turns.
- Use Dragon Crusher to cap a big threat's damage at 20 — the cap lasts 2 turns on Black Tornado targets.
- Save Terra Destroyer to wipe all Shields and Nullify on the field, gaining +5 damage per effect removed for a 35+ hit.
- Pop Uncrested Shield for Invulnerability to survive a turn; his passive already ignores non-damage effects.

**⚔ Playing against BlackWarGreymon**
- Don't stack Shields or Nullify against him — Terra Destroyer removes them all and grows stronger for each one.
- Black Tornado punishes using new skills and taxes Strategic energy, so sequence turns to avoid the 10 Piercing chip.
- His Dark Creation passive Isolates him and ignores non-damage effects, so stuns and debuffs won't stick — rely on raw damage.
- Uncrested Shield gives him Invulnerability, so bait it before committing your burst.

---

## Broly
*Dragon Ball* &nbsp;·&nbsp; `broly` &nbsp;·&nbsp; `counter` `transform` `burst` `aoe` `invuln` `dot` `sustain`

**Core:** Broly is a punish-tank: Legendary Super Saiyan gives him permanent +5 damage every time a Harmful skill hits him, and at 4+ stacks it upgrades Explosive Wave into the AoE nuke Planet Geyser Wave while fueling Powered Shell Protect's healing.

**▶ Playing as Broly**
- Let yourself get hit by Harmful skills — each one permanently adds 5 damage and builds toward the Planet Geyser Wave unlock.
- At 4+ Legendary Super Saiyan stacks, fire Planet Geyser Wave for 30 Piercing AoE, but note it resets your stacks.
- Powered Shell Protect gives an invuln turn and heals 10 per stack, so pop it when stacked high.
- Eraser Cannon counters the target's next Harmful skill, Gigantic Slam stuns non-Strategic skills, and Explosive Wave Shatters the whole team.

**⚔ Playing against Broly**
- Attacking Broly feeds Legendary Super Saiyan for permanent damage growth — avoid over-committing Harmful skills into him.
- At 4+ stacks he unlocks Planet Geyser Wave, a 30 Piercing AoE burst, so do not leave the team low together.
- Eraser Cannon is a counter trap: your next new Harmful skill gets countered for 10 damage, so bait it or answer with Strategic tools.
- His Powered Shell Protect invuln heals heavily when stacked — do not throw burst into that turn.

---

## Byakuya Kuchiki
*Bleach* &nbsp;·&nbsp; `byakuya` &nbsp;·&nbsp; `dot` `invisible` `transform` `burst` `aoe` `invuln` `stun-lock`

**Core:** Byakuya is a ramping bleed engine: Scatter, Senbonzakura applies a permanent invuln-piercing damage-over-time, and after 4 skills his Bankai spreads it to every enemy while unlocking the AoE finisher White Imperial Sword, with an invisible Senka trap adding pressure.

**▶ Playing as Byakuya Kuchiki**
- Land Scatter, Senbonzakura early for permanent 10 Piercing per turn that Bypasses Invulnerability, then spend 1 Red to spike 20 or retarget.
- Use any 4 skills to release Bankai, applying Scatter to all enemies and enabling White Imperial Sword's 90 Piercing AoE.
- Senka is invisible and punishes passivity — if they skip a new skill they eat 15 Piercing and a permanent -5 damage.
- Bakudo #61 Shatters and Stuns for 2 turns, and Bakudo #81: Airtight banks a safe invuln turn.

**⚔ Playing against Byakuya Kuchiki**
- Scatter, Senbonzakura is a permanent bleed that Bypasses Invulnerability — invuln will not stop it, so you must race Byakuya down.
- Senka is invisible; you cannot see it coming, so use a new skill every turn to avoid its 15 Piercing and permanent damage cut.
- After 4 skills his Bankai spreads Scatter to your whole team and arms White Imperial Sword — a 90 Piercing AoE that also bypasses invuln.
- Bakudo #61's 2-turn Shatter-and-Stun is a long lockout, so play around it.

---

## Cell
*Dragon Ball* &nbsp;·&nbsp; `cell` &nbsp;·&nbsp; `transform` `burst` `dot` `aoe` `sustain` `disruption`

**Core:** A transformation-threshold engine: Genetic Perfection transforms Cell whenever an enemy dies under Absorption or lets its Nullify expire unbroken, and each transform upgrades his kit and adds +5 to Perfected Combat.

**▶ Playing as Cell**
- Cast Absorption to force a break-or-suffer choice: failing to break its 25 Nullify, or dying under it, transforms you via Genetic Perfection.
- Land Absorption on a target at 30 HP or less to also Stun them for a free follow-up.
- Each transformation adds +5 to Perfected Combat and unlocks stronger skills, so trigger Genetic Perfection early and often.
- Once transformed, close with Bypassing finishers Inherited Kamehameha (40 Piercing) and Inherited Death Beam to ignore enemy defenses.

**⚔ Playing against Cell**
- Break Absorption's 25 Nullify before it expires and never let a low ally die under it — both transform Cell via Genetic Perfection.
- Keep Absorbed allies above 30 HP or Absorption also Stuns them.
- Fully transformed, Cell's Inherited Kamehameha (40 Piercing) and Inherited Death Beam Bypass your defenses — respect that burst.
- Rampant Energy Rain is a Channel hitting 3 random targets each turn; stun or kill Cell to break it.

---

## Chrome Dokuro
*Katekyo Hitman Reborn* &nbsp;·&nbsp; `chrome` &nbsp;·&nbsp; `dot` `disruption` `sustain` `aoe`

**Core:** Nullify-as-punishment plus an Empower state: her Illusions place Nullify that damages or stuns enemies who fail to break it, and Rokudo Takeover Empowers her whole kit for 3 turns.

**▶ Playing as Chrome Dokuro**
- Her Nullify punishes enemies who fail to break it, so stack Flame Pillar (25 Affliction) and Snake Bind (Pierce + Stun) and let it expire.
- Open with Rokudo Takeover to Empower for 3 turns — Flame Pillar then hits all enemies and Snake Bind lasts longer.
- Rokudo Takeover costs nothing at 40 HP or below and heals 15, doubling as your sustain and your power spike.
- Use Illusion: Broken Ground to cut enemy damage; while Empowered it isn't removed when they attack.

**⚔ Playing against Chrome Dokuro**
- Chrome's Nullify is a punish, not a shield — break Snake Bind's 25 to avoid its Piercing + Stun and Flame Pillar's to dodge 25 Affliction.
- After Rokudo Takeover (Empower), Flame Pillar becomes team-wide and her Illusions linger longer — bait it or race the window.
- Broken Ground normally drops when you use a Harmful skill, but not while she's Empowered.

---

## Cooler
*Dragon Ball* &nbsp;·&nbsp; `cooler` &nbsp;·&nbsp; `counter` `invisible` `transform` `stun-lock` `dot` `disruption`

**Core:** A mark-and-transform loop with a hidden counter: Death Chaser marks and swaps into Sadistic Tread for a stun, and Cruel Transformation grants Final Form whenever he hits a stunned enemy, drops a target below 50 HP, or triggers Nova Chariot.

**▶ Playing as Cooler**
- Chain Death Chaser (mark) into Sadistic Tread (25 + Stun), then Death Chaser the stunned target to trigger Cruel Transformation.
- In Final Form Cooler is unstunnable, Supernova detonates instantly, and Death Chaser is cheaper — keep triggering to stay transformed.
- Nova Chariot grants Invisible 25 Damage Reduction and punishes attackers with +10 Death Chaser next turn; it even works while Stunned.
- Darkness Eye Laser Bypasses defenses and caps the target's HP, locking a low enemy before you finish them.

**⚔ Playing against Cooler**
- Respect Nova Chariot: it's an Invisible 25 Damage Reduction counter, and hitting Cooler during it feeds his next Death Chaser +10 against your attacker.
- Avoid being low or stunned — Death Chaser dropping you below 50 HP or hitting a stunned ally triggers Cruel Transformation into unstunnable Final Form.
- The Death Chaser to Sadistic Tread mark loop stun-locks; peel the marked ally or race the tempo.
- Darkness Eye Laser Bypasses your defenses and caps HP, so healing won't raise that character afterward.

---

## Crona
*Soul Eater* &nbsp;·&nbsp; `crona` &nbsp;·&nbsp; `dot` `disruption` `aoe`

**Core:** An energy-investment engine: most of Crona's harmful and defensive skills scale with the total energy poured into them, backed by Affliction and cost-inflation disruption. Partner: Ragnarok converts her colored costs to Random early and extends each time she takes damage.

**▶ Playing as Crona**
- Dump extra energy into Scream Chaser, Scream Assault, Hardened Body, and Tortured Resonance — every energy spent adds damage, duration, or defense.
- Open Tortured Resonance for team-wide Affliction and +1 Random cost on everyone, then it swaps into Scream Chaser for a scaled nuke.
- Hardened Body turns energy directly into Shield + Damage Reduction, so pop it on a big-energy turn to wall incoming burst.
- Black Blood AoE-Afflicts but raises your own next-turn cost, so use it when you can absorb the setback.

**⚔ Playing against Crona**
- Her Affliction DoTs Black Blood and Tortured Resonance tick every turn and ignore defenses — bring cleanse or race the ramp.
- Tortured Resonance inflates everyone's costs by 1 Random for turns equal to energy spent, so expect an economy lull.
- Scream Assault Taunts your character into attacking Crona; plan around losing that unit's target choice.
- Hardened Body scales its Shield + Damage Reduction with energy, so don't dump burst into her on a fortified turn.

---

## Death
*Soul Eater* &nbsp;·&nbsp; `death` &nbsp;·&nbsp; `execute` `counter` `invuln` `aoe` `dot` `disruption` `burst`

**Core:** A control-and-execute controller: Death Claws blankets the enemy team in DoT that executes anyone at 10 HP or less and slows their cooldowns, Kishin Hunter is an uncounterable invuln-bypassing 50 Piercing self-cleanse nuke, and Death Barrier is a team-wide counter.

**▶ Playing as Death**
- Spread Death Claws early for four turns of team-wide DoT that executes any enemy dropping to 10 HP and raises cooldowns.
- Fire Kishin Hunter as an uncounterable, invuln-bypassing 50 Piercing nuke that also strips enemy effects off you.
- Use Barrier Pressure to stun, Isolate, and Pierce a key threat while cutting its damage output.
- Pre-empt their big turn with Death Barrier to counter the first Harmful skill and make your whole team Invulnerable.

**⚔ Playing against Death**
- Death Barrier counters the first Harmful skill against his team, so bait it with a throwaway before committing your payoff.
- Kishin Hunter is Uncounterable and bypasses invulnerability for 50 Piercing, so shields and invuln won't save you.
- Keep your low allies above 10 HP under Death Claws or they'll simply be executed.
- Barrier Pressure Isolates and stuns a target for turns, so keep a cleanse or don't over-commit that character.

---

## Death the Kid
*Soul Eater* &nbsp;·&nbsp; `kid`

**Core:** No special engine is evident from the provided kit text (descriptions are blank); from the class tags it reads as a straightforward damage character built on Energy Harmful nukes (Sanzu River Shot, Death Cannon, Stable Resonance) plus a Physical hit (Fatal Error), a Strategic tool (Death Slide), and a passive (Partners: Liz and Patty).

**▶ Playing as Death the Kid**
- Most of his output is Energy-typed (Sanzu River Shot, Death Cannon, Stable Resonance), so keep Energy banked to keep pressing damage.
- Stable Resonance is tagged both Harmful and Helpful, so lean on it when you want damage and support from a single skill.
- Open with your Strategic skill Death Slide to set up before you commit Energy into the Harmful nukes.

**⚔ Playing against Death the Kid**
- His damage is mostly Energy-typed (Sanzu River Shot, Death Cannon), so energy denial and Nullify blunt him effectively.
- He has one Physical option (Fatal Error) and a passive, Partners: Liz and Patty, with no visible counter or burst window, so trade into him freely.

---

## Diane
*Seven Deadly Sins* &nbsp;·&nbsp; `diane` &nbsp;·&nbsp; `invisible` `invuln` `burst` `dot` `disruption`

**Core:** A delayed, hidden bomb built around Mother Catastrophe (a bypassing strike on an invisible target) that Heavy Metal's Shield charges up, backed by a Queen's Embrace / Ground Gladius skill-swap mode.

**▶ Playing as Diane**
- Fire Mother Catastrophe early: its target is invisible and the hit Bypasses, so enemies can't see who to protect.
- Stack Heavy Metal before or during the bomb; while its 30 Shield holds, Mother Catastrophe delays but deals 20 more damage.
- Use Queen's Embrace for team-wide 15 damage reduction, which arms Ground Gladius to hit an embraced enemy for 30 piercing plus Bleed.
- Diane Dance buys an invulnerable turn and permanently extends Queen's Embrace for the rest of the game.

**⚔ Playing against Diane**
- Beware Mother Catastrophe: its target is INVISIBLE and the damage BYPASSES, so invulnerability won't save you and hitting an invuln target STUNS them for a turn.
- It is a delayed BURST that grows while Heavy Metal's 30 Shield holds, so shattering that shield shrinks the incoming hit.
- Don't dump damage while she casts Diane Dance, which makes her INVULNERABLE for a turn.
- Under Queen's Embrace she swaps in Ground Gladius for 30 piercing plus a Bleed DoT, so respect that mode.

---

## Edward Elric
*Fullmetal Alchemist* &nbsp;·&nbsp; `edward` &nbsp;·&nbsp; `invuln` `dot` `disruption`

**Core:** An alchemy toggle economy: Battle Alchemy and Defensive Alchemy re-cost and modify each other and Destruction Alchemy, and using an improved version refunds random energy via Free Transmutation, all anchored by a 45 Affliction nuke that caps the target's health.

**▶ Playing as Edward Elric**
- Lead with Destruction Alchemy for 45 Affliction damage that also caps the target's max health.
- Use Defensive Alchemy to Shield an ally or drop 20 Nullify on an enemy, but note it makes Destruction Alchemy cost more and hit 10 less that turn.
- Chain Battle Alchemy into a next-turn free Defensive Alchemy, and cast improved skills to trigger Free Transmutation's random-energy refund.
- Fullmetal Alchemy grants an invulnerable turn and then arms a 4-turn window to poke 20 piercing damage.

**⚔ Playing against Edward Elric**
- Fullmetal Alchemy makes Edward INVULNERABLE for a turn (then arms a 4-turn 20 piercing follow-up), so don't waste burst into it.
- Respect Destruction Alchemy: 45 Affliction damage that also caps your health, which straight healing can't restore.
- His Defensive Alchemy can slap 20 Nullify onto your character to shut off a key skill, so time your important casts around it.

---

## EMIYA (Archer)
*Fate* &nbsp;·&nbsp; `emiyaarcher` &nbsp;·&nbsp; `invuln` `burst` `disruption`

**Core:** A skill-use counter plus empowerment engine: Hawkeye empowers his kit while multi-hit skills count as multiple uses, racing toward Grand Caladbolg's 12-use threshold that turns Caladbolg Barrage into a 50 True-damage stun-nuke.

**▶ Playing as EMIYA (Archer)**
- Bank uses fast: Caladbolg Barrage counts as 2 uses (3 empowered) and empowered Twinblade Rush counts as 2, rushing the 12-use threshold.
- Cast Hawkeye for an invuln turn plus next-turn empowerment; every skill anyone uses drops its cooldown so you re-up it often.
- At 12 skills, land the empowered Caladbolg Barrage for 50 True damage and a stun on the target's non-Strategic skills.
- Hold Eye of the Mind as a spare invulnerable turn to dodge burst while you build the counter.

**⚔ Playing against EMIYA (Archer)**
- Track his skill count: after 12 uses Grand Caladbolg turns Caladbolg Barrage into a 50 True-damage BURST that stuns your non-Strategic skills.
- Both Hawkeye and Eye of the Mind grant INVULNERABLE turns, so never dump damage while he's untargetable.
- His output is largely True damage that shreds through shields, so save invuln or defensive tools instead of armor.
- Hawkeye's cooldown falls with every skill used by anyone, so his empowered windows come back fast.

---

## Emiya Shirou
*Fate/stay night* &nbsp;·&nbsp; `emiya`

**Core:** A physical damage dealer built on Projection blades (Nameless Blade, Kanshou, Bakuya) supported by Strategic/Mental setup (Trace, On!; True Projection), a Helpful defensive skill (Rho Aias), and the Unlimited Blade Works passive; the kit text spells out no special engine beyond that.

**▶ Playing as Emiya Shirou**
- Spend your energy on the Projection strikes — Nameless Blade, Kanshou, and Bakuya are your Physical, Harmful damage.
- Open with the Strategic/Mental setup skills Trace, On! and True Projection before committing your blades.
- Hold Projection - Rho Aias as your Helpful defensive answer for turns you expect incoming harm.

**⚔ Playing against Emiya Shirou**
- Most of his threat is straightforward Physical damage from the Projection blades, so mitigate or out-tempo his strike turns.
- Expect setup from Trace, On! and True Projection, and respect Rho Aias as his defensive option before you commit.

---

## Eren Yeager
*Attack on Titan* &nbsp;·&nbsp; `eren` &nbsp;·&nbsp; `transform` `invisible` `invuln` `burst` `aoe` `stun-lock` `sustain`

**Core:** An HP-threshold transformer: he stacks invisible, unremovable Titan Transformation marks and deliberately lowers his own health (Reckless Charge, Sacrificial Save) to 50 or below, detonating every mark for 10 damage per stack, self-healing, and permanently swapping his whole moveset to stronger Titan skills.

**▶ Playing as Eren Yeager**
- Stack Titan Transformation early — it's invisible and unremovable — so its 10-per-stack detonation hits hard once you drop under 50 HP.
- Use Reckless Charge to damage an enemy while chipping your own health toward the 50-HP transformation trigger.
- Sacrificial Save redirects an ally's incoming harm onto you, another way to push yourself under the 50-HP threshold.
- After transforming, lean on the upgraded kit: Titan Bite's 65, Titan KO's full stun, and the invulnerable Titan Eren Assault.

**⚔ Playing against Eren Yeager**
- Titan Transformation is invisible and unremovable — expect a delayed mark detonation the instant Eren reaches 50 HP or below.
- As his health nears 50, brace for the transform: all marked enemies take 10 per stack and his entire kit upgrades.
- Post-transform Titan KO lands 30 damage plus a full 1-turn stun, so don't get caught mid-setup.
- Eren Rampage and Titan Eren Assault make him invulnerable, so don't dump key skills into those turns.

---

## Erza Scarlet
*Fairy Tail* &nbsp;·&nbsp; `erza`

**Core:** A straightforward damage kit — three harmful attacks split across Physical (Titania's Rampage) and Energy (Circle Blade, Nakagami's Starlight) — plus one Strategic/Mental skill, Queen of Fairies; the kit text shows no special engine.

**▶ Playing as Erza Scarlet**
- Match your damage to your energy: Titania's Rampage is Physical, while Circle Blade and Nakagami's Starlight are Energy.
- Use Queen of Fairies as your Strategic/Mental setup woven around your attacking turns.

**⚔ Playing against Erza Scarlet**
- She's a direct damage threat across two energy types with no hidden trap in the shown kit, so trade efficiently.
- Track which resource she's banking to predict a Physical (Titania's Rampage) versus Energy (Nakagami's Starlight) turn.

---

## Esdeath
*Akame ga Kill* &nbsp;·&nbsp; `esdeath`

**Core:** A damage kit whose signature is Uncounterable attacks — Empire's Strongest and Weiss Schnabel ignore counters — backed by the Energy/Strategic Mahapadma, a defensive Effortless Block, and the Heart of Cruelty passive; no further engine is detailed in the kit text.

**▶ Playing as Esdeath**
- Aim Empire's Strongest and Weiss Schnabel at enemies sitting on counters — both are Uncounterable and punch straight through.
- Keep Effortless Block for defense and use Mahapadma as your Energy, Strategic play.

**⚔ Playing against Esdeath**
- Don't try to counter her: Empire's Strongest and Weiss Schnabel are Uncounterable and will ignore your counter skills.
- Save your defensive tools for her attacks and respect Mahapadma as her Strategic Energy option.

---

## Frankenstein
*Fate* &nbsp;·&nbsp; `frankenstein` &nbsp;·&nbsp; `burst` `aoe` `disruption` `sustain`

**Core:** A cooldown-denial bruiser: Bridal Chest inflates enemy skill cooldowns while Blasted Tree is a self-destruct nuke that deals Piercing equal to her own missing HP. Galvanism both sustains her and amplifies the cooldown lock.

**▶ Playing as Frankenstein**
- Open with Galvanism so Bridal Chest pushes enemy cooldowns by 2 and you heal 15 whenever an Energy skill hits you.
- Spam Bridal Chest to keep a key enemy skill locked out; Bridal Rampage adds a free one every turn for two turns.
- During Bridal Rampage she ignores non-damage effects, so use that window to power through stun and debuff setups.
- Save Blasted Tree for when she is low — it self-destructs her but deals Piercing equal to her missing HP.

**⚔ Playing against Frankenstein**
- Blasted Tree is a missing-HP Piercing nuke — the lower her HP, the harder it hits, so don't chip her down slowly.
- During Bridal Rampage she ignores non-damage effects for two turns and auto-hits with Bridal Chest — don't waste stuns then.
- Bridal Chest keeps inflating your cooldowns, worse under Galvanism, so don't assume a skill will be ready when you need it.

---

## Frieren
*Frieren* &nbsp;·&nbsp; `frieren` &nbsp;·&nbsp; `stealth` `transform` `dot` `invuln` `burst`

**Core:** A stealth-stance toggle: Mana Concealment keeps her skills permanently Stealthed but stops her generating energy, while casting Mana Release breaks stealth to empower her and swap Flower Field/Mana Release into the Vollzanbel/Judradjim burst-and-Affliction package.

**▶ Playing as Frieren**
- Under Mana Concealment your skills are Stealthed but you gain no energy — lean on free Zoltraak and free Flight Evasion.
- Cast Mana Release to empower a turn: gain White energy, 10 Damage Reduction, and swap in Vollzanbel and Judradjim.
- Empowered Zoltraak hits 25 Piercing, and Vollzanbel plants a permanent 10-per-turn Affliction that lasts the rest of the game.
- Judradjim is Uncounterable — fire it for three turns of random Piercing while Flight Evasion covers you with Invulnerability.

**⚔ Playing against Frieren**
- Under Mana Concealment her skills are permanently Stealthed, so you often won't see the hit coming until she casts Mana Release.
- Mana Release is her transform turn: it swaps in Vollzanbel's game-long Affliction and Judradjim — respect that power spike.
- Judradjim is Uncounterable and hits two random targets for 20 Piercing over three turns; counters won't stop it.
- Vollzanbel's Affliction ticks 10 every turn for the rest of the game — cleanse it or race her down.

---

## Fumikage Tokoyami
*My Hero Academia* &nbsp;·&nbsp; `tokoyami` &nbsp;·&nbsp; `counter` `stun-lock` `invuln` `aoe` `disruption`

**Core:** Black Abyss stack-scaling: he banks one stack per turn (max 3), and each stack widens Sabbath's stun, Covert Black-Ops Arms' counter, and Dark Aura's invuln from a single class to all skills and allies, while cheapening Dark Shadow Rampage.

**▶ Playing as Fumikage Tokoyami**
- Stall early to bank Black Abyss stacks; at 3 stacks his stun, counter, and invuln cover every skill and your allies.
- At full stacks Dark Shadow Rampage costs three less Random and hits all enemies for 10 over four turns.
- Pre-place Covert Black-Ops Arms — at 3 stacks it counters the first skill from the entire enemy team.
- Guard your stacks: being Stunned, Silenced, or Blinded strips one and blocks gaining one that turn.

**⚔ Playing against Fumikage Tokoyami**
- Covert Black-Ops Arms is a counter — at 3 stacks it counters every enemy's first skill, so bait it with a throwaway.
- Stun, Silence, or Blind him to strip a Black Abyss stack and stop him reaching the 3-stack all-skills lockdown.
- Left unchecked, Sabbath escalates to stun your whole class range and allies — don't let him free-stack.
- At 3 stacks Dark Aura makes him and allies Invulnerable across classes; land your big hit while it's down.

---

## Fushiguro Megumi
*Jujutsu Kaisen* &nbsp;·&nbsp; `megumi` &nbsp;·&nbsp; `stun-lock` `disruption` `burst` `invuln`

**Core:** Mark-and-payoff with rotating class stuns: Bottomless Well and Great Serpent apply 3-turn marks that Nue cashes in (30 Piercing, or enemy -5 damage), while Shikigami Summoning re-rolls which skill-class his stuns and invuln lock each turn.

**▶ Playing as Fushiguro Megumi**
- Mark with Bottomless Well, then fire Nue for 30 Piercing; a Great Serpent mark instead makes Nue cut the enemy's damage.
- Alternate Bottomless Well and Great Serpent to chain stuns and keep 3-turn marks alive for Nue payoffs.
- Check Shikigami Summoning's current class each turn — it re-rolls which skills Bottomless Well, Great Serpent, and Rabbit Escape lock.
- Use Rabbit Escape for a turn of class-based Invulnerability when you need to dodge and reset tempo.

**⚔ Playing against Fushiguro Megumi**
- A Bottomless Well mark turns his Nue into 30 Piercing — cleanse the mark or brace for the spike.
- His stun classes rotate each turn via Shikigami Summoning, so which of your skills gets locked keeps changing — keep a backup line.
- Rabbit Escape gives him class-based Invulnerability; don't throw your big skill into the class he's immune to that turn.

---

## Fushiguro Toji
*Jujutsu Kaisen* &nbsp;·&nbsp; `toji`

**Core:** A straightforward physical-damage bruiser: every listed skill is Physical and Harmful with no special engine in the kit text, one of them (Playful Cloud) an Action.

**▶ Playing as Fushiguro Toji**
- Prioritize Physical energy, since your entire kit from Split Soul Katana to X-Slash deals Physical damage.
- Playful Cloud is an Action skill, so weave it in on a turn you can fully commit to it.
- With no setup engine, just sequence your hardest-hitting Physical skills onto priority targets.

**⚔ Playing against Fushiguro Toji**
- His visible kit has no counter, stealth, or transform, so he's pure Physical pressure to mitigate normally.
- Inverted Spear of Heaven and Chain of a Thousand Miles are all-in Physical hits that damage reduction and healing answer.

---

## Gallantmon
*Digimon* &nbsp;·&nbsp; `gallantmon` &nbsp;·&nbsp; `counter` `invuln` `disruption`

**Core:** A counter-punish engine whose Shield of the Just morphs based on outcomes: it grants Invulnerability if Gallant Guard expires unused, or adds a stun if Lightning Joust gets countered.

**▶ Playing as Gallantmon**
- Lead with Gallant Guard on a threatened ally; if the counter never triggers it swaps into Shield of the Just next turn.
- After Gallant Guard resolves, Lightning Joust strikes twice for a turn, so save it for the double-hit follow-up.
- Bait counters with Lightning Joust — if it gets countered it converts into a stunning Shield of the Just.
- Use Yuggoth Blaster to tax a key enemy's energy and Grani Flight to sit safe on invulnerable turns.

**⚔ Playing against Gallantmon**
- Respect Gallant Guard's counter — never feed it your best Harmful, non-Strategic skill; open with Strategic or chip damage.
- Feeding into a countered Lightning Joust just hands Gallantmon a stunning Shield of the Just, so bait or bypass it.
- Grani Flight and Shield-of-the-Just grant invulnerability, so hold your burst until he is actually exposed.
- Yuggoth Blaster spikes your skill costs by a Random energy — keep a cheap action ready that turn.

---

## Ganta Igarashi
*Deadman Wonderland* &nbsp;·&nbsp; `ganta` &nbsp;·&nbsp; `burst` `aoe` `dot`

**Core:** A low-health payoff nuke: his Woodpecker passive afflicts himself, and the lower his HP the harder Supersonic Ganta Gun scales and the closer he gets to the sub-10-HP Ganbare Gun bomb.

**▶ Playing as Ganta Igarashi**
- Stack Woodpecker by spamming harmful skills; the self-affliction lowers your HP to fuel Supersonic Ganta Gun's missing-health scaling.
- Save Ganbare Gun for its low-HP threshold — it hits 45 single then 25 to all enemies, but bleeds your team 15.
- Keep passive stacks running since Ganta Gun gains +5 damage per stack for steady baseline pressure.
- Pop Reckless Rush when a kill is incoming — you cannot die and retaliate through invulnerability with bonus damage.

**⚔ Playing against Ganta Igarashi**
- Fear Ganbare Gun: once Ganta sits near 10 HP he can unleash a 45 plus 25-to-all burst, so don't leave him uncontested at low health.
- Reckless Rush makes him unkillable for a turn and lets his skills Bypass Invulnerability — don't waste your defensive turn or your hits into it.
- His own Woodpecker passive drags him toward Ganbare range, so denying his big turn matters more than raw damage.

---

## Gatomon
*Digimon* &nbsp;·&nbsp; `gatomon` &nbsp;·&nbsp; `transform` `invuln` `disruption` `aoe` `sustain`

**Core:** A stack-building transformer: every basic skill and Nekodamashi adds a Digivolution stack, then Gatomon Digivolve permanently becomes Angewomon at 2 stacks or the far stronger Ophanimon at 3.

**▶ Playing as Gatomon**
- Bank Digivolution stacks with Lightning Paw, Cat's Eye, and Nekodamashi before ever spending Gatomon Digivolve.
- Hold for 3 stacks to reach Ophanimon when you can — her team-wide Final Judgement and blind lock outclass Angewomon.
- Gatomon Digivolve is usable while stunned, so you can escape a lockdown by transforming out of it.
- As Ophanimon, Sefirot Crystal bypasses invulnerability and Holy Light wipes all harmful effects off your team.

**⚔ Playing against Gatomon**
- Race the transformation — pressure Gatomon hard early before she banks stacks and Digivolves into Angewomon or Ophanimon.
- Don't rely on invulnerability against Ophanimon; her Sefirot Crystal bypasses it entirely.
- Ophanimon's Final Judgement blinds your whole team and extends if you act, so plan a do-nothing turn around it.
- Her blinds — Lightning Paw, Cat's Eye's cooldown paralyze, Eden's Javelin — shut off your skills, so respect the disruption.

---

## Genos
*One Punch Man* &nbsp;·&nbsp; `genos` &nbsp;·&nbsp; `dot` `aoe` `disruption` `invuln` `burst`

**Core:** An Affliction-ramp and setup engine: Machine-Gun Blows permanently grows, Super Incineration Cannon lays a 3-turn DoT that unlocks Lightning Drill Cannon, and Lightning Eye amps the whole enemy team for a burst window.

**▶ Playing as Genos**
- Re-cast Machine-Gun Blows to convert it to Affliction and permanently raise its damage each cycle.
- Super Incineration Cannon lays a big DoT and swaps you into Lightning Drill Cannon — a 40 piercing full-stun finisher.
- Time Lightning Eye to Shatter, Blind, and plus-5-damage-amp the enemy team right before your burst.
- Rocket Boosters buys an invulnerable turn and, once improved by Lightning Eye, upgrades into Self-Destruct.

**⚔ Playing against Genos**
- Watch the Lightning Eye setup — it shatters your shields and amps all incoming damage right before Lightning Drill Cannon's 40 piercing full stun.
- Don't throw new Affliction skills at Genos while Super Incineration Cannon is active; it punishes you with 10 Affliction back.
- His Machine-Gun Blows only ramps, so end fights fast rather than trading long against a growing DoT.
- Play around his Rocket Boosters invulnerable turn before committing your burst.

---

## Gilgamesh
*Fate* &nbsp;·&nbsp; `gilgamesh` &nbsp;·&nbsp; `counter` `trap` `invisible` `burst` `invuln` `disruption`

**Core:** A stack-banking burst engine: Gate of Babylon cast on himself adds stacks, then cast on an enemy it deals 10 and repeats once per stored stack. His control comes from an invisible counter (Enkidu) and damage/healing nullification.

**▶ Playing as Gilgamesh**
- Cast Gate of Babylon on Gilgamesh to bank stacks, then fire it at an enemy to repeat 10 damage per stack for a spike.
- Drop Enkidu, Chains of Heaven pre-emptively; it invisibly counters the enemy's next new Harmful skill, then nullifies their damage and healing.
- Enuma Elish deals 35 piercing and shuts off a target's damage and healing for a turn, ideal against a key threat.
- Spend a single Gate stack on Interception for an invulnerable turn, but weigh it against saving stacks for the burst.

**⚔ Playing against Gilgamesh**
- Respect the Gate of Babylon BURST: after he self-stacks, one enemy cast repeats 10 damage per stack, so pressure him before it detonates.
- Enkidu, Chains of Heaven is an INVISIBLE COUNTER TRAP; never throw a new Harmful skill into it or you get countered and then zeroed next turn.
- Expect an Interception INVULN turn whenever he still holds a Gate of Babylon stack.
- Both Enuma Elish and Enkidu can nullify your damage and healing, so don't commit a payoff turn into him.

---

## Gogeta
*Dragon Ball* &nbsp;·&nbsp; `gogeta`

**Core:** Skill descriptions are blank in the provided data, so no special engine can be confirmed from text; by its class tags it reads as a straightforward damage kit built around a Channeled energy nuke (Big Bang Kamehameha) and an Uncounterable Bluff Kamehameha.

**▶ Playing as Gogeta**
- Big Bang Kamehameha is Channeled, so it likely commits you across turns; set it up from a safe position.
- Bluff Kamehameha is Uncounterable, so it lands through defensive counters; save it for counter-holding enemies.
- Unapproachable Stance is your Strategic tool; hold it as your protective play.

**⚔ Playing against Gogeta**
- Bluff Kamehameha is Uncounterable, so don't rely on a counter to stop it.
- Big Bang Kamehameha is Channeled, so interrupt the cast with a stun if you can.

---

## Gon Freecss
*Hunter x Hunter* &nbsp;·&nbsp; `gon` &nbsp;·&nbsp; `execute` `aoe` `burst` `disruption` `sustain`

**Core:** A stacking build-up engine: Jajanken Stance stacks grant Shield and a permanent +10 damage and upgrade each Jajanken, but the stance ends the instant Gon uses a Damaging skill, forcing a build-then-cash-out rhythm.

**▶ Playing as Gon Freecss**
- Stack Jajanken Stance for Shield and permanent +10 damage, but remember any Damaging skill ends the stance.
- With Stance active, Jajanken Rock stuns and Jajanken Paper becomes piercing team-wide, costs 1 Random, and Blinds.
- Jajanken Scissors executes enemies at 25 HP or below and first deals 10 per Stance stack, so stack tall before executing.

**⚔ Playing against Gon Freecss**
- Watch Jajanken Scissors: it's an EXECUTE on anyone at 25 HP or below, plus 10 damage per Jajanken Stance stack, so keep low allies out of range.
- While Gon builds Jajanken Stance, expect a Rock stun and a Paper AoE piercing Blind, all cashing into a bigger burst.
- His whole threat drops the moment he uses a Damaging skill, so bait the stance out before he sets up.

---

## Gray Fullbuster
*Fairy Tail* &nbsp;·&nbsp; `gray` &nbsp;·&nbsp; `transform` `invuln` `dot` `aoe` `stun-lock` `sustain`

**Core:** A low-HP transformation threshold: at 30 HP or below Disciple of Ur permanently grants Ice, Make... and swaps his Shield for the self-sacrificing Iced Shell, while the Ice, Make... chain escalates through Unlimited into One-Sided Chaotic Dance.

**▶ Playing as Gray Fullbuster**
- Use Ice, Make... to ignore stuns and unlock Ice, Make Unlimited, then One-Sided Chaotic Dance which scales +10 per prior Ice, Make... use.
- Ice, Make Unlimited gives your team 5 Shield and chips the enemy team 5 piercing every turn for the rest of the game.
- Ice, Make Hammer stuns and Ice, Make Shield grants invulnerability; Freeze Lancer is 2-turn AoE piercing pressure.
- Once Disciple of Ur triggers at 30 HP, Iced Shell permanently stuns a target with 10 true damage per turn but kills Gray unpreventably.

**⚔ Playing against Gray Fullbuster**
- Below 30 HP Gray TRANSFORMS via Disciple of Ur, unlocking Iced Shell, so respect that swing before pushing him low.
- Iced Shell is UNCOUNTERABLE: a permanent stun plus 10 true damage per turn that trades Gray's life and can't be reflected or death-prevented.
- Ice, Make... lets him ignore stuns, so stun-locking Gray won't hold him.
- Ice, Make Shield gives him invuln turns and Unlimited drips team-wide piercing every turn once it's up.

---

## Haruno Sakura
*Naruto* &nbsp;·&nbsp; `sakura` &nbsp;·&nbsp; `counter` `trap` `invisible` `invuln` `disruption`

**Core:** A counter-and-trap defender: Cherry Blossom Fist counter-punishes harmful skills (feeding her random energy) while Rampage Gloves plants an invisible retaliation mark, backed by invuln and stun-immunity tools.

**▶ Playing as Haruno Sakura**
- Aim Cherry Blossom Fist at a likely attacker to counter their new harmful skill and bank 1 random energy on success.
- Plant Rampage Gloves on a threatened ally or yourself so the first harmful skill eats 25 damage plus a 1-turn stun.
- Pop Medical Ninjutsu for 15 Damage Reduction and 3 turns of stun immunity when you expect burst or stun pressure.
- Cherry Blossom Crash is your payoff: 30 damage plus a 1-turn lockout of Physical, Mental, and Strategic skills.

**⚔ Playing against Haruno Sakura**
- Cherry Blossom Fist is a COUNTER on its target, so don't feed it a harmful skill or you eat the counter and hand her energy.
- Rampage Gloves is an INVISIBLE trap on Sakura or an ally; probe with a throwaway skill or hit elsewhere to avoid the 25 damage plus stun.
- Sakura Dodge gives her INVULN for a turn, so never dump your burst into it.
- Medical Ninjutsu makes her stun-immune for 3 turns, so don't count on locking her down.

---

## Hashibira Inosuke
*Demon Slayer* &nbsp;·&nbsp; `inosuke`

**Core:** A straightforward Physical damage kit as written in the kit text: two Harmful strikes, one Uncounterable Mental/Strategic skill, and a Strategic dodge, with no special engine visible in the (blank) descriptions.

**▶ Playing as Hashibira Inosuke**
- Apply steady pressure with Double Serrated Slash and Second Fang: Slice as your Physical Harmful strikes.
- Seventh Fang: Spatial Awareness is Uncounterable, so use it to act safely into counter-based enemies.
- Keep Inosuke Dodge as your Strategic defensive option to fall back on under pressure.

**⚔ Playing against Hashibira Inosuke**
- Seventh Fang: Spatial Awareness is Uncounterable, so counters and reactive defenses won't stop it.
- His output reads as pure Physical damage, so physical mitigation and Damage Reduction blunt most of what he does.

---

## Hashirama Senju
*Naruto* &nbsp;·&nbsp; `hashirama` &nbsp;·&nbsp; `trap` `invisible` `dot` `aoe` `sustain` `disruption`

**Core:** A delayed-skill engine: he stacks Deep Forest Bloom: Pollen and Strangle as delayed skills, enhances and extends them with Deep Forest Creation, and Great Thriving Forest converts every active delayed skill into 5 team Shield plus 5 Piercing enemy damage per turn.

**▶ Playing as Hashirama Senju**
- Open with Deep Forest Creation to enhance and further-delay Pollen and Strangle, then cast both to stack delayed skills.
- Keep as many delays live as possible since Great Thriving Forest gives 5 Shield and 5 Piercing per active delayed skill each turn.
- Reactivate Deep Forest Creation to extend all active delay effects and prolong the passive's snowball.
- Drop Wood Clone as an invisible delay-trap that shoves the first harmful skill on you or an ally back 2 turns.

**⚔ Playing against Hashirama Senju**
- His value scales with stacked delayed skills, so pressure him early before Deep Forest Creation and the passive snowball out of control.
- Wood Clone is an INVISIBLE trap that delays the first harmful skill on Hashirama or an ally by 2 turns, so bait it with a throwaway.
- Enhanced Strangle keeps stunning a random enemy's Physical and Energy skills each delayed turn, so hold key skills for a clear window.
- Pollen's Affliction and the passive's Piercing bypass normal mitigation, so raw Damage Reduction won't fully save you.

---

## Hawkmon
*Digimon* &nbsp;·&nbsp; `hawkmon` &nbsp;·&nbsp; `transform`

**Core:** A digivolution kit built around Hawkmon Digivolve, the transformation that opens up a large expanded moveset of Physical and Energy Harmful attacks plus Strategic guard/field tools; exact per-skill effects aren't present in the kit text.

**▶ Playing as Hawkmon**
- Use Hawkmon Digivolve to transform and unlock the expanded roster of Energy and Physical attacks.
- Balance your energy between Physical strikes (Feather Strike, Grand Horn, Top Gun) and Energy attacks (Blast Wings, Static Force, Dual Sonic, Storm Bomber).
- Lean on Wind Guard and Air Field as Strategic defensive tools, with Wind Breath as a Strategic Energy option.

**⚔ Playing against Hawkmon**
- Respect Hawkmon Digivolve, his TRANSFORMATION, which opens a much larger moveset, so pressure him early or brace for the power spike after it fires.
- His attacks split across Physical and Energy damage, so don't over-commit mitigation to just one type.

---

## Hibari Kyouya
*Katekyo Hitman Reborn* &nbsp;·&nbsp; `hibari` &nbsp;·&nbsp; `invuln` `dot` `aoe` `disruption`

**Core:** Porcospino Nuvola creates an AoE punish zone: for 3 turns all enemies bleed Piercing damage, take an extra 10 Piercing whenever they use a Harmful skill, and Cloud Tonfa loses its cooldown for free spam. His passive punishes Invisible play.

**▶ Playing as Hibari Kyouya**
- Open with Porcospino Nuvola to apply the AoE Piercing bleed and unlock cooldown-free Cloud Tonfa spam.
- While Porcospino is active, hammer Cloud Tonfa every turn and let enemies self-punish for attacking.
- Use Alaudi's Handcuffs to Stun and Isolate their key threat, cutting it off for a turn.
- Pop Hibari Block for Invulnerability to skip a dangerous incoming burst turn.

**⚔ Playing against Hibari Kyouya**
- During Porcospino Nuvola, avoid Harmful skills or eat an extra 10 Piercing each time — take setup turns instead.
- Hibari Block grants him Invulnerability for a turn, so don't dump burst into it.
- Never use Invisible skills near him; his Cloud Flames passive stacks permanent Affliction on you for each one.
- Alaudi's Handcuffs can Stun and Isolate your carry — position around it.

---

## Himiko Toga
*My Hero Academia* &nbsp;·&nbsp; `toga` &nbsp;·&nbsp; `transform` `invuln` `burst` `dot` `aoe` `disruption`

**Core:** Stack-building around Twisted Love: stacks from Thirsting Knife and Vacuum Syringe hit 2/4/6 thresholds that buff Killing Spree, discount energy, and convert Twisted Love into the AoE-stun Drop Dead. She opens the match disguised via Quirk: Transform.

**▶ Playing as Himiko Toga**
- Build Twisted Love stacks with Thirsting Knife and the 3-turn Vacuum Syringe DoT, which adds a stack each turn.
- Stay disguised by only using Thirsting Knife early — Transform breaks the moment you take damage or use any other skill.
- Keep Twisted Love running: 2 stacks buff Killing Spree +15, 4 cheapen skills, 6 unlocks Drop Dead.
- Killing Spree delivers 30+ Piercing and grants Invulnerability, making it your safe burst turn.

**⚔ Playing against Himiko Toga**
- Quirk: Transform means an enemy could be Toga in disguise — her identity hides until she takes damage or acts beyond Thirsting Knife.
- Killing Spree is a burst window: up to 45 Piercing plus self-Invulnerability.
- At 6 Twisted Love stacks she gains Drop Dead — a full-team Stun followed by 25 delayed damage.
- Pressure her early to break the disguise and interrupt her stack-building.

---

## Hiragi Shinoa
*Seraph Of The End* &nbsp;·&nbsp; `shinoa`

**Core:** A straightforward mixed damage/utility kit with no special engine evident from the available kit text: two Harmful attacks (Doji Slash, Doji Sweep) backed by three Strategic tools (Four Scythe Child, Shinoa Deflection, Doji Manifestation), split across Physical and Energy costs.

**▶ Playing as Hiragi Shinoa**
- Doji Slash (Physical) and Doji Sweep (Energy) are her two Harmful attacks — split energy to keep both online.
- Spend non-attack turns on her Strategic skills: Four Scythe Child, Doji Manifestation, and Shinoa Deflection.
- Three of her five skills are Energy-typed, so prioritize banking Energy over Physical.

**⚔ Playing against Hiragi Shinoa**
- Her only Harmful damage comes from Doji Slash and Doji Sweep; the rest are Strategic setup tools.
- Deny Energy where you can, since most of her kit (Four Scythe Child, Doji Sweep, Doji Manifestation) leans on it.

---

## Hisoka Morow
*Hunter x Hunter* &nbsp;·&nbsp; `hisoka` &nbsp;·&nbsp; `counter` `execute` `invisible` `disruption` `aoe`

**Core:** Card Throw stack-building toward an execute: the 4th stack swaps Card Throw for Flamboyant Execution on the lowest-HP enemy. This is backed by a counter (Bungee Gum - Catch, then Reflect) that ignores and redirects a Harmful skill, plus HP-hiding info denial from Texture Surprise.

**▶ Playing as Hisoka Morow**
- Chain Card Throw to build stacks; each adds random Piercing hits and the 4th unlocks Flamboyant Execution.
- Fire Flamboyant Execution to execute the lowest-HP enemy — funnel chip damage onto that target first.
- Bungee Gum - Catch ignores an incoming Harmful skill (Invisible), then Reflect throws it back — bait their attack.
- Texture Surprise hides a target's HP from the opponent, masking how close it sits to execute range.

**⚔ Playing against Hisoka Morow**
- Bungee Gum - Catch is a counter: it ignores your Harmful skill for a turn and Reflect fires it back — don't attack into it.
- Flamboyant Execution executes your lowest-HP unit once Hisoka reaches his 4th Card Throw stack — keep fragile units topped up.
- Texture Surprise hides an enemy's HP changes, so a unit may slip into execute range unseen.
- Bungee Gum - Attract Taunts, forcing one of your units to target Hisoka for a turn.

---

## Horohoro
*Shaman King* &nbsp;·&nbsp; `horohoro` &nbsp;·&nbsp; `transform` `invuln` `stun-lock` `aoe` `burst` `disruption`

**Core:** A stun-conversion engine: he marks enemies (Icicle Sword, Frost That Rouses The Sleeping) so his Harmful skills stun them, then turns those stuns into repeated Invulnerability (Impeccable Power) and heavy AoE burst (All-Swallowing Avalanche).

**▶ Playing as Horohoro**
- Open with Icicle Sword or Frost That Rouses The Sleeping to mark enemies, so your other Harmful skills stun them automatically.
- Activate Impeccable Power first, then every stun you land refreshes its duration and keeps you Invulnerable for a turn.
- Line up stuns, then fire All-Swallowing Avalanche for 40 AoE to all stunned enemies and mop up the rest next turn.
- Avoid Nipopo Punch on a stunned target you are saving for Avalanche, since it ends their stuns.

**⚔ Playing against Horohoro**
- While Impeccable Power is up, any stun he lands makes him Invulnerable, so deny him easy stun targets to break the loop.
- All-Swallowing Avalanche is a 40-damage AoE burst on every stunned enemy plus a follow-up hit next turn, so avoid being stunned into it.
- Kororo Snowboard is a 4-turn transform where he ignores stuns and heals 20, so stun-locking him backfires.

---

## Hyuuga Hinata
*Naruto* &nbsp;·&nbsp; `hinata` &nbsp;·&nbsp; `invisible` `disruption` `sustain` `dot`

**Core:** A defensive protector who layers ongoing team damage-reduction and shields (Protective Eight Trigrams: 64 Palms) with a punish-taunt trap (My Turn To Protect) that unlocks her offensive mode, Gentle Step: Twin Lions Fist.

**▶ Playing as Hyuuga Hinata**
- Set up Gentle Fist Taijutsu and Protective Eight Trigrams: 64 Palms early, since both discount Eight Trigrams: Air Palm's Random cost.
- Mark a fragile ally with My Turn To Protect; if an enemy stuns them or drops them below 30 HP, you auto-taunt that enemy and unlock Twin Lions Fist.
- With 64 Palms active, spend its free activation to shield allies and punish enemies who use Harmful skills with 5 Piercing.
- Once Twin Lions Fist unlocks, its 4-turn effect adds 10 damage to everything you hit, so activate it before your attacks.

**⚔ Playing against Hyuuga Hinata**
- My Turn To Protect places an invisible mark on an ally, and stunning them or bursting them below 30 HP permanently taunts you onto Hinata.
- Her whole team gets 5 damage reduction from 64 Palms and returns 5 Piercing when you use Harmful skills, so grinding her wall is costly.
- Eight Trigrams: Air Palm stuns your Harmful skills for a turn, so don't queue a Harmful finisher right after she acts.

---

## Ichibe Hyosube
*Bleach* &nbsp;·&nbsp; `ichibe` &nbsp;·&nbsp; `execute` `invuln` `sustain` `disruption` `aoe`

**Core:** An Ink Splatter stack engine: every ink application both marks enemies and grants Ichibe stacking permanent Shield. At 4 stacks on a target he permanently neuters it (Shirafude Ichimonji), and at 10 self-stacks he unlocks Futen Taisatsuryo, an uncounterable execute.

**▶ Playing as Ichibe Hyosube**
- Build Ink Splatter stacks with Ichimonji and Ink Splatter, since every stack applied to you grants 5 permanent Shield and turns you into a wall.
- Once a target holds 4 Ink stacks, Shirafude Ichimonji permanently silences it, stuns its Strategic skills, and caps its damage at 10.
- At 10 self-stacks, Ink Splatter becomes Futen Taisatsuryo, an uncounterable execute that strips buffs and ignores Immortality, so save it for a real threat.
- Use Ink Manipulation: Conceal for a 1-turn Invulnerability panic button while you keep stacking.

**⚔ Playing against Ichibe Hyosube**
- Futen Taisatsuryo is an uncounterable execute that ignores Immortality once he reaches 10 Ink stacks, so pressure or kill him before then.
- Shirafude Ichimonji permanently silences and damage-caps any target with 4+ Ink stacks, so keep your carry off ink or lose them for the game.
- His Ink stacks grant stacking permanent Shield, making chip damage useless, so commit real burst or leave him alone.
- Named Reconstitution revives him once after death when an ally next uses a skill, so his first kill may not stick.

---

## Ichigo Kurosaki
*Bleach* &nbsp;·&nbsp; `ichigo` &nbsp;·&nbsp; `burst` `invuln`

**Core:** A damage-ramp snowball: nearly every action permanently raises his output, as Bankai: Tensa Zangetsu adds 5 per skill used, Zangetsu Slash grows each cast, and Getsuga Tenshou scales with its own uses, while self-invuln windows keep him alive to escalate.

**▶ Playing as Ichigo Kurosaki**
- Activate Bankai: Tensa Zangetsu early so every later skill permanently adds 5 damage and snowballs your output.
- Ramp with repeated Zangetsu Slash, then cash out on Getsuga Tenshou's 45 piercing nuke.
- Getsuga Tenshou also makes you invulnerable to non-Strategic skills and refunds 1 random energy, so it doubles as a defensive beat.
- Hold Ichigo Block as a clean 1-turn Invulnerability panic button when you can't afford to trade.

**⚔ Playing against Ichigo Kurosaki**
- Ichigo snowballs harder every turn from Bankai: Tensa Zangetsu and stacking Zangetsu Slash, so close the game out before his damage spirals.
- Getsuga Tenshou is a 45 piercing burst that also makes him invulnerable to non-Strategic skills, so answer it with a Strategic skill if you must hit him.
- Both Getsuga Tenshou and Ichigo Block grant Invulnerability turns, so don't dump your key damage into them blindly.

---

## Impmon
*Digimon* &nbsp;·&nbsp; `impmon` &nbsp;·&nbsp; `transform` `sustain` `dot` `disruption`

**Core:** Impmon's engine is sustain-through-aggression: Lord of Gluttony heals him for 50% of all damage he deals, while Warp Digivolve - Beelzemon transforms his kit for a bigger payoff.

**▶ Playing as Impmon**
- Stay on the attack every turn, since Lord of Gluttony converts 50% of all damage you deal into healing.
- Fire Warp Digivolve - Beelzemon to transform into your stronger form when you want to raise your ceiling.
- Apply Infernal Funnel's Affliction for damage-over-time that keeps ticking and still feeds your lifesteal.
- Hold Imp Trick's Mental skill to disrupt a key enemy turn rather than spending it on raw damage.

**⚔ Playing against Impmon**
- Respect Warp Digivolve - Beelzemon: pressure him before he transforms, because his threat jumps afterward.
- Trading blows only sustains him via Lord of Gluttony's 50% lifesteal, so burst him down or deny his targets.
- Infernal Funnel lays Affliction damage-over-time, so cleanse it or race him rather than let it stack.

---

## Inuyasha
*InuYasha* &nbsp;·&nbsp; `inuyasha` &nbsp;·&nbsp; `dot`

**Core:** The provided kit text gives no detailed engine, so play him as a straightforward multi-type attacker: three Harmful hits spanning Energy (Wind Scar), Physical (Iron Reaver Soul Stealer), and Affliction (Blades of Blood), plus the Strategic Tessaiga Barrier and the Hanyo Cycle passive.

**▶ Playing as Inuyasha**
- Rotate Wind Scar (Energy), Iron Reaver Soul Stealer (Physical), and Blades of Blood to vary your damage type against enemy defenses.
- Use Blades of Blood's Affliction damage as damage-over-time chip to pressure enemy healers.
- Fall back on Tessaiga Barrier, your Strategic defensive tool, when you need to weather a turn.

**⚔ Playing against Inuyasha**
- Blades of Blood applies Affliction damage-over-time, so expect lingering chip even after Inuyasha finishes acting.
- He attacks across Energy and Physical types, so spread your defenses rather than over-committing to countering one damage type.
- Tessaiga Barrier is his defensive Strategic answer, so bait it out before committing a big turn of offense.

---

## Iron Maiden Jeanne
*Shaman King* &nbsp;·&nbsp; `jeanne` &nbsp;·&nbsp; `execute` `counter` `invuln` `sustain` `disruption`

**Core:** Gibbet locks a single enemy into a 1v1, cutting them off from their team, then Jeanne grinds them with Skull and Knee Crushers until they hit 35 HP and Guillotine executes them; the Iron Maiden stance keeps her untargetable and self-healing while inactive.

**▶ Playing as Iron Maiden Jeanne**
- Sit in Iron Maiden to heal 10 HP a turn untargetable, then activate it when you are ready to attack.
- Stamp Gibbet on a priority target to lock them into fighting only you and deny their allies from helping them.
- Grind the Gibbet target with Skull and Knee Crushers to tax their energy and drop them to 35 HP, then Guillotine to execute.
- Hold Shamash's Kiss to make an ally Invulnerable or resurrect a dead one at 35 HP, and use Shamash Judgment to punish anyone hitting you.

**⚔ Playing against Iron Maiden Jeanne**
- Respect the Guillotine execute: once your Gibbet-locked character reaches 35 HP, heal or invuln them or they die outright.
- Shamash Judgment reflects 20 damage for 2 turns, so stop spamming Harmful skills into Jeanne while it is active.
- While Iron Maiden is inactive she is untargetable and self-healing, so only pressure her after she activates to attack.
- Gibbet severs your locked ally from your team and Skull and Knee Crushers taxes their skill costs, so plan energy around the isolation.

---

## Itadori Yuuji
*Jujutsu Kaisen* &nbsp;·&nbsp; `yuji` &nbsp;·&nbsp; `burst` `stun-lock` `invuln` `sustain`

**Core:** A Black Flash snowball: every True-damage hit climbs his Black Flash proc chance, and a trigger bursts 15 bonus True damage plus stuns the target's Harmful skills, while Consume Finger and Combat Awakening permanently pump the odds.

**▶ Playing as Itadori Yuuji**
- Chain Divergent Fist so its next-turn True damage keeps ratcheting your Black Flash chance every turn.
- Spend Consume Finger to heal and permanently raise the minimum Black Flash chance; Combat Awakening adds 15% and makes Divergent Fist double-hit.
- Drop below 50 HP with Combat Awakening up so Divergent Fist's initial hit also lands True damage, feeding Black Flash faster.
- Pop Unusual Fortitude for a free Invulnerable turn when you are under pressure.

**⚔ Playing against Itadori Yuuji**
- Black Flash can suddenly deal 15 bonus True damage and stun your Harmful skills, and the longer he goes without proccing the higher the odds.
- Divergent Fist plants True damage that lands the next turn, so expect chip you cannot reduce.
- He turns Invulnerable with Unusual Fortitude, so never sink a big hit into that turn.
- His Black Flash chance only grows via Consume Finger and Combat Awakening, so burst or disrupt him before the odds get dangerous.

---

## Jack the Ripper
*Fate* &nbsp;·&nbsp; `jack` &nbsp;·&nbsp; `burst` `invuln` `dot` `aoe` `disruption`

**Core:** A setup-and-payoff kit around Isolation and Fog of London: Fog blankets the enemy team with affliction and cut healing, the Streets of the Lost passive Isolates lone-acting enemies, and those conditions unlock his big hits (Maria The Ripper, the 30-damage We Are Jack) and a cheap invuln.

**▶ Playing as Jack the Ripper**
- Open with Fog of London for 3 turns of AoE affliction and 50% reduced enemy healing that also enables your other skills, and it cannot be countered.
- Land We Are Jack for 30 affliction on an enemy that is both Isolated and under Fog for your biggest burst.
- Read turn tempo so Streets of the Lost Isolates enemies who act alone or are the only one not to act, setting up Maria The Ripper.
- Aim Smokescreen Ambush at Isolated or Fogged targets for an Invulnerable turn plus a slashed cooldown.

**⚔ Playing against Jack the Ripper**
- We Are Jack drops 30 affliction on an Isolated plus Fogged target, so deny those two conditions to defang his burst.
- Fog of London is Uncounterable and cuts your healing 50% for 3 turns, so do not rely on counters or heals to answer it.
- Streets of the Lost Isolates enemies who act alone or are the lone non-actor, so coordinate your team's actions to avoid feeding him targets.
- Smokescreen Ambush turns him Invulnerable for a turn, so do not sink a key attack into it.

---

## Jaden Yuki
*Yu-Gi-Oh!* &nbsp;·&nbsp; `jaden` &nbsp;·&nbsp; `sustain` `dot` `disruption` `aoe`

**Core:** A Shield-stacking fusion engine: each base Elemental HERO permanently adds 25 Shield plus a persistent aura, and casting the right two base HEROes unlocks a powerful fused HERO (Flame Wingman, Rampart Blaster, Mudballman, or Mariner). Every aura only works while its Shield survives.

**▶ Playing as Jaden Yuki**
- Cast two base HEROes to enable a fusion, e.g. Avian plus Burstinatrix unlocks Flame Wingman for 35 auto-damage to a random enemy each turn.
- Every base skill permanently stacks 25 Shield, so pile them on to fuel the auras and stay bulky enough that they persist.
- Pick your fusion by pairing: Rampart Blaster (Clayman+Burstinatrix) Shatters and locks enemy Shields, while Mariner (Avian+Bubbleman) auto-cleanses your team each turn.
- Burstinatrix's 10 Affliction-per-turn to all enemies and Bubbleman's team heal keep passive value flowing while you assemble a fusion.

**⚔ Playing against Jaden Yuki**
- His auras only run while Shield holds, so dump Shield-shatter and Piercing damage to strip the 25/45/100 Shield and switch his whole engine off.
- Respect the fusion payoff: Flame Wingman auto-hits for 35 every turn and Rampart Blaster Shatters your entire team and blocks your Shield regen.
- Burstinatrix pings your whole team for 10 Affliction each turn regardless of his defenses, so cleanse it or race him down.

---

## Jesse Anderson
*Yu-Gi-Oh!* &nbsp;·&nbsp; `jesse` &nbsp;·&nbsp; `burst` `invuln` `aoe` `disruption`

**Core:** A Crystal Beasts stack-building engine: stacks scale Crystal Beasts damage, unlock escalating AoE and stun tiers on Crystal Abundance, and at 7 stacks permanently upgrade Crystal Beasts into the Rainbow Dragon nuke.

**▶ Playing as Jesse Anderson**
- Build stacks fast: each Crystal Beasts cast adds 2 (and hits harder per stack), while Crystal Blessing adds 1 and heals 15.
- Bank to 5+ stacks so Crystal Abundance stuns all enemies' Harmful skills, and to 7 stacks for triple damage before you fire it.
- Reaching 7 stacks upgrades Crystal Beasts into Rainbow Dragon, a 75 Piercing Uncounterable bypass hit, so push relentlessly for that threshold.
- Spend a stack on Crystal Promise for a turn of Invulnerability when threatened, weighing the tempo against your lost scaling.

**⚔ Playing against Jesse Anderson**
- Pressure or kill him before 7 stacks unlocks Rainbow Dragon, a 75 Piercing Uncounterable bypass that ignores Invulnerability.
- At 5+ stacks Crystal Abundance stuns your whole team's Harmful skills, so don't lean on a Harmful counter that turn.
- He can consume a stack for Crystal Promise Invulnerability, so avoid feeding your biggest hit into it.

---

## Kamado Nezuko
*Demon Slayer* &nbsp;·&nbsp; `nezuko` &nbsp;·&nbsp; `invuln` `sustain` `dot` `disruption`

**Core:** A mark-spreading engine: Blood Demon Art permanently marks any target (heal/cleanse an ally or damage an enemy), and Demonic Frenzy re-casts Blood Demon Art on every marked character at once while self-healing, with Pyrokinesis punishing marked enemies harder.

**▶ Playing as Kamado Nezuko**
- Spread Blood Demon Art marks widely, on enemies for damage and allies for the 20 heal plus affliction-cleanse, to load up Demonic Frenzy.
- Demonic Frenzy re-triggers Blood Demon Art on all marks and heals you 15 per target, so mark broadly before firing it.
- Mark an enemy first, then Pyrokinesis hits them for bonus affliction plus a 5-per-turn burn over the next 2 turns.
- Little Nezuko! buys a turn of Invulnerability, and Demon Blood auto-heals 10 per turn once you first drop to 50 HP.

**⚔ Playing against Kamado Nezuko**
- Blood Demon Art marks are permanent, and Demonic Frenzy bypasses invulnerability, so your invuln won't block its damage or the re-mark.
- Marked characters eat extra affliction and a burn from Pyrokinesis, so cleanse marks when you can before they compound.
- She stalls with Little Nezuko! Invulnerability and the Demon Blood heal, so save burst to punch through the sustain window.

---

## Kamado Tanjiro
*Demon Slayer* &nbsp;·&nbsp; `tanjiro` &nbsp;·&nbsp; `counter` `invisible` `invuln` `aoe`

**Core:** A form-swapping engine: his first three skills cycle between paired Water Breathing forms (via the Enhanced Smell passive and on-use swaps), alternating single-target Piercing, sustained AoE, and an invisible counter that sets up a Piercing Waterfall Basin.

**▶ Playing as Kamado Tanjiro**
- Act to swap forms: Fourth Form becomes Tenth Form: Constant Flux (AoE that gains 20 per dead enemy), and forms also cycle each turn via Enhanced Smell.
- Land the invisible Seventh Form counter, then Eighth Form: Waterfall Basin hits those countered enemies for bonus Piercing damage.
- Third Form: Flowing Dance extends its duration each time you act during it and grants 10 damage reduction, so keep chaining skills while it runs.
- Fire Sixth Form: Whirlpool against Energy-heavy foes to make your team invulnerable to Energy skills while pinging AoE.

**⚔ Playing against Kamado Tanjiro**
- Seventh Form: Drop Ripple Thrust is an invisible counter to the first Harmful non-Strategic skill, so don't blindly feed it your big attack.
- He blocks with Second Form: Water Wheel Invulnerability and Sixth Form's Energy-invuln, so time hits around his defensive forms.
- Tenth Form: Constant Flux gains 20 damage per dead enemy, snowballing into a lethal team-wipe once bodies start dropping.

---

## Katara
*Avatar: The Last Airbender* &nbsp;·&nbsp; `kitara` &nbsp;·&nbsp; `counter` `invuln` `sustain`

**Core:** A sustain-support kit anchored by Slicing Water Waves, a Channeled skill that deals permanent piercing damage, backed by a Harmful-reflect, a cleanse-heal, and an invuln.

**▶ Playing as Katara**
- Start Slicing Water Waves early since its Channeled 15 Piercing damage sticks permanently and keeps ticking.
- Pop Ice Deflection to reflect all Harmful skills targeting you without interrupting your ongoing channel.
- Use Soothing Water to heal an ally 35 and strip their damaging Afflictions in one action.
- Save Ice Barrier's invulnerability for when the enemy commits a big attack into you.

**⚔ Playing against Katara**
- Do not fire Harmful skills at her while Ice Deflection is active or they reflect back at you.
- Don't waste burst into Ice Barrier's invulnerable turn; wait it out then commit.
- Her cleanse-heal Soothing Water undoes your Affliction pressure, so time DoTs around it.

---

## Ken Kaneki
*Tokyo Ghoul* &nbsp;·&nbsp; `ken` &nbsp;·&nbsp; `counter` `dot` `invuln`

**Core:** A Bleed-stacking bruiser: Tentacle Pierce permanently ramps its own Piercing damage each cast, Disembowel locks Bleed permanent, and Bloodthirsty Rampage turns him into a counter.

**▶ Playing as Ken Kaneki**
- Spam Tentacle Pierce to permanently ramp its Piercing damage and layer stacking Bleed each turn.
- Fire Disembowel while Bleed is active on a target to make that Bleed permanent.
- Activate Bloodthirsty Rampage to auto-punish attackers with Tentacle Pierce and ignore Harmful non-damaging effects for 3 turns.
- Use Tentacle Block for an invulnerable turn when you can't afford to trade.

**⚔ Playing against Ken Kaneki**
- Don't attack him during Bloodthirsty Rampage; every new harmful skill triggers a Tentacle Pierce counter, and non-damaging harmful effects are ignored.
- Cleanse Bleed before he casts Disembowel or it becomes permanent damage-over-time.
- His Tentacle Pierce only grows, so trading long favors him; respect the Tentacle Block invuln turn.

---

## Killua Zoldyck
*Hunter x Hunter* &nbsp;·&nbsp; `killua` &nbsp;·&nbsp; `execute` `burst` `dot` `disruption` `invuln`

**Core:** A Decapitation stack-and-detonate assassin: build Decapitation counters with Claws Assassination and Heart Ripper, then detonate for 15 affliction per stack with an Execute at 20 HP or below.

**▶ Playing as Killua Zoldyck**
- Stack Decapitation with Claws Assassination and Heart Ripper before detonating for the big affliction payoff.
- Open with Claws Assassination to give both piercing skills +10 damage for the next 2 turns.
- Use Heart Ripper to stun for a turn while adding another Decapitation stack.
- Detonate Decapitation once the target is near 20 HP to trigger the Execute.

**⚔ Playing against Killua Zoldyck**
- Respect the Decapitation Execute: at 20 HP or below the detonation instantly kills, so heal above it or cleanse the stacks first.
- Each stacked counter is 15 affliction burst on detonation, so don't let stacks pile up.
- Heart Ripper stuns for a turn; don't count on that character acting, and wait out the Killua Hide invuln.

---

## King
*Seven Deadly Sins* &nbsp;·&nbsp; `king` &nbsp;·&nbsp; `counter` `invisible` `dot` `aoe` `invuln` `sustain` `burst`

**Core:** An Empower-and-punish zoner: True Spirit Spear Chastifold Empowers every skill and inflicts Disaster on anyone who attacks him or his allies, while the Disaster passive tacks Bleed onto his non-Bleed damage.

**▶ Playing as King**
- Cast True Spirit Spear Chastifold to Empower your whole kit and punish attackers with Disaster for 4 turns.
- Empowered Chastifold: Sunflower jumps to 35 and Chastifold: Increase becomes a 10 Piercing AoE over 3 turns.
- Chain your damage so the Disaster passive adds 10 Bleed after each non-Bleed hit.
- Shield allies with Chastifold: Guardian, or use Pollen Garden to make idle allies invulnerable and heal them.

**⚔ Playing against King**
- After True Spirit Spear Chastifold, attacking King or his allies inflicts Disaster on you, so think before swinging.
- Empowered Chastifold: Sunflower is a 35-damage burst window; respect the empowered state.
- Empowered Chastifold: Guardian reflects your next Harmful skill and the reflect is Invisible, so you won't see it coming.
- Base Sunflower can't hit targets already under Disaster, but his Bleed and AoE pressure still stacks fast.

---

## Koro-sensei
*Assassination Classroom* &nbsp;·&nbsp; `koro` &nbsp;·&nbsp; `invuln` `sustain` `disruption`

**Core:** A rotating class-invulnerability field (Hard Lessons) blankets the whole board while Pitch Black turns Impossible Speed into a bypassing, mark-spreading poke that also feeds his Class Is In Session shield/heal passive.

**▶ Playing as Koro-sensei**
- Open with Hard Lessons to wrap every character in rotating class-invulnerability, then spam Impossible Speed to proc Class Is In Session shields and heals.
- Cast Pitch Black so Impossible Speed Bypasses invuln and marks a target, then repeat it to also strike every marked enemy for free.
- Drop Protective Molting on a threatened ally to auto-cleanse and heal 25 when they're hit, which also makes your next Pitch Black free.
- Remember the passive rewards inaction, so idle allies gain Shield and stunned allies heal 10 HP.

**⚔ Playing against Koro-sensei**
- Track Hard Lessons' rotating invulnerable class each turn or your Physical, Mental, Energy, or Affliction skill will whiff harmlessly.
- Once Pitch Black is up, Impossible Speed Bypasses invulnerability and marks targets for repeated free hits, so pressure or peel Koro fast.
- Don't lean on invuln to save a marked ally, since his bypass hits straight through it.

---

## Korra
*Avatar* &nbsp;·&nbsp; `korra` &nbsp;·&nbsp; `counter` `invisible` `transform` `aoe` `disruption`

**Core:** Element-counter cycling: each Control skill is an Invisible counter that swaps into an elemental attack when it fires, and using one element five times triggers a one-time Avatar State that buffs her and upgrades her kit.

**▶ Playing as Korra**
- Lead with the Invisible Control counters to bait an enemy's matching skill class, then unleash the swapped elemental attack.
- Commit repeatedly to one element to hit five uses and trigger the once-per-game Avatar State, picking the buff that fits the matchup.
- Use Energybending early to permanently silence a key enemy or make an ally immune to non-damage effects, since it cannot be removed.
- Lean on Air Wave and Gate Open for piercing AoE and Water Arm Stun to lock down non-Mental skills for two turns.

**⚔ Playing against Korra**
- Every Control skill is an Invisible counter, so don't throw your Affliction, Mental, Physical, or Energy skill into an open Korra turn.
- Watch her element count: five same-element uses trigger a one-time Avatar State with strong buffs and upgraded skills, so burst her before it lands.
- Energybending permanently silences and cannot be removed, so protect your key non-damage carry from being tagged.

---

## Kugisaki Nobara
*Jujutsu Kaisen* &nbsp;·&nbsp; `nobara` &nbsp;·&nbsp; `counter` `invisible` `execute` `stun-lock` `disruption`

**Core:** Straw Doll Technique locks a single target with Isolation and healing reduction, empowering her escalating Hammer Swing stacks, her Resonance stun rotation, and her Hairpin counter-execute against that one enemy.

**▶ Playing as Kugisaki Nobara**
- Tag your priority target with Straw Doll Technique first to Isolate them, cut their healing, and extend Resonance stuns to three turns.
- Stack Hammer Swing on one enemy to permanently ramp its damage, then pair it with Resonance to rotate stuns across their skill classes.
- Hold Hairpin, an Invisible counter, to punish a big Harmful skill and execute enemies at 30 HP or less.
- Use Embrace Pain to ignore execute effects and convert enemy debuffs into heal plus DR, and note it works while stunned.

**⚔ Playing against Kugisaki Nobara**
- Hairpin is an Invisible counter that executes you at 30 HP or less, so never throw a Harmful skill at Nobara while low.
- Once Straw Doll marks you, you're Isolated with reduced healing and eat three-turn Resonance stuns, so play around the locked target.
- Every Hammer Swing permanently raises the damage that skill deals to you, so don't let it stack unanswered.

---

## Kurapika
*Hunter x Hunter* &nbsp;·&nbsp; `kurapika` &nbsp;·&nbsp; `execute` `invisible` `stun-lock` `dot` `disruption`

**Core:** The Chain Jail to Judgement Chain combo marks and stuns a target, then locks them under an unremovable death sentence that instant-kills after three new skills or bleeds them for staying idle.

**▶ Playing as Kurapika**
- Land Chain Jail to stun and mark a target, which swaps in Judgement Chain, then fire it that turn to lock the death sentence.
- Keep pressuring the sealed target since Judgement Chain kills after three new skills or drains 10 affliction and 1 energy each idle turn.
- Pop Scarlet Eyes, an Invisible skill, to ignore the next enemy damage while it buffs Bokken Smash by 10.
- Use Bokken Smash to strip Shields and Holy Chain to cleanse and heal an ally 35 HP.

**⚔ Playing against Kurapika**
- Judgement Chain is an unremovable execute, so after Chain Jail marks you, avoid using three new skills and eat the affliction drain instead.
- Scarlet Eyes is Invisible and negates his next damage taken, so don't waste a big hit into it.
- Chain Jail stuns your non-Mental skills, so keep a Mental option or cleanse ready.

---

## Kyojuro Rengoku
*Demon Slayer* &nbsp;·&nbsp; `rengoku` &nbsp;·&nbsp; `counter` `transform` `dot`

**Core:** Shatter-and-Bleed payoff engine: he applies Shatter to amplify his Bleed and extend his damage-over-time, backed by a team counter (Fourth Form) that Shatters the whole enemy team and an Esoteric Art skill-swap into the Uncounterable Ninth Form.

**▶ Playing as Kyojuro Rengoku**
- Open with Second Form: Rising Scorching Sun to Shatter, then Swift Sword Slash lands doubled 10-per-turn Bleed on the Shattered target.
- Fourth Form: Blooming Flame Undulation counters the first harmful skill against your team and Shatters every enemy, priming your Bleed payoffs.
- Esoteric Art cleanses your damage effects, ignores Stun for a turn, and unlocks the Uncounterable Ninth Form for 40 damage plus extended Bleed.
- Ninth Form's Bleed lasts an extra turn against Shattered enemies, so keep Shatter up before you fire it.

**⚔ Playing against Kyojuro Rengoku**
- Fourth Form: Blooming Flame Undulation counters the first harmful skill on his team and Shatters your whole squad, so don't lead with your combo.
- Esoteric Art swaps his kit into the Uncounterable Ninth Form (40 damage) — counters and reactions won't stop it.
- Avoid trading into Shattered allies; Shatter doubles Swift Sword Slash's Bleed and extends Ninth Form's damage over time.

---

## LadyDevimon
*Digimon* &nbsp;·&nbsp; `ladydevimon` &nbsp;·&nbsp; `invuln` `dot` `disruption`

**Core:** Affliction attrition: her passive Lady's Poison permanently stacks 5 Affliction on anyone who attacks her for the rest of the game, backed by pure Affliction damage and an invulnerability stall.

**▶ Playing as LadyDevimon**
- Bait enemies into hitting her — Lady's Poison stacks permanent 5 Affliction per attacker every turn for the rest of the game.
- Black Wing chips 25 Affliction damage while Darkness Spear seeds another Lady's Poison stack plus Nullify and a non-Affliction damage cut.
- Darkness Wave buys an invulnerable turn to stall safely while your stacked poison ticks the enemy down.
- Devil Slap Taunts a target to control who can act against you.

**⚔ Playing against LadyDevimon**
- Every Harmful hit on her stacks permanent Lady's Poison Affliction on that attacker for the rest of the game — pick your attacker or kill her fast.
- Darkness Wave grants an invulnerable turn, so don't dump your burst into it.
- Devil Slap Taunts and Darkness Spear's 10 Nullify plus damage reduction can neutralize your carry for a turn.

---

## Levi Ackerman
*Attack on Titan* &nbsp;·&nbsp; `levi`

**Core:** A straightforward physical-damage kit with no special engine in the text: four Physical skills, a Strategic setup tool in Unmatched Agility, and a passive (Relentless Captain) whose effect isn't shown.

**▶ Playing as Levi Ackerman**
- Focus Physical energy, since Precision Strike, ODM Gear Assault, and Humanity's Strongest are all Physical damage.
- Use Unmatched Agility, his Strategic tool, to set up or protect yourself before committing to attacks.
- ODM Gear Assault is an Action, so line it up on a turn you can dedicate to it.

**⚔ Playing against Levi Ackerman**
- No counter, stealth, transform, or execute appears in his kit, so respect steady Physical damage and mitigate it.
- Treat Unmatched Agility as a setup or defensive move rather than a burst threat to race through.

---

## Lucy Heartfilia
*Fairy Tail* &nbsp;·&nbsp; `lucy` &nbsp;·&nbsp; `aoe` `invuln`

**Core:** All-enemy AoE pressure with a setup lever: Gemini extends her skills' duration and unlocks the stronger all-enemy nuke Urano Metria, supported by team damage reduction and an invulnerable turn.

**▶ Playing as Lucy Heartfilia**
- Lead with Gemini to keep your skills active an extra turn and unlock the 25-damage AoE Urano Metria.
- Aquarius hits all enemies for 15 and grants your team 10 damage reduction — strong when you're under pressure.
- Capricorn is your 25 single-target nuke; close games with Urano Metria's team-wide 25 AoE.
- Leo gives an invulnerable turn to survive an incoming burst.

**⚔ Playing against Lucy Heartfilia**
- Gemini unlocks Urano Metria (25 to all enemies) and extends her effects, so expect escalating team-wide damage — spread your HP.
- Leo grants Lucy an invulnerable turn; don't waste your combo swinging into it.

---

## Lyserg Diethel
*Shaman King* &nbsp;·&nbsp; `lyserg` &nbsp;·&nbsp; `execute` `stun-lock` `aoe` `counter` `disruption`

**Core:** Morphin Mark engine: marks fuel an all-target stun (Blind Pendulum), an escalating delayed nuke, and a low-HP execute (Big Ben Wire Frame), while Mastema Dolkeen auto-generates marks and punishes attackers.

**▶ Playing as Lyserg Diethel**
- Stack Morphin Marks with Homing Pendulum, then Blind Pendulum stuns every marked enemy at once.
- At 3+ marks Blind Pendulum becomes Big Ben Wire Frame — a per-mark scaling delayed nuke and a low-HP execute.
- Mastema Dolkeen auto-marks each turn and punishes attackers, swapping Homing Pendulum for the self-healing AoE Halvaya.
- Heavenly Intervention saves a flagged ally from one lethal hit and counter-hits the attacker for 35.

**⚔ Playing against Lyserg Diethel**
- Big Ben Wire Frame executes below 10 HP (+10 per Morphin Mark) and detonates a per-mark scaling nuke — clear marks and stay topped up.
- Blind Pendulum stun-locks every marked enemy, and attacking into Mastema Dolkeen only piles on more marks.
- Heavenly Intervention makes his chosen ally Immortal against a killing blow once and hits your attacker for 35 — don't commit lethal blindly.

---

## Machinedramon
*Digimon* &nbsp;·&nbsp; `machinedramon` &nbsp;·&nbsp; `aoe` `dot` `disruption` `invuln` `burst`

**Core:** A Taunt-and-redirect control engine that forces enemies to attack him while taxing their energy, capped by a death-explosion passive.

**▶ Playing as Machinedramon**
- Lead with Infinite Hand for team-wide DoT plus its Taunt-redirect, punishing any enemy who attacks someone other than you.
- Giga Cannon and Giga Destroyer Taunt threats; Giga Destroyer also strips a Physical attacker by stunning their Physical skills for 2 turns.
- Pop EMP Wave for a 1-turn invuln and a banked Blue energy when you need to survive a swing.
- Once below 20 HP, Catastrophe Day fires at the end of your next turn for 25 to everyone, so trade freely and take them with you.

**⚔ Playing against Machinedramon**
- Respect Catastrophe Day: when he drops under 20 HP, at his next turn's end he deals 25 to ALL targetable characters and dies, so spread out or burst him past it.
- While Infinite Hand is up, hitting anyone but Machinedramon Taunts you onto him, so don't waste attacks elsewhere.
- EMP Wave gives a 1-turn invuln, so don't dump your big hit into it.

---

## Madoka Kaname
*Puella Magi Madoka Magica* &nbsp;·&nbsp; `madoka` &nbsp;·&nbsp; `aoe` `dot` `sustain` `invuln` `disruption`

**Core:** A Shield/Nullify stacking engine: she plants Shield on allies and Nullify on enemies that both fuel Magical Arrow and feed a passive counting toward a self-kill and a game-swinging ultimate.

**▶ Playing as Madoka Kaname**
- Open with Karmic Destiny so every new skill permanently adds Shield to allies and Nullify to enemies, arming Magical Arrow's +5-per-effect bonus.
- Use Rose Barrage's free follow-up to pile 15 Nullify on one enemy, then Magical Arrow hits far harder.
- Bank passive stacks to 7 to unlock My Wish: resurrect an ally, full-heal-cleanse-invuln one, or silence all enemies at the cost of her life.
- Watch the passive: 15 stacks of absorbed Shield/Nullify instantly kills Madoka, so don't over-plant shields the enemy will chew through.

**⚔ Playing against Madoka Kaname**
- My Wish at 7 passive stacks is a massive swing: it can rez a dead ally at 50 HP, full-heal-cleanse-invuln one, or PERMANENTLY silence your whole team, so pressure her before she banks stacks.
- Every new skill you use plants permanent Nullify on you under Karmic Destiny, directly powering her Magical Arrow.
- Rose Barrage is team-wide piercing DoT for 4 turns that raw HP can't block.

---

## Maka Albarn
*Soul Eater* &nbsp;·&nbsp; `maka` &nbsp;·&nbsp; `counter` `invisible` `dot` `disruption` `burst`

**Core:** A channel-and-detonate engine: Witch Hunter taxes energy and bleeds the target while setting up Figure-6 Hunter's 35 true-damage payoff, backed by an invisible counter.

**▶ Playing as Maka Albarn**
- Channel Witch Hunter to apply piercing DoT and a +1 random energy tax, then swap to Figure-6 Hunter for 35 true damage.
- Remember Witch Hunter ends if the target uses a new harmful skill, so it pressures them to stall or lose your setup.
- Scythe Deflection is an invisible 1-turn counter against Physical skills targeting Maka, so drop it to bait an enemy attack.
- Stack allied damage buffs before Figure-6 Hunter since it takes double effect from them; Soul Resonance is free and unstunnable with Soul on your team.

**⚔ Playing against Maka Albarn**
- Beware Scythe Deflection, an INVISIBLE counter that punishes any Physical skill targeting Maka for a turn, so don't blindly throw physicals at her.
- Under Witch Hunter you bleed piercing DoT and pay +1 random energy, and Figure-6 Hunter threatens 35 true damage that ignores shields.
- Using a new harmful skill ends Witch Hunter, so weigh escaping the setup against feeding her turn.

---

## Mami Tomoe
*Puella Magi Madoka Magica* &nbsp;·&nbsp; `mami` &nbsp;·&nbsp; `counter` `burst` `disruption` `aoe`

**Core:** A mark-stacking payoff engine: Tiro Concert marks build on the enemy team and cash out as Tiro Finale burst, all racing a Soul Gem timer that unlocks the finisher but self-kills at 6 stacks.

**▶ Playing as Mami Tomoe**
- Open with Tiro Concert to permanently mark the whole enemy team so every skill they use deals damage and stacks.
- Use Tiro Assault to counter the first Harmful skill each turn, feeding both Tiro Concert and Soul Gem stacks.
- At 3 Soul Gem stacks, Ribbon Wrap becomes Tiro Finale, so isolate a heavily-marked target and detonate for 40 plus 10 per stack.
- Mind the Soul Gem clock, which ticks up each turn and kills Mami at 6 stacks, so land Tiro Finale before then.

**⚔ Playing against Mami Tomoe**
- Respect Tiro Assault's counter: it counters the first Harmful skill each turn for 3 turns and stacks more marks every time, so don't feed it.
- Tiro Concert marks build toward Tiro Finale, a 40-damage burst growing +10 per stack, so avoid getting isolated by Ribbon Wrap before the payoff.
- She permanently ignores stuns via Soul Gem so you can't lock her down, but she self-destructs at 6 stacks, letting you race her clock.

---

## Marco the Phoenix
*One Piece* &nbsp;·&nbsp; `marco` &nbsp;·&nbsp; `sustain`

**Core:** A straightforward support/sustain kit: the clear engine is healing via Blue Flames of Resurrection (25 HP), paired with Hoo-In, a Bypassing physical strike that ignores invulnerability, plus assorted Helpful/Strategic protection tools.

**▶ Playing as Marco the Phoenix**
- Keep allies topped up with Blue Flames of Resurrection's 25-HP heal to grind out attrition fights.
- Save Hoo-In for enemies hiding behind invulnerability, since its Bypassing class punches straight through.
- Round out your turns with the Helpful/Strategic tools (Immortal Thistle, Phoenix Wing Block, Pineapple Stone) to protect the team rather than race for damage.

**⚔ Playing against Marco the Phoenix**
- Don't count on invulnerability to stop Hoo-In — its Bypassing class ignores that protection entirely.
- Marco's 25-HP heal drags out fights, so focus overwhelming burst on one target to outpace his sustain.

---

## Mash Kyrielight
*Fate* &nbsp;·&nbsp; `mash` &nbsp;·&nbsp; `invuln` `aoe` `disruption` `sustain`

**Core:** A Shield-stacking protection tank: Shield on Mash both scales Flying Galahad's damage and gates A Knight That Protects, which shields her while reflecting harmful skills, then punishes whoever breaks that Shield.

**▶ Playing as Mash Kyrielight**
- Cast A Knight That Protects to make an ally invulnerable to non-Strategic skills and reflect harmful skills back onto Mash's 30 Shield.
- Pump the Shield with Shield of White Walls (up to 40) to both survive and boost Flying Galahad's per-Shield damage.
- The instant the Shield breaks, swing Around Round Axe at whoever broke it for bonus damage and a 1-turn stun.
- Use Lord Camelot as a 2-turn team-invulnerability panic button and Around Round Crash to AoE plus taunt your primary target.

**⚔ Playing against Mash Kyrielight**
- Respect Lord Camelot — it makes her whole team invulnerable for 2 turns, so hold your burst instead of feeding it.
- A Knight That Protects reflects your harmful skills back to Mash and shields her; break that Shield with Strategic skills, which the protection ignores.
- Whoever breaks her Shield eats Around Round Axe's bonus damage and a 1-turn stun, so choose your breaker deliberately.

---

## Mavis Vermillion
*Fairy Tail* &nbsp;·&nbsp; `mavis` &nbsp;·&nbsp; `aoe` `burst` `invuln` `disruption` `sustain`

**Core:** A stack-snowball support: the Fairy Star Strategy passive marks a random ally each turn, and when they use a new skill Mavis banks a stack that escalates team buffs (Shield to heal to permanent +damage to free skills), all behind the Fairy Law channel finisher.

**▶ Playing as Mavis Vermillion**
- Have your marked ally use a new skill every turn to build Fairy Star Strategy stacks and climb the buff ladder toward free skills.
- Start channeling Fairy Law early; after 3 turns it hits all non-invulnerable enemies for 35 with a stun and heals your team 25.
- Use Bestow to hand an ally Fairy Glitter, a 40 True-damage nuke that is Uncounterable.
- Fairy Sphere ignores all damage for a turn as a panic button, while Fairy Heart parks Mavis invulnerable and banks Random energy.

**⚔ Playing against Mavis Vermillion**
- Fairy Law is a 3-turn channel — go invulnerable or pressure Mavis before it detonates for 35 AoE damage plus a stun.
- Watch for Bestow granting an ally Fairy Glitter, a 40 True-damage burst that cannot be countered.
- Deny her snowball — Fairy Star Strategy at 3+ stacks permanently buffs her team's damage and hands out cost-free skills.

---

## Maximillion Pegasus
*Yu-Gi-Oh!* &nbsp;·&nbsp; `pegasus` &nbsp;·&nbsp; `counter` `invisible` `transform` `invuln` `stun-lock`

**Core:** A counter-and-transform trap kit: Relinquished counters a harmful skill for Shield, and landing Dark-Eyes Illusionist's Invisible mark while holding that Shield permanently upgrades Relinquished into Thousand-Eyes Restrict, a 4-turn harmful-skill lockdown.

**▶ Playing as Maximillion Pegasus**
- Bait a harmful skill into Relinquished; the counter grants 30 Shield and makes the countered skill unusable while you hold it.
- While holding Relinquished's Shield, trigger Dark-Eyes Illusionist's Invisible mark to permanently transform into Thousand-Eyes Restrict.
- Thousand-Eyes Restrict stuns an enemy's harmful skills for 4 turns — aim it at their main damage threat.
- Chip with Toon Assault's 20 Bypassing damage over 2 turns and dodge burst with Millennium Eye's 1-turn invulnerability.

**⚔ Playing against Maximillion Pegasus**
- Respect Relinquished — using a Harmful skill into it gets you countered and shields Pegasus, so force it out with a throwaway skill first.
- Dark-Eyes Illusionist marks you Invisible: use a new skill or take 25 damage, but acting can transform his counter into Thousand-Eyes Restrict.
- Thousand-Eyes Restrict locks your harmful skills for 4 turns — break Pegasus's 40 Shield to end the transform early.

---

## Mayuri Kurotsuchi
*Bleach* &nbsp;·&nbsp; `kurotsuchi` &nbsp;·&nbsp; `dot` `transform` `aoe` `disruption` `sustain` `invuln` `stun-lock`

**Core:** An Affliction-stacking engine fed by Drug empowerment and a use-count transformation: Ashisogi Jizo stacks toward a permanent DoT, Data Collection empowers his randomly-swapping Drug skills, and using 5 skills releases Bankai.

**▶ Playing as Mayuri Kurotsuchi**
- Repeatedly land Ashisogi Jizo to reach 3 stacks, where its 5 Affliction-per-turn damage becomes permanent.
- Use Data Collection to reveal invisible skills, gain Random energy, and empower your Drug skills' effects.
- Remember Flesh-Healing, Superhuman, and Postcognition Drugs swap randomly each turn, so plan around whichever is currently active.
- Fire 5 skills to trigger Bankai - Konjiki Ashisogi Jizo, amplifying all Affliction and swapping Ashisogi Jizo into AoE Deadly Gas.

**⚔ Playing against Mayuri Kurotsuchi**
- Ashisogi Jizo becomes a PERMANENT damage-over-time at 3 stacks, so cleanse it or pressure him before it locks in.
- Nikushibuki is a death-save: your kill instead Banishes him and returns him at 30 HP, then it grants Invulnerability.
- After 5 skills his Bankai boosts all Affliction and Deadly Gas blocks your cleansing and healing entirely.
- Don't invest in invisibility against him; Data Collection reveals all invisible skills and effects for 3 turns.

---

## Megumin
*Konosuba* &nbsp;·&nbsp; `megumin`

**Core:** The provided kit text contains no ability descriptions, so only skill types are known: Explosion (Energy, Harmful) is her single damaging skill, fronted by the Mental/Strategic setups Waga wa Megumin! and Crimson Incantation.

**▶ Playing as Megumin**
- Explosion is her only Harmful skill, so treat Waga wa Megumin! and Crimson Incantation as setup pointed toward it.
- Face-first Slide is a Physical/Strategic utility, so lean on it as support rather than as damage.

**⚔ Playing against Megumin**
- Her only damage source is Explosion (Energy); the rest of her kit reads as Mental/Physical/Strategic setup.
- With no descriptions available, play cautiously around Explosion as her single obvious payoff skill.

---

## Meliodas
*Seven Deadly Sins* &nbsp;·&nbsp; `meliodas` &nbsp;·&nbsp; `counter` `invisible` `invuln` `burst` `aoe` `dot`

**Core:** A counter-punish engine: Full Counter and the passive Dragon's Sin of Wrath punish enemies who attack, while Revenge Counter is a stealth charge window that scales its payoff by every Harmful skill he soaks.

**▶ Playing as Meliodas**
- Hold Full Counter to deter Harmful skills, baiting enemies into eating 25 Piercing when they attack.
- Revenge Counter goes Invisible for 2 turns, then unleashes 30 Piercing plus 30 per Harmful skill received, so soak hits to fuel it.
- Dragon's Sin of Wrath passively deals 10 Piercing whenever enemies hit your allies with non-Strategic skills.
- Jitsuzo Bunshin hits all enemies and grants a turn of Invulnerability for defensive tempo.

**⚔ Playing against Meliodas**
- Full Counter punishes your next NEW Harmful skill for 25 Piercing, so don't attack him blindly while it is up.
- Revenge Counter charges while he's Invisible and can't act; every Harmful hit adds +30, so stop attacking him during it.
- Dragon's Sin of Wrath retaliates for non-Strategic skills used on his allies, even when Full Counter doesn't trigger.
- Hellblaze's Affliction blocks your healing for 2 turns.

---

## Midoriya Izuku (Deku)
*My Hero Academia* &nbsp;·&nbsp; `midoriya` &nbsp;·&nbsp; `burst` `invuln` `stun-lock` `disruption` `transform`

**Core:** A stacking self-buff ramp: One For All permanently grows his damage, damage reduction, and stun immunity at an HP cost, escalating into Faux 100% which grants a huge Piercing burst plus permanent Invulnerability and Invuln-bypass.

**▶ Playing as Midoriya Izuku (Deku)**
- Stack One For All for permanent +damage, +damage reduction, and stun immunity, but watch HP since each new skill costs 5.
- St. Louis Smash full-stuns and swaps to Faux 100% for a turn, opening a 45 Piercing burst window.
- After Faux 100%, all his skills grant 1-turn Invulnerability and Bypass Invulnerability for the rest of the game.
- Chain control with Blackwhip (stuns helpful skills, +delayed damage) and Detroit Smash (full silence) to lock enemies down.

**⚔ Playing against Midoriya Izuku (Deku)**
- St. Louis Smash full-stuns you and unlocks Faux 100%, a 45 Piercing BURST that then makes all his skills Invulnerable and Invuln-bypassing.
- Once One For All is stacked he ignores stun effects for the rest of the game, so stop relying on stuns.
- Expect heavy disruption: St. Louis full-stun, Detroit silence, and Blackwhip's helpful-skill stun.
- He self-damages 5 HP per skill via One For All, so chip damage can close the gap despite his ramp.

---

## Mikasa Ackerman
*Attack on Titan* &nbsp;·&nbsp; `mikasa` &nbsp;·&nbsp; `invisible` `stun-lock` `invuln` `disruption`

**Core:** A stun-support bruiser whose piercing hits punish stunned targets while she locks enemies across both skill categories and shields allies from death; an invisible Maneuvering Gear swaps in the shield-shattering Thunder Spear.

**▶ Playing as Mikasa Ackerman**
- Open with Unlikely Savior to go invulnerable and stun the target's non-Strategic skills, then Titan Takedown for its +5 stun bonus.
- Cast Maneuvering Gear to swap in Thunder Spear, then use it to shatter a Shield and stun the target's Strategic skills.
- Stack Rallying Call early so its unkillable window grows, carrying your team through enemy burst and executes.
- Chain Unlikely Savior (non-Strategic stun) into Thunder Spear (Strategic stun) to fully lock an enemy's options.

**⚔ Playing against Mikasa Ackerman**
- Maneuvering Gear is invisible, so an ally suddenly shrugging off your Harmful effects means Thunder Spear is loaded to shatter Shields and stun.
- Rallying Call makes her whole team unkillable for stacking turns, so don't dump burst or executes while it's active.
- Titan Takedown is Uncounterable and hits harder into stuns, so avoid handing her a stunned target.

---

## Mine
*Akame ga Kill* &nbsp;·&nbsp; `mine` &nbsp;·&nbsp; `burst` `aoe` `stun-lock` `invuln`

**Core:** A reverse-scaling glass cannon: the lower Mine's HP falls, the more her guns gain damage, piercing, AoE stun, and cost reduction, making near-death her strongest state; Genius Sniper marks a target for Uncounterable, Bypassing bonus damage.

**▶ Playing as Mine**
- Mark a priority target with Genius Sniper to make your skills Uncounterable, Bypassing, and +10 damage against them for 3 turns.
- Lean into low HP: under 70 Pumpkin pierces harder, under 60 Blast Blade AoE-stuns, under 40 it's cheap, under 30 it hits huge.
- Use Narrow Dodge to survive a turn while staying inside your dangerous low-HP damage bands.

**⚔ Playing against Mine**
- A wounded Mine is a bigger threat, not a smaller one — below 30 HP her AoE Blast Blade adds massive burst, so finish her fast or leave her be.
- Once Genius Sniper marks someone, Mine's skills turn Uncounterable and Bypassing for 3 turns, so counters and invuln won't save that target.
- Below 60 HP her Blast Blade stuns your whole team's non-Strategic skills, so respect that AoE lockout window.

---

## Minene Uryuu
*Mirai Nikki* &nbsp;·&nbsp; `minene` &nbsp;·&nbsp; `trap` `invuln` `burst` `dot` `aoe`

**Core:** A trap-and-detonate stack engine: Grenade plants Explosives Detonator plus a Ticking Trigger that auto-grows stacks every turn, Landmines punishes attackers with more stacks, and Explosives Detonator cashes them all in for invulnerability-bypassing burst.

**▶ Playing as Minene Uryuu**
- Lead with Grenade to plant Explosives Detonator and a Ticking Trigger that adds a stack every turn until you detonate.
- Stall with Escape Route and Master of Disguise to let stacks tower, then fire Explosives Detonator for a huge invuln-bypassing hit.
- Plant Landmines on a low ally to punish any attacker with Affliction damage and free Detonator stacks.
- Escape Route becomes fully invulnerable under 70 HP, and Escape Diary can reset its cooldown, so lean on it when pressured.

**⚔ Playing against Minene Uryuu**
- Beware Explosives Detonator: it Bypasses invulnerability and hits 10 per stack, so never let stacks pile up unchecked.
- Killing Minene backfires, since on death every Explosives Detonator charge on the field detonates at once.
- Don't hit an ally carrying Landmines, or you'll eat Affliction and hand her another Detonator stack.
- Escape Route and Escape Diary make her slippery to single big hits, so chip her or force the detonate.

---

## Misaka Mikoto
*A Certain Scientific Railgun* &nbsp;·&nbsp; `misaka` &nbsp;·&nbsp; `transform` `burst` `invuln` `sustain`

**Core:** Runs on ability-upgrades and damage-fed scaling: using Iron Sand or Railgun unlocks a one-turn stronger form (Iron Colossus / Ultra Railgun), while Overcharge permanently boosts Railgun and Iron Sand every time she takes damage.

**▶ Playing as Misaka Mikoto**
- Fire Railgun (bypasses invuln, uncounterable) to unlock the 40-damage Ultra Railgun nuke on your next turn.
- Pop Overcharge right before you expect to take hits so every point of damage permanently buffs your Railgun and shields.
- Pick your commit carefully: Ultra Railgun doubles your kit but adds cost, while Iron Colossus makes Iron Sand and Railgun hit the whole enemy team.
- Fall back on Electric Deflection or Iron Colossus for invulnerability when you need to survive a turn.

**⚔ Playing against Misaka Mikoto**
- Railgun and Ultra Railgun bypass invulnerability and can't be countered or reflected, so defensive layers won't stop them.
- Ultra Railgun is a 40-damage transformation burst — respect the turn right after she fires Railgun, when it's loaded.
- Don't chip her while Overcharge is up; each hit permanently strengthens her Railgun and shields.

---

## Monkey D. Luffy
*One Piece* &nbsp;·&nbsp; `luffy` &nbsp;·&nbsp; `burst` `stun-lock` `aoe` `invuln` `sustain`

**Core:** An anti-invulnerability specialist: every offensive skill Bypasses Invulnerability and gains a bonus against invulnerable enemies, while the Rubber Body passive converts all his damage into Shield.

**▶ Playing as Monkey D. Luffy**
- Attack invulnerable enemies freely — Pistol refunds red energy, Gatling extends, and Bazooka fully stuns, all while bypassing their invuln.
- Spam Gomu Gomu No Gatling Gun to stack its permanent +5 damage growth across the whole enemy team.
- Rubber Body turns your damage into Shield, so hitting hard keeps you tanky — pair it with Balloon for a survival turn.

**⚔ Playing against Monkey D. Luffy**
- Never lean on invulnerability against Luffy — his skills bypass it and Bazooka's 40 damage fully stuns you for being invulnerable.
- Bazooka is a 40-damage burst threat, and since his damage feeds him Shield, straight trades favor him.
- Gatling Gun's damage permanently grows each cast, so don't let a long game snowball his AoE.

---

## Muichiro Tokito
*Demon Slayer* &nbsp;·&nbsp; `muichiro` &nbsp;·&nbsp; `aoe`

**Core:** The only detailed engine is a Third Form stack count: Scattering Mist Splash hits the whole enemy team for 10, upgrading to 15 once Muichiro holds 3 stacks of Third Form. His other Forms are Physical/Strategic/Helpful setup tools whose effects aren't spelled out in the kit text.

**▶ Playing as Muichiro Tokito**
- Lean on Scattering Mist Splash as your damage core, ramping its team-wide hit from 10 to 15 once you hold 3 Third Form stacks.
- Weave your Strategic and Helpful Forms in as setup between AOE turns rather than committing everything at once.

**⚔ Playing against Muichiro Tokito**
- Scattering Mist Splash is team-wide AOE, so avoid clustering your low-HP characters, especially once he reaches the 15-damage version.
- Several of his Forms are Strategic or Helpful setup, so expect a buildup before his biggest AOE turns.

---

## Myotismon
*Digimon* &nbsp;·&nbsp; `myotismon` &nbsp;·&nbsp; `counter` `invuln` `disruption` `sustain`

**Core:** A mark-and-punish engine built around Grisly Wing's mark: the mark permanently shuts off a target's healing via Crimson Lightning and extends Disintegrate's counter-banish, while Grisly Wing self-heals for the damage it deals.

**▶ Playing as Myotismon**
- Open with Grisly Wing to mark a target for 3 turns and heal yourself off its Piercing damage.
- On a marked target, Crimson Lightning permanently blocks their healing and Disintegrate's counter banishes them for 2 turns instead of 1.
- Set Disintegrate to punish enemy Helpful skills, and hold Myotismon Protect for a turn of Invulnerability when focused.

**⚔ Playing against Myotismon**
- Don't use a Helpful skill into Disintegrate — it counters and banishes you, for 2 turns if you're marked by Grisly Wing.
- Once Grisly Wing marks you, Crimson Lightning permanently blocks all your healing, so cleanse or bait the mark.
- He can go Invulnerable with Myotismon Protect, so don't dump a burst turn into it.

---

## Nagisa Shiota
*Assassination Classroom* &nbsp;·&nbsp; `nagisa` &nbsp;·&nbsp; `counter` `invuln` `dot` `disruption` `sustain` `burst`

**Core:** A Silence-and-Affliction engine centered on Killing Intent: Bloody Knife empowers it with lifesteal and +5 damage, Friendly Smile stacks to make its Affliction repeat and extend the Silence, and it also strikes every enemy marked by Bloody Knife.

**▶ Playing as Nagisa Shiota**
- Set up with Bloody Knife first, then fire Killing Intent for empowered Affliction, lifesteal, and a Silence for two turns.
- Stack Friendly Smile before spending it on Killing Intent to repeat the Affliction and extend the Silence one turn per stack.
- Killing Intent also strikes every enemy marked by Bloody Knife, so spread marks for multi-target pressure.
- Use Don't Test Me as defense — it ignores all Harmful damage and Silences anyone who touches you for two turns.

**⚔ Playing against Nagisa Shiota**
- Never attack into Don't Test Me — Nagisa ignores all Harmful damage that turn and Silences your attacker for two turns.
- Respect stacked Friendly Smile: it makes him Invulnerable and turns the next Killing Intent into a repeating, long-Silence burst.
- Killing Intent Silences and drains health, and his passive makes Silenced characters deal 5 less damage to him.

---

## Naruto Uzumaki
*Naruto* &nbsp;·&nbsp; `naruto`

**Core:** No ability descriptions are provided in the kit text, so this reads as a straightforward damage kit: a Physical strike (Toad Kumite), an Energy nuke (Rasenshuriken), a Strategic Energy tool (Sage Chakra Gather), and a Strategic defensive skill (Naruto Block), with no special engine shown.

**▶ Playing as Naruto Uzumaki**
- Lead with Toad Kumite and Rasenshuriken for Physical and Energy damage, using Sage Chakra Gather as your Strategic setup first.
- Keep Naruto Block in reserve for turns you expect to take heavy incoming damage.

**⚔ Playing against Naruto Uzumaki**
- He threatens both a Physical strike (Toad Kumite) and an Energy hit (Rasenshuriken), so expect damage of either type.
- He carries Naruto Block for defense, so save your biggest hit for a turn he can't block.

---

## Natsu Dragneel
*Fairy Tail* &nbsp;·&nbsp; `natsu` &nbsp;·&nbsp; `dot` `aoe` `sustain` `disruption`

**Core:** An Affliction snowball: the passive I'm all fired up! stacks +5 Affliction on all skills for 3 turns every time Natsu deals new Affliction damage or is hit by a harmful Strategic skill. Consume Flame feeds the engine by cleansing enemy effects off him to heal, add stacks, and unlock Fire Dragon's Roar.

**▶ Playing as Natsu Dragneel**
- Land new Affliction every turn with Iron Fist or Fire Dragon's Roar to keep stacking I'm all fired up! and ramp all your damage.
- Use Consume Flame to strip enemy effects off yourself: heal big, gain a stack per effect, and it swaps you to Fire Dragon's Roar per harmful effect removed.
- Open Fire Dragon's Roar for 35 Affliction plus a -15 damage debuff, then reuse its cheap single-Random follow-up on that same target.
- Fire Dragon's Wing Attack forces a choice: cast a new skill and it's delayed 2 turns, or sit still and eat a team-wide Affliction hit.

**⚔ Playing against Natsu Dragneel**
- His I'm all fired up! passive stacks +5 Affliction each time he lands new Affliction damage, so race him before the snowball becomes uncatchable.
- Don't dump debuffs on him: Consume Flame cleanses your effects off him to heal, build stacks, and swap him into Fire Dragon's Roar.
- Hitting him with a harmful Strategic skill also triggers his passive stack, so pressure him through damage instead.
- After Fire Dragon's Wing Attack, weigh whether to act: a new skill gets delayed 2 turns, but passing eats team-wide Affliction damage.

---

## Neferpitou
*Hunter x Hunter* &nbsp;·&nbsp; `neferpitou`

**Core:** Full skill text isn't available for this kit; from class tags it reads as a Physical/Strategic setup character whose only Harmful skill is Terpsichora, backed by strategic tools (Puppeteering, Cat Reflexes), a Helpful support in Doctor Blythe, and the Post-Mortem Nen passive.

**▶ Playing as Neferpitou**
- Terpsichora is your only Harmful skill, so it's your damage while Puppeteering and Cat Reflexes handle Physical Strategic setup.
- Doctor Blythe is your Helpful Energy skill; lean on it as your support and upkeep tool between setup turns.

**⚔ Playing against Neferpitou**
- Only Terpsichora is Harmful, so most of her turns are Physical Strategic setup, deny her those windows before she stabilizes.
- Doctor Blythe is her Helpful support skill; apply pressure to outpace whatever upkeep it provides.

---

## Nelliel tu Odelschwank
*Bleach* &nbsp;·&nbsp; `nel`

**Core:** Full skill text isn't available for this kit; from class tags it reads as a straightforward Physical character whose defining trait is the Uncounterable nuke Lanzador Verde, supported by Strategic setup (Cero Doble, Declare Gamuza), the Nel Block defensive, and the Protector's Reiatsu passive.

**▶ Playing as Nelliel tu Odelschwank**
- Lanzador Verde is your Uncounterable Physical nuke, so throw it freely into enemies packing Counter or Reflect skills.
- Use Nel Block as your Strategic defensive tool while Cero Doble and Declare, Gamuza handle your setup turns.

**⚔ Playing against Nelliel tu Odelschwank**
- Don't rely on Counter or Reflect to stop Lanzador Verde, it's flagged Uncounterable and will punch straight through.
- Her Cero Doble, Declare Gamuza, and Nel Block turns are Strategic setup and defense, so pressure her before she settles in.

---

## Nimaiya Oetsu
*Bleach* &nbsp;·&nbsp; `nimaiya` &nbsp;·&nbsp; `invisible` `invuln` `dot` `burst`

**Core:** A Bypassing True-damage ramp: Unblockable Strike grows +5 True damage every time it's used this battle and bypasses defenses, while Sheath Dodger amplifies it and God of the Sword permanently empowers an ally over three separate casts.

**▶ Playing as Nimaiya Oetsu**
- Use Unblockable Strike early and often, since every cast permanently adds +5 True damage to all future casts and bypasses defenses.
- Apply Sheath Dodger first: its 4-turn True DoT makes the target take +5 from Unblockable Strike and grants you invulnerability to Strategic skills.
- Invest God of the Sword on one ally across turns for permanent Counter/Reflect immunity, then -1 cooldowns, then -1 Random cost.
- Play Perfect Stance to ignore all harmful effects for a turn, and it's Invisible so the enemy can't see it coming.

**⚔ Playing against Nimaiya Oetsu**
- Unblockable Strike Bypasses and ramps +5 True damage every cast, punching through invuln and shields, so close the game before it scales.
- Perfect Stance is Invisible and makes him ignore all harmful effects for a turn, so don't sink a key skill into him blind.
- While Sheath Dodger is active he's invulnerable to Strategic skills, so hit him with damage rather than control.
- God of the Sword can permanently make an ally ignore your Counter and Reflect skills, so track exactly who he has buffed.

---

## Noelle Silva
*Black Clover* &nbsp;·&nbsp; `noelle` &nbsp;·&nbsp; `transform` `invuln` `burst` `disruption`

**Core:** Energy denial plus a defensive transformation: Sea Dragon's Cradle taxes every enemy's skill costs, and Saint Valkyrie Dress makes that tax stick while swapping in her Point-Blank burst.

**▶ Playing as Noelle Silva**
- Open with Sea Dragon's Cradle to raise all enemies' costs by one random, then punish a marked target with Sea Dragon's Roar to stun it.
- Cast Saint Valkyrie Dress for 10 damage reduction; it stops Cradle being consumed and swaps Roar into Point-Blank Sea Dragon's Roar.
- Fire Point-Blank Sea Dragon's Roar into a Cradle target for up to 45 piercing damage.
- Hold Sea Dragon's Nest to go invulnerable and dodge a threatened burst turn.

**⚔ Playing against Noelle Silva**
- Sea Dragon's Cradle taxes your cost but drops off the moment you act, so clear it with a throwaway skill before your key play.
- After Saint Valkyrie Dress she gains 10 damage reduction and Point-Blank Sea Dragon's Roar, threatening a 45 piercing burst on a Cradle'd ally.
- A Cradle target hit by Sea Dragon's Roar gets stunned for a turn, so don't leave the mark standing.
- She can dodge your alpha strike with Sea Dragon's Nest invulnerability.

---

## Nonon Jakazure
*Kill la Kill* &nbsp;·&nbsp; `nonon` &nbsp;·&nbsp; `aoe` `invuln` `burst` `disruption`

**Core:** Stacked, sustained piercing pressure: she layers Overture Barrage (AoE) and Concentrated Climax (single-target) so Unstoppable Performance strikes overlapping enemies multiple times each turn.

**▶ Playing as Nonon Jakazure**
- Lead with Overture Barrage for three turns of AoE piercing, which unlocks Concentrated Climax.
- Land Concentrated Climax on a Barrage target so it Bypasses invulnerability and unlocks Unstoppable Performance.
- Overlap Overture Barrage and Concentrated Climax on one enemy so Unstoppable Performance hits it two or three times a turn.
- Flute Missile raises a target's non-Affliction damage taken by 5, so apply it before you pile on.

**⚔ Playing against Nonon Jakazure**
- Concentrated Climax Bypasses invulnerability on any Overture Barrage target, so going invuln won't save a marked ally.
- Spread your team out; stacking Overture Barrage and Concentrated Climax lets Unstoppable Performance strike one enemy multiple times.
- Flute Missile amps all non-Affliction damage a target takes by 5, so peel or protect that enemy fast.
- She can dodge a full turn with Sound Negation invulnerability.

---

## Omnimon
*Digimon* &nbsp;·&nbsp; `omnimon` &nbsp;·&nbsp; `invuln` `burst` `disruption`

**Core:** Nemesis payoff engine: Digidestiny marks a random enemy at game start, and killing that Nemesis heals Omnimon 25 HP and permanently activates the Bypass, shield-strip, and stun bonuses on all his damaging skills.

**▶ Playing as Omnimon**
- Hunt your marked Nemesis relentlessly; killing them heals 25 and permanently powers up every damaging skill's bonus effect.
- Use Destiny Digivolve to Isolate the Nemesis, lock targeting onto them, and ignore Harmful non-damaging effects for four turns.
- Into the Nemesis, Transcendent Sword strips all Shields and Bypasses, while Garuru Cannon Bypasses and stuns their non-Strategic skills.
- Brave Shield buys a turn of invulnerability when you're threatened.

**⚔ Playing against Omnimon**
- Note who Digidestiny marked as Nemesis; if Omnimon kills them he heals 25 and permanently upgrades all his damaging skills, so guard that ally.
- Against the Nemesis, Transcendent Sword removes every Shield and Garuru Cannon stuns non-Strategic skills, both Bypassing invulnerability.
- During Destiny Digivolve he ignores your Harmful non-damaging effects for four turns, so don't waste debuffs on him.
- He can turtle a turn behind Brave Shield invulnerability.

---

## Orihime Inoue
*Bleach* &nbsp;·&nbsp; `orihime` &nbsp;·&nbsp; `sustain`

**Core:** A shield-based support kit: every skill is named for a Shield, with two Helpful/Strategic protective shields, one Harmful shield in Solitary Sacred Cutting Shield, and an Unstunnable option in Six Princess Shielding Flowers.

**▶ Playing as Orihime Inoue**
- Lean on your Helpful shields, Twin Sacred Return Shield and Three Sacred Links Shield, to protect and support allies.
- Solitary Sacred Cutting Shield is your only Harmful, Physical option when you actually need to deal damage.
- Six Princess Shielding Flowers is Unstunnable, so keep it as a reliable play even under stun pressure.

**⚔ Playing against Orihime Inoue**
- She's a defensive shielder, so plan to break through her protection rather than trying to out-race her.
- Six Princess Shielding Flowers is Unstunnable, meaning you can't lock it out with a stun.
- Her only direct damage comes from Solitary Sacred Cutting Shield; the rest of her kit is support.

---

## Portgas D. Ace
*One Piece* &nbsp;·&nbsp; `ace` &nbsp;·&nbsp; `dot` `aoe`

**Core:** Ace is a defensive ramp engine: Flame Pillar piles up permanent flat Damage Reduction, and the Flame Commandment passive converts that flat DR into ever-growing bonus Affliction damage, while Firefly marks detonate on any new damage.

**▶ Playing as Portgas D. Ace**
- Stack Flame Pillar every turn for permanent Damage Reduction; the Flame Commandment passive turns that flat DR into bonus Affliction on your attacks.
- Spread Firefly's mark across the whole enemy team, then any new damage detonates the marks for 10 per stack consumed.
- Flame Emperor lays permanent, stacking Affliction on all enemies, so ramp your DR first to fatten every Affliction tick.
- Use Flame Pillar's 50% one-turn Damage Reduction to survive burst while your permanent stacks come online.

**⚔ Playing against Portgas D. Ace**
- Ace scales hard: Flame Pillar's permanent Damage Reduction feeds the Flame Commandment passive into growing Affliction, so pressure him early.
- Don't let Firefly marks linger; any new damage into a marked ally detonates 10 per stack, so cleanse them if possible.
- Flame Emperor's permanent, stacking team-wide Affliction ignores defenses, making a long game against a ramped Ace dangerous.

---

## Renamon
*Digimon* &nbsp;·&nbsp; `renamon` &nbsp;·&nbsp; `transform` `dot`

**Core:** Renamon is primarily a Physical attacker whose defining tool is 'Digivolve: Kyubimon,' a transformation that evolves her into a stronger form, supplemented by Affliction pressure from Foxtail Inferno.

**▶ Playing as Renamon**
- Lead with your Physical strikes, Korenkyaku, Diamond Storm, and High Speed Leap, for steady direct damage.
- Cast 'Digivolve: Kyubimon' to transform into your evolved form and raise your threat level.
- Mix in Foxtail Inferno for Affliction damage that ignores defenses alongside your Physical hits.

**⚔ Playing against Renamon**
- Respect 'Digivolve: Kyubimon': Renamon can transform into a stronger form, so expect a power spike once she evolves.
- Most of her pressure is Physical, so Physical mitigation helps, but Foxtail Inferno's Affliction bypasses that.

---

## Rimuru Tempest
*That Time I Got Reincarnated as a Slime* &nbsp;·&nbsp; `rimuru` &nbsp;·&nbsp; `invisible` `trap` `transform` `dot` `aoe` `sustain` `disruption`

**Core:** Rimuru is an Affliction-and-control engine with a skill-swap transformation: Megiddo (Demon Lord Awakening) upgrades his first three skills into alternate versions, while the Invisible Gluttony mark copies and cooldown-paralyzes and Black Flame stuns non-Strategic skills.

**▶ Playing as Rimuru Tempest**
- Open with Black Flame to deal Affliction and stun the target's non-Strategic skills, shutting off their offense for a turn.
- Gluttony is Invisible, so plant it on a key enemy; if they act you copy the skill and paralyze their cooldowns for 2 turns.
- Fire Megiddo to hit the whole team with Affliction plus permanent damage, then swap your first three skills to their stronger alternates.
- Slime Transformation ignores harmful non-damage effects and heals 15 over 2 turns, but locks you into Demon Summon, so use it to ride out control.

**⚔ Playing against Rimuru Tempest**
- Gluttony is Invisible, so you can't see the mark; using a new skill lets Rimuru copy it and paralyze your cooldowns for 2 turns.
- Black Flame stuns your non-Strategic skills, so keep a Strategic option ready to still act through the lock.
- Megiddo swaps his first three skills into alternate versions and drops permanent team-wide Affliction, so expect a mid-fight escalation.
- While Slime Transformation is up he ignores harmful non-damage effects and heals, so hold your hard damage until it drops.

---

## Rob Lucci
*One Piece* &nbsp;·&nbsp; `rob`

**Core:** A straightforward, all-Physical damage kit with no special resource engine; its standout traits are two Uncounterable finishers (Rankyaku Gaicho and Sai Dai Rin: Rokuogan) and the Neko Neko no Mi, Model: Leopard passive.

**▶ Playing as Rob Lucci**
- Lucci is a pure Physical bruiser, so chain his Rokushiki attacks (Shigan, Rankyaku, Rokuogan) for reliable direct damage.
- Break through enemy counter setups with Rankyaku Gaicho or Sai Dai Rin: Rokuogan, both of which are Uncounterable.
- Lean on Tekkai Utsugi, his Strategic tool, as a defensive beat between your offensive turns.

**⚔ Playing against Rob Lucci**
- Don't bank on counters: Rankyaku Gaicho and Sai Dai Rin: Rokuogan are Uncounterable and punch straight through counter setups.
- Almost all his damage is Physical, so Physical damage reduction blunts most of his kit outside those Uncounterable finishers.

---

## Roronoa Zoro
*One Piece* &nbsp;·&nbsp; `zoro` &nbsp;·&nbsp; `counter` `invisible` `invuln` `execute`

**Core:** A swap-cycle swordsman who stacks permanent damage with Master of Swords and alternates Onigiri and One-Sword Style: Lion Strike, backed by an invulnerability wall and an invisible counter.

**▶ Playing as Roronoa Zoro**
- Cast Master of Swords early and repeatedly to permanently raise every skill's damage before you start trading blows.
- Cycle Onigiri into One-Sword Style: Lion Strike to execute enemies at 15HP or below, ignoring their invulnerability.
- Drop Three-Sword Style Counter (it's Invisible) before an expected big enemy skill to punish it for free.
- Save Three-Sword Style Parry for a guaranteed invulnerable turn against an incoming burst.

**⚔ Playing against Roronoa Zoro**
- One-Sword Style: Lion Strike executes anyone at 15HP or below and bypasses invulnerability, so don't sit low behind invuln.
- Three-Sword Style Counter is Invisible, so assume he may be countering and avoid feeding a key skill into it.
- Three-Sword Style Parry gives him a full invulnerable turn — wait it out instead of wasting damage.
- Master of Swords permanently stacks his damage, so close the game before his hits scale out of control.

---

## Ryohei Sasagawa
*Katekyo Hitman Reborn* &nbsp;·&nbsp; `ryohei` &nbsp;·&nbsp; `burst` `sustain`

**Core:** A damage-fueled brawler: To the Extreme!! converts every 20 damage he takes into stacks that supercharge one all-at-once payoff, either a huge Maximum Cannon or an extended team heal from Kangaryu.

**▶ Playing as Ryohei Sasagawa**
- Let Ryohei absorb hits to bank To the Extreme!! stacks, then dump them into one oversized Maximum Cannon.
- Alternatively spend stacks on Kangaryu for a longer-lasting, larger team heal when your side needs sustain.
- Pop Vongola Headgear against stun turns; it also makes Maximum Cannon piercing and gives Kangaryu 10 damage reduction.
- Track your random energy, since each stack adds 1 random to the empowered skill's cost.

**⚔ Playing against Ryohei Sasagawa**
- Damaging Ryohei feeds To the Extreme!! stacks, so burst him down fast rather than letting your damage become his Maximum Cannon.
- While Vongola Headgear is up he ignores stuns and his Maximum Cannon pierces, so don't count on locking him then.
- Deny his payoff by killing him before he cashes a big stack count into a nuke or team heal.

---

## Ryomen Sukuna
*Jujutsu Kaisen* &nbsp;·&nbsp; `sukuna` &nbsp;·&nbsp; `execute` `dot` `aoe` `disruption`

**Core:** An untargetable Affliction engine: Cleave and Dismantle layers permanent stacking AoE damage-over-time on the whole enemy team, while Malevolent Shrine sets a team-wide execute, and Sealed King keeps Sukuna stunned/untargetable while buffing a marked ally.

**▶ Playing as Ryomen Sukuna**
- Spam Cleave and Dismantle to stack permanent, Uncounterable AoE afflictions across the entire enemy team.
- Open Malevolent Shrine for a 4-turn team-wide execute, and note it makes Cleave and Dismantle hit twice more.
- Land kills early, since the execute threshold rises each turn and whenever an enemy uses a skill on Sukuna.
- Use Fire Arrow's 35 True damage to finish a single target your afflictions can't reach in time.

**⚔ Playing against Ryomen Sukuna**
- Malevolent Shrine is an Uncounterable team-wide execute — keep everyone above the rising HP threshold until it expires.
- Cleave and Dismantle stacks permanent, Uncounterable damage-over-time on all enemies, so bring healing before it snowballs.
- Don't attack Sukuna during Malevolent Shrine; each skill used on him raises the execute threshold against your team.
- Sukuna is untargetable behind Sealed King, so killing his marked ally is the way to shut it down permanently.

---

## Ryuko Matoi
*Kill la Kill* &nbsp;·&nbsp; `ryuko` &nbsp;·&nbsp; `invuln` `sustain` `aoe` `disruption`

**Core:** A snowballing striker whose Fiber Lost permanently grows on kills and caps enemy damage, paired with Life Fiber Synchronization to convert incoming ally damage into healing, all toggleable to team-wide via Decapitation Mode.

**▶ Playing as Ryuko Matoi**
- Secure kills with Fiber Lost — each one permanently adds 10 damage and heals Ryuko 10, snowballing her fast.
- Use Fiber Lost on a big threat before its turn to cap that enemy's damage at 20.
- Pre-cast Life Fiber Synchronization before an enemy nuke to turn your team's incoming damage into healing.
- Toggle Decapitation Mode to make Fiber Lost and Life Fiber Synchronization hit all characters for 1 extra random each.

**⚔ Playing against Ryuko Matoi**
- Ryuko Block gives her a full invulnerable turn, so don't sink your burst into it.
- Deny Fiber Lost kills — each one permanently boosts her damage and heals her, snowballing the whole game.
- Life Fiber Synchronization converts damage on her team into healing, so burst through it or wait the 2 turns out.
- Under Decapitation Mode Fiber Lost hits your entire team and caps everyone's damage at 20.

---

## Saber (Arturia Pendragon)
*Fate* &nbsp;·&nbsp; `saber` &nbsp;·&nbsp; `invuln` `sustain` `disruption`

**Core:** A protection-and-sustain package: Avalon gives an ally permanent regen plus an on-demand reflect and Providence grants 1-turn invulnerability, while Wind Blade Combat cost-cycles (Green, then 1 Random, then free) to power a cheap, uncounterable offense capped by Excalibur's 45-piercing Silence nuke.

**▶ Playing as Saber (Arturia Pendragon)**
- Drop Avalon on a priority ally early for permanent 10 HP/turn, then reactivate it to bounce their incoming harmful effects onto Saber.
- Cycle Wind Blade Combat (Green, then 1 Random, then free) to attack for almost no energy and cheapen Providence, which always copies its cost.
- Save Excalibur's uncounterable 45 piercing Silence for a key caster, remembering it begins the match on cooldown.
- Use Providence to make Saber or the Avalon target invulnerable for a turn to blank an incoming burst.

**⚔ Playing against Saber (Arturia Pendragon)**
- Excalibur cannot be countered or reflected and lands 45 piercing plus a Silence, so never bank on counters to stop it.
- Providence gives Saber or her Avalon ally a 1-turn invulnerability, so time your burst for a turn it is not up.
- Wind Blade Combat is uncounterable and ignores stun, so stunning Saber will not keep her from swinging with it.
- Avalon's reactivation reflects harmful effects back onto Saber, so avoid piling debuffs on her healed ally that turn.

---

## Sailor Jupiter
*Sailor Moon* &nbsp;·&nbsp; `jupiter`

**Core:** A straightforward damage kit with no special engine evident from the available text: three Harmful energy attacks, one Helpful/Strategic support skill, and a passive.

**▶ Playing as Sailor Jupiter**
- Lean on your three Harmful energy attacks, Supreme Thunder, Flower Hurricane, and Supreme Thunder Dragon, for steady damage pressure.
- Use Sparkling Wide Pressure as your Helpful/Strategic play for support or utility rather than raw damage.
- Thunder Antenna is a Passive, so its benefit applies automatically without costing you a turn.

**⚔ Playing against Sailor Jupiter**
- Jupiter stacks three Harmful energy attacks, so keep your team's health buffered against sustained damage.
- Watch Sparkling Wide Pressure for a Helpful/Strategic swing that can tilt a trade in her favor.

---

## Sailor Mars
*Sailor Moon* &nbsp;·&nbsp; `mars` &nbsp;·&nbsp; `dot` `disruption` `sustain`

**Core:** Mark-driven: Ofuda marks a chosen target plus one random character for the whole game, and every other ability can ONLY hit marked characters, with Blazing Mandala scaling per mark.

**▶ Playing as Sailor Mars**
- Cast Ofuda first every game, since none of her other skills can target anything that isn't marked.
- Pile on Ofuda marks to scale Blazing Mandala, which deals or heals 5 per marked character.
- Akuryo Taisen hits a marked enemy for 20 and Stuns them a turn, or heals a marked ally for 25.
- Snake Fire lays 15 Affliction for 3 turns on a marked enemy and lets marked allies heal 15 by attacking it.

**⚔ Playing against Sailor Mars**
- Mars can't act offensively until Ofuda lands, so the marked target and one random ally become her only victims, protect them.
- Respect Akuryo Taisen's 20 damage plus 1-turn Stun on the marked enemy, and don't leave a key marked piece exposed.
- Snake Fire is a 3-turn Affliction on the marked enemy that also fuels her team's healing, so race her before marks compound.

---

## Sailor Mercury
*Sailor Moon* &nbsp;·&nbsp; `mercury`

**Core:** A damage-and-utility kit with no special engine evident from the available text: two Harmful energy attacks and two Strategic energy skills.

**▶ Playing as Sailor Mercury**
- Deal damage with your Harmful attacks, Shabon Spray and Shabon Spray Freeze.
- Use Mercury Aqua Mirage and Shine Aqua Illusion as Strategic tools for control or utility over raw damage.
- Every skill costs energy, so manage your pool to keep both attacks and Strategic plays online.

**⚔ Playing against Sailor Mercury**
- Mercury backs two Harmful attacks with two Strategic skills, so expect utility pressure alongside her damage.
- No counter, stealth, transform, or execute appears in her kit, so straightforward trades are safe.

---

## Sailor Saturn
*Sailor Moon* &nbsp;·&nbsp; `saturn`

**Core:** A support-leaning kit: a single Physical damage tool (Ruinous Scythe) backed by Helpful Energy skills (Silence Glaive Surprise, Silence Wall) and one dual Helpful/Harmful Energy skill (Death Reborn Revolution). No distinct combo engine is evident from the available kit text.

**▶ Playing as Sailor Saturn**
- Ruinous Scythe is your only dedicated Harmful skill, so it's your main damage tool while the rest supports.
- Lean on the Helpful Energy skills Silence Glaive Surprise and Silence Wall to protect and enable the team.
- Death Reborn Revolution carries both Helpful and Harmful tags, so time it when both allies and enemies matter.

**⚔ Playing against Sailor Saturn**
- Most of Saturn's kit is Helpful Energy support; pressure her before Silence Glaive Surprise and Silence Wall stabilize her team.
- Ruinous Scythe is her lone dedicated damage skill, so her threat is disruption and defense more than raw offense.

---

## Sailor Uranus
*Sailor Moon* &nbsp;·&nbsp; `uranus` &nbsp;·&nbsp; `counter` `invisible` `invuln` `aoe` `dot`

**Core:** A mark-based protector: Uranus Lip Rod permanently marks the ally directly below her, and nearly her whole kit (Shield from Space Sword Blaster, cheaper Intercepting Strike counter, World Shaking's bonus damage, shared Invulnerability) revolves around shielding and amplifying that marked ally.

**▶ Playing as Sailor Uranus**
- Position your best ally directly below Uranus at match start so Uranus Lip Rod marks them for 10 Damage Reduction.
- Cast World Shaking early so the marked ally deals +5 damage to every enemy across its 3-turn duration.
- Intercepting Strike on the marked ally is a near-free 1-turn-cooldown counter, so bait Harmful skills into its 25-damage punish.
- Hold Space Defense to hand Uranus or the marked ally Invulnerability against a key enemy burst.

**⚔ Playing against Sailor Uranus**
- Intercepting Strike is an Invisible counter that punishes a Harmful skill on the protected ally for 25 damage, so probe with a non-Harmful skill or hit elsewhere.
- World Shaking is a 3-turn AoE that also amps the marked ally's damage against you, so spread out or race it down.
- Respect Space Defense: it grants a full turn of Invulnerability, so don't dump burst into it.
- The ally below Uranus carries Lip Rod's Damage Reduction plus shield and counter synergy, so removing that ally or Uranus unravels the package.

---

## Sailor Venus
*Sailor Moon* &nbsp;·&nbsp; `venus` &nbsp;·&nbsp; `disruption` `invuln` `aoe`

**Core:** A Taunt/Blind disruption engine fueled by Venus Burning Love, which permanently stacks +5 damage on her next skill each time she's hit by a Harmful skill (doubled if that attacker is Taunted), so she goads enemies into hitting her, then unloads amplified control.

**▶ Playing as Sailor Venus**
- Open with Venus Love and Beauty Shock to Blind the enemy team, then recast to convert Blinded foes into Taunts.
- Taunt with Venus Love Me Chain so enemy Harmful skills into you each grant 2 Venus Burning Love stacks.
- Bank Venus Burning Love stacks, then dump them into Crescent Beam Barrage to extend its Taunt lock far beyond two turns.
- Use Defensive Binding's Invulnerable turn to dodge a lethal hit, but otherwise let taunted enemies strike you to build stacks.

**⚔ Playing against Sailor Venus**
- Venus Burning Love turns every Harmful skill you land on her into stacked bonus damage, doubled while you're Taunted, so avoid feeding a taunted Venus.
- She chains Taunts (Venus Love Me Chain, Crescent Beam Barrage) and Blinds (Venus Love and Beauty Shock), so expect to lose control of your targeting.
- Crescent Beam Barrage's Taunt scales with her banked stacks and can lock a character for many turns, so disrupt or kill her first.
- Defensive Binding gives her an Invulnerable turn, so don't waste key skills into it.

---

## Saitama
*One Punch Man* &nbsp;·&nbsp; `saitama` &nbsp;·&nbsp; `counter` `invisible` `execute` `invuln` `aoe` `burst`

**Core:** Toggle-punch pressure plus a counter-into-execute chain: Normal Punch and Consecutive Normal Punches alternate single-target and team-wide shield-breaking damage every turn, while Serious Side-Hops counters a hit to mark an enemy and unlock Serious Punch, an instant kill.

**▶ Playing as Saitama**
- Alternate Normal Punch (single-target 45) and Consecutive Normal Punches (team-wide 30) as the toggle swaps each turn to fit the board.
- Both punches destroy Shields before dealing damage, so swing freely into shielded enemies.
- Use Serious Side-Hops (Invisible) to counter the enemy's next non-Strategic Harmful skill, marking them and unlocking Serious Punch.
- Chain a successful Side-Hops into Serious Punch to instantly kill the marked enemy; it's Uncounterable and unreflectable.
- Save Serious Table-Flip as a panic button: it clears your team's harmful skills, grants team Invulnerability, and Shatters the enemy team, but swaps away permanently.

**⚔ Playing against Saitama**
- Serious Side-Hops is an Invisible counter that turns your next non-Strategic Harmful skill into a death mark, so bait it with a Strategic skill or don't swing blindly.
- Once marked by Side-Hops, Serious Punch instantly kills you and is Uncounterable and unreflectable, so go Invulnerable, cleanse the mark, or kill Saitama first.
- Shields are useless against him: both Normal Punch and Consecutive Normal Punches destroy Shields before hitting.
- Serious Table-Flip makes his team Invulnerable for a turn and Shatters yours for two, so don't commit burst into that Invulnerable window.

---

## Sasuke Uchiha
*Naruto* &nbsp;·&nbsp; `sasuke` &nbsp;·&nbsp; `trap` `invisible` `execute` `dot` `burst` `invuln` `aoe`

**Core:** A skill-replacement combo engine: Shuriken Jutsu transforms into the invisible Shadow Shuriken Wire Trap, while Great Dragon Fire's mark upgrades into the one-time Kirin execute.

**▶ Playing as Sasuke Uchiha**
- Open with Shuriken Jutsu to stick a 5-per-turn DoT and unlock the invisible Shadow Shuriken Wire Trap.
- Cast Great Dragon Fire to mark a target, then fire Kirin two turns later for 50 uncounterable damage.
- Set the invisible Shadow Shuriken Wire Trap to bait a Harmful skill into 15 damage and a stun.
- Bank Stalemate's invulnerability to safely bridge the turns between marking and detonating Kirin.

**⚔ Playing against Sasuke Uchiha**
- Great Dragon Fire's mark telegraphs Kirin, which is uncounterable and executes at 10 or less HP, so heal marked allies above it.
- After Shuriken Jutsu, expect the invisible Shadow Shuriken Wire Trap and avoid Harmful skills that turn.
- Don't leave a marked target sitting low, as Kirin one-shots for 50 and cannot be countered.

---

## Satoru Gojo
*Jujutsu Kaisen* &nbsp;·&nbsp; `gojo` &nbsp;·&nbsp; `burst` `aoe` `invuln` `disruption`

**Core:** A high-damage energy kit built on a Blue-then-Red cadence: Reversal: Red hits harder the turn after Lapse: Blue, and Six Eyes discounts Blue energy whenever Gojo is damaged.

**▶ Playing as Satoru Gojo**
- Cast Lapse: Blue, then Reversal: Red the following turn for the +10 bonus, totaling 45 damage.
- After Gojo takes damage, spend that turn on Blue skills to bank Six Eyes' energy discount.
- Fire Hollow Technique: Purple as your piercing nuke, 45 to one enemy and 15 to the rest.
- Pop Infinity Barrier to both go invulnerable and cleanse all harmful effects off Gojo.

**⚔ Playing against Satoru Gojo**
- Watch the Blue-into-Red sequence, since a Lapse: Blue last turn means Reversal: Red lands for 45 next.
- Hollow Technique: Purple deals piercing AoE that bypasses mitigation and hits your whole team.
- Lapse: Blue ends your Channeled skills, so don't commit a channel while he can interrupt it.
- Infinity Barrier is invuln plus a full cleanse, so don't dump burst or DoT into that turn.

---

## Satsuki Kiryuin
*Kill la Kill* &nbsp;·&nbsp; `satsuki` &nbsp;·&nbsp; `burst` `invuln` `disruption`

**Core:** A full-health conditional engine: every offensive and defensive skill gains a powerful bonus while Satsuki is at maximum HP, so staying topped off is the whole game plan.

**▶ Playing as Satsuki Kiryuin**
- Stay at full HP to unlock every bonus: +10 piercing, a Harmful-skill stun, and Perfect Crescent's Bypass.
- At full health, lead with Perfect Crescent for 50 bypassing damage that ignores invulnerability.
- Use Overwhelming Power while topped off to stun an enemy's Harmful skills before they act.
- Disdainful Block grants invuln and, at full HP, returns two turns sooner to keep the pressure up.

**⚔ Playing against Satsuki Kiryuin**
- Chip her below full HP to shut off every bonus, since her stun, Bypass, and bonus damage all require it.
- At full health Perfect Crescent Bypasses your invulnerability for 50, so don't rely on invuln to block it.
- Overwhelming Power stuns your Harmful skills while she's topped off, so damage her before attacking.

---

## Sawada Tsunayoshi
*Katekyo Hitman Reborn* &nbsp;·&nbsp; `tsunayoshi` &nbsp;·&nbsp; `counter` `aoe` `invuln` `disruption`

**Core:** A counter-and-mark combo kit: Zero Point Breakthrough punishes Affliction/Energy skills to buff X-Burner, while Burning Axle's permanent mark detonates when hit by X-Burner.

**▶ Playing as Sawada Tsunayoshi**
- Mark an enemy with Burning Axle, then land X-Burner to detonate for +10 damage and a stun.
- Pre-set Zero Point Breakthrough to counter and stun the first Affliction or Energy skill, buffing X-Burner +10 for two turns.
- Use X-Burner as your AoE payoff after the Burning Axle mark and a successful counter are set.
- Hold Flare Burst's invulnerability to stall while cooldowns reset or a mark waits to trigger.

**⚔ Playing against Sawada Tsunayoshi**
- Zero Point Breakthrough counters and stuns the first Affliction or Energy skill used on him, so lead with Physical that turn.
- Burning Axle's mark is permanent and detonates under X-Burner for bonus damage and a stun, so respect the follow-up.
- Flare Burst gives him a turn of invulnerability, so don't waste burst into it.

---

## Sayaka Miki
*Puella Magi Madoka Magica* &nbsp;·&nbsp; `sayaka` &nbsp;·&nbsp; `counter` `invisible` `sustain`

**Core:** A self-sustain bruiser whose Soul Gem passive ticks up a stack every turn — granting missing-HP healing at 6+ stacks but killing her at 12 — while her damage scales off how much she has healed.

**▶ Playing as Sayaka Miki**
- Pump healing with Azure Healing and Soul Gem so Hero Slash gains its +5 damage per 20 HP healed.
- Hero Counter is Invisible, so set it on a turn the enemy is likely to swing for a free heal-flip.
- At 6+ Soul Gem stacks she self-heals per missing HP and ignores heal-prevention, so trade aggressively while low.
- Track your stack count: 12 Soul Gem stacks instantly kills you, and Enraged Slash adds an extra stack.

**⚔ Playing against Sayaka Miki**
- Hero Counter is Invisible and flips a new damaging ability into healing, so bait it before committing your big hit.
- Enraged Slash is Uncounterable and Bypassing and can't deal under 20, so shields and counters won't stop it.
- She dies on her own at 12 Soul Gem stacks, so stall and let a stacked-up Sayaka run out her own clock.

---

## Semiramis
*Fate* &nbsp;·&nbsp; `semiramis` &nbsp;·&nbsp; `dot` `aoe` `disruption` `invuln`

**Core:** An Affliction control mage who punishes defensive buffs — Arrogant King's Poison converts enemy Shields, Invulnerability, and heal-over-time into permanent Affliction; she also starts banished two turns before returning with 25 permanent Shield.

**▶ Playing as Semiramis**
- Hanging Gardens banishes her for 2 turns; plan around returning with 25 permanent Shield and a random energy.
- Fire Arrogant King's Poison after enemies commit Shields, Invuln, or heals to convert them all into permanent Affliction.
- Hydra pressures every enemy; unless they end a turn Invulnerable, it expires into a stun.
- Spend Scales of the Sacred Fish for a safe invuln turn and Chains to shut off an enemy's Helpful and Strategic skills.

**⚔ Playing against Semiramis**
- Never stack Shields, Invuln, or heal-over-time into Arrogant King's Poison — it converts them into permanent Bypassing Affliction damage.
- Escape Hydra's AoE Affliction by ending a turn Invulnerable, or eat the stun when it expires.
- She's banished the first 2 turns, so build your lead before she returns shielded and start pressuring immediately.

---

## Seto Kaiba
*Yu-Gi-Oh!* &nbsp;·&nbsp; `kaiba`

**Core:** The available tip data contains no skill descriptions, so only class tags are certain: a Harmful damage kit spanning Energy, Physical, and Mental skills, with Blue-Eyes Ultimate Dragon flagged Uncounterable as its one confirmed special property.

**▶ Playing as Seto Kaiba**
- Blue-Eyes Ultimate Dragon is your Uncounterable Energy attack, so aim it into enemies relying on counters.
- His Harmful pressure spans Energy (Burst Stream, Ultimate Dragon), Physical, and Mental skills, so bank energy for your Energy closer.
- Blue-Eyes White Dragon and Hold This! are your Physical/Strategic tools; Enemy Controller and Crush Card Virus add Mental pressure.

**⚔ Playing against Seto Kaiba**
- Blue-Eyes Ultimate Dragon is Uncounterable, so don't rely on counters to stop it — use invulnerability or removal instead.
- The rest of his kit is Energy, Physical, and Mental Harmful skills, so deny the energy his attacks need.

---

## Sheele
*Akame ga Kill* &nbsp;·&nbsp; `sheele` &nbsp;·&nbsp; `invuln` `aoe` `disruption`

**Core:** A Piercing single-target assassin that punishes defensive setups — Extase deals bonus damage to enemies with Shield or Damage Reduction, and Savior Strike pierces while stripping cancellable effects.

**▶ Playing as Sheele**
- Extase punishes defense, dealing +10 versus Shield and +5 versus Damage Reduction, and both bonuses can stack together.
- Savior Strike is flexible: pierce an enemy and end their cancellable effects, or cleanse an ally and make them Invulnerable.
- Trump Card Shatters all enemies for 2 turns while making both allies unkillable — a strong offensive-defensive window.
- Hold Extase Block for a self-invuln turn to survive incoming burst.

**⚔ Playing against Sheele**
- Don't sit behind Shield or Damage Reduction against Extase — it deals bonus Piercing damage to both.
- Savior Strike is Piercing and ends your cancellable effects, so removable buffs won't block it.
- During Trump Card her allies can't be killed for 2 turns while you're Shattered, so don't waste burst trying to kill through it.

---

## Shinra Kusakabe
*Fire Force* &nbsp;·&nbsp; `shinra` &nbsp;·&nbsp; `invuln` `dot` `transform` `disruption`

**Core:** Ignition: Shinra is a self-buff that discounts his damaging skills and stamps permanent affliction on each hit; the passive Hysterical Strength flips on at 40 health, auto-reapplying Ignition on every Harmful skill for a self-snowballing affliction engine.

**▶ Playing as Shinra Kusakabe**
- Cast Ignition: Shinra first so your damaging skills cost one less Green and apply 5 permanent affliction on each hit.
- Use Tora Hishigi to stun and Rapid Kick to Taunt, dictating which enemy gets to act.
- Hold Adolla Burst's one-turn invulnerability to dodge an incoming burst rather than spending it early.
- Below 40 health, Hysterical Strength auto-reapplies Ignition on every Harmful skill, so keep swinging to pile permanent affliction.

**⚔ Playing against Shinra Kusakabe**
- Respect Adolla Burst, a full turn of invulnerability, and never dump your burst damage into it.
- Once he drops to 40 health, Hysterical Strength turns on and Ignition reapplies each Harmful skill, snowballing permanent affliction.
- Tora Hishigi stuns and Rapid Kick Taunts, so budget for a turn where you cannot act freely.

---

## Shirai Kuroko
*A Certain Scientific Railgun* &nbsp;·&nbsp; `kuroko` &nbsp;·&nbsp; `invuln` `disruption`

**Core:** A sequencing combo engine: each of her three Harmful skills gains a different bonus based on which skill she used the previous turn, so turn order is everything, backed by two separate invulnerability turns for self-peel.

**▶ Playing as Shirai Kuroko**
- Plan two turns deep: each Harmful skill gains a bonus based on the skill you used last turn.
- Teleporting Strike into Judgement Throw stuns; Needle Pin after Teleporting Strike Bypasses for 20 piercing damage.
- Loop Teleporting Strike after Needle Pin (no cooldown) to stay invulnerable while still dealing damage.
- Fall back on Tactical Teleport for an invulnerable turn when Teleporting Strike is on cooldown.

**⚔ Playing against Shirai Kuroko**
- She carries two invulnerable turns, Teleporting Strike and Tactical Teleport, so bait them out before committing burst.
- Needle Pin after Teleporting Strike Bypasses invulnerability for 20 piercing, so a defensive turn will not always save you.
- Her combos can stun, drain energy, Silence, or Isolate depending on last turn's skill, so track her sequence.

---

## Shiro
*Deadman Wonderland* &nbsp;·&nbsp; `shiro` &nbsp;·&nbsp; `disruption` `aoe` `stun-lock`

**Core:** An improvement-buff engine: each basic skill arms a one-turn boost to her OTHER damaging skills (+10 damage plus a stun, silence, or immunity rider), while channeling Ganta Fight Song banks Ganta Fever stacks that extend those boosts two turns each.

**▶ Playing as Shiro**
- Fire one basic skill to arm an improvement (+10 damage plus a stun, silence, or immunity rider), then cash it with your others.
- Channel Ganta Fight Song to Taunt the whole enemy team while banking a Ganta Fever stack each turn.
- Spend Ganta Fever by attacking to extend an improvement two turns, layering multiple riders at once.
- Arm Shiro Rampage's improvement to ignore enemy stun and silence before diving in.

**⚔ Playing against Shiro**
- Ganta Fight Song permanently Taunts your whole team, but Shiro takes 5 extra damage per new skill, so punish the channel.
- After her first strike each sequence, her follow-ups stun or silence you, so expect crowd control.
- While Shiro Rampage's buff is up she ignores your stun and silence, so do not rely on locking her down then.

---

## Shokuhou Misaki
*A Certain Scientific Railgun* &nbsp;·&nbsp; `shokuhou` &nbsp;·&nbsp; `disruption`

**Core:** Skill descriptions were not provided in the kit text, so only class tags are known: Mental Out is her sole Harmful, Control skill, while Plan to Lose, Exterior, and Subordinate Protection are Strategic Mental support skills, indicating a control-and-setup kit with unspecified effects.

**▶ Playing as Shokuhou Misaki**
- Mental Out is your only Harmful skill and carries Control, so aim it at the enemy you most need to disrupt.
- Plan to Lose, Exterior, and Subordinate Protection are Strategic Mental tools, so use them to set up before committing.

**⚔ Playing against Shokuhou Misaki**
- Mental Out carries the Control class, so respect a disruption landing on whichever ally she targets.
- Her other three skills are Strategic, so expect setup and utility from them rather than raw damage.

---

## Sogiita Gunha
*A Certain Scientific Railgun* &nbsp;·&nbsp; `gunha`

**Core:** No ability descriptions are available in the kit text; by skill names and classes it reads as a straightforward physical-bruiser kit — two Physical strikes (Super Awesome Punch, Guts Explosion), a Mental strategic tool (Overwhelming Suppression), a Strategic/Physical defensive skill (Gutsy Defense), and the Guts passive.

**▶ Playing as Sogiita Gunha**
- Lead with your Physical hitters, Super Awesome Punch and Guts Explosion, for direct damage.
- Turn to Gutsy Defense, your Strategic/Physical tool, when you need to brace and soak a turn.
- Work in Overwhelming Suppression as your Mental strategic play to add pressure between strikes.
- Lean on the Guts passive as your always-on baseline throughout the fight.

**⚔ Playing against Sogiita Gunha**
- Two Physical hitters in Super Awesome Punch and Guts Explosion mean steady melee damage — keep a health buffer.
- Gutsy Defense is a defensive tool, so avoid dumping your biggest hit into a turn he braces.
- Overwhelming Suppression is a Mental strategic skill worth respecting as possible control — keep an out ready.

---

## Son Gohan
*Dragon Ball* &nbsp;·&nbsp; `gohan`

**Core:** No ability descriptions are available in the kit text; by skill names and classes it reads as a straightforward damage kit — Physical strikes (Merciless Punch, Brutal Kick, Gohan Dodge), an Energy/Strategic setup (Saiyan Rage), and an Energy finisher (Father-Son Kamehameha).

**▶ Playing as Son Gohan**
- Apply pressure with your Physical strikes Merciless Punch and Brutal Kick.
- Use Saiyan Rage, your Energy/Strategic setup skill, to prime before you commit to damage.
- Bank Energy for Father-Son Kamehameha, your Harmful Energy payoff.
- Remember Gohan Dodge is a Physical Harmful skill despite its name — fold it into your offense.

**⚔ Playing against Son Gohan**
- Expect consistent Physical damage from Merciless Punch and Brutal Kick — keep your health topped.
- Father-Son Kamehameha is his Energy payoff; watch his blue energy and respect a possible spike.
- Saiyan Rage is a strategic setup, so brace for a follow-up on the turn after he casts it.

---

## Son Goku
*Dragon Ball* &nbsp;·&nbsp; `goku` &nbsp;·&nbsp; `transform` `invuln` `burst` `disruption`

**Core:** An energy-discount ramp: each cast of the reduced-cost Kamehameha (1 blue, -15 damage) shaves a Blue off Spirit Bomb, letting Goku land a cheap 60 piercing, stunning, Bypassing nuke — while Kaioken x20 toggles into Kaioken Rush and amps his Kamehameha at the cost of self-affliction.

**▶ Playing as Son Goku**
- Cast the reduced-cost Kamehameha (1 blue) repeatedly to cut Spirit Bomb's Blue cost, then fire it for 60 piercing and a stun.
- Activate Kaioken x20 for 10 damage reduction and a piercing +10 Kamehameha, but track the 5 self-affliction it deals each turn.
- While Kaioken is active, both Kamehameha and Kaioken Rush pierce — lean on them against defensive targets.
- Pop Instant Transmission for an invulnerable turn to dodge incoming burst before committing to Spirit Bomb.

**⚔ Playing against Son Goku**
- Spirit Bomb is Bypassing and hits for 60 piercing plus a 1-turn stun, so invulnerability won't save you — this is his kill window.
- Instant Transmission makes Goku invulnerable for a full turn; don't sink your biggest hit into it.
- Kaioken x20 is a transformation toggle that boosts his Kamehameha but ticks his own health — race his self-affliction.
- Repeated cheap Kamehameha casts signal a discounted Spirit Bomb incoming; pressure him before the stun combo lands.

---

## Soul Evans
*Soul Eater* &nbsp;·&nbsp; `soul` &nbsp;·&nbsp; `transform` `dot` `disruption` `sustain`

**Core:** A weapon-support engine: Scythe Transformation hands an ally a +5 damage and Red-to-Random cost buff (auto-going to Maka if alive), while Nightmare Wavelength/Sonata stack Affliction and delay enemy strategic skills, and Consume Soul permanently scales the wielder's buff.

**▶ Playing as Soul Evans**
- Cast Scythe Transformation early so an ally gains +5 damage and Red-to-Random costs while Soul takes 10 damage reduction.
- Lead with Nightmare Sonata to delay enemy strategic skills for 3 turns and add 20 damage to Nightmare Wavelength.
- Keep Soul wielded by an ally so Nightmare Wavelength's 30 self-affliction is split rather than landing fully on him.
- After dealing 100 damage, use Consume Soul to heal 50 and permanently raise the wielder's damage bonus.

**⚔ Playing against Soul Evans**
- Nightmare Sonata delays your strategic skills for 3 turns — sequence your setup off before it lands.
- Nightmare Wavelength is stacking Affliction, boosted +20 under Sonata, so you can't stall the DoT out.
- Scythe Transformation is a transformation buff on an ally wielder — break it by focusing the empowered ally (or Maka).
- Consume Soul heals him 50 and scales his threat each cast; push him past the 100-damage gate to deny it.

---

## Sung Jin-woo
*Solo Leveling* &nbsp;·&nbsp; `jinwoo` &nbsp;·&nbsp; `sustain` `invuln` `disruption`

**Core:** A stack-building shield engine: Shadow Summon banks permanent stacks that convert into per-turn Shield, and once he hits his Shield cap the excess stacks auto-blast a random enemy each turn, favoring targets marked by Hand of the Monarch.

**▶ Playing as Sung Jin-woo**
- Spam Shadow Summon early to bank stacks; once your Shield caps, every extra stack chips a random enemy for free each turn.
- Use Hand of the Monarch to stun a threat's non-Strategic skills and, with Shadow Summon active, funnel all that overflow damage onto them.
- Vital Strike's follow-up costs no energy next turn, so alternate it to keep energy free for Shadow Summon.
- Pop Vanish to go Untargetable and skip a dangerous turn while your Shadow stacks keep shielding and ticking.

**⚔ Playing against Sung Jin-woo**
- Respect Vanish making him Untargetable for a full turn, don't dump a big skill into it.
- Hand of the Monarch only stuns non-Strategic skills, so your Strategic defenses still fire, save them for it.
- His Shadow Summon Shield grows permanently and eventually spills into damage, so pressure him before it caps.

---

## Superbia Squalo
*Katekyo Hitman Reborn* &nbsp;·&nbsp; `squalo` &nbsp;·&nbsp; `dot` `invuln` `disruption`

**Core:** An anti-defense piercing bruiser: he strips and permanently denies enemy defenses (Shields via Scontro, permanent Shatter via Grande Pioggia) while dealing Piercing damage that ignores reduction, with Zanna even bypassing Invulnerability.

**▶ Playing as Superbia Squalo**
- Open with Zanna di Squalo for a 3-turn Piercing damage-over-time that Bypasses even Invulnerable enemies.
- Use Scontro di Squalo to wipe a target's Shields (and clear any Nullify off yourself) before you commit damage.
- Fire Squalo Grande Pioggia into shield-reliant enemies to deal 35 and permanently Shatter them so they can never re-shield.
- Hold Squalo Parry to become Invulnerable for a turn and dodge a threatened burst.

**⚔ Playing against Superbia Squalo**
- Squalo Grande Pioggia permanently Shatters, so any ally who leans on Shields loses them for the whole match.
- Scontro di Squalo tears off Shields before it hits, and all his damage is Piercing that ignores damage reduction.
- Zanna di Squalo is Bypassing, so going Invulnerable will not stop his damage-over-time.
- He can turtle a turn with Squalo Parry's Invulnerability, so bait it before your big swing.

---

## Tamaki Kotatsu
*Fire Force* &nbsp;·&nbsp; `tamaki` &nbsp;·&nbsp; `transform` `dot` `trap` `aoe`

**Core:** A stacking Affliction engine: Nekomata Cage deters enemies from attacking (a new harmful skill inflicts permanent damage-over-time), and every permanent affliction stack scales up Nekomata Blaze and Fireball by +5 each.

**▶ Playing as Tamaki Kotatsu**
- Apply Nekomata Cage early so any enemy that uses a new harmful skill eats permanent 5-per-turn affliction.
- Stack permanent afflictions with Blaze, since each damage-over-time on a target adds +5 to Blaze and Fireball.
- Pop Ignition: Nekomata for 15 permanent Shield, immunity to enemy non-damage effects, and Cage on every enemy, unlocking Nekomata Fireball.
- Against a Caged target, Blaze and Fireball Bypass Invulnerability, so use them to punish turtling enemies.

**⚔ Playing against Tamaki Kotatsu**
- Nekomata Cage punishes any new harmful skill with permanent affliction, so weigh every attack on a Caged ally.
- Watch the Ignition: Nekomata transformation, which Cages your entire team at once and lets Blaze/Fireball ignore Invulnerability.
- Her afflictions are permanent and stacking, and they scale her nukes, so cleanse or race her before they pile up.
- Fearless Defender reflects Harmful skills aimed at her allies back onto herself, so focus-firing her ally can backfire.

---

## Tatsumaki
*One Punch Man* &nbsp;·&nbsp; `tatsumaki` &nbsp;·&nbsp; `stun-lock` `burst` `aoe` `invuln` `disruption`

**Core:** A stun-lock and execute setup: she stuns with Psychic Shear and Psychokinetic Bind, extends stuns with Extreme Psychic Twisting, then swaps in Spear of Green Light to nuke a stunned target for 75.

**▶ Playing as Tatsumaki**
- Stun a target with Psychic Shear or Psychokinetic Bind, then swap to Spear of Green Light for a 75-damage hit on them.
- Extreme Psychic Twisting hits all enemies for 30, lengthens existing stuns by a turn, and unlocks Spear of Green Light.
- Psychokinetic Bind can slam two Nullified enemies together for 2-turn stuns and Bypasses Invulnerability.
- Tatsumaki Barrier gives you an Invulnerable turn and unlocks City-Wide Barrier to make your whole team Invulnerable for two.

**⚔ Playing against Tatsumaki**
- Respect the stun-into-Spear-of-Green-Light combo, which drops 75 damage onto any stunned character.
- Psychokinetic Bind Bypasses Invulnerability and can stun two enemies at once, so avoid clustering.
- Extreme Psychic Twisting is team-wide AoE and adds a turn to any stun you are already under.
- She can make her entire team Invulnerable for two turns with City-Wide Barrier, so time your burst around it.

---

## Tatsumi
*Akame ga Kill* &nbsp;·&nbsp; `tatsumi` &nbsp;·&nbsp; `transform` `invuln`

**Core:** A transformation bruiser: Incursio makes him Invulnerable on any turn he holds his skill (with Bypass while invuln), while Neuntote permanently marks a target as 'stunned' to fuel Killing Strike's bonus damage.

**▶ Playing as Tatsumi**
- Activate Incursio, then skip using a new skill each turn to become Invulnerable while your attacks Bypass.
- While Invulnerable under Incursio, use Invisibility for an extra guaranteed Invulnerable turn.
- Neuntote deals 40 Piercing and permanently marks a target as stunned, powering Killing Strike's +5 stun bonus.
- Killing Strike stacks bonus damage on stunned and sub-50-health targets, and turns Piercing under Incursio.

**⚔ Playing against Tatsumi**
- Respect the Incursio transformation, which makes him Invulnerable every turn he withholds a skill, with attacks that Bypass.
- Neuntote's 'stunned' mark is permanent and never wears off, keeping Killing Strike's bonus always online.
- Under Incursio he chains Invulnerability with Invisibility, making him very hard to pin down and punish.
- Killing Strike deals extra damage to allies below 50 health, so do not leave a wounded character exposed to him.

---

## Tengen Uzui
*Demon Slayer* &nbsp;·&nbsp; `uzui` &nbsp;·&nbsp; `counter` `invuln` `disruption`

**Core:** The Score is a sequencing engine: his first 4 skills each stamp a numbered mark on a random enemy, and once four marks have triggered his cooldowns reset and his skills go free and Uncounterable — as long as he keeps attacking marked enemies in numeric order.

**▶ Playing as Tengen Uzui**
- Spend your first four skills freely to stamp The Score marks, then attack marked enemies in numeric order to unlock free, Uncounterable skills.
- Once The Score activates, plan your target sequence carefully — hitting an unmarked or out-of-order enemy instantly ends the free/Uncounterable window.
- String Performance counters the first Harmful Physical skill used on Uzui, so drop it before you expect a big physical swing.
- First Form: Roar strips a random energy — aim it at a setup enemy who needs a specific color.

**⚔ Playing against Tengen Uzui**
- String Performance sets a counter on the first Harmful Physical skill used on Uzui — bait it with a throwaway hit or use a non-Physical skill.
- Uzui Dodge makes him Invulnerable for a turn, so don't dump burst into it.
- Pressure him before The Score completes four marks; after that his skills are free and Uncounterable until he mis-orders a target.

---

## The Thompson Sisters (Liz and Patty)
*Soul Eater* &nbsp;·&nbsp; `lizandpatty` &nbsp;·&nbsp; `transform` `invuln` `sustain`

**Core:** A weapon-support duo that arms allies via Transform: Liz / Transform: Patty; Brooklyn Devils flips the active sister each time one is wielded, gating which Wavelength Compression and Soul Resonance payoff is available.

**▶ Playing as The Thompson Sisters (Liz and Patty)**
- Arm an ally with Transform: Liz or Patty to gain 10 Damage Reduction and add 10 free damage whenever that ally uses a new Harmful skill.
- Track Brooklyn Devils — wielding one sister flips the active form, so plan which Wavelength Compression you'll have (Liz gives Shield, Patty gives heal).
- Time Soul Resonance to an ally's action to grant Immortality (Strategic), team healing (Liz + Helpful), or a +15 damage spike (Patty + Harmful).
- Coordinated Evasion buys the sisters an Invulnerable turn when they get targeted.

**⚔ Playing against The Thompson Sisters (Liz and Patty)**
- Their Transform skills turn an ally into a damage-adding weapon while granting the sisters 10 Damage Reduction — focus the sisters or the armed ally down.
- Soul Resonance can make an ally Immortal for 2 turns off a Strategic skill, so don't commit a kill attempt into a fresh Resonance.
- Coordinated Evasion grants a full turn of Invulnerability — hold your burst until it drops.

---

## Tia Halibel
*Bleach* &nbsp;·&nbsp; `halibel` &nbsp;·&nbsp; `transform` `invuln` `aoe` `dot` `sustain`

**Core:** Aspect of Sacrifice tanking: she redirects a protected ally's damage onto herself to bank permanent damage-scaling stacks, and dropping below 60 HP triggers her Resurrección transformation that upgrades her whole kit.

**▶ Playing as Tia Halibel**
- Shield an ally with Aspect of Sacrifice; every time that ally is attacked, Halibel banks a permanent stack that boosts Ola Blast/Cascada and Ola Azul/Hirviendo.
- Staying below max HP unlocks Ola Azul's Shatter and extends Hirviendo's boiling DoT to three turns.
- Falling below 60 HP triggers Resurrección: attacks become AoE Cascada and DoT Hirviendo, plus 10 permanent Damage Reduction and a free Aspect stack.
- Tiburón Block gives an Invulnerable turn to survive burst while your stacks ramp.

**⚔ Playing against Tia Halibel**
- Respect Resurrección — dropping her below 60 HP transforms her into an AoE + boiling-DoT threat with +10 Damage Reduction, so either burst clean past it or don't feed chip damage.
- Aspect of Sacrifice redirects a protected ally's damage to Halibel and banks permanent damage stacks, so hitting the shielded ally only powers her up.
- Tiburón Block grants a turn of Invulnerability — don't waste damage into it.

---

## Todoroki Shoto
*My Hero Academia* &nbsp;·&nbsp; `todoroki` &nbsp;·&nbsp; `stun-lock` `invuln` `dot` `disruption`

**Core:** Half-Hot / Half-Cold stack balancing: Jet Burn scales with Half-Hot while Half-Cold extends his stuns and debuffs, but the passive self-punishes overstacking either side (excess Hot deals self-Affliction, excess Cold taxes his energy).

**▶ Playing as Todoroki Shoto**
- Alternate hot and cold skills — Jet Burn hits harder per Half-Hot stack, while Half-Cold lengthens Glacial Prison's stun and Ice Wall's debuff.
- Avoid overstacking: more than one Half-Hot burns you for 10 Affliction each end of turn, and extra Half-Cold costs 1 more Random energy per stack.
- Build a couple Half-Cold stacks before Glacial Prison to extend both the stun and its per-turn damage.
- Fire Wall gives an Invulnerable turn plus a Half-Hot stack — use it to reset while rebalancing your stacks.

**⚔ Playing against Todoroki Shoto**
- Glacial Prison stuns for a turn and lasts longer the more Half-Cold he's stacked, so cleanse or avoid the lock while he's cold-loaded.
- Fire Wall makes him Invulnerable for a turn — don't waste burst into it.
- His passive punishes overstacking, so steady pressure can let his own Half-Hot Affliction chip him down.

---

## Toph Beifong
*Avatar* &nbsp;·&nbsp; `toph`

**Core:** A straightforward physical earthbending kit pairing Harmful attacks with defensive tools and a passive; no special engine is detailed in this data beyond attack-and-defend fundamentals.

**▶ Playing as Toph Beifong**
- Apply pressure with your Harmful physical attacks, Stone Pillar and Earthen Shackles.
- Fall back on Metal Armor (Helpful self-buff) and Earth Wall (Strategic defense) when you need to weather a turn.
- Seismic Sense runs passively in the background, so build a simple attack-plus-defense rhythm each turn.

**⚔ Playing against Toph Beifong**
- She leans on defensive tools Metal Armor and Earth Wall, so expect her to tank and stall rather than explode.
- Her offense is single-hit physical pressure (Stone Pillar, Earthen Shackles) with nothing hidden described here.

---

## Toudou Touka
*Chivalry of a Failed Knight* &nbsp;·&nbsp; `toudou` &nbsp;·&nbsp; `counter` `invisible` `stealth` `burst` `invuln` `disruption`

**Core:** Draw Stance is a counter-stance that both punishes incoming Harmful skills (counter for 15) and arms Raikiri, her 45 Piercing Uncounterable finisher, while Nukiashi hides all her setup behind Invisibility.

**▶ Playing as Toudou Touka**
- Cast Draw Stance to bait enemies: a fresh Harmful skill gets countered for 15, and it swaps you into Raikiri regardless.
- Fire Raikiri next for 45 Uncounterable Piercing damage as your main finisher.
- Open with Nukiashi so your skills go Invisible for 2 turns and enemies can't react to your setup.
- Hold Graceful Dodge to ignore all damage on a telegraphed hit, and use Raiou to stall an enemy by raising their cooldowns.

**⚔ Playing against Toudou Touka**
- Don't feed a fresh Harmful skill into her Draw Stance; it counters you for 15 and swaps her toward Raikiri.
- Respect Raikiri: 45 Piercing that is Uncounterable, so counters won't stop it, bait or pre-heal instead.
- When she casts Nukiashi her skills turn Invisible for 2 turns, so shield or heal preemptively since the hit is hidden.
- Graceful Dodge (ignores all damage) and Raiou's cooldown lock let her stall, so don't burn key cooldowns while she dodges.

---

## Touka Kirishima
*Tokyo Ghoul* &nbsp;·&nbsp; `touka` &nbsp;·&nbsp; `transform` `aoe` `stun-lock` `invuln` `disruption` `dot` `sustain`

**Core:** Crystallized Ukaku is a transformation state that shields her, chips the whole team, and supercharges her attacks, turning Ukaku Slam into a +20 team-hit that fully stuns and Crystallized Shards into a heavier cooldown-disruptor.

**▶ Playing as Touka Kirishima**
- Enter Crystallized Ukaku for 20 Shield and 5 AoE chip per turn, but note it makes your skills single-target.
- Inside Crystallized Ukaku, Ukaku Slam gains +20 and fully stuns 1 turn while Crystallized Shards gains +15, your payoff.
- Prime enemies with Crystallized Shards so Ukaku Slam adds +5 to them and their cooldowns rise for 2 turns.
- Pop Touka Observation for invulnerability and +5 damage to survive a turn or line up your empowered hit.

**⚔ Playing against Touka Kirishima**
- Watch for Crystallized Ukaku: it shields her 20, ticks 5 on your whole team, and turns Ukaku Slam into a +20 AoE that fully stuns.
- She's untouchable during Touka Observation (invulnerable), so don't dump burst into that turn.
- Crystallized Shards raises your cooldowns for 2 turns and primes you for bonus damage, so expect the stun-slam follow-up.

---

## Tsubaki Nakatsukasa
*Soul Eater* &nbsp;·&nbsp; `tsubaki` &nbsp;·&nbsp; `dot`

**Core:** A mode-switching kit rotating through several 'Tsubaki Mode' forms: Helpful support stances, an Affliction (damage-over-time) attack in Smoke Bomb, and an Uncounterable strike in Uncanny Sword; exact effects aren't detailed in this data.

**▶ Playing as Tsubaki Nakatsukasa**
- Rotate her Modes: Kusarigama, Soul Resonance, and Dummy Star are Helpful support tools while Smoke Bomb and Uncanny Sword are offense.
- Lead with Smoke Bomb to plant its Affliction so the damage-over-time keeps ticking while you switch stances.
- Save Uncanny Sword (Uncounterable) for enemies holding counters, since it can't be countered.
- Partner: Black Star is an always-on passive working in the background of your rotation.

**⚔ Playing against Tsubaki Nakatsukasa**
- Smoke Bomb applies an Affliction, so expect damage-over-time to keep ticking on your team after she acts.
- Uncanny Sword is Uncounterable, so don't rely on counters to stop that hit.
- She cycles through support Modes (Kusarigama, Soul Resonance, Dummy Star), so track which stance she's in each turn.

---

## Tsubasa Kazanari
*Symphogear* &nbsp;·&nbsp; `tsubasa` &nbsp;·&nbsp; `aoe` `dot` `disruption` `invuln` `sustain`

**Core:** Team-wide Affliction attrition paired with escalating self-defense: One Thousand Tears and the Burning Wrath Whirl chain pour ramping AoE Affliction and stuns onto the enemy team, while Ame no Habakiri stacks Damage Reduction every skill use, capping in Burning Wrath Blade.

**▶ Playing as Tsubasa Kazanari**
- Open with One Thousand Tears for ramping team-wide Affliction that also Taunts anyone who dares touch your allies.
- Chain Burning Wrath Whirl across turns to keep AoE Affliction and non-Strategic stuns rolling until it becomes Burning Wrath Blade.
- Cash Burning Wrath Blade for 40 Affliction and a permanent Taunt locked onto their biggest threat.
- Act freely to stack Ame no Habakiri Damage Reduction, and hold Tsubasa Block for a guaranteed safe turn.

**⚔ Playing against Tsubasa Kazanari**
- Burning Wrath Whirl stuns your non-Strategic skills each cast, so route damage through Strategic skills or invuln windows.
- Don't attack her allies under One Thousand Tears, or you'll be Taunted onto a target you didn't want.
- Ame no Habakiri stacks Damage Reduction the more she acts, so burst her in one window rather than chipping.
- Respect Tsubasa Block's full Invulnerability, don't waste your payoff turn into it.

---

## Uchiha Itachi
*Naruto* &nbsp;·&nbsp; `itachi` &nbsp;·&nbsp; `counter` `transform` `invisible` `burst` `disruption`

**Core:** Itachi weaves Invisible setups (Crow Clone's energy discount, Kotoamatsukami's counter, Yata Mirror's shield) into a Tsukuyomi payoff that upgrades stun into banish, while Susanoo transforms his entire kit once his HP first drops below 50.

**▶ Playing as Uchiha Itachi**
- Land Crow Clone or Kotoamatsukami's counter this turn, then Tsukuyomi next turn to upgrade its stun into a full banish.
- Crow Clone discounts your Random (and White if they hit you) costs, so drop it before your expensive plays.
- After Susanoo triggers below 50 HP, seal a target with Totsuka Blade then finish with Yasaka Magatama for +20 damage.
- Kotoamatsukami can either counter an enemy's next Harmful skill or pre-guard an ally's incoming one.

**⚔ Playing against Uchiha Itachi**
- Kotoamatsukami is a COUNTER hidden on an Invisible target, so don't blindly throw your key Harmful skill at it.
- Once Itachi drops below 50 HP, Susanoo TRANSFORMS his kit into a Totsuka Blade skill-seal plus a 70-damage Yasaka Magatama BURST.
- If Crow Clone or his counter touched you last turn, Tsukuyomi BANISHES you instead of merely stunning.
- Crow Clone marks you Invisible, and using any new skill triggers his cost cuts plus 10 Piercing to you.

---

## Uraraka Ochaco
*My Hero Academia* &nbsp;·&nbsp; `uraraka` &nbsp;·&nbsp; `invisible` `aoe` `disruption`

**Core:** Uraraka stacks Invisible Zero Gravity marks on enemies, then swaps to Gravity Plus to detonate them for damage and stacking energy taxes — a mark-and-detonate energy-denial engine.

**▶ Playing as Uraraka Ochaco**
- Stack Zero Gravity marks single-target or via Comet Shower's AoE, then swap to Gravity Plus to detonate for damage and energy taxes.
- Comet Shower marks every enemy and grants two turns of Gravity Plus, letting you detonate repeatedly.
- Uraraka Float shields you and auto-marks anyone who attacks you, feeding more Gravity Plus fuel.
- Each Zero Gravity mark stacks, so more marks means bigger Gravity Plus damage and heavier skill costs.

**⚔ Playing against Uraraka Ochaco**
- Zero Gravity is an Invisible mark that drains your energy and weakens your next skill's damage when you act through it.
- Gravity Plus detonates every mark for 20 damage and inflates your skill costs, so avoid letting marks pile up.
- Attacking Uraraka Float just marks you with Zero Gravity, so don't feed it free stacks.

---

## Usopp
*One Piece* &nbsp;·&nbsp; `usopp` &nbsp;·&nbsp; `counter` `aoe` `disruption`

**Core:** Usopp spreads Blind with Smoke Star and turns it into a payoff engine — Blinded enemies feed his AoE (Lead Star, Gunpowder Star) and get countered-and-stunned by Impact Dial — while Sharpshooter keeps his own aim immune.

**▶ Playing as Usopp**
- Open with Smoke Star to Blind enemies, then Lead Star and Gunpowder Star punish everyone Blinded for bonus AoE.
- Impact Dial counters and stuns any Blinded enemy who attacks you or your ally, so pair it with Smoke Star.
- Gunpowder Star detonates Smoke Star for big burst (5 extra per turn remaining), so weigh cashing it early versus letting Blind linger.
- Sharpshooter means your attacks can't Miss and you ignore Blind, so blind the board freely.

**⚔ Playing against Usopp**
- Impact Dial is a COUNTER that also stuns you if you're Blinded, so don't attack Usopp or his ally while Smoke Star is on you.
- Smoke Star's Blind is Bypassing, so invulnerability won't stop it; expect Lead and Gunpowder Star AoE to follow.
- Gunpowder Star's AoE hits Blinded enemies harder the more Smoke Star duration remains.

---

## Uzumaki Boruto
*Naruto* &nbsp;·&nbsp; `boruto`

**Core:** Ability descriptions aren't provided in the kit text, so only class tags are known: this reads as a straightforward Energy-cost Harmful damage kit with one Strategic setup skill (Boruto Shadow Clones), a Passive (Rasengan Specialist), and a Bypassing finisher (Compression Rasengan) — no special engine is verifiable.

**▶ Playing as Uzumaki Boruto**
- Most of Boruto's kit is Energy-cost Harmful damage (three Rasengan variants plus Thunderclap Arrow), so bank Energy to keep pressure flowing.
- Boruto Shadow Clones is his only Strategic skill, so treat it as setup before committing to damage.
- Save Compression Rasengan for targets hiding behind invulnerability, since it's Bypassing.

**⚔ Playing against Uzumaki Boruto**
- Compression Rasengan is Bypassing, so invulnerability won't protect you from it.
- His threats are repeated Energy-cost damage skills, so starving his Energy slows the Rasengan pressure.

---

## Vegeta
*Dragon Ball* &nbsp;·&nbsp; `vegeta` &nbsp;·&nbsp; `burst` `aoe` `disruption`

**Core:** A patience-and-ramp engine: withholding damaging skills each turn stacks Ki Blast's bonus damage, while Galick Gun grows +5 per use and Energy Charge quietly discounts its Red cost.

**▶ Playing as Vegeta**
- Skip damaging skills on quiet turns to stack Ki Blast's +5, then unleash the empowered hit or Double Ki Blast for the whole team.
- Chain Energy Charge on turns you aren't attacked to shave Galick Gun's Red cost and tank 10 damage while you ramp.
- Save Galick Gun as your finisher: it's Uncounterable, piercing, and gains +5 damage every single cast.
- Ki Blast also cuts the target's non-Affliction damage, so lead with it against a heavy attacker.

**⚔ Playing against Vegeta**
- Galick Gun is Uncounterable and piercing and keeps growing +5 per use, so counters and invuln timing won't save you from his finisher.
- Land a Harmful skill on Vegeta while Energy Charge is up to deny his Galick Gun cost-discount stacks.
- If he passes on damaging turns, his Ki Blast is stacking toward a much bigger piercing burst.

---

## Veldora Tempest
*That Time I Got Reincarnated as a Slime* &nbsp;·&nbsp; `veldora` &nbsp;·&nbsp; `invuln` `aoe` `sustain` `disruption`

**Core:** Slumbering Dragon is an idle-to-power engine: each turn he uses no skill he heals 5 and buffs his next Harmful, and at 3+ stacks Imitation Kamehameha gains a stun and Tempest Fist becomes team-wide.

**▶ Playing as Veldora Tempest**
- Pass on turns to bank Slumbering Dragon stacks (heal plus bonus damage) toward the 3-stack threshold.
- At 3+ stacks, Imitation Kamehameha stuns and Tempest Fist hits the whole enemy team, so cash them once you're loaded.
- Hide behind Tempest Guard's invulnerability to safely idle and stack when under pressure.
- Explosive Aura chips all enemies and cuts their damage, and the follow-up turn it only costs 1 Random.

**⚔ Playing against Veldora Tempest**
- Time your big hits for when Tempest Guard's invulnerability is down.
- If Veldora idles, he's stacking Slumbering Dragon toward 3 stacks, which unlocks his stun and his team-wide Tempest Fist.
- Pressure him early and interrupt his stacking before those upgrades come online.

---

## Xanxus
*Katekyo Hitman Reborn* &nbsp;·&nbsp; `xanxus` &nbsp;·&nbsp; `invisible` `invuln` `aoe` `dot` `sustain` `disruption`

**Core:** Scars of Wrath is a reactive punish engine: the first time Xanxus suffers each harm type (normal/piercing/Affliction damage, stun, counter, shatter, isolate, or dropping below half HP) it permanently buffs his skills and unlocks conditional bonuses on them.

**▶ Playing as Xanxus**
- Every unique harm you take permanently powers your kit, so don't fear absorbing stuns, pierces, and Afflictions.
- Sequence your Scars first: after being stunned/pierced/afflicted, Scoppio d'Ira gains a stun, piercing, or permanent Affliction.
- Use Flames of Wrath (Invisible) to re-arm all Scars triggers, then fire a fully-loaded Scoppio d'Ira and Martello di Fiamma.
- Time Sky Flame Deflection's invulnerability against Affliction, Shatter, or Isolate to also heal, gain 25 Shield, or fully cleanse.

**⚔ Playing against Xanxus**
- Don't feed him varied effects: each stun, pierce, Affliction, counter, shatter, and isolate permanently strengthens Scars of Wrath.
- Beware Flames of Wrath, which is Invisible and resets his triggers to set up a loaded burst turn.
- Martello di Fiamma turns Uncounterable if you've countered him and splashes 20 to your others once he's below half, so mind counters and his HP.
- Attacking into Sky Flame Deflection's invulnerability with Affliction/Shatter/Isolate just heals, Shields, or cleanses him.

---

## Yamamoto Takeshi
*Katekyo Hitman Reborn* &nbsp;·&nbsp; `yamamoto` &nbsp;·&nbsp; `transform` `invisible` `invuln` `aoe` `disruption` `sustain`

**Core:** A stack-and-transform engine: Shinotsuku Ame and Utsuhi Ame build Asari Ugetsu stacks, and activating Asari Ugetsu grants 25 Shield and swaps his kit into upgraded Scontro/Beccata di Rondine for one turn plus one per stack consumed.

**▶ Playing as Yamamoto Takeshi**
- Bank Asari Ugetsu stacks with Shinotsuku Ame and Utsuhi Ame, then activate to transform and gain 25 Shield.
- Utsuhi Ame marks a target Invisibly and its delayed hit Bypasses Invulnerability, so bait a skill from them for +15 damage and 2 stacks.
- Stack damage-reduction with Shinotsuku Ame and Beccata di Rondine so transformed Scontro di Rondine gains +5 per reducing effect.
- Consume more stacks for a longer transformation window, and use Sakamaku Ame's invulnerability to survive while building.

**⚔ Playing against Yamamoto Takeshi**
- Utsuhi Ame is an Invisible delayed strike that Bypasses Invulnerability, so don't use a skill under it (it doubles the hit and his stacks) and don't rely on invuln.
- When Yamamoto activates Asari Ugetsu he transforms into Scontro/Beccata di Rondine and gains 25 Shield, and Scontro scales off the damage-cuts he's stacked on you.
- Respect Sakamaku Ame's invulnerability turn when timing your burst.

---

## Yubel
*Yu-Gi-Oh!* &nbsp;·&nbsp; `yubel` &nbsp;·&nbsp; `counter` `invisible` `transform` `disruption`

**Core:** A reflect-tank built on Sealed Nightmare: her HP is capped at 5 but she ignores all Harmful effects while any ally is targetable, and each time she is the primary target of a Harmful skill she gains a Terror Incarnate stack that fuels damage reflection back onto attackers.

**▶ Playing as Yubel**
- Spam Taunts (Sadistic Taunt, Dark Dimension, Malicious Intent) to funnel enemy fire onto Yubel, who ignores all Harmful effects while allies live.
- Every Harmful skill aimed at her builds a Terror Incarnate stack; at 2+ cast Terror Incarnate to permanently reflect the damage she ignores back at the user.
- Push to 4 stacks, then swap to Ultimate Nightmare so all ignored damage reflects back doubled to the whole enemy team for the rest of the game.
- Keep at least one ally alive and targetable, since her Harmful immunity and stack engine both collapse once she is the only target left.

**⚔ Playing against Yubel**
- Her Taunts are Invisible (Sadistic Taunt, Dark Dimension, Malicious Intent) and force you to attack her, so plan around losing target control.
- Attacking Yubel builds Terror Incarnate and gets reflected back, doubled under Ultimate Nightmare, so do not dump burst into her.
- She only ignores Harmful effects while she has living allies, so kill or remove her allies first to expose her 5-HP body.

---

## Yugi Mutou
*Yu-Gi-Oh!* &nbsp;·&nbsp; `yugi`

**Core:** The provided kit has no ability descriptions, so only the class tags are readable: it reads as an Energy-based damage kit whose key nukes are built to be unstoppable — Dark Magician is Unstunnable and Uncounterable, Dark Magician Girl is Unstunnable — backed by the non-Harmful Big Shield Gardna and the Exodia, the Forbidden One passive.

**▶ Playing as Yugi Mutou**
- Dark Magician is your unstoppable Energy finisher, being both Unstunnable and Uncounterable, so lead with it into stun- or counter-reliant enemies.
- Dark Magician Girl is also Unstunnable, so keep it as a reliable Energy attack when you are stun-locked.
- Big Shield Gardna is your only non-Harmful tool (Physical/Strategic), so hold it for defense or setup rather than damage.

**⚔ Playing against Yugi Mutou**
- Do not rely on stuns, because Dark Magician and Dark Magician Girl are both Unstunnable and will fire anyway.
- Do not waste a counter on Dark Magician since it is Uncounterable; save counters for her other skills.
- Her damage is almost entirely Energy-costed (Dark Magician, Obliterate!, Dark Magician Girl), so Energy denial slows her nukes.

---

## Yumiya Rakko
*A Certain Scientific Railgun* &nbsp;·&nbsp; `rakko` &nbsp;·&nbsp; `dot` `invuln` `counter`

**Core:** A Bleed-stacking hunter: Bleeding Shot and her Relentless Hunter punish-Bleeds trigger Wave Tracking to auto-Shatter targets, and a Shattered enemy lets Close-Range Rifle fire for free while it scales up +5 for every Bleed effect on them.

**▶ Playing as Yumiya Rakko**
- Open with Bleeding Shot, since Wave Tracking auto-Shatters the target for the Bleed's full duration.
- Once Wave Tracking has Shattered an enemy, Close-Range Rifle costs nothing and gains +5 damage per Bleed effect on them.
- Stack more Bleeds via Bleeding Shot plus Relentless Hunter's punish-Bleed to inflate Close-Range Rifle's bonus damage.
- Use Relentless Hunter for 4 turns of invulnerability to Strategic skills, and Rakko Block for a full turn of invuln when threatened.

**⚔ Playing against Yumiya Rakko**
- Respect her Invulnerability windows: Rakko Block is a full turn and Relentless Hunter makes her immune to Strategic skills for 4 turns.
- While Relentless Hunter is active, do not cast new Strategic skills, as each one is punished with Bleed.
- Every Bleed feeds Wave Tracking's Shatter and a free, scaling Close-Range Rifle, so cleanse Bleed early or the pressure snowballs.

---

## Yuno Gasai
*Mirai Nikki* &nbsp;·&nbsp; `gasai` &nbsp;·&nbsp; `counter` `invisible` `invuln` `burst` `aoe`

**Core:** A stack-building engine around Yukiteru Diary marks that accrue each turn on Yuno and a random ally, simultaneously scaling her damage and turning marked allies into protected, attacker-punishing zones.

**▶ Playing as Yuno Gasai**
- Let Yukiteru Diary stacks accumulate before firing Axe Crazy — at 3+ combined stacks it Pierces and Bypasses a marked target.
- Cast Breakdown to lock stacks from removal, then unleash Mow Down for 5 AoE damage per field stack, Bypassing marked enemies.
- Use Knife Deflection on a marked ally — at 2+ stacks it counters all their incoming skills and retaliates with Axe Crazy.
- Remember every skill you use strips one of your own stacks, so time Axe Crazy for peak stack count.

**⚔ Playing against Yuno Gasai**
- Beware Knife Deflection: an Invisible counter on Yuno's marked allies that can punish all your skills and trigger a free Axe Crazy.
- Attacking a marked ally marks YOU for a turn, setting up Mow Down to Bypass and burst your whole team.
- Desperate Escape grants Yuno or a marked ally Invulnerability, so don't dump key damage into that turn.

---

## Yuno Grinberryall
*Black Clover* &nbsp;·&nbsp; `yuno` &nbsp;·&nbsp; `transform` `burst` `aoe` `invuln` `dot`

**Core:** A transformation carry: Spirit Dive: Sylph upgrades her whole kit into Sylph forms, drips blue energy plus damage reduction, and every AoE hit cheapens the finisher Spirit of Zephyr — a 65-damage nuke that Bypasses Invulnerability and extends the transformation whenever it secures a kill.

**▶ Playing as Yuno Grinberryall**
- Cheapen and cast Spirit Dive: Sylph (keep Towering Tornado up and land a full-team Wind Blades Shower) to transform and gain blue energy plus 10 damage reduction.
- In form, hammer AoE Gale White Bow and Sylph's Breath, since each enemy struck cuts Spirit of Zephyr's blue-energy cost.
- Close with Spirit of Zephyr: 65 piercing that Bypasses Invulnerability, and a kill extends Spirit Dive: Sylph by 2 turns to keep the form running.
- Sylph Block buys a turn of full invulnerability when you need to survive to your next big cast.

**⚔ Playing against Yuno Grinberryall**
- Respect the transformation: Spirit Dive: Sylph upgrades her entire kit and grants damage reduction, so burst her before she dives or wait the form out.
- Spirit of Zephyr is a 65-damage nuke that Bypasses Invulnerability, so you cannot hide behind invuln, and a kill extends her transformation.
- Never counter Spirit of Zephyr, because if it is countered it simply auto-casts again the following turn.
- She is AoE-heavy (Gale White Bow, Sylph's Breath's Shatter and per-turn piercing), so don't clump low-HP characters into her team-wide damage.

---
