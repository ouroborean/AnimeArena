extends Character


# Per-enemy set of Toji's DISTINCT damaging skills that have hit them (enemy -> [skill_name]).
# Drives the X-Slash swap. Reset each battle in startup(). Kept on the character (not a
# synthetic passive ability) — the passive hookups are installed in startup(), the Alphonse way.
var xslash_hits = {}


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)
	# Heavenly Restriction — Toji's passive machinery. Following Alphonse's S4 (a permanent
	# effect installed in the character's startup rather than a synthetic "Passive" ability),
	# all three reactive hooks live on Toji, are invisible/system, and are sourced to X-Slash
	# (base_abilities[4]) — the hidden ability whose swap they drive:
	#   DAMAGE_DEALT     -> track which distinct skills have hit each enemy; swap X-Slash in at 3.
	#   HARMFUL_RECEIVE  -> extend Playful Cloud when its victim uses a Harmful skill on Toji.
	#   START_OF_TURN    -> re-check the swap each turn (revert/retarget if the qualifier dies).
	xslash_hits = {}
	var xslash = moveset.base_abilities[4]
	var dealt = Effect.trigger_effect(Trigger.always(toji_track_damage), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, "")
	dealt.set_source(xslash)
	dealt.invisible = true
	dealt.system = true
	Character.add_allied_effect(context, self, self, dealt)
	var received = Effect.trigger_effect(Trigger.always(toji_extend_playful_cloud), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, -1, "")
	received.set_source(xslash)
	received.invisible = true
	received.system = true
	Character.add_allied_effect(context, self, self, received)
	var turn = Effect.trigger_effect(Trigger.always(toji_reevaluate), EffectType.Type.START_OF_TURN_TRIGGER, -1, "")
	turn.set_source(xslash)
	turn.invisible = true
	turn.system = true
	Character.add_allied_effect(context, self, self, turn)

func initialize(_moveset = false):
	character_name = "Fushiguro Toji"
	path_name = "toji"
	universe = CharacterConcept.Universe.JUJUTSU_KAISEN
	character_colors = [0]
	description = "Toji Fushiguro, the Sorcerer Killer. Born into the Zenin clan with Heavenly Restriction, he traded all cursed energy for a peerless body - able to hunt jujutsu sorcerers with an arsenal of cursed tools no technique can anticipate."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass

# --- passive hooks (callables installed in startup) ------------------------------------

# DAMAGE_DEALT_TRIGGER: record each distinct skill Toji damages an enemy with.
func toji_track_damage(context):
	var enemy = context['target']
	if enemy == null or not is_hostile(enemy):
		return
	var src = context['source']
	var skill_name
	if src is Ability:
		skill_name = src.ability_name
	elif src is Effect and src.source is Ability:
		skill_name = src.source.ability_name
	else:
		return
	if not xslash_hits.has(enemy):
		xslash_hits[enemy] = []
	if not skill_name in xslash_hits[enemy]:
		xslash_hits[enemy].append(skill_name)
	toji_evaluate_xslash(context)

# Swap X-Slash into Inverted Spear's slot while a LIVING enemy has been hit by 3 distinct
# skills; revert otherwise (which also retargets if a different enemy still qualifies).
func toji_evaluate_xslash(context):
	var xslash = moveset.base_abilities[4]
	var has_qualifier = false
	for enemy in context['enemy_team'].characters:
		if enemy.dead or enemy.banished:
			continue
		if xslash_hits.has(enemy) and xslash_hits[enemy].size() >= 3:
			has_qualifier = true
			break
	var swap = effects.has_effect(xslash.ability_name, EffectType.Type.ABILITY_SWAP, self)
	if has_qualifier and swap == null:
		var swap_eff = Effect.ability_swap_effect(4, 2, self, -1)
		swap_eff.set_source(xslash)
		Character.add_allied_effect(context, self, self, swap_eff)
	elif not has_qualifier and swap != null:
		effects.remove_effect(xslash.ability_name, EffectType.Type.ABILITY_SWAP, self)

func toji_reevaluate(context):
	if dead or banished:
		return
	toji_evaluate_xslash(context)

# HARMFUL_RECEIVE_TRIGGER: when a Playful-Cloud'd foe uses a Harmful skill on Toji, extend
# that foe's Playful Cloud DoT (and its Green tax) by 1 turn.
func toji_extend_playful_cloud(context):
	var attacker = context['owner']
	if attacker == null:
		return
	if not context['source'] is Ability:
		return
	if not context['source'].classes["Harmful"]:
		return
	# +2 duration = +1 player-facing turn (durations tick down every player's turn; DoTs only
	# tick on Toji's own turns, so a full extra tick needs +2). Matches crona6's "extended by 1
	# turn" -> duration += 2.
	var dot = attacker.has_effect("Playful Cloud", EffectType.Type.DAMAGE, self)
	if dot != null:
		dot.duration += 2
		dot.effect_updated.emit(dot)
	var tax = attacker.has_effect("Playful Cloud", EffectType.Type.COST_MOD, self)
	if tax != null:
		tax.duration += 2
		tax.effect_updated.emit(tax)
