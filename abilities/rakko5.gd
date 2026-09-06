extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Any time an enemy is affected by a new Bleed effect, Rakko also Shatters them for the same duration."

func split_desc():
	return [
		"Whenever an enemy receives a new Bleed effect, Rakko Shatters them for the same duration",
		["Shatters mirrored from Wave Tracking enable Close-Range Rifle's free-cast condition", Color.AQUAMARINE]
	]

func execute(user, battle):
	# Passive — the Bleed→Shatter observer logic is intentionally NOT wired
	# here. It needs novel observer hooks that aren't covered by the existing
	# trigger types, and the user is implementing that separately.
	#
	# rakko2 (Close-Range Rifle) references "Wave Tracking" by ability_name
	# in its cost() override to detect Shatters originating from this passive;
	# that contract is stable so however the Bleed→Shatter trigger ends up
	# being implemented, as long as the resulting Effect.def_negate() is
	# sourced from this passive (set_source(self) inside whatever observer
	# you wire up), the rakko2 free-cast condition will read it correctly.
	pass

func extra_usable(user):
	return true

func target(user, battle):
	pass
