# AGENTS

**Read [CONTEXTO.md](CONTEXTO.md) first.** That file is the project memory for coding agents (current state, architecture, paid gates, privacy, signing, and do-nots).

Quick rules:

- Company spelling: **Red Soluciones** (one d, never Redd).
- No generative AI features; no AdMob / Firebase analytics.
- Do not commit `upload-keystore.jks` or `key.properties`.
- Paid unlocks: reuse `RedPosLicenseStore.isAdsFree()` and `lib/widgets/redpos_paid_gate.dart`.
- Prefer Spanish; confirm before large refactors.
- Windows PowerShell: use `;` not `&&`. Local checkout: `C:\Users\RS-Soporte\Documents\app`.

## Alcance y escalacion (arquitectura multi-Hermes)

Esta carpeta es un limite de trabajo aislado para cualquier agente (Hermes, Codex, Claude Code, subagentes) que opere aqui.

Reglas de alcance:
- Nunca leas, escribas, ejecutes ni navegues fuera de esta carpeta (ni carpetas hermanas dentro de Documents/Jheff, ni el resto del sistema), salvo que el usuario lo pida explicitamente.
- Todo el trabajo (archivos, comandos, subagentes) se mantiene dentro de este arbol de carpetas.

Escalacion - si necesitas una skill/habilidad que no tienes instalada aqui:
1. No la inventes ni la simules. Pide ayuda al jefe: el perfil Hermes "default" (corre en Documents/Jheff), que tiene el catalogo completo de skills.
2. Ejecuta en terminal: hermes -p default -z "Necesito la skill para TAREA_CONCRETA. Instalamela en: C:/Users/RS-Soporte/AppData/Local/hermes/profiles/app/skills/"
3. El jefe busca o crea la skill y la copia a tu carpeta de skills. Reintenta la tarea despues.

Perfil Hermes de este proyecto: app
Carpeta de skills de este perfil: C:/Users/RS-Soporte/AppData/Local/hermes/profiles/app/skills/
