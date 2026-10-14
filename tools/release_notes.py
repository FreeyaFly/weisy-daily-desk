"""Print the CHANGELOG.md section of one version (used as the GitHub release notes).

    python tools/release_notes.py v0.2.0 [OUTPUT_FILE]

With OUTPUT_FILE the notes are written there as UTF-8 (no shell redirection, which may change the encoding).
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def notes(version):
    text = (ROOT / 'CHANGELOG.md').read_text(encoding='utf-8')
    m = re.search(rf'^## {re.escape(version)} \(.*?\)\n(.*?)(?=^## |\Z)', text, flags=re.M | re.S)
    if not m:
        sys.exit(f'CHANGELOG.md has no section "## {version} (...)"')
    return m.group(1).strip() + '\n'


if __name__ == '__main__':
    text = notes(sys.argv[1])
    if len(sys.argv) > 2:
        out = Path(sys.argv[2])
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text, encoding='utf-8')
    else:
        sys.stdout.reconfigure(encoding='utf-8')
        print(text, end='')
