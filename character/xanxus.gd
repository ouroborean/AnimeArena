extends Character
class_name Xanxus


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0]
	character_name = "Xanxus"
	path_name = "xanxus"
	universe = CharacterConcept.Universe.KATEKYO_HITMAN_REBORN
	description = "Xanxus is the son of the Vongola family's Ninth Boss, and the leader of the Varia, its independent assassination squad. He possesses the Flames of Wrath, a power made even more devastating when used in conjunction with his handguns."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "xanxus_unlock" in player.unlocks

# "A stack of Scars of Wrath" is not a counter — it IS these three permanent per-stack modifiers.
# The nine-slot storage dict only records which TRIGGERS have already paid out, which is why the
# per-turn faucet in xanxus5 grants a stack through here instead: it takes the generic bonuses
# without consuming (or needing) one of the nine categories.
func grant_wrath_stack():
	var context = QueryContext.from_game_state(self, self.battle)
	self.manually_advance_mission(8, 1)
	var damage_mod = Effect.damage_mod_effect(5, -1, ["Scoppio d'Ira"])
	damage_mod.set_source(moveset.base_abilities[4])
	damage_mod.stackable = true
	damage_mod.display_stacks = true
	damage_mod.per_stack = true

	var cost_mod = Effect.cost_mod_effect(-1, -1, Energy.Type.RANDOM, ["Martello di Fiamma"])
	cost_mod.set_source(moveset.base_abilities[4])
	cost_mod.stackable = true
	cost_mod.per_stack = true

	var cooldown_mod = Effect.cooldown_mod(-1, -1, ["Sky Flame Deflection"])
	cooldown_mod.set_source(moveset.base_abilities[4])
	cooldown_mod.stackable = true
	cooldown_mod.per_stack = true

	Character.add_allied_effect(context, self, self, damage_mod)
	Character.add_allied_effect(context, self, self, cost_mod)
	Character.add_allied_effect(context, self, self, cooldown_mod)

func wrath_check(condition):
	var context = QueryContext.from_game_state(self, self.battle)
	var wrath_eff = effects.has_effect("Scars of Wrath", EffectType.Type.XANXUS_STORAGE, self)
	# The storage is death-cleansed with everything else Xanxus applied to himself, so a revived
	# Xanxus reaches this with nothing to read. Bail rather than crash — a runtime error here only
	# logs and continues, leaving the passive silently dead for the rest of the match.
	if wrath_eff == null:
		return
	if wrath_eff.storage[condition] == 0 or (marked_by("Flames of Wrath", self) and condition != "half"):
		grant_wrath_stack()
		if wrath_eff.storage[condition] == 0:
			var mark
			match condition:
				"normal":
					mark = Effect.mark(-1, func (eff): return "Xanxus has received Normal damage.")
					mark.set_source(moveset.base_abilities[4])
				"piercing":
					mark = Effect.mark(-1, func (eff): return "Xanxus has received Piercing damage.")
					mark.set_source(moveset.base_abilities[4])
				"affliction":
					mark = Effect.mark(-1, func (eff): return "Xanxus has received Affliction damage.")
					mark.set_source(moveset.base_abilities[4])
				"counter":
					mark = Effect.mark(-1, func (eff): return "Xanxus has been countered.")
					mark.set_source(moveset.base_abilities[4])
					var counter_ignore = Effect.ignore_counter_effect(-1, ["Martello di Fiamma"])
					counter_ignore.set_source(moveset.base_abilities[1])
					Character.add_allied_effect(context, self, self, counter_ignore)
				"stun":
					mark = Effect.mark(-1, func (eff): return "Xanxus has been Stunned.")
					mark.set_source(moveset.base_abilities[4])
				"isolate":
					mark = Effect.mark(-1, func (eff): return "Xanxus has been Isolated.")
					mark.set_source(moveset.base_abilities[4])
				"shatter":
					mark = Effect.mark(-1, func (eff): return "Xanxus has been Shattered.")
					mark.set_source(moveset.base_abilities[4])
				"half":
					mark = Effect.mark(-1, func (eff): return "Xanxus has been brought below half health.")
					mark.set_source(moveset.base_abilities[4])
					var target_change = Effect.target_change_effect(TargetType.Type.ALL, -1, ["Martello di Fiamma"])
					target_change.set_source(moveset.base_abilities[1])
					Character.add_allied_effect(context, self, self, target_change)
			Character.add_allied_effect(context, self, self, mark)
				
		wrath_eff.storage[condition] += 1

func _process(delta):
	pass
