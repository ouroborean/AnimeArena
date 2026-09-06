extends Node
class_name StatComponent

var random = RandomNumberGenerator.new()

var base_stats = {
	StatType.Type.ATTACK: random.randi_range(25, 100),
	StatType.Type.DEFENSE: random.randi_range(25, 100),
	StatType.Type.SPEED: random.randi_range(25, 100),
	StatType.Type.MIND: random.randi_range(25, 100),
	StatType.Type.RESIST: random.randi_range(25, 100)
}



# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func get_base_stat(stat):
	return base_stats[stat]

func get_mod_stat(entity, stat):
	var base_stat = base_stats[stat]
	
	#TODO get stat mod effects
	var stat_boost_effects = entity.get_effects_by_type(EffectType.Type.PRIMARY_STAT_MOD)
	
	if stat_boost_effects:
		for boost in stat_boost_effects:
			if boost.stat_target == stat:
				base_stat += base_stats[stat] * boost.mag
	
	return base_stat

func modify_outgoing_damage_by_stat(base_damage, stat, entity):
	var base_multi = 20
	return base_multi * base_damage * get_mod_stat(entity, stat)
	
func modify_incoming_damage_by_stat(inc_damage, stat, entity):
	return int( ( (inc_damage / get_mod_stat(entity, stat) / 50) + 4 ) * random.randf_range(0.85, 1.0) )

func pretty_print(entity):
	for stat in StatType.Type.keys():
		print("\t" + stat + ": " + str(get_mod_stat(entity, StatType.Type[stat])) + " (" + str(get_base_stat(StatType.Type[stat])) + ")")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
