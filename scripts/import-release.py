"""Import only the five approved assets from short-lived download links."""
import hashlib
import json
import re
import sys
import urllib.parse
import urllib.request
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
        name, url = item['name'], item['url']
        approved = required[name]
        if Path(name).name != name:
            raise ValueError('Invalid asset name')
        def allowed(value):
            parsed = urllib.parse.urlsplit(value)
            return parsed.scheme == 'https' and parsed.hostname in {'release-assets.githubusercontent.com', 'objects.githubusercontent.com'} and not parsed.username and not parsed.password
        if not allowed(url):
            raise ValueError('Download must use GitHub release asset storage')
        digest, total = hashlib.sha256(), 0
        with urllib.request.urlopen(url, timeout=120) as response, (destination / name).open('wb') as output:
            if not allowed(response.geturl()):
                raise ValueError('Unexpected download redirect')
            while chunk := response.read(1024 * 1024):
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
        # Keep short-lived download URLs out of public error logs.
        print('Release import failed: ' + type(error).__name__, file=sys.stderr)
        sys.exit(1)
