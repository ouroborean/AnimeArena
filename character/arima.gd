extends Character

# Kishou Arima (Tokyo Ghoul). All kit logic lives in the ability files + the SSS Ukaku Quinque passive
# (arima5), which installs Arima's persistent machinery. The directional "ignore all damage from one
# enemy" of Ixa Shield rides a small engine extension to is_ignoring_damage (effect.character_target).

func _ready():
	pass

func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)

func initialize(_moveset = false):
	character_colors = [3]   # Red is the only non-random cost colour; audit with tools/roster_colors.py
	character_name = "Kishou Arima"
	path_name = "arima"
	universe = CharacterConcept.Universe.TOKYO_GHOUL
	description = "Kishou Arima is the CCG's undefeated \"Reaper\" — a legendary Ghoul Investigator who wields the quinques Narukami and IXA, and is secretly the One-Eyed Owl."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "arima_unlock" in player.unlocks

func _process(delta):
	pass
