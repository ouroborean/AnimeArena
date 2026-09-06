"""Adversarial-review driver: run the SAME non-Godot generator against the
adversarial_fixture.json captured by training/tests/bounty_adversarial_probe.gd.

These are input shapes the original fixtures never covered (200/1000-char usernames,
control characters, NBSP, NFC-vs-NFD, ZWJ emoji, U+10FFFF, and reroll tokens
4/10/17/99/100/1000/999999/-1/-42, plus the whole roster at rerolls=7 + mastery).

  python compare_adversarial.py
"""

import sys

from compare import check_generation

if __name__ == "__main__":
    fails = check_generation("adversarial_fixture.json", "adversarial")
    print("\nADVERSARIAL FAILURES: %d" % fails)
    sys.exit(1 if fails else 0)
