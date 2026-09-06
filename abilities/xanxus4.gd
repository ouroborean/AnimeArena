extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Makes Xanxus invulnerable for 1 turn. This gains the following bonus effects, corresponding to the effects that have triggered Scars of Wrath: Received Affliction damage -> Heals Xanxus 15 health. Received a Shatter effect -> Gives Xanxus 25 Shield. Received an Isolate effect -> Fully cleanses Xanxus."

func split_desc():
	return [
		["Xanxus becomes invulnerable for 1 turn", Color.CADET_BLUE],
		["Scars of Wrath (Affliction triggered): Heals Xanxus 15 health", Color.CADET_BLUE],
		["Scars of Wrath (Shatter triggered): Gives Xanxus 25 Shield", Color.CADET_BLUE],
		["Scars of Wrath (Isolate triggered): Fully cleanses Xanxus of enemy effects", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)
	if user.path_name != "xanxus":
		return
	var wrath_storage = user.effects.has_effect("Scars of Wrath", EffectType.Type.XANXUS_STORAGE, user).storage
	if wrath_storage['isolate'] > 0:
		user.effects.cleanse_all_enemy_effects(user)
	if wrath_storage['affliction'] > 0:
		Character.resolve_healing(context, user, 15)
	if wrath_storage['shatter'] > 0:
		var shield = Effect.shield_effect(25, -1)
		shield.set_source(self)
		Character.add_allied_effect(context, user, user, shield)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 15, 1.3)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
