extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Black Star becomes invulnerable for one turn. If Tsubaki: Enchanted Sword Mode is active, Black Star's skills will Bypass the following turn."

func split_desc():
	return [
		"Black Star becomes Invulnerable for 1 turn",
		"Black Star Bypasses for 1 turn if used during Tsubaki: Enchanted Sword Mode"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)
	var mark = Effect.mark(3, "Black Star's skills will Bypass Invulnerability.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += self.behavior_self_panic_button(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
