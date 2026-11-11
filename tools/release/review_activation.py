"""Print a reviewable activation diff. Intentionally has no write/apply mode."""
import difflib
import hashlib
from pathlib import Path

ACTIVE = Path(".github/workflows/pages-release.yml")
STAGED = Path(".github/release-staging/pages-one-click.yml.in")
EXPECTED_ACTIVE_SHA256 = "cac935fa33f36c39d31acaf7133595bf94954886e3f8312d0b7e84f18bb0a2dd"


def activation_diff():
    before = ACTIVE.read_bytes()
    if hashlib.sha256(before).hexdigest() != EXPECTED_ACTIVE_SHA256:
        raise ValueError("Active publisher changed: review its new safety policy before preparing activation")
    after = STAGED.read_text()
    return "".join(difflib.unified_diff(before.decode().splitlines(True), after.splitlines(True), fromfile=str(ACTIVE), tofile=str(ACTIVE)))


if __name__ == "__main__":
    print("REVIEW ONLY: inactive proposal. Explicit user approval and a separately tested PR are required. No file is changed.")
    print(activation_diff())
