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

const { recordGenerated, consume, listCodes, setPrice, setGlobalPrice } = require('../lib/store');
const { sumUsedPrices } = require('../lib/price');

(async () => {
  await recordGenerated('RP-AAAA-BBBB-CCCC', 'AAAA');
  await recordGenerated('RP-DDDD-EEEE-FFFF', 'DDDD');
  const blocked = await setPrice('DDDD', 25.5);
  assert.strictEqual(blocked.ok, false);
  assert.strictEqual(blocked.error, 'not_used');
  assert.strictEqual((await consume('AAAA')).ok, true);
  assert.strictEqual((await consume('DDDD')).ok, true);
  assert.strictEqual((await setGlobalPrice(20)).ok, true);
  assert.strictEqual((await setPrice('AAAA', 10)).ok, true);
  const listed = await listCodes();
  assert.strictEqual(listed.globalPrice, 20);
  const a = listed.codes.find((row) => row.nonce === 'AAAA');
  const d = listed.codes.find((row) => row.nonce === 'DDDD');
  assert.strictEqual(a.price, 10);
  assert.strictEqual(d.price, null);
  assert.strictEqual(sumUsedPrices(listed.codes, listed.globalPrice), 30);
  fs.unlinkSync(data);
  console.log('store.test.js ok');
})().catch((err) => {
  try { fs.unlinkSync(data); } catch (_) {}
  console.error(err);
  process.exit(1);
});
