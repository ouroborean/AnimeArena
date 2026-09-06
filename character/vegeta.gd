extends Character
class_name Vegeta


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)
	
	var ticking_trigger = Effect.trigger_effect(Trigger.always(ki_blast_trigger), EffectType.Type.END_OF_TURN_TRIGGER, -1, func (eff): return "Ki Blast will gain 5 damage (stacks).")
	ticking_trigger.set_source(moveset.base_abilities[0])
	Character.add_allied_effect(context, self, self, ticking_trigger)

func ki_blast_trigger(context):
	var vegeta = context['owner']
	if vegeta.acted and (vegeta.used_ability == null or (vegeta.used_ability.ability_name != "Energy Charge" and vegeta.used_ability.ability_name != "Galick Gun")):
		return
	var damage_mod = Effect.damage_mod_effect(5, -1, ["Ki Blast", "Double Ki Blast"])
	damage_mod.set_source(moveset.base_abilities[0])
	damage_mod.stackable=true
	damage_mod.display_stacks=true
	damage_mod.per_stack=true
	Character.add_allied_effect(context, vegeta, vegeta, damage_mod)
	

func initialize(_moveset = false):

	character_colors = [1, 3]
	character_name = "Vegeta"
	path_name = "vegeta"
	universe = CharacterConcept.Universe.DRAGON_BALL
	description = "Vegeta, legendary prince of the Saiyans. A powerful and relentless warrior, Vegeta bears the pride of his fallen race on his back and never accepts defeat."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
