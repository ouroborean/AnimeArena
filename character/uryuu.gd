extends Character
class_name Uryu


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)
	#Call passive startup functions here
	#example_passive_startup_function(context)

func initialize(_moveset = false):
	path_name = "uryuu"
	description = "The last known Quincy is a calm and collected character who is able to analyze any situation. Uryuu's Quincy skills allow for amazing defensive and offensive abilities."
	character_name = "Ishida Uryu"
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func example_passive_startup_function(context):
	pass

func spend_quincy_energy(energy):
	var spirit_particles = self.effects.has_effect("Spirit Particle Subjugation", EffectType.Type.MARK, self)
	spirit_particles.change_mag(-energy)
	if spirit_particles.mag <= 0:
		effects.full_remove_effect_by_name("Spirit Particle Subjugation")

func _process(delta):
	pass
