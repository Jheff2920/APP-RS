const fs = require('fs');
const path = require('path');
const { readPrice } = require('./price');

const INDEX_KEY = 'codes:index';
const GLOBAL_PRICE_KEY = 'settings:globalPrice';

function dataFile() {
  return (
    process.env.REDPOS_ADMIN_DATA ||
    path.join(__dirname, '..', 'data', 'codes.json')
  );
}

function kvUrl() {
  return process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL || '';
}

function kvToken() {
  return process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN || '';
}

function hasKv() {
  return Boolean(kvUrl() && kvToken());
}

function loadFile() {
  try {
    return JSON.parse(fs.readFileSync(dataFile(), 'utf8'));
  } catch {
    return { codes: [] };
  }
}

function saveFile(data) {
  fs.mkdirSync(path.dirname(dataFile()), { recursive: true });
  fs.writeFileSync(dataFile(), JSON.stringify(data, null, 2));
}

async function kv(command) {
  if (!command.length) return [];
  const url = kvUrl().replace(/\/$/, '');
  const res = await fetch(`${url}/pipeline`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${kvToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(command),
  });
  if (!res.ok) {
    throw new Error(`KV ${res.status}`);
  }
  return res.json();
}

function hashToRow(nonce, raw) {
  const o = {};
  if (raw && !Array.isArray(raw) && typeof raw === 'object') {
    Object.assign(o, raw);
  } else if (Array.isArray(raw)) {
    for (let i = 0; i < raw.length - 1; i += 2) {
      o[String(raw[i])] = raw[i + 1];
    }
  }
  const used = o.used === '1' || o.used === 1 || o.used === true;
  return {
    code: o.code || '',
    nonce,
    used,
    price: readPrice(o.price),
    createdAt: o.createdAt || null,
    usedAt: o.usedAt || null,
  };
}

function sortRows(rows) {
  return rows.sort((a, b) => {
    const ta = a.createdAt || a.usedAt || '';
    const tb = b.createdAt || b.usedAt || '';
    return tb.localeCompare(ta);
  });
}

async function scanKeys(match) {
  const keys = [];
  let cursor = '0';
  try {
    for (let i = 0; i < 30; i++) {
      const [res] = await kv([['SCAN', cursor, 'MATCH', match, 'COUNT', '200']]);
      const payload = res && res.result;
      if (!Array.isArray(payload) || payload.length < 2) break;
      cursor = String(payload[0]);
      const batch = payload[1] || [];
      if (Array.isArray(batch)) keys.push(...batch);
      if (cursor === '0') break;
    }
  } catch {
    return keys;
  }
  return keys;
}

async function listFromKv() {
  const nonces = new Set();
  try {
    const [members] = await kv([['SMEMBERS', INDEX_KEY]]);
    const listed = (members && members.result) || [];
    if (Array.isArray(listed)) {
      for (const n of listed) {
        if (n) nonces.add(String(n));
      }
    }
  } catch {
    // El indice puede no existir todavia.
  }

  const scanned = await scanKeys('code:*');
  for (const key of scanned) {
    const nonce = String(key).replace(/^code:/, '');
    if (nonce) nonces.add(nonce);
  }

  if (!nonces.size) return [];

  const nonceList = [...nonces];
  try {
    await kv([['SADD', INDEX_KEY, ...nonceList]]);
  } catch {
    // El listado igual sirve sin reindexar.
  }

  const rows = [];
  const chunk = 40;
  for (let i = 0; i < nonceList.length; i += chunk) {
    const part = nonceList.slice(i, i + chunk);
    const replies = await kv(part.map((n) => ['HGETALL', `code:${n}`]));
    part.forEach((n, idx) => {
      const raw = replies[idx] && replies[idx].result;
      const row = hashToRow(n, raw);
      if (row.code || row.used || row.createdAt || row.usedAt) {
        rows.push(row);
      }
    });
  }
  return sortRows(rows);
}

async function recordGenerated(code, nonce) {
  const row = {
    code,
    nonce,
    used: false,
    price: null,
    createdAt: new Date().toISOString(),
  };
  if (hasKv()) {
    await kv([
      [
        'HSET',
        `code:${nonce}`,
        'code',
        code,
        'used',
        '0',
        'createdAt',
        row.createdAt,
      ],
      ['SADD', INDEX_KEY, nonce],
    ]);
    return;
  }
  if (process.env.VERCEL) {
    return;
  }
  const data = loadFile();
  data.codes.push(row);
  saveFile(data);
}

