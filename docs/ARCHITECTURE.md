# Architecture

_Source of truth: original design from the build brief (Part 2)._

Goal: a lean native Mac assistant with fast voice, reliable computer control, learned skills, and very low running cost.

## 1. Principles
1. **Cheap by construction.** Every request goes down a ladder: skill replay (free) then rule router (free) then small model then bigger model. The LLM is the last resort.
2. **Verify, don't assume.** Every action returns a checked outcome. Unverified outcomes are never learned.
3. **Small contracts, swappable parts.** Speech-to-text, text-to-speech, model, capture, hands, and browser are protocols with fake implementations for tests.
4. **Crash isolation.** Risky or heavy work (browser helper) runs in a separate process; a crash there never kills the app.
5. **Least privilege.** Each capability (screen, input, shell, files, network, purchase) is separately permissioned, logged, and revocable.
6. **Observable.** Every request has a trace id and a latency and cost breakdown.

## 2. Process model
```
 Hotkey / wake word / mic ──┐
                            ▼
                     ┌──────────────┐
                     │  CORE (Swift)│  agent loop, router, skills, memory,
                     │              │  policy gate, cost, audit, journal
                     └──┬────┬────┬─┘
          ┌─────────────┘    │    └───────────────┐
          ▼                  ▼                    ▼
   Model provider       Hands + Capture     Voice engine
   (Claude)             (Accessibility,     (Apple STT, VAD,
                         CGEvent,            Apple TTS,
                         ScreenCaptureKit,   barge-in)
                         AppleScript)
                            │
                            ▼
                 Browser helper (Playwright, separate process)
```

## 3. Core protocols (interfaces, not implementations)
- `ModelProvider`: stream(messages, tools, tier) returning events; reports tokens and cost.
- `SpeechToText`: stream(audio) returning partial and final transcript events.
- `TextToSpeech`: speak(text) with immediate cancel; reports when speech starts and stops.
- `Hands`: listWindows, focus, click, type, key, scroll, menu; each returns `ActionResult`.
- `Capture`: screenshot(target) and readText(target) via the accessibility tree.
- `Browser`: navigate, readPage, fill, click, with a fake for tests.
- `Tool`: name, JSON schema, risk level, undo behaviour, async run().
- `Skill`: parameterized recorded plan plus verification checks.

All protocols are versioned and live in one shared module. Nothing else is shared across modules.

## 4. Request pipeline (cost and latency ladder)
1. **Intake:** final voice transcript becomes a `Request` with a trace id and an active-context snapshot (frontmost app, focused window, display under the mouse, selected text).
2. **Stop check:** if the text matches the stop phrase, halt everything now. No model call.
3. **Skill match:** match intent and extract parameters; replay with no LLM if confidence is high and verification checks pass.
4. **Rule router:** deterministic commands (open app, move window, media, search).
5. **Small model** with cached system prompt and compact tool list.
6. **Escalation:** on tool failure, low confidence, or a multi-step plan, retry once on the larger tier.
7. **Policy gate** before every tool call: risk level, permissions, per-app rules, approval if needed.
8. **Execute and verify.** On success, feed the learner and write the journal entry. On failure, repair or report honestly.
9. **Respond:** stream text to speech, write the audit and cost record.

## 5. Skill learner
- Record the verified tool-call sequence for a successful request.
- Abstract parameters (app names, text, numbers, dates, prices).
- Store a skill as trigger phrases, parameter slots, steps, and postconditions.
- Promote after N verified successes; demote or flag when a postcondition fails.
- Skills never contain secrets. Destructive or purchase steps always re-ask on replay.

## 6. Security model
- Capabilities: `screen.read`, `input.control`, `shell.run`, `fs.read`, `fs.write`, `net.fetch`, `send.external`, `purchase`. Each has a policy of allow, ask, or deny, with per-app overrides.
- Untrusted-content rule: anything from screens, web pages, files, or messages is tagged untrusted and cannot grant itself permissions or trigger risky tools.
- Secrets in the Keychain; redaction in logs.
- Global kill switch and stop phrase.

## 7. Data
- SQLite with migrations: settings, memory, skills, audit, cost ledger, journal.
- Append-only audit log. Cost ledger drives spend caps.
- Everything exportable and deletable.

## 8. Repo layout
```
Clara/
  App/           menu bar app, settings, overlay, first-run permissions
  Core/          agent loop, router, policy, cost, audit, journal (no OS-specific code)
  Contracts/     protocols and data models (source of truth)
  Voice/         STT, TTS, VAD, wake word, barge-in
  Hands/         Accessibility, CGEvent, AppleScript backends + fakes
  Capture/       ScreenCaptureKit, accessibility reading + fakes
  Models/        Claude provider (and optional local provider later)
  Skills/        learner, store, replay, verifier
  BrowserHelper/ Playwright helper process
  Tests/         unit, contract, integration (fakes), evals, latency
docs/            ARCHITECTURE.md, DECISIONS.md, SECURITY.md
```
Rules: no file over about 400 lines; Core never imports platform backends directly, only Contracts.
