"""Check public commit email identities and common sensitive file/token patterns."""
import re
import subprocess
import sys
from pathlib import PurePosixPath


def git(*args):
    return subprocess.check_output(['git', *args])


def private_email(value):
    return not (value.endswith('@users.noreply.github.com') or value == 'noreply@github.com')


def main():
    ref = sys.argv[1] if len(sys.argv) > 1 else 'HEAD'
    findings = []
    for row in git('log', ref, '--format=%H%x09%ae%x09%ce').decode().splitlines():
        sha, author, committer = row.split('\t')
        if private_email(author) or private_email(committer):
            findings.append('Non-private commit identity: ' + sha[:10])
    tokens = re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)')
    emails = re.compile(rb'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
    for path in git('ls-tree', '-r', '--name-only', '-z', ref).decode().split('\0'):
        if not path:
            continue
        name = PurePosixPath(path).name.lower()
        if name in {'auth.json', 'credentials.json', 'settings.json', '.env'} or '.codex' in PurePosixPath(path).parts or name.endswith(('.pem', '.key', '.pfx', '.p12')) or (name.startswith('.env.') and name != '.env.example'):
            findings.append('Sensitive file name: ' + path)
        data = git('show', ref + ':' + path)
        if tokens.search(data):
            findings.append('Possible credential: ' + path)
        if b'\0' not in data:
            if any(private_email(value.decode()) for value in emails.findall(data)):
                findings.append('Personal email in text: ' + path)
    if findings:
        # Report locations, never the matching secret or email address.
        print('\n'.join(findings), file=sys.stderr)
        return 1
    print('Privacy checks passed: commit email identities and tracked files')
    return 0


if __name__ == '__main__':
    sys.exit(main())
