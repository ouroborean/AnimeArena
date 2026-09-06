extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Meliodas equips his Sacred Treasure, permanently lowering the cost of Hellblaze by 1 random energy and reducing the cooldown of Full Counter by 1 turn. This skill is replaced by Jitsuzo Bunshin."

func split_desc():
	return [
		"Whenever an enemy uses a Harmful non-Strategic skill on Meliodas's allies, he deals 10 damage to them",
		["This also occurs if Full Counter is not triggered", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in context.ally_team.characters:
		if target == user:
			continue
		var eff = Effect.trigger_effect(Trigger.always(damage_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, -1, "")
		eff.set_source(self)
		eff.system = true
		Character.add_allied_effect(context, user, target, eff)
	var mark = Effect.mark(-1, "Meliodas will deal 10 damage to any enemy that uses a Harmful, non-Strategic skill on his allies.")
	mark.set_source(self)
	mark.cleansable = false
	Character.add_allied_effect(context, user, user, mark)

func damage_trigger(context):
	if context.source.classes["Strategic"]:
		return
	var _target = context.owner
	var effect = context.effect
	var new_context = QueryContext.from_game_state(user, user.battle)
	Character.resolve_effect_damage(new_context, effect, _target, 10, DamageType.Type.NORMAL)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true



func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
