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
  const out = await res.json();
  // El pipeline responde 200 aunque un comando falle: revisar cada uno.
  const failed = Array.isArray(out) && out.find((r) => r && r.error);
  if (failed) throw new Error(`KV ${failed.error}`);
  return out;
}

function toObject(raw) {
  const o = {};
  if (raw && !Array.isArray(raw) && typeof raw === 'object') {
    Object.assign(o, raw);
  } else if (Array.isArray(raw)) {
    for (let i = 0; i < raw.length - 1; i += 2) {
      o[String(raw[i])] = raw[i + 1];
    }
  }
  return o;
}

const flag = (v) => v === '1' || v === 1 || v === true;
// usedAt se escribe primero (HSETNX): basta para contar la key como usada.
const isUsed = (o) => flag(o.used) || Boolean(o.usedAt);

// El hash del teléfono no sale del servidor: el panel solo ve si hay uno.
function hashToRow(nonce, raw) {
  const o = toObject(raw);
  const used = isUsed(o);
  return {
    code: o.code || '',
    nonce,
    used,
    pending: !used && flag(o.pending),
    released: used && flag(o.rebind),
    bound: Boolean(o.device),
    name: o.name || '',
    email: o.email || '',
    phone: o.phone || '',
    kind: o.kind || '',
    note: o.note || '',
    price: readPrice(o.price),
    createdAt: o.createdAt || null,
    usedAt: o.usedAt || null,
    reactivatedAt: o.reactivatedAt || null,
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
  return hashToRow(nonce, (data.codes || []).find((row) => row.nonce === nonce));
}

// Cambia un campo de la key (null lo borra). [guard] devuelve un error o nada.
async function setField(nonce, field, value, guard) {
  const row = await rowByNonce(nonce);
  if (!row.createdAt && !row.code) return { ok: false, error: 'missing' };
  const bad = guard && guard(row);
  if (bad) return { ok: false, error: bad };
  if (hasKv()) {
    await kv([
      value == null
        ? ['HDEL', `code:${nonce}`, field]
        : ['HSET', `code:${nonce}`, field, String(value)],
    ]);
    return { ok: true };
  }
  if (process.env.VERCEL) return { ok: false, error: 'no_kv' };
  const data = loadFile();
  const found = data.codes.find((e) => e.nonce === nonce);
  if (value == null) delete found[field];
  else found[field] = value;
  saveFile(data);
  return { ok: true };
}

const setPrice = (nonce, price) =>
  setField(nonce, 'price', price, (row) => !row.used && 'not_used');

// Entregada al cliente pero sin saber si la activó (la app 1.8.9+55 no avisaba).
const setPending = (nonce, pending) =>
  setField(nonce, 'pending', pending ? '1' : null, (row) => row.used && 'used');

// Liberar: la próxima activación (desde cualquier teléfono) vuelve a valer.
const setRelease = (nonce, release) =>
  setField(nonce, 'rebind', release ? '1' : null, (row) => !row.used && 'not_used');

const CLIENT_FIELDS = { name: 80, email: 120, phone: 40, note: 200 };
const KINDS = ['lifetime', 'trial'];

// Ficha del comprador (la escribe el dueño en el panel) para reconocerlo si
// pide liberar la key. Con datos de contacto, una key sin activar queda entregada.
async function setClient(nonce, client = {}) {
  const row = await rowByNonce(nonce);
  if (!row.createdAt && !row.code) return { ok: false, error: 'missing' };
  const values = {};
  for (const [field, max] of Object.entries(CLIENT_FIELDS)) {
    values[field] = String(client[field] || '').trim().slice(0, max);
  }
  if (values.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(values.email)) {
    return { ok: false, error: 'correo' };
  }
  values.kind = KINDS.includes(client.kind) ? client.kind : '';
  if (!row.used && (values.name || values.email || values.phone)) values.pending = '1';
  const fill = Object.entries(values).filter(([, v]) => v);
  const empty = Object.keys(values).filter((k) => !values[k]);
  if (hasKv()) {
    await kv([
      ...(fill.length ? [['HSET', `code:${nonce}`, ...fill.flat()]] : []),
      ...(empty.length ? [['HDEL', `code:${nonce}`, ...empty]] : []),
    ]);
    return { ok: true };
  }
  if (process.env.VERCEL) return { ok: false, error: 'no_kv' };
  const data = loadFile();
  const found = data.codes.find((e) => e.nonce === nonce);
  fill.forEach(([k, v]) => { found[k] = v; });
  empty.forEach((k) => { delete found[k]; });
  saveFile(data);
  return { ok: true };
}

// Activa una key del generador. Una key usada vuelve a valer si llega desde
// el mismo teléfono ([device]) o una sola vez si el panel la liberó.
async function consume(nonce, device = '') {
  const now = new Date().toISOString();
  if (hasKv()) {
    const key = `code:${nonce}`;
    const [reply] = await kv([['HGETALL', key]]);
    const raw = toObject(reply && reply.result);
    // Solo keys del generador: el secreto HMAC viaja dentro de la app y no basta.
    if (!raw.createdAt) return { ok: false, error: 'unknown' };
    if (isUsed(raw)) {
      if (device && raw.device === device) {
        // Mismo teléfono: no se reescribe device para no pisar una transferencia.
        await kv([['HSET', key, 'reactivatedAt', now]]);
        return { ok: true, again: true };
      }
      if (!flag(raw.rebind)) return { ok: false, error: 'used' };
      // HDEL es atómico: si dos teléfonos llegan a la vez, solo uno se la lleva.
      const [claim] = await kv([['HDEL', key, 'rebind']]);
      if (claim.result !== 1) return { ok: false, error: 'used' };
      // Sin hash (iPhone, app vieja) el teléfono anterior deja de valer igual.
      await kv([
        ['HSET', key, 'reactivatedAt', now, ...(device ? ['device', device] : [])],
        ...(device ? [] : [['HDEL', key, 'device']]),
      ]);
      return { ok: true, again: true };
    }
    // HSETNX es atómico: dos activaciones simultáneas no pueden ganar ambas.
    const [claim] = await kv([['HSETNX', key, 'usedAt', now]]);
    if (claim.result !== 1) return { ok: false, error: 'used' };
    await kv([
      ['HSET', key, 'used', '1', ...(device ? ['device', device] : [])],
      ['HDEL', key, 'pending'],
      ['SADD', INDEX_KEY, nonce],
    ]);
    return { ok: true };
  }
  if (process.env.VERCEL) return { ok: false, error: 'no_kv' };
  const data = loadFile();
  const found = (data.codes || []).find((e) => e.nonce === nonce);
  if (!found) return { ok: false, error: 'unknown' };
  if (!isUsed(found)) {
    found.used = true;
    found.usedAt = now;
    if (device) found.device = device;
    delete found.pending;
    saveFile(data);
    return { ok: true };
  }
  const sameDevice = Boolean(device && found.device === device);
  if (!sameDevice && !flag(found.rebind)) return { ok: false, error: 'used' };
  if (!sameDevice) {
    delete found.rebind;
    if (device) found.device = device;
    else delete found.device;
  }
  found.reactivatedAt = now;
  saveFile(data);
  return { ok: true, again: true };
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
  const codes = (data.codes || []).map((row) => hashToRow(row.nonce || '', row));
  return {
    kv: false,
    globalPrice: readPrice(data.globalPrice),
    codes: sortRows(codes),
  };
}

module.exports = {
  recordGenerated,
  consume,
  setPending,
  setRelease,
  setClient,
  hasKv,
  listCodes,
  setPrice,
  getGlobalPrice,
  setGlobalPrice,
};
