extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "After using 4 skills Byakuya will release his Bankai, applying Scatter, Senbonzakura to all enemies and making it target all enemies for the rest of the game. During this time, Senka is replaced by White Imperial Sword."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger_desc = func (eff):
		return "Byakuya will activate his Bankai after using " + str(eff.mag) + " more skills."
	var action_trigger = Effect.trigger_effect(Trigger.always(bankai_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, trigger_desc)
	action_trigger.mag = 4
	action_trigger.waiting = false
	action_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, action_trigger)

func split_desc():
	return [
		"Applies Scatter, Senbonzakura to all enemies and makes it AOE for the rest of the game",
		"Triggers after Byakuya uses 4 skills",
		["Swaps Senka to White Imperial Sword", Color.AQUAMARINE]
	]

func bankai_trigger(context):
	var byakuya = context['owner']
	var enemy_team = context['enemy_team']
	context['effect'].change_mag(-1)
	if context['effect'].mag <= 0:
		byakuya.manually_advance_mission(8, 1)
	#Removes bankai tracker, makes Scatter AoE and swaps in White Imperial Sword
		context['owner'].effects.remove_effect("Bankai: Senbonzakura Kageyoshi", EffectType.Type.ACTION_USE_TRIGGER, context['owner'])
		var aoe_effect = Effect.target_change_effect(TargetType.Type.ALL, -1, ["Scatter, Senbonzakura"])
		aoe_effect.set_source(self)
		var swap1 = Effect.ability_swap_effect(6, 2, context['owner'], -1)
		swap1.set_source(self)
		Character.add_allied_effect(context, user, user, swap1)
		Character.add_allied_effect(context, user, user, aoe_effect)

		#Cleansing characters and byakuya of Scatter effects so it may cast correctly
		for character in enemy_team.characters:
			if(character.effects.get_all_effects_by_name("Scatter, Senbonzakura", byakuya) != []):
				character.effects.remove_effect("Scatter, Senbonzakura", EffectType.Type.DAMAGE, byakuya)
		if(byakuya.effects.get_all_effects_by_name("Scatter, Senbonzakura", byakuya) != []):
			byakuya.effects.remove_effect("Scatter, Senbonzakura", EffectType.Type.COST_CHANGE, byakuya)
			
		#Targeting Swapping and executing the now-AoE Senbonzakura	
		var target_temp_storage = context['owner'].targeter.targets
		var main_target_temp_storage = context['owner'].targeter.main_target
		var used_ability_storage = context['owner'].used_ability
			
		byakuya.targeter.targets = enemy_team.characters
		byakuya.targeter.main_target = target
		byakuya.used_ability = byakuya.moveset.base_abilities[0]
		byakuya.used_ability.execute(byakuya, byakuya.battle)
		byakuya.check_ability_use_triggers(byakuya.battle, byakuya.moveset.base_abilities[0])
		
		byakuya.targeter.targets = target_temp_storage
		byakuya.targeter.main_target = main_target_temp_storage
		byakuya.used_ability = used_ability_storage

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
