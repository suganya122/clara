# Contributing

- Do not copy code, prompts, UI or structure from PhoneAgent, Atticus, OpenClaw or similar projects. Design everything independently.
- Only permissive-license dependencies (MIT, Apache, BSD). List each in `THIRD_PARTY.md`.
- Core imports Contracts only. Platform code goes behind a protocol with a fake for tests.
- No file over about 400 lines. Every module has unit tests.
- Every new tool declares its risk level and how it is undone (or that it is irreversible).
- Record any design change in `docs/DECISIONS.md`.
