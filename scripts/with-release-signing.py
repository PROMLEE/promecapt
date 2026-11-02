#!/usr/bin/env python3
"""Run packaging with an isolated keychain; never print signing credentials."""
import base64
import os
from pathlib import Path
import secrets
import shlex
import subprocess
import tempfile


def run(*args):
    result = subprocess.run(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode:
        raise SystemExit(f"Signing setup failed: {args[0]} {args[1]} (exit {result.returncode})")
    return result


def main():
    encoded = os.environ.pop('MACOS_SIGNING_P12', '')
    password = os.environ.pop('MACOS_SIGNING_PASSWORD', '')
    if not encoded or not password:
        raise SystemExit('Missing persistent code-signing secrets; refusing unsigned release')
    original = shlex.split(subprocess.check_output(['security', 'list-keychains', '-d', 'user'], text=True))
    with tempfile.TemporaryDirectory(prefix='promecapt-signing-') as directory:
        root = Path(directory)
        p12 = root / 'identity.p12'
        p12.write_bytes(base64.b64decode("".join(encoded.split()), validate=True))
        p12.chmod(0o600)
        keychain = str(root / 'release.keychain-db')
        key_password = secrets.token_urlsafe(48)
        try:
            run('security', 'create-keychain', '-p', key_password, keychain)
            run('security', 'set-keychain-settings', '-lut', '21600', keychain)
            run('security', 'unlock-keychain', '-p', key_password, keychain)
            run('security', 'import', str(p12), '-k', keychain, '-P', password, '-T', '/usr/bin/codesign')
            run('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', key_password, keychain)
            run('security', 'list-keychains', '-d', 'user', '-s', *original, keychain)
            env = dict(os.environ, SIGNING_MODE='self-signed', SIGNING_KEYCHAIN=keychain,
                       SIGNING_IDENTITY=Path('updates/code-signing-sha1.txt').read_text().strip())
            subprocess.run(['bash', 'scripts/package.sh'], env=env, check=True)
        finally:
            run('security', 'list-keychains', '-d', 'user', '-s', *original)
            subprocess.run(['security', 'delete-keychain', keychain], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == '__main__':
    main()
