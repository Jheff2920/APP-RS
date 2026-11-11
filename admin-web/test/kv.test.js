// Prueba el camino KV de store.js contra un Redis mínimo en memoria. Cada
// pipeline corre entero de una vez (como en Upstash) y entre pipelines se
// cede el turno, así dos activaciones a la vez se intercalan de verdad.
const assert = require('assert');

process.env.KV_REST_API_URL = 'https://kv.test';
process.env.KV_REST_API_TOKEN = 'token';
delete process.env.VERCEL;

const db = new Map();
let failNext = null;

function hash(key) {
  if (!db.has(key)) db.set(key, new Map());
  return db.get(key);
}

function run([cmd, ...a]) {
  if (failNext && failNext === cmd) {
    failNext = null;
    return { error: `ERR simulado en ${cmd}` };
  }
  switch (cmd) {
    case 'HGETALL': return db.has(a[0]) ? [...db.get(a[0])].flat() : [];
    case 'HSET': {
      const h = hash(a[0]);
      for (let i = 1; i < a.length; i += 2) h.set(a[i], String(a[i + 1]));
      return (a.length - 1) / 2;
    }
    case 'HSETNX': {
      const h = hash(a[0]);
      if (h.has(a[1])) return 0;
      h.set(a[1], String(a[2]));
      return 1;
    }
    case 'HDEL': {
      const h = db.get(a[0]);
      return h ? a.slice(1).filter((f) => h.delete(f)).length : 0;
    }
    case 'SADD': {
      if (!db.has(a[0])) db.set(a[0], new Set());
      a.slice(1).forEach((m) => db.get(a[0]).add(m));
      return a.length - 1;
    }
    case 'SMEMBERS': return db.has(a[0]) ? [...db.get(a[0])] : [];
    case 'SCAN': return ['0', [...db.keys()].filter((k) => k.startsWith('code:'))];
    case 'GET': return db.has(a[0]) ? db.get(a[0]) : null;
    case 'SET': db.set(a[0], String(a[1])); return 'OK';
    default: return { error: `ERR comando no soportado ${cmd}` };
  }
}

global.fetch = async (url, opts) => {
  await new Promise((r) => setImmediate(r));
  const out = JSON.parse(opts.body).map((c) => {
    const r = run(c);
    return r && r.error ? r : { result: r };
  });
  return { ok: true, status: 200, json: async () => out };
};

const { recordGenerated, consume, listCodes, setRelease } = require('../lib/store');

const A = 'a'.repeat(64);
const B = 'b'.repeat(64);
const C = 'c'.repeat(64);
const row = async (nonce) => (await listCodes()).codes.find((r) => r.nonce === nonce);

(async () => {
  await recordGenerated('RP-AAAA-BBBB-CCCC', 'AAAA');
  assert.strictEqual((await consume('ZZZZ', A)).error, 'unknown');

  // Dos teléfonos con la misma key nueva a la vez: solo uno gana.
  const first = await Promise.all([consume('AAAA', A), consume('AAAA', B)]);
  assert.deepStrictEqual(first.filter((r) => r.ok), [{ ok: true }]);
  const owner = first[0].ok ? A : B;
  const other = owner === A ? B : A;
  assert.deepStrictEqual(await consume('AAAA', owner), { ok: true, again: true });
  assert.strictEqual((await consume('AAAA', other)).error, 'used');
  assert.strictEqual((await row('AAAA')).used, true);
  assert.strictEqual((await row('AAAA')).bound, true);

  // Liberada y dos teléfonos a la vez: la liberación vale una sola vez.
  assert.strictEqual((await setRelease('AAAA', true)).ok, true);
  const race = await Promise.all([consume('AAAA', other), consume('AAAA', C)]);
  assert.strictEqual(race.filter((r) => r.ok).length, 1, JSON.stringify(race));
  const winner = race[0].ok ? other : C;
  assert.deepStrictEqual(await consume('AAAA', winner), { ok: true, again: true });
  assert.strictEqual((await consume('AAAA', owner)).error, 'used', 'el anterior ya no vale');

  // Liberación usada sin hash (iPhone): el teléfono anterior deja de valer.
  await setRelease('AAAA', true);
  assert.deepStrictEqual(await consume('AAAA', ''), { ok: true, again: true });
  assert.strictEqual((await row('AAAA')).bound, false);
  assert.strictEqual((await consume('AAAA', winner)).error, 'used');

  // Falla a mitad de la primera activación: queda usada y se puede liberar.
  await recordGenerated('RP-DDDD-EEEE-FFFF', 'DDDD');
  failNext = 'HSET';
  await assert.rejects(consume('DDDD', A), /ERR simulado/);
  assert.strictEqual((await row('DDDD')).used, true, 'usedAt basta para verla usada');
  assert.strictEqual((await consume('DDDD', A)).error, 'used');
  assert.strictEqual((await setRelease('DDDD', true)).ok, true);
  assert.deepStrictEqual(await consume('DDDD', A), { ok: true, again: true });

  console.log('kv.test.js ok');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
