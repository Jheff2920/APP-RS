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

function staffPassword() {
  return process.env.REDPOS_STAFF_PASSWORD || 'R100301S';
}

function dashboardPassword() {
  return process.env.REDPOS_DASHBOARD_PASSWORD || staffPassword();
}

function staffOk(req) {
  return readBody(req).password === staffPassword();
}

function dashboardOk(req) {
  return readBody(req).password === dashboardPassword();
}

module.exports = { readBody, staffOk, dashboardOk };
