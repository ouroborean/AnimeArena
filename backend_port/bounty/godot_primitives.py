"""Non-Godot reimplementation of the two engine primitives bounty generation rests on.

Both are reproduced from first principles, then diffed against a fixture captured from the real
engine (backend_port/bounty/primitives_fixture.json, produced by
training/tests/bounty_hash_rng_probe.gd). Nothing here imports Godot.

  1. godot_hash(s)  == GDScript global hash(String) == String.hash()
  2. GodotRNG      == RandomNumberGenerator with `.seed = X`, then randi()/randi_range()

WHY these two and nothing else: scripts/bounty.gd:229 seeds an RNG with hash(player+path+rerolls)
and every one of the ~25 board squares is chosen with randi_range. Get either wrong by one bit and
every in-flight bingo card silently changes at cutover.
"""

MASK64 = (1 << 64) - 1
MASK32 = (1 << 32) - 1

# ---------------------------------------------------------------------------------------------
# 1. Godot's String::hash  (core/string/ustring.h)
#       uint32_t hashv = 5381;
#       while ((c = *p_cstr++)) hashv = ((hashv << 5) + hashv) + c;
#    ...iterating char32_t, i.e. UNICODE CODE POINTS, not UTF-8 bytes and not UTF-16 units.
#    That distinction is the whole ballgame for a JS/TS port: JS strings iterate UTF-16 units by
#    default, so an astral character (emoji) would hash as two surrogates instead of one code
#    point. Iterate with [...str] / codePointAt, never charCodeAt.
# ---------------------------------------------------------------------------------------------


def godot_hash(s: str) -> int:
    """GDScript `hash(some_string)`. Returns the unsigned 32-bit value Godot returns."""
    h = 5381
    for ch in s:
        cp = ord(ch)
        h = ((h << 5) + h + cp) & MASK32
    return h


# ---------------------------------------------------------------------------------------------
# 2. RandomPCG (core/math/random_pcg.h) wrapping the canonical pcg32 minimal C implementation.
# ---------------------------------------------------------------------------------------------

PCG_DEFAULT_INC_64 = 1442695040888963407  # 0x14057B7EF767814F
PCG_MULT = 6364136223846793005


class GodotRNG:
    """Mirrors Godot 4's RandomNumberGenerator for the calls bounty.gd makes."""

    def __init__(self, seed_value: int = 0):
        self.set_seed(seed_value)

    def set_seed(self, seed_value: int) -> None:
        # GDScript ints are signed 64-bit; the setter takes a uint64, so a negative seed wraps.
        s = seed_value & MASK64
        self.current_seed = s
        # canonical pcg32_srandom_r(rng, initstate=s, initseq=PCG_DEFAULT_INC_64)
        self.state = 0
        self.inc = ((PCG_DEFAULT_INC_64 << 1) | 1) & MASK64
        self._step()
        self.state = (self.state + s) & MASK64
        self._step()

    def _step(self) -> int:
        old = self.state
        self.state = (old * PCG_MULT + self.inc) & MASK64
        xorshifted = (((old >> 18) ^ old) >> 27) & MASK32
        rot = (old >> 59) & 31
        return ((xorshifted >> rot) | (xorshifted << ((-rot) & 31))) & MASK32

    def randi(self) -> int:
        """Raw 32-bit draw (RandomPCG::rand())."""
        return self._step()

    def randi_range(self, from_: int, to: int) -> int:
        """RandomNumberGenerator::randi_range, via RandomPCG::random(int, int).

        *** THE DEGENERATE CASE DOES NOT DRAW. *** RandomPCG::random short-circuits `from == to`
        and returns immediately, so randi_range(0, 0) advances the stream ZERO times. bounty.gd
        hits that on every square for a character with exactly one archetype
        (bounty_types[randi_range(0, len-1)] with len 1) and for a universe holding exactly one
        other character. A port that always draws desynchronises from square 2 onward — verified:
        modelling it as "always draws" reproduced 72/168 fixture cards, and 0 of the cards for
        goku / lizandpatty (one archetype each).

        Reversed ranges (to < from) DO draw and behave as a plain swap — also verified against the
        engine, though bounty.gd never produces one.
        """
        if to < from_:
            from_, to = to, from_
        if from_ == to:
            return from_
        return self._step() % (to - from_ + 1) + from_
