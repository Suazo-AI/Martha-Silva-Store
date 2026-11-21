"""Read image headers, then record truthful intrinsic dimensions in storefront HTML.

This does not decode, resample, crop, replace or generate photographic media.
Run before prepare.py when original images or captured HTML are changed.
"""
from html import unescape
from pathlib import Path
import json
import re
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
STATIC = ROOT / 'build-inputs/static'


def dimensions(path):
    with path.open('rb') as stream:
        header = stream.read(32)
        if header[:8] == b'\x89PNG\r\n\x1a\n':
            return struct.unpack('>II', header[16:24])
        if header[:2] == b'\xff\xd8':
            stream.seek(2)
            while True:
                marker = stream.read(1)
                if not marker:
                    break
                if marker != b'\xff':
                    continue
                while marker == b'\xff':
                    marker = stream.read(1)
                code = marker[0]
                if code in (0x01, *range(0xD0, 0xD9)):
                    continue
                length_bytes = stream.read(2)
                if len(length_bytes) != 2:
                    break
                length = struct.unpack('>H', length_bytes)[0]
                if code in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                            0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                    _, height, width = struct.unpack('>BHH', stream.read(5))
                    return width, height
                stream.seek(length - 2, 1)
        if header[:4] == b'RIFF' and header[8:12] == b'WEBP':
            stream.seek(12)
            while True:
                chunk = stream.read(8)
                if len(chunk) != 8:
                    break
                kind, length = chunk[:4], struct.unpack('<I', chunk[4:])[0]
                payload = stream.read(min(length, 16))
                if kind == b'VP8X':
                    return (int.from_bytes(payload[4:7], 'little') + 1,
                            int.from_bytes(payload[7:10], 'little') + 1)
                if kind == b'VP8 ' and payload[3:6] == b'\x9d\x01\x2a':
                    width, height = struct.unpack('<HH', payload[6:10])
                    return width & 0x3FFF, height & 0x3FFF
                if kind == b'VP8L' and payload[0] == 0x2F:
                    bits = int.from_bytes(payload[1:5], 'little')
                    return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
                stream.seek(length - len(payload) + length % 2, 1)
    if path.suffix.lower() == '.svg':
        element = ET.parse(path).getroot()
        if element.get('viewBox'):
            _, _, width, height = map(float, element.get('viewBox').split())
            return round(width), round(height)
        return tuple(int(re.match(r'\d+', element.get(k, '')).group())
                     for k in ('width', 'height'))
    raise ValueError('Cannot read image dimensions: ' + str(path))


def attribute(tag, key):
    match = re.search(r'\b' + re.escape(key) + r'="([^"]*)"', tag)
    return unescape(match[1]) if match else None


def set_attribute(tag, key, value):
    pattern = r'\b' + re.escape(key) + r'="[^"]*"'
    replacement = key + '="' + str(value) + '"'
    if re.search(pattern, tag):
        return re.sub(pattern, lambda _: replacement, tag, count=1)
    ending = '/>' if tag.endswith('/>') else '>'
    return tag[:-len(ending)].rstrip() + ' ' + replacement + ending


def annotate():
    paths = sorted(path for path in STATIC.rglob('*')
                   if path.is_file() and path.suffix.lower() in ('.jpg', '.jpeg', '.png', '.webp', '.svg'))
    inventory = {'/' + path.relative_to(STATIC).as_posix(): list(dimensions(path))
                 for path in paths}
    counts = {'html_files': 0, 'image_elements': 0, 'source_elements': 0,
              'responsive_width_descriptors_corrected': 0}

    def correct(tag):
        src = attribute(tag, 'src')
        srcset = attribute(tag, 'srcset')
        if srcset:
            candidates = []
            for candidate in srcset.split(','):
                parts = candidate.split()
                if not parts:
                    continue
                path = parts[0]
                if path in inventory and len(parts) == 2 and parts[1].endswith('w'):
                    descriptor = str(inventory[path][0]) + 'w'
                    counts['responsive_width_descriptors_corrected'] += descriptor != parts[1]
                    parts[1] = descriptor
                candidates.append(' '.join(parts))
            tag = set_attribute(tag, 'srcset', ', '.join(candidates))
            if not src and candidates:
                src = candidates[-1].split()[0]
        if src in inventory:
            width, height = inventory[src]
            tag = set_attribute(set_attribute(tag, 'width', width), 'height', height)
            counts['image_elements' if tag.startswith('<img') else 'source_elements'] += 1
        return tag

    for path in sorted(STATIC.glob('*.html')):
        # Read on each write so concurrent, unrelated language insertions survive.
        original = path.read_text(encoding='utf-8')
        result = re.sub(r'<(?:img|source)\b[^>]*>', lambda match: correct(match[0]), original)
        if result != original:
            path.write_text(result, encoding='utf-8', newline='')
        counts['html_files'] += 1

    catalog_path = STATIC / 'catalog.js'
    catalog = catalog_path.read_text(encoding='utf-8')
    catalog = re.sub(r'\n?window\.STORE_IMAGE_DIMENSIONS=.*?;\s*$', '', catalog, flags=re.S)
    catalog_path.write_text(catalog.rstrip() + '\nwindow.STORE_IMAGE_DIMENSIONS=' +
                            json.dumps(inventory, separators=(',', ':')) + ';\n',
                            encoding='utf-8', newline='')
    evidence = ROOT / 'evidence/bridal-bilingual'
    evidence.mkdir(parents=True, exist_ok=True)
    report = {'inspection': 'Headers only; no decoding or new visual QA claimed',
              'media_bytes_changed': False, 'image_files': len(inventory),
              **counts, 'dimensions': inventory}
    (evidence / 'image-dimensions.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in report.items() if key != 'dimensions'}))


if __name__ == '__main__':
    annotate()
