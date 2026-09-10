const { verify } = require('../lib/code');
const { consume, hasKv } = require('../lib/store');

module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, error: 'method' });
    return;
  }
  const body = req.body || {};
  const checked = verify(body.code || '');
  if (!checked.ok || !checked.nonce) {
    res.status(400).json({ ok: false, error: 'invalid' });
    return;
  }
  if (checked.testAlias) {
    res.status(400).json({ ok: false, error: 'invalid' });
    return;
  }
  const result = await consume(checked.nonce);
  if (!result.ok) {
    const status = result.error === 'no_kv' ? 503 : 409;
    res.status(status).json({
      ok: false,
      error: result.error,
      hint:
        result.error === 'no_kv'
          ? 'En Vercel crea un KV (Upstash) y las variables KV_REST_API_URL / KV_REST_API_TOKEN.'
          : undefined,
    });
    return;
  }
  res.status(200).json({ ok: true, kv: hasKv() });
};
