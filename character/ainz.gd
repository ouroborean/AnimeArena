extends Character

# The Goal of all Life is Death gains at most ONE stack (counter + cost-mod) per turn; this stamps the
# last turn a stack was taken so extra negations that turn still negate but don't re-stack.
var _goal_last_turn := -1


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_colors = [1, 3]
	character_name = "Ainz Ooal Gown"
	path_name = "ainz"
	universe = CharacterConcept.Universe.OVERLORD
	description = "Ainz Ooal Gown, the undead Sorcerer King and supreme ruler of the Great Tomb of Nazarick. Once the human Momonga, he now commands death itself — turning aside the curses and bindings hurled at him and answering with super-tier magic."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "ainz_unlock" in player.unlocks

func _process(delta):
	pass

# The Goal of all Life is Death (passive). A harmful NON-DAMAGE effect that would land on Ainz is
# negated; in exchange his skills cost +1 Random for a window matching that effect's duration, and a
# cumulative trigger counter (the "The Goal of all Life is Death" MARK, planted by ainz5) advances —
# Astral Smite and Fallen Down scale off it. Damage / DoTs are NOT negated.
func negate_harmful_effect(effect, context) -> bool:
	if dead or banished:
		return false
	if effect == null or effect.source == null:
		return false
	if effect.effect_type == EffectType.Type.DAMAGE:
		return false                                   # damage + DoTs still land
	if Character.trigger_delivers_damage(effect):
		return false                                   # a ticking trigger that delivers damage (Toga's Bleed, Baki's delayed hits) is effectively a DoT — it still lands
	# This hook only runs in add_hostile_effect — an ENEMY applying an effect to Ainz — so any non-damage
	# effect here is "negative" regardless of the source ability's Helpful/Harmful class. That also catches
	# an enemy setup tagged Helpful, e.g. Madoka's Karmic Destiny trigger (grants its target Nullify on
	# their next action): negating the trigger stops the Nullify at its source.
	var counter = has_effect("The Goal of all Life is Death", EffectType.Type.MARK, self)
	if counter == null:
		return false                                   # passive not installed (shouldn't happen mid-battle)
	# The effect is ALWAYS negated. A stack (trigger counter + cost bump) is gained at most ONCE per
	# turn, however many effects are negated that turn.
	var turn = int(battle.current_turn_number)
	if _goal_last_turn != turn:
		_goal_last_turn = turn
		var ctx = QueryContext.from_game_state(self, battle)
		# +1 Random to ALL of Ainz's skills for 3 turns (fixed — NOT the negated effect's duration).
		# Each stack is its own cost-mod with a unique (current-time) render id, so the separate 3-turn
		# timers are individually trackable. "extra energy" = sum(cost) - sum(base).
		var cost_up = Effect.cost_mod_effect(1, 6, Energy.Type.RANDOM)   # "3 turns" = 2N = 6
		cost_up.set_source(moveset.base_abilities[4])  # source = The Goal, so effect_name resolves right
		cost_up.unique_render_id = int(Time.get_ticks_msec())
		Character.add_allied_effect(ctx, self, self, cost_up)
		counter.stacks += 1                            # permanent stacking trigger count (max +1 per turn)
	return true
