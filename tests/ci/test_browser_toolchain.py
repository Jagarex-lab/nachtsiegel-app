"""Prevent real-browser suites silently drifting onto different engines.

The audio product probe exercises WebAudio, storage reloads and WebKit just as
other browser suites exercise the same exported Godot product. Keep their exact
Playwright installation pins aligned; no probe or browser duty is optional.
"""
from pathlib import Path
import re
import shlex
import unittest


class BrowserToolchain(unittest.TestCase):
    def test_product_browser_workflows_share_one_exact_playwright_pin(self):
        root = Path(__file__).resolve().parents[2]
        installs = []
        for workflow in sorted((root / '.github' / 'workflows').glob('*.yml')):
            for number, line in enumerate(workflow.read_text().splitlines(), 1):
                if not re.match(r'^\s*npm\s+install\b', line):
                    continue
                tokens = shlex.split(line, comments=True)
                packages = [token for token in tokens
                            if token == 'playwright' or token.startswith('playwright@')]
                if not packages:
                    continue
                location = f'{workflow.name}:{number}'
                self.assertEqual(len(packages), 1, location)
                pin = packages[0].removeprefix('playwright@')
                self.assertRegex(pin, r'^\d+\.\d+\.\d+$',
                                 f'{location} must pin an exact Playwright version')
                installs.append((workflow.name, number, pin))
        required = {
            'web-preview.yml', 'alpha-qa.yml', 'alpha03-integration-qa.yml',
            'audio-qa.yml', 'campaign-orafold-qa.yml', 'economy-qa.yml',
            'pages-release.yml',
        }
        self.assertTrue(required <= {name for name, _, _ in installs},
                        'All existing real-browser workflow entrypoints must remain covered')
        versions = {pin for _, _, pin in installs}
        self.assertEqual(len(versions), 1,
                         'Real-browser toolchain drift: ' + ', '.join(
                             f'{name}:{number}={pin}' for name, number, pin in installs))


if __name__ == '__main__':
    unittest.main()
