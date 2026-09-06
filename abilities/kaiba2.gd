extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Kaiba gains 15 Shield and 1 stack of Blue-Eyes White Dragon",
		["If Kaiba has 3 stacks, this skill is replaced by Blue-Eyes Ultimate Dragon", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	user.manually_advance_mission(6, 1)
	var shield = Effect.shield_effect(15, -1)
	shield.stack_mag = true
	shield.display_mag = true
	shield.stackable = true
	shield.unique_render_id = 15
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)
	var damage_mod = Effect.damage_mod_effect(5, -1, ["Burst Stream of Destruction"])
	damage_mod.set_source(self)
	damage_mod.display_stacks = true
	damage_mod.stackable = true
	damage_mod.stack_mag = true
	Character.add_allied_effect(context, user, user, damage_mod)
	var mark = Effect.mark(-1, "Burst Stream of Destruction will deal Piercing damage and is now Uncounterable.")
	mark.set_source(self)
	mark.stackable = true
	Character.add_allied_effect(context, user, user, mark)
	user.moveset.base_abilities[0].classes["Uncounterable"] = true
	if user.has_effect("Blue-Eyes White Dragon", EffectType.Type.MARK).stacks >= 3:
		var swap = Effect.ability_swap_effect(5, 1, user, -1)
		swap.set_source(self)
		swap.unique_render_id = 5
		Character.add_allied_effect(context, user, user, swap)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 20)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
