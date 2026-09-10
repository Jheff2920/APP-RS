const fs = require('fs');
const path = require('path');

const filePath =
  process.env.REDPOS_ADMIN_DATA ||
  path.join(__dirname, '..', 'data', 'codes.json');

function hasKv() {
  return Boolean(process.env.KV_REST_API_URL && process.env.KV_REST_API_TOKEN);
}

function loadFile() {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return { codes: [] };
  }
}

function saveFile(data) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

async function kv(command) {
  const url = process.env.KV_REST_API_URL.replace(/\/$/, '');
  const res = await fetch(`${url}/pipeline`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.KV_REST_API_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(command),
  });
  if (!res.ok) {
    throw new Error(`KV ${res.status}`);
  }
  return res.json();
}

async function recordGenerated(code, nonce) {
  const row = {
    code,
    nonce,
    used: false,
    createdAt: new Date().toISOString(),
  };
  if (hasKv()) {
    await kv([
      ['HSET', `code:${nonce}`, 'code', code, 'used', '0', 'createdAt', row.createdAt],
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

async function consume(nonce) {
  if (nonce === 'TESTALIAS') {
    return { ok: false, error: 'test_alias' };
  }
  if (hasKv()) {
    const [setNx] = await kv([['SET', `used:${nonce}`, new Date().toISOString(), 'NX']]);
    if (setNx.result == null) {
      return { ok: false, error: 'used' };
    }
    await kv([['HSET', `code:${nonce}`, 'used', '1', 'usedAt', new Date().toISOString()]]);
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

module.exports = { recordGenerated, consume, hasKv };
