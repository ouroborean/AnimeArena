extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Erza gains 15 Shield and becomes Invulnerable to Strategic skills for 1 turn",
		["Using this skill removes any active Armor effects and activates a random one", Color.CADET_BLUE],
		["If Erza's corresponding skill is on cooldown, its cooldown is reset", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var shield = Effect.shield_effect(15, 2)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)
	var invuln = Effect.invuln_effect(2, ["Strategic"])
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	var equipped = user.call_unique("erza", "wearing_armor", ["Nakagami's Armor"])
	if equipped:
		var cooldown_mod = Effect.cooldown_mod(-1, -1, ["Queen of Fairies"])
		cooldown_mod.set_source(self)
		cooldown_mod.stackable = true
		cooldown_mod.stack_mag = true
		cooldown_mod.display_stacks = true
		cooldown_mod.unique_render_id = 5
		Character.add_allied_effect(context, user, user, cooldown_mod)
	
	
	var armors = ["clear_heart", "heavens_wheel", "nakagamis"]
	var roll = battle.roll(0, 2)
	var armor = armors[roll]
	user.call_unique("erza", "requip_armor", [armor])
	if user.path_name == "erza":
		user.moveset.base_abilities[roll].cooldown_remaining = 0

		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context)
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
