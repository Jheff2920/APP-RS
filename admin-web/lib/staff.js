const crypto = require('crypto');

function readBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  if (typeof req.body === 'string' && req.body) {
    try {
      return JSON.parse(req.body);
    } catch {
      return {};
    }
  }
  return {};
}

// Sin clave configurada en Vercel no entra nadie (antes había una de respaldo en el código).
function staffPassword() {
  return process.env.REDPOS_STAFF_PASSWORD || '';
}

function dashboardPassword() {
  return process.env.REDPOS_DASHBOARD_PASSWORD || staffPassword();
}

function same(given, expected) {
  if (!expected || typeof given !== 'string') return false;
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function staffOk(req) {
  return same(readBody(req).password, staffPassword());
}

function dashboardOk(req) {
  return same(readBody(req).password, dashboardPassword());
}

module.exports = { readBody, staffOk, dashboardOk };
