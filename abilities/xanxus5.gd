extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "The first time Xanxus receives normal damage, Scoppio d'Ira permanently deals 5 more damage, Martello di Flamma costs 1 less Random energy, and Sky Flame Deflection has 1 less cooldown. The same is true for receiving Piercing damage, receiving Affliction damage, being stunned, being countered, being shattered, being isolated, and being reduced below half health."

func split_desc():
	return [
		["Passive (Scars of Wrath): The first time Xanxus receives normal damage, Scoppio d'Ira permanently deals 5 more damage, Martello di Flamma costs 1 less Random energy, and Sky Flame Deflection has 1 less cooldown", Color.DIM_GRAY],
		["The same applies for Piercing damage, Affliction damage, being stunned, countered, shattered, isolated, and reduced below half health", Color.DIM_GRAY],
		["Xanxus also gains a stack on his 2nd and 4th turns", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var wrath_eff = Effect.xanxus_storage_effect()
	wrath_eff.set_source(self)
	Character.add_allied_effect(context, user, user, wrath_eff)
	# The two free stacks are counted in XANXUS'S OWN ACTING TURNS, so this is a START_OF_TURN_TRIGGER
	# (it fires at the top of EVERY turn, both sides — hence the acting-team gate in turn_trigger)
	# rather than a TICKING_TRIGGER: a ticker is skipped outright while its holder is dead or
	# banished, and the owner ruled that the count must not pause for either. system +
	# remove_on_death = false keeps the counter itself alive across a death for the same reason;
	# display_system puts it back on the wire, because when the next free stack lands is information
	# both players are entitled to.
	var turn_counter = Effect.trigger_effect(Trigger.always(turn_trigger), EffectType.Type.START_OF_TURN_TRIGGER, -1, turn_counter_desc())
	turn_counter.set_source(self)
	turn_counter.mag = 0
	turn_counter.system = true
	turn_counter.display_system = true
	turn_counter.remove_on_death = false
	Character.add_allied_effect(context, user, user, turn_counter)

func turn_counter_desc():
	return func (eff):
		if eff.mag < 2:
			return "Xanxus will gain a stack of Scars of Wrath on his 2nd and 4th turns."
		if eff.mag < 4:
			return "Xanxus will gain a stack of Scars of Wrath on his 4th turn."
		return "Xanxus has taken every stack of Scars of Wrath his turns can give him."

func turn_trigger(context):
	var eff = context['effect']
	var xanxus = eff.user
	var mbattle = xanxus.battle
	# START_OF_TURN fires for every character at the top of BOTH sides' turns, so only Xanxus's own
	# side's turns may count. `waiting_for_turn` is the player/enemy SIDE split, NOT "my team" — it
	# inverts when Xanxus is player 2 — so derive the acting team from it and ask whether he is on it.
	var acting_team = mbattle.enemy.team if mbattle.waiting_for_turn else mbattle.player.team
	if not xanxus in acting_team.characters:
		return
	eff.mag += 1
	if eff.mag != 2 and eff.mag != 4:
		return
	xanxus.grant_wrath_stack()
	# Named like the nine trigger categories (same effect name, same type and user — they do NOT
	# merge, each is stored separately) so the free stacks are legible on his tooltip too.
	var mark
	if eff.mag == 2:
		mark = Effect.mark(-1, func (_eff): return "Xanxus has fought on into his 2nd turn.")
	else:
		mark = Effect.mark(-1, func (_eff): return "Xanxus has fought on into his 4th turn.")
	mark.set_source(self)
	Character.add_allied_effect(QueryContext.from_game_state(xanxus, mbattle), xanxus, xanxus, mark)
		
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
