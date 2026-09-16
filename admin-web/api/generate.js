const { generate, verify } = require('../lib/code');
const { staffOk } = require('../lib/staff');
const { recordGenerated } = require('../lib/store');

module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, error: 'method' });
    return;
  }
  if (!staffOk(req)) {
    res.status(401).json({ ok: false, error: 'clave' });
    return;
  }
  const code = generate();
  const checked = verify(code);
  await recordGenerated(code, checked.nonce);
  res.status(200).json({ ok: true, code });
};
