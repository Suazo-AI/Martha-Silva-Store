'use strict';
// JavaScript mirror of prepare.py public_path/public_bytes for tests that read dist/.
// Source folders keep their provenance names; dist publishes them under build-inputs/public-paths.json.
const path = require('node:path');
const config = require('../build-inputs/public-paths.json');

const prefixes = [...config.prefixes].sort((left, right) => right[0].length - left[0].length);
const TEXT = new Set(['.html', '.js', '.css', '.json', '.txt', '.xml', '.svg', '.webmanifest']);
const escape = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const reference = new RegExp('/(' + prefixes.map(([old]) => escape(old)).join('|') + ')', 'g');
const targets = new Map(prefixes.map(([old, fresh]) => [old, '/' + fresh]));

// Source URL or relative path -> published form. Leading slash is preserved.
function publicPath(value) {
  const slash = value.startsWith('/') ? '/' : '';
  const relative = slash ? value.slice(1) : value;
  for (const [old, fresh] of prefixes) if (relative.startsWith(old)) return slash + fresh + relative.slice(old.length);
  return value;
}

// Published text bytes for a source file, as prepare.py writes them.
function publicBytes(relative, bytes) {
  if (!(TEXT.has(path.extname(relative)) || path.basename(relative) === '_headers')) return bytes;
  return Buffer.from(bytes.toString('latin1').replace(reference, (_, old) => targets.get(old)), 'latin1');
}

module.exports = {publicPath, publicBytes};