async function rowByNonce(nonce) {
  if (hasKv()) {
    const [reply] = await kv([['HGETALL', `code:${nonce}`]]);
    return hashToRow(nonce, reply && reply.result);
  }
  const data = loadFile();
  const found = (data.codes || []).find((row) => row.nonce === nonce);
  if (!found) return { code: '', nonce, used: false, price: null, createdAt: null, usedAt: null };
  return {
    code: found.code || '',
    nonce,
    used: found.used === true,
    price: readPrice(found.price),
    createdAt: found.createdAt || null,
    usedAt: found.usedAt || null,
  };
}

async function setPrice(nonce, price) {
  const row = await rowByNonce(nonce);
  const exists = Boolean(row.code || row.used || row.createdAt || row.usedAt);
  if (!exists) return { ok: false, error: 'missing' };
  if (!row.used) return { ok: false, error: 'not_used' };
  if (hasKv()) {
    if (price == null) {
      await kv([['HDEL', `code:${nonce}`, 'price']]);
    } else {
      await kv([['HSET', `code:${nonce}`, 'price', String(price)]]);
    }
    return { ok: true };
  }
  if (process.env.VERCEL) {
    return { ok: false, error: 'no_kv' };
  }
  const data = loadFile();
  const i = (data.codes || []).findIndex((e) => e.nonce === nonce);
  if (i < 0) return { ok: false, error: 'missing' };
  if (data.codes[i].used !== true) return { ok: false, error: 'not_used' };
  data.codes[i].price = price;
  saveFile(data);
  return { ok: true };
}

async function consume(nonce) {
  if (nonce === 'TESTALIAS') {
    return { ok: false, error: 'test_alias' };
  }
  if (hasKv()) {
    const usedAt = new Date().toISOString();
    const [setNx] = await kv([['SET', `used:${nonce}`, usedAt, 'NX']]);
    if (setNx.result == null) {
      return { ok: false, error: 'used' };
    }
    await kv([
      ['HSET', `code:${nonce}`, 'used', '1', 'usedAt', usedAt],
      ['SADD', INDEX_KEY, nonce],
    ]);
    return { ok: true };
  }
  if (process.env.VERCEL) {
    return { ok: false, error: 'no_kv' };
  }
  const data = loadFile();
  const list = data.codes || [];
  const i = list.findIndex((e) => e.nonce === nonce);
  if (i >= 0) {
    if (list[i].used === true) return { ok: false, error: 'used' };
    list[i].used = true;
    list[i].usedAt = new Date().toISOString();
  } else {
    list.push({
      nonce,
      used: true,
      usedAt: new Date().toISOString(),
      note: 'hmac-offline',
    });
  }
  data.codes = list;
  saveFile(data);
  return { ok: true };
}

async function getGlobalPrice() {
  if (hasKv()) {
    const [reply] = await kv([['GET', GLOBAL_PRICE_KEY]]);
    return readPrice(reply && reply.result);
  }
  if (process.env.VERCEL) return null;
  return readPrice(loadFile().globalPrice);
}

async function setGlobalPrice(price) {
  if (hasKv()) {
    if (price == null) {
      await kv([['DEL', GLOBAL_PRICE_KEY]]);
    } else {
      await kv([['SET', GLOBAL_PRICE_KEY, String(price)]]);
    }
    return { ok: true };
  }
  if (process.env.VERCEL) {
    return { ok: false, error: 'no_kv' };
  }
  const data = loadFile();
  data.globalPrice = price;
  saveFile(data);
  return { ok: true };
}

async function listCodes() {
  if (hasKv()) {
    return {
      kv: true,
      globalPrice: await getGlobalPrice(),
      codes: await listFromKv(),
    };
  }
  if (process.env.VERCEL) {
    return { kv: false, globalPrice: null, codes: [] };
  }
  const data = loadFile();
  const codes = (data.codes || []).map((row) => ({
    code: row.code || '',
    nonce: row.nonce || '',
    used: row.used === true,
    price: readPrice(row.price),
    createdAt: row.createdAt || null,
    usedAt: row.usedAt || null,
  }));
  return {
    kv: false,
    globalPrice: readPrice(data.globalPrice),
    codes: sortRows(codes),
  };
}

module.exports = {
  recordGenerated,
  consume,
  hasKv,
  listCodes,
  setPrice,
  getGlobalPrice,
  setGlobalPrice,
};
