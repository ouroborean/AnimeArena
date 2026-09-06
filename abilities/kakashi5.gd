extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Kakashi's skills cannot be countered or reflected."

func split_desc():
	return [
		["Kakashi's skills cannot be countered or reflected", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	#var trigger_desc = func (eff):
	#	return "Whenever Luffy deals damage to an enemy, he gains that amount of destructible defense for 1 turn."
	#var trigger = Trigger.from_condition(Condition.always(), null)
	#var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, trigger_desc)
	#trigger_eff.set_source(self)
	#Character.add_allied_effect(context, user, user, trigger_eff)
	
	var ignore_eff = Effect.ignore_effect_effect(-1, EffectType.Type.COUNTER_RECEIVE)
	ignore_eff.set_source(self)
	ignore_eff.description = func (eff):
		return "Kakashi's skills cannot be countered or reflected."
	ignore_eff.cleansable = false
	var ignore_eff2 = Effect.ignore_effect_effect(-1, EffectType.Type.COUNTER_USE)
	ignore_eff2.system = true
	ignore_eff2.set_source(self)
	ignore_eff2.cleansable = false

	Character.add_allied_effect(context, user, user, ignore_eff)
	Character.add_allied_effect(context, user, user, ignore_eff2)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return false
	
func target(user, battle):
	pass
