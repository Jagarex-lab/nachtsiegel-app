"""Check packaged story data and the explicitly selected production contract."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
story = json.loads((root / "data/campaign_orafold/prototype.json").read_text())
catalog = json.loads((root / "data/production/cards.json").read_text())
assert len(story["chapters"]) == 2 and len(story["scenes"]) == 13
assert story["editorial"]["prototype"] and not story["editorial"]["new_lore_approved"]
assert not story["editorial"]["eira_revelations_authored"]
assert len(catalog["cards"]) == 550
for encounter in story["encounters"].values():
    assert encounter["rules_profile"] == "production-550-v1"
    assert encounter["starting_situation"] == "engine_default"
    for field in ("deck_profile", "enemy_profile"):
        assert len(catalog["starters"][encounter[field]]) == 30
for chapter in (1, 2):
    reward = story["rewards"][f"production_chapter_{chapter}"]
    assert reward["type"] == "external" and reward["target"] == "alpha550_economy"
    assert reward["payload"] == {"reward_id": "campaign_chapter", "chapter": chapter}
for ending in ("ending_record", "ending_open"):
    assert {"type": "reward", "id": "production_chapter_2"} in story["scenes"][ending]["on_complete"]
for locale in ("de", "en"):
    text = json.loads((root / f"data/campaign_orafold/locales/{locale}.json").read_text())
    assert "PROTOTYPE" in text["ui.prototype"].upper() or "PROTOTYP" in text["ui.prototype"].upper()
    for key in ("ui.main_menu", "ui.reward_pending", "ui.reward_retry", "ui.recovery_notice"):
        assert text[key]
print("CAMPAIGN PRODUCTION DATA: two chapters, thirteen scenes, 550-card profile, two idempotent chapter grants; OK")
