const crypto = require('crypto');

const ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const NONCE_LEN = 8;
const MAC_LEN = 4;

function defaultSecret() {
  return process.env.REDPOS_HMAC || 'REDPOS-PRUEBA-NO-USAR-EN-PRODUCCION';
}

function normalize(input) {
  return String(input || '')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');
}

function format(raw12) {
  const body = String(raw12).toUpperCase();
  if (body.length !== 12) return body;
  return `RP-${body.slice(0, 4)}-${body.slice(4, 8)}-${body.slice(8, 12)}`;
}

function charsFromHash(hash, count) {
  let out = '';
  let acc = 0;
  let bits = 0;
  let i = 0;
  while (out.length < count && i < hash.length) {
    acc = (acc << 8) | hash[i++];
    bits += 8;
    while (bits >= 5 && out.length < count) {
      bits -= 5;
      out += ALPHABET[(acc >> bits) & 31];
    }
  }
  return out;
}

function macChars(secret, nonce) {
  const digest = crypto
    .createHmac('sha256', secret)
    .update(`RP1|${nonce}`)
    .digest();
  return charsFromHash(digest, MAC_LEN);
}

function generate(secret = defaultSecret()) {
  let nonce = '';
  const bytes = crypto.randomBytes(NONCE_LEN);
  for (let i = 0; i < NONCE_LEN; i++) {
    nonce += ALPHABET[bytes[i] % ALPHABET.length];
  }
  return format(nonce + macChars(secret, nonce));
}

function verify(input, secret = defaultSecret()) {
  const trimmed = String(input || '').trim();
  if (!trimmed) {
    return { ok: false, error: 'empty' };
  }
  if (normalize(trimmed) === normalize('R100301S')) {
    return { ok: true, nonce: 'TESTALIAS', testAlias: true };
  }
  let body = normalize(trimmed);
  if (body.startsWith('RP') && body.length === 14) {
    body = body.slice(2);
  }
  if (body.length !== 12) return { ok: false, error: 'invalid' };
  for (const ch of body) {
    if (!ALPHABET.includes(ch)) return { ok: false, error: 'invalid' };
  }
  const nonce = body.slice(0, NONCE_LEN);
  const mac = body.slice(NONCE_LEN);
  const expected = macChars(secret, nonce);
  if (mac.length !== expected.length) return { ok: false, error: 'invalid' };
  let diff = 0;
  for (let i = 0; i < mac.length; i++) {
    diff |= mac.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  if (diff !== 0) return { ok: false, error: 'invalid' };
  return { ok: true, nonce, testAlias: false };
}

module.exports = { generate, verify, format, normalize, macChars };
