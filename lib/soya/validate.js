// Validates JSON-LD data against a SOyA structure with soya-js, without any
// network access. Used by DidLint::LocalValidator in offline mode.
//
// stdin:  {"structure": <self-contained SOyA structure>, "data": <JSON-LD>}
// stdout: the result of SoyaValidate, as soya-web-cli returns it
// SOYA_JS points to the soya-js package (default /opt/soya-js).
const fs = require('fs');
const path = require('path');

const base = process.env.SOYA_JS || '/opt/soya-js';
// soya-js logs debug output to stdout; keep stdout for the result
const silent = new Proxy({}, { get: () => () => {} });
require(path.join(base, 'dist/services/logger.js')).setLogger(silent);
const { SoyaValidate } = require(path.join(base, 'dist/overlays/validate.js'));

(async () => {
  const input = JSON.parse(fs.readFileSync(0, 'utf8'));
  const result = await new SoyaValidate().run(input.structure, input.data);
  process.stdout.write(JSON.stringify(result.data));
})().catch((err) => {
  process.stderr.write(String((err && err.message) || err) + '\n');
  process.exit(1);
});
