const { readBody, dashboardOk } = require('../lib/staff');
const { setPending, setRelease, setClient } = require('../lib/store');

// Cambios del panel a una key: { nonce, pending | release | client }.
module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, error: 'method' });
    return;
  }
  if (!dashboardOk(req)) {
    res.status(401).json({ ok: false, error: 'clave' });
    return;
  }
  const body = readBody(req);
  const nonce = String(body.nonce || '').trim();
  if (!nonce) {
    res.status(400).json({ ok: false, error: 'codigo' });
    return;
  }
  let result;
  if ('pending' in body) result = await setPending(nonce, body.pending === true);
  else if ('release' in body) result = await setRelease(nonce, body.release === true);
  else if ('client' in body) result = await setClient(nonce, body.client || {});
  else result = { ok: false, error: 'campo' };
  if (!result.ok) {
    const status = { used: 409, not_used: 409, missing: 404, no_kv: 503 }[result.error] || 400;
    res.status(status).json({ ok: false, error: result.error });
    return;
  }
  res.status(200).json({ ok: true, nonce });
};
