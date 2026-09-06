extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Whenever one of Madoka's Shield or Nullify effects is fully absorbed, this effect gains one stack. If Madoka reaches 15 stacks of this effect, she is instantly killed."

func split_desc():
	return [
		["Gains 1 stack each turn, and 1 whenever one of Madoka's Shield or Nullify effects is fully absorbed", Color.CADET_BLUE],
		["At 12 stacks, Madoka is instantly killed", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	seed_gem(user)
	# The per-turn stack. A TICKING_TRIGGER fires once per ROUND, on its user's own side's turn
	# (get_ticking_effects filters on the ACTING team), so it needs no side-gate and no doubled
	# duration. system + remove_on_death = false is what makes the passive itself outlive a death:
	# the owner's ruling is that a revive clears the Soul Gem MARK but leaves the ticking and the
	# tracking running. display_system puts the ticker back on the wire — when Madoka's next stack
	# lands is information both players are entitled to, and the tick panel lists it like any other.
	var ticking = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Madoka will gain 1 stack of Soul Gem: Madoka.")
	ticking.set_source(self)
	ticking.system = true
	ticking.display_system = true
	ticking.remove_on_death = false
	Character.add_allied_effect(context, user, user, ticking)

# The gem MARK is death-cleansed by design, so it has to be re-plantable: after a revive the ticker
# is still running and would otherwise tick forever against a gem that no longer exists.
func seed_gem(user):
	if user.has_effect("Soul Gem: Madoka", EffectType.Type.MARK):
		return
	var passive_mark = Effect.mark(-1, "Whenever one of Madoka's Shield or Nullify effects is fully broken, and once each turn, this effect gains one stack. If Madoka reaches 12 stacks of this effect, she is instantly killed.")
	passive_mark.set_source(self)
	passive_mark.mag = 0
	passive_mark.display_mag = true
	passive_mark.cleansable = false
	Character.add_allied_effect(QueryContext.from_game_state(user, user.battle), user, user, passive_mark)

func tick_trigger(context):
	var madoka = context['effect'].user
	seed_gem(madoka)
	madoka.gain_corruption()
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	pass
