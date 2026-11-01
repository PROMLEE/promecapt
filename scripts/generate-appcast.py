#!/usr/bin/env python3
"""Produce a signed, architecture-specific Sparkle feed from a final release ZIP."""
import argparse
import base64
from datetime import datetime, timezone
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile
import plistlib

ROOT = Path(__file__).resolve().parent.parent
NS = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', NS)
parser = argparse.ArgumentParser()
parser.add_argument('--version', required=True)
parser.add_argument('--arch', required=True, choices=['arm64', 'x86_64'])
parser.add_argument('--key-file', type=Path, required=True)
parser.add_argument('--directory', type=Path, default=ROOT / 'dist')
args = parser.parse_args()
if not re.fullmatch(r'\d+\.\d+\.\d+', args.version):
    raise SystemExit('Only stable semantic release versions are accepted')
archive = args.directory / f'Promecapt-{args.version}-macos-{args.arch}.zip'
with zipfile.ZipFile(archive) as z:
    info = plistlib.loads(z.read('Promecapt.app/Contents/Info.plist'))
if info.get('CFBundleIdentifier') != 'com.promlee.promepaste':
    raise SystemExit('Test apps cannot be published as production updates')
if info['CFBundleShortVersionString'] != args.version or info['CFBundleVersion'] != args.version:
    raise SystemExit('Archive app version must match the release version')
if info.get('SUFeedURL') != f'https://github.com/PROMLEE/promecapt/releases/latest/download/appcast-{args.arch}.xml':
    raise SystemExit('Archive update feed does not match its architecture')
if info.get('SUPublicEDKey') != (ROOT / 'updates/public-key.txt').read_text().strip():
    raise SystemExit('Archive update trust key differs from the project public key')
tool = ROOT / '.build/artifacts/sparkle/Sparkle/bin/sign_update'
key_args = ['--ed-key-file', str(args.key_file.resolve())]
signature = subprocess.check_output([str(tool), *key_args, '-p', str(archive)], text=True).strip()
if len(base64.b64decode(signature, validate=True)) != 64:
    raise SystemExit('Invalid signature output')
subprocess.run(['xcrun', 'swift', str(ROOT / 'scripts/VerifyUpdate.swift'), str(ROOT / 'updates/public-key.txt'), str(archive), signature], check=True)
subprocess.run([str(tool), *key_args, '--verify', str(archive), signature], check=True)
rss = ET.Element('rss', version='2.0')
channel = ET.SubElement(rss, 'channel')
ET.SubElement(channel, 'title').text = 'Promecapt'
item = ET.SubElement(channel, 'item')
ET.SubElement(item, 'title').text = f'Promecapt {args.version}'
ET.SubElement(item, 'link').text = f'https://github.com/PROMLEE/promecapt/releases/tag/v{args.version}'
ET.SubElement(item, 'pubDate').text = datetime.now(timezone.utc).strftime('%a, %d %b %Y %H:%M:%S %z')
ET.SubElement(item, f'{{{NS}}}version').text = args.version
ET.SubElement(item, f'{{{NS}}}shortVersionString').text = args.version
ET.SubElement(item, f'{{{NS}}}minimumSystemVersion').text = '13.0.0'
ET.SubElement(item, 'description').text = f'Promecapt {args.version}. Release notes: https://github.com/PROMLEE/promecapt/releases/tag/v{args.version}'
ET.SubElement(item, 'enclosure', {
    'url': f'https://github.com/PROMLEE/promecapt/releases/download/v{args.version}/{archive.name}',
    f'{{{NS}}}edSignature': signature, 'length': str(archive.stat().st_size), 'type': 'application/octet-stream'})
output = args.directory / f'appcast-{args.arch}.xml'
ET.indent(rss)
ET.ElementTree(rss).write(output, encoding='utf-8', xml_declaration=True)
subprocess.run([str(tool), *key_args, str(output)], check=True)
subprocess.run([str(tool), *key_args, '--verify', str(output)], check=True)
print(output)
