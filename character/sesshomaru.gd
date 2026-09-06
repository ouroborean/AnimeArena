extends Character

# Sesshomaru (Inuyasha). A daiyokai striker built around Destructive Corrosion — a debuff applied by
# Bakusaiga that his other skills key off of. Destructive Corrosion is NOT a castable kit skill; it is a
# Passive-classed effect SOURCE (sesshomaru6, base_abilities[5]) whose only job is to hold the effect and
# be its source, exactly like All Might's One For All. Perfect Daiyoukai (sesshomaru5) is the real passive.

func _ready():
	pass

func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)

# Perfect Daiyoukai (part 1): shorten each incoming Stun by 1 turn (dur 2), floored at 0, on a 3-turn cooldown.
# on_stun_received runs PRE-application with the live effect node (character_component.gd:195), so we mutate the
# stun's duration before it lands. The COOLDOWN + its visible "ready / recharging" indicator live on the passive
# (sesshomaru5): a "Perfect Daiyoukai" MARK, permanent when ready, a ticking one while recharging.
func on_stun_received(effect) -> bool:
	var pd = moveset.base_abilities[4]   # Perfect Daiyoukai
	if pd.stun_on_cooldown(self):
		return false   # recharging — the stun lands at full duration
	effect.duration -= 2   # 1 turn == duration 2
	if effect.duration < 0:
		effect.duration = 0
	pd.begin_stun_cooldown(self)   # start the visible recharge; hide the "ready" indicator
	return effect.duration == 0    # fully block the stun only when reduced to nothing

func initialize(_moveset = false):
	character_colors = [0]   # Green is the only non-random cost colour; audit with tools/roster_colors.py
	character_name = "Sesshomaru"
	path_name = "sesshomaru"
	universe = CharacterConcept.Universe.INUYASHA
	description = "Sesshomaru, the Killing Perfection — a full-blooded daiyokai and Inuyasha's elder half-brother. Cold and merciless, he wields Bakusaiga's corrosive power and the life-and-death blades Tenseiga and Tokijin to grind lesser beings to nothing."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "sesshomaru_unlock" in player.unlocks

func _process(delta):
	pass
