"""Minimal GDScript *literal-expression* reader.

WHY this exists: the replacement backend must read the game's reference tables without
running Godot, but several of those tables are GDScript source (`var x = {...}` bodies
that contain `load()` calls and `Enum.MEMBER` references). They are therefore neither
JSON nor safely `eval`-able. This module reads the subset of GDScript that those
declarations actually use — strings, numbers, bools/null, arrays, dicts, dotted
identifiers and function calls — and nothing else, so an unexpected construct raises
instead of silently producing wrong data.

Non-literal nodes are preserved structurally rather than evaluated:
    Foo.Bar.BAZ            -> Ident("Foo.Bar.BAZ")
    load("res://a/b.png")  -> Call("load", ["res://a/b.png"])
The caller decides how to render them (e.g. a `load()` becomes its path string).
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, List


class GDParseError(Exception):
    pass


@dataclass(frozen=True)
class Ident:
    """A dotted name such as `CharacterConcept.Universe.NARUTO`."""
    name: str


@dataclass(frozen=True)
class Call:
    """A function call such as `load("res://x.png")` or `CharacterConcept.create(...)`."""
    name: str
    args: tuple


_IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:\s*\.\s*[A-Za-z_][A-Za-z0-9_]*)*")
_NUM_RE = re.compile(r"-?(?:0[xX][0-9a-fA-F_]+|(?:\d[\d_]*)?\.\d[\d_]*(?:[eE][-+]?\d+)?|\d[\d_]*(?:[eE][-+]?\d+)?)")


class _Reader:
    def __init__(self, src: str, pos: int = 0):
        self.s = src
        self.i = pos

    # --- lexing helpers ---------------------------------------------------
    def _skip(self) -> None:
        """Skip whitespace, line continuations and `#` comments.

        Comments matter: several of the tables carry trailing `# note` lines *inside*
        the braces (bucket_handler's PERMANENT_EXCLUDED, server_connection's GATE_BANDS),
        so a naive scanner would choke on them.
        """
        while self.i < len(self.s):
            c = self.s[self.i]
            if c in " \t\r\n":
                self.i += 1
            elif c == "\\" and self.i + 1 < len(self.s) and self.s[self.i + 1] in "\r\n":
                self.i += 1
            elif c == "#":
                nl = self.s.find("\n", self.i)
                self.i = len(self.s) if nl < 0 else nl
            else:
                return

    def _peek(self) -> str:
        self._skip()
        return self.s[self.i] if self.i < len(self.s) else ""

    def _expect(self, ch: str) -> None:
        if self._peek() != ch:
            raise GDParseError(f"expected {ch!r} at offset {self.i}: {self.s[self.i:self.i + 60]!r}")
        self.i += 1

    # --- values -----------------------------------------------------------
    def value(self) -> Any:
        c = self._peek()
        if c == "":
            raise GDParseError("unexpected end of input")
        if c in "\"'":
            return self._string()
        if c == "[":
            return self._array()
        if c == "{":
            return self._dict()
        if c == "-" or c.isdigit() or (c == "." and self.i + 1 < len(self.s) and self.s[self.i + 1].isdigit()):
            return self._number()
        m = _IDENT_RE.match(self.s, self.i)
        if not m:
            raise GDParseError(f"unparseable value at offset {self.i}: {self.s[self.i:self.i + 60]!r}")
        name = re.sub(r"\s+", "", m.group(0))
        self.i = m.end()
        if name == "true":
            return True
        if name == "false":
            return False
        if name in ("null", "None"):
            return None
        if self._peek() == "(":
            self.i += 1
            args: List[Any] = []
            if self._peek() != ")":
                while True:
                    args.append(self.value())
                    if self._peek() == ",":
                        self.i += 1
                        if self._peek() == ")":
                            break
                        continue
                    break
            self._expect(")")
            return Call(name, tuple(args))
        return Ident(name)

    def _string(self) -> str:
        quote = self.s[self.i]
        # GDScript triple-quoted strings do not appear in the tables we read; reject
        # rather than mis-parse them into a truncated value.
        if self.s.startswith(quote * 3, self.i):
            raise GDParseError(f"triple-quoted string at offset {self.i} is not supported")
        self.i += 1
        out: List[str] = []
        escapes = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "0": "\0", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}
        while True:
            if self.i >= len(self.s):
                raise GDParseError("unterminated string")
            c = self.s[self.i]
            if c == "\\":
                nxt = self.s[self.i + 1]
                if nxt == "u":
                    out.append(chr(int(self.s[self.i + 2:self.i + 6], 16)))
                    self.i += 6
                    continue
                out.append(escapes.get(nxt, nxt))
                self.i += 2
                continue
            if c == quote:
                self.i += 1
                return "".join(out)
            out.append(c)
            self.i += 1

    def _number(self):
        m = _NUM_RE.match(self.s, self.i)
        if not m:
            raise GDParseError(f"bad number at offset {self.i}")
        self.i = m.end()
        raw = m.group(0).replace("_", "")
        if raw.lower().startswith(("0x", "-0x")):
            return int(raw, 16)
        if "." in raw or "e" in raw.lower():
            return float(raw)
        return int(raw)

    def _array(self) -> list:
        self._expect("[")
        out: list = []
        if self._peek() == "]":
            self.i += 1
            return out
        while True:
            out.append(self.value())
            if self._peek() == ",":
                self.i += 1
                if self._peek() == "]":
                    break
                continue
            break
        self._expect("]")
        return out

    def _dict(self) -> list:
        """Returns a list of (key, value) pairs — order is preserved because Godot
        Dictionaries are insertion-ordered and several consumers iterate them."""
        self._expect("{")
        out: list = []
        if self._peek() == "}":
            self.i += 1
            return out
        while True:
            key = self.value()
            self._expect(":")
            out.append((key, self.value()))
            if self._peek() == ",":
                self.i += 1
                if self._peek() == "}":
                    break
                continue
            break
        self._expect("}")
        return out


def parse_value(src: str, pos: int = 0):
    """Parse one literal expression starting at `pos`; returns (value, end_offset)."""
    r = _Reader(src, pos)
    v = r.value()
    return v, r.i


def _decl_offset(src: str, name: str, top_level: bool = True) -> int:
    """Offset just past the `=` of a `var name = ` / `const name := ` declaration.

    `top_level` anchors the match at column 0, which is what separates a class member
    from a same-named local. bounty.gd has both: the member table `var archetypes = [...]`
    at column 0 and an indented `var archetypes = []` accumulator inside two funcs.
    """
    indent = r"" if top_level else r"[ \t]*"
    pat = re.compile(r"^" + indent + r"(?:@export\s+)?(?:var|const)\s+" + re.escape(name) +
                     r"\s*(?::\s*[A-Za-z_][\w.\[\]]*\s*)?:?=\s*", re.M)
    m = pat.search(src)
    if not m:
        raise GDParseError(f"no declaration of {name!r} found")
    if pat.search(src, m.end()):
        raise GDParseError(f"{name!r} is declared more than once — ambiguous")
    return m.end()


def read_decl(src: str, name: str, top_level: bool = True):
    """Read the literal assigned by the single `var`/`const` declaration of `name`."""
    return parse_value(src, _decl_offset(src, name, top_level))[0]


def read_local_decl(src: str, func_name: str, name: str):
    """Read an indented `var name = <literal>` inside `func func_name(...)`.

    Needed for bounty.flat_bounty_categories, whose category table is a function-local
    duplicate of the class-level one.
    """
    m = re.search(r"^[ \t]*(?:static\s+)?func\s+" + re.escape(func_name) + r"\s*\(", src, re.M)
    if not m:
        raise GDParseError(f"no func {func_name!r} found")
    pat = re.compile(r"^[ \t]+var\s+" + re.escape(name) + r"\s*(?::\s*[A-Za-z_][\w.\[\]]*\s*)?:?=\s*", re.M)
    d = pat.search(src, m.end())
    if not d:
        raise GDParseError(f"no local {name!r} in {func_name!r}")
    return parse_value(src, d.end())[0]


def read_return_literal(src: str, func_name: str):
    """Read the literal in the FIRST `return <literal>` of `func func_name(...)`.

    Used for the character_database tables, which are `static func`s whose whole body
    is one `return [...]`.
    """
    m = re.search(r"^[ \t]*(?:static\s+)?func\s+" + re.escape(func_name) + r"\s*\(", src, re.M)
    if not m:
        raise GDParseError(f"no func {func_name!r} found")
    ret = re.compile(r"^[ \t]*return\s+", re.M).search(src, m.end())
    if not ret:
        raise GDParseError(f"func {func_name!r} has no `return <literal>`")
    return parse_value(src, ret.end())[0]


def pairs_to_dict(pairs) -> dict:
    """(key, value) pairs -> dict, rejecting duplicate keys instead of silently
    keeping the last one (a duplicate key in a source table is a real defect)."""
    out = {}
    for k, v in pairs:
        if k in out:
            raise GDParseError(f"duplicate key {k!r}")
        out[k] = v
    return out
