const assert = require('assert');
const { generate, verify } = require('../lib/code');

const secret = 'unit-test-secret';
const code = generate(secret);
const result = verify(code, secret);
assert.strictEqual(result.ok, true, 'generated code must verify');
assert.strictEqual(result.nonce.length, 8);
assert.strictEqual(verify(code, 'other').ok, false);
assert.strictEqual(verify(code.toLowerCase().replace(/-/g, ' - '), secret).ok, true);
console.log('hmac.test.js ok', code);
