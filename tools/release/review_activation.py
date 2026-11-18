"""Report the reviewed Alpha publisher and its archival predecessor, read-only."""
import difflib
from pathlib import Path

ACTIVE = Path(".github/workflows/pages-release.yml")
STAGED = Path(".github/release-staging/pages-one-click.yml.in")

def activation_status():
    active = ACTIVE.read_text()
    if not active.startswith("name: Automatic Alpha Pages release\n") or "  workflow_run:\n" not in active:
        raise ValueError("Unknown active publisher: review its release policy before reporting activation")
    return (
        "ACTIVE: owner-approved automatic Alpha publisher with inputless manual fallback.\n"
        "ARCHIVE: .github/release-staging/pages-one-click.yml.in is inactive historical material.\n"
        "READ ONLY: no files, deployments, merges or GitHub settings are changed."
    )


def activation_diff():
    """Compare the inactive historical proposal with the active reviewed policy."""
    activation_status()
    return "".join(difflib.unified_diff(
        STAGED.read_text().splitlines(True), ACTIVE.read_text().splitlines(True),
        fromfile=str(STAGED), tofile=str(ACTIVE),
    ))


if __name__ == "__main__":
    print(activation_status())
    print(activation_diff())
