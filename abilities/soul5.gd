extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "If Maka is alive on Soul's team, Scythe Transformation can only target her and he will begin the game with Maka wielding him."

func split_desc():
	return [
		["If Maka is alive on Soul's team, Scythe Transformation can only target her, and the game begins with Maka wielding him", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in user.team.characters:
		if character.path_name == "maka":
			
			user.targeter.targets = [character]
			user.targeter.main_target = character
			
			user.moveset.base_abilities[0].execute(user, battle)
			user.moveset.base_abilities[0].cooldown_remaining = 3
			if battle.get_player_owner(user).waiting_for_turn:
				user.moveset.base_abilities[0].cooldown_remaining = 4
			user.targeter.clear_targets()
			var mark_eff = Effect.mark(-1, "Scythe Transformation can only target Maka Albarn.")
			mark_eff.set_source(self)
			mark_eff.cleansable = false
			Character.add_allied_effect(context, user, user, mark_eff)
			
	var eat_desc = func (eff):
		return "Soul has eaten " + str(eff.stacks) + " souls."
	var eat_counter = Effect.mark(-1, eat_desc)
	eat_counter.set_source(user.moveset.base_abilities[3])
	eat_counter.stacks = 0
	var trigger_desc = func (eff):
		return "Soul has dealt " + str(eff.mag) + " damage."
	var eat_trigger = Effect.trigger_effect(Trigger.always(consume_trigger), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, trigger_desc)
	eat_trigger.set_source(user.moveset.base_abilities[3])
	eat_trigger.stacks = 0
	Character.add_allied_effect(context, user, user, eat_counter)
	Character.add_allied_effect(context, user, user, eat_trigger)

func consume_trigger(context):
	context['effect'].mag += context['value']

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	pass
