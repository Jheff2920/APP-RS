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
  const body =
    req.body && typeof req.body === 'object'
      ? req.body
      : (() => {
          try {
            return JSON.parse(req.body || '{}');
          } catch {
            return {};
          }
        })();
  const checked = verify(body.code || '');
  if (!checked.ok || !checked.nonce) {
    res.status(400).json({ ok: false, error: 'invalid' });
    return;
  }
  // Hash anónimo del teléfono (sha256 hex) para reactivar en el mismo equipo.
  const device = /^[a-f0-9]{64}$/.test(String(body.device || '')) ? body.device : '';
  const result = await consume(checked.nonce, device);
  if (!result.ok) {
    const status = result.error === 'no_kv' ? 503 : 409;
    res.status(status).json({
      ok: false,
      error: result.error,
      hint: undefined,
    });
    return;
  }
  res.status(200).json({ ok: true, kv: hasKv(), again: result.again === true });
};
