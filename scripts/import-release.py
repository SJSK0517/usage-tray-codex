"""Restore only the five approved assets from temporary binary transfer parts."""
import hashlib
import json
import re
import sys
from pathlib import Path


def main():
    request = json.loads(Path('.release-import.json').read_text())
    tag = request['tag']
    if not re.fullmatch(r'usage-tray-v\d+\.\d+\.\d+', tag):
        raise ValueError('Invalid release tag')
    expected = json.loads(Path('release-manifests', tag + '.json').read_text())
    required = {item['name']: item for item in expected['assets']}
    supplied = request['assets']
    if len(supplied) != len(required) or {item['name'] for item in supplied} != required.keys():
        raise ValueError('Asset list does not match the approved manifest')
    destination = Path('dist')
    destination.mkdir()
    for item in supplied:
        name, parts = item['name'], item['parts']
        approved = required[name]
        if Path(name).name != name or not parts or len(parts) > 8 or len(set(parts)) != len(parts):
            raise ValueError('Invalid asset or part list')
        digest, total = hashlib.sha256(), 0
        with (destination / name).open('wb') as output:
            for part in parts:
                path = Path(part)
                if path.is_symlink() or path.parent != Path('.release-parts') or not path.is_file():
                    raise ValueError('Invalid transfer part')
                with path.open('rb') as source:
                    while chunk := source.read(1024 * 1024):
                        total += len(chunk)
                        if total > approved['size']:
                            raise ValueError('Asset exceeds approved size')
                        digest.update(chunk)
                        output.write(chunk)
        if total != approved['size'] or digest.hexdigest() != approved['sha256']:
            raise ValueError('Asset size or SHA-256 mismatch: ' + name)
        print('Verified ' + name)
    expected_sums = {f"{item['sha256']}  {item['name']}" for item in required.values() if item['name'].endswith('.exe')}
    actual_sums = (destination / 'SHA256SUMS.txt').read_text().splitlines()
    if len(actual_sums) != 2 or set(actual_sums) != expected_sums:
        raise ValueError('Installer checksum manifest does not match')
    Path('release-tag.txt').write_text(tag)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Report the failure without printing installer contents.
        print('Release import failed: ' + type(error).__name__ + ': ' + str(error), file=sys.stderr)
        sys.exit(1)
