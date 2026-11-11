const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const data = path.join(os.tmpdir(), `redpos-codes-test-${Date.now()}.json`);
process.env.REDPOS_ADMIN_DATA = data;
delete process.env.VERCEL;
delete process.env.KV_REST_API_URL;
delete process.env.KV_REST_API_TOKEN;
delete process.env.UPSTASH_REDIS_REST_URL;
delete process.env.UPSTASH_REDIS_REST_TOKEN;

const {
  recordGenerated, consume, listCodes, setPrice, setGlobalPrice, setPending, setRelease, setNote,
} = require('../lib/store');
const { sumUsedPrices } = require('../lib/price');

const PHONE_A = 'a'.repeat(64);
const PHONE_B = 'b'.repeat(64);
const row = async (nonce) => (await listCodes()).codes.find((r) => r.nonce === nonce);

(async () => {
  await recordGenerated('RP-AAAA-BBBB-CCCC', 'AAAA');
  await recordGenerated('RP-DDDD-EEEE-FFFF', 'DDDD');
  await recordGenerated('RP-GGGG-HHHH-JJJJ', 'GGGG');
  await recordGenerated('RP-KKKK-LLLL-MMMM', 'KKKK');

  // Pendiente: se marca y se quita; al activarse deja de estar pendiente.
  assert.strictEqual((await setPending('GGGG', true)).ok, true);
  assert.strictEqual((await row('GGGG')).pending, true);
  assert.strictEqual((await setPending('GGGG', false)).ok, true);
  assert.strictEqual((await row('GGGG')).pending, false);
  assert.strictEqual((await setPending('ZZZZ', true)).error, 'missing');
  assert.strictEqual((await setPending('AAAA', true)).ok, true);

  const blocked = await setPrice('DDDD', 25.5);
  assert.strictEqual(blocked.ok, false);
  assert.strictEqual(blocked.error, 'not_used');
  assert.strictEqual((await consume('AAAA')).ok, true);
  assert.strictEqual((await consume('DDDD')).ok, true);
  assert.strictEqual((await consume('DDDD')).error, 'used');
  assert.strictEqual((await consume('ZZZZ')).error, 'unknown');
  assert.strictEqual((await setPending('DDDD', true)).error, 'used');

  // Mismo teléfono reactiva; otro teléfono no, salvo que el panel la libere.
  assert.deepStrictEqual(await consume('KKKK', PHONE_A), { ok: true });
  assert.strictEqual((await row('KKKK')).bound, true);
  assert.deepStrictEqual(await consume('KKKK', PHONE_A), { ok: true, again: true });
  assert.strictEqual((await consume('KKKK', PHONE_B)).error, 'used');
  assert.strictEqual((await consume('KKKK')).error, 'used', 'sin teléfono no reactiva');
  assert.strictEqual((await setRelease('GGGG', true)).error, 'not_used');
  assert.strictEqual((await setRelease('KKKK', true)).ok, true);
  assert.strictEqual((await row('KKKK')).released, true);
  assert.deepStrictEqual(await consume('KKKK', PHONE_B), { ok: true, again: true });
  assert.strictEqual((await row('KKKK')).released, false, 'liberar sirve una vez');
  assert.ok((await row('KKKK')).reactivatedAt);
  assert.strictEqual((await consume('KKKK', PHONE_A)).error, 'used', 'ahora vale el teléfono B');
  assert.deepStrictEqual(await consume('KKKK', PHONE_B), { ok: true, again: true });
  // Una key activada sin teléfono (app vieja) solo vuelve con «Liberar».
  assert.strictEqual((await consume('DDDD', PHONE_A)).error, 'used');
  assert.strictEqual((await setRelease('DDDD', true)).ok, true);
  assert.deepStrictEqual(await consume('DDDD', PHONE_A), { ok: true, again: true });

  // Cliente: se guarda recortado y vacío lo borra.
  assert.strictEqual((await setNote('KKKK', '  Bodega Rosita 987654321  ')).ok, true);
  assert.strictEqual((await row('KKKK')).note, 'Bodega Rosita 987654321');
  assert.strictEqual((await setNote('KKKK', 'x'.repeat(300))).ok, true);
  assert.strictEqual((await row('KKKK')).note.length, 120);
  assert.strictEqual((await setNote('KKKK', '')).ok, true);
  assert.strictEqual((await row('KKKK')).note, '');
  assert.strictEqual((await setNote('ZZZZ', 'x')).error, 'missing');
  assert.strictEqual(JSON.stringify(await listCodes()).includes(PHONE_A), false, 'el hash no sale');

  assert.strictEqual((await setGlobalPrice(20)).ok, true);
  assert.strictEqual((await setPrice('AAAA', 10)).ok, true);
  const listed = await listCodes();
  assert.strictEqual(listed.globalPrice, 20);
  const a = listed.codes.find((r) => r.nonce === 'AAAA');
  const d = listed.codes.find((r) => r.nonce === 'DDDD');
  assert.strictEqual(a.price, 10);
  assert.strictEqual(d.price, null);
  assert.strictEqual(a.pending, false, 'activar quita pendiente');
  assert.strictEqual(sumUsedPrices(listed.codes, listed.globalPrice), 10 + 20 + 20);
  fs.unlinkSync(data);
  console.log('store.test.js ok');
})().catch((err) => {
  try { fs.unlinkSync(data); } catch (_) {}
  console.error(err);
  process.exit(1);
});
