# AGENTS

**Read [CONTEXTO.md](CONTEXTO.md) first.** That file is the project memory for coding agents (current state, architecture, paid gates, privacy, signing, and do-nots).

Quick rules:

- Company spelling: **Red Soluciones** (one d, never Redd).
- No generative AI features; no AdMob / Firebase analytics.
- Do not commit `upload-keystore.jks` or `key.properties`.
- Paid unlocks: reuse `RedPosLicenseStore.isAdsFree()` and `lib/widgets/redpos_paid_gate.dart`.
- Prefer Spanish; confirm before large refactors.
- Windows PowerShell: use `;` not `&&`. Local checkout: `C:\Users\RS-Soporte\Documents\app`.
