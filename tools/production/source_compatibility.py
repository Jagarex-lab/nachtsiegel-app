"""Exact, reversible compatibility proof for the approved human draw controller.

This never rewrites executed-source hashes or permits arbitrary model changes.
The original offline model remains the comparison anchor.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

MODEL = "scripts/alpha/model.gd"
BEFORE_SHA256 = "fd1c2937f74bf587a4bcdf7a82e0da5990ad8dfadb7bf812b4ad0728b9fa6bd2"
AFTER_SHA256 = "9e41cab7589c3a05ab1ede8375075018672142c9afdd90873a72efaaf0c5d089"
HOOK = (b'# Explicit controller seam: offline enemy draw behavior is the default.\n'
        b'func _automatic_draw_side(side: String) -> bool:return side=="enemy"\n')
OLD_BRANCH = b'\tif side=="enemy":\n\t\twhile p.hand.size()+mini(int(p.pendingDraw),p.deck.size())>6:'
NEW_BRANCH = b'\tif _automatic_draw_side(side):\n\t\twhile p.hand.size()+mini(int(p.pendingDraw),p.deck.size())>6:'
HOOK_ANCHOR = b'func _init() -> void:catalog=AlphaCatalog.new()\n'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalize_draw_controller(data: bytes) -> bytes:
    """Accept only the two exact reviewed sources, then reverse the exact seam."""
    actual = sha(data)
    if actual == BEFORE_SHA256:
        return data
    if actual != AFTER_SHA256:
        raise ValueError("Unapproved draw-controller model source: " + actual)
    if data.count(HOOK) != 1 or data.count(NEW_BRANCH) != 1 or data.count(HOOK_ANCHOR) != 1:
        raise ValueError("Approved model hash does not contain the exact controller seam")
    normalized = data.replace(HOOK, b"", 1).replace(NEW_BRANCH, OLD_BRANCH, 1)
    if sha(normalized) != BEFORE_SHA256:
        raise ValueError("Controller seam does not restore the original model anchor")
    # Prove both directions, including placement, rather than deleting a name
    # or ignoring all lines around a hook.
    reconstructed = normalized.replace(HOOK_ANCHOR, HOOK + HOOK_ANCHOR, 1).replace(OLD_BRANCH, NEW_BRANCH, 1)
    if reconstructed != data:
        raise ValueError("Controller seam is not the exact reversible approved edit")
    return normalized


def inspect_draw_controller(data: bytes) -> dict:
    normalized = normalize_draw_controller(data)
    actual = sha(data)
    return {"compatibility": "approved-human-draw-opt-out" if actual == AFTER_SHA256 else "unchanged-default-source",
            "anchor_sha256": BEFORE_SHA256, "executed_sha256": actual,
            "normalized_sha256": sha(normalized), "default_predicate": 'side=="enemy"',
            "compatibility_guard_sha256": sha(Path(__file__).read_bytes())}


def compare_frozen_source(path: str, current: bytes, anchor: bytes) -> dict | None:
    """All other paths and all other deltas must remain byte-identical."""
    if current == anchor:
        return None
    if path != MODEL or sha(anchor) != BEFORE_SHA256 or sha(current) != AFTER_SHA256:
        raise ValueError("Modified frozen source outside approved controller seam: " + path)
    proof = inspect_draw_controller(current)
    if normalize_draw_controller(current) != anchor:
        raise ValueError("Controller normalization differs from original frozen bytes")
    return proof


def verify_executed_draw_controller(source_hashes: dict, current: bytes) -> dict:
    proof = inspect_draw_controller(current)
    if source_hashes.get(MODEL) != proof["executed_sha256"]:
        raise ValueError("Executed model source differs from checkout; fresh evidence is required")
    return proof
