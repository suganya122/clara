# Clara: Build Brief + Architecture (single file for Claude Code)

Clara is a voice-first personal AI assistant for macOS. The user speaks, Clara looks at the screen, acts on the Mac, and talks back like a human assistant. No chat window is needed for normal use.

This file has three parts:
1. Product brief (what to build, rules, milestones)
2. Architecture (our own design to follow)
3. Voice and "feels human" spec (including barge-in)

---

# PART 1: PRODUCT BRIEF

## What Clara is
- **Mac only.** Native Swift app (SwiftUI menu bar app). No Windows or Linux.
- **Fully voice-driven.** Whatever the user says, Clara does it, step by step, until done.
- **Two ways to talk to her:** hold the **Option + Space** hotkey and speak, or say the wake word **"Clara"** (optional, can be turned off).
- **Female voice and name.** The assistant's name is "Clara". Put it in a single config constant (`APP_NAME` / `WAKE_WORD`) so it can be changed. Do not hardcode it in assets or package names.
- **Examples of what she should handle:** "Open Uber and book a cab to the airport", "Find the cheapest flight from Chennai to Bangalore tomorrow and take me to the payment page", "Move Safari to the left half", "Summarize this page", "Clean up my Downloads folder".
- **Human-style interaction:** she can be interrupted mid-sentence (barge-in), speaks naturally, and keeps replies short. See Part 3.

## Reference material (idea only)
The user studied an open-source iPhone project called PhoneAgent. Its idea, in our own words: an agent loop where an AI model reads the current screen as structured text (an accessibility tree), picks one action (tap, type, scroll, open app), the action runs, the new screen is read, and the loop repeats until the task is done.

Clean-room rules:
- Do NOT clone, open, copy, paraphrase, or port code, prompts, UI, assets, or file structure from PhoneAgent, Atticus, OpenClaw, or any similar project. Do not fetch their repos.
- Design every prompt, schema, and UI yourself.
- If tempted to look at another project's source, ask the user instead.
- Use only permissive-license dependencies (MIT/Apache/BSD). Keep `THIRD_PARTY.md` listing each dependency and license.
- Our own license: MIT.

## Cost policy (hard rule)
- Everything must be free except the main reasoning model, which is **Claude** (Anthropic API, key supplied by the user).
- Speech-to-text and text-to-speech use **Apple's built-in macOS engines only**. **Do not use Whisper.** No paid or cloud speech services.
- No telemetry, no hosted backends, no paid SaaS.
- Claude cost controls (the only paid part, so keep it cheap and visible):
  - Default to the cheapest model tier; escalate only on failure or multi-step work.
  - Use prompt caching for the stable system prompt and tool definitions.
  - Prefer accessibility text over screenshots; downscale and crop screenshots before sending.
  - Cap tool-output size; summarize long context.
  - Instant commands and skill replays use zero LLM calls.
  - Live cost meter (tokens and estimated dollars per ask, per day, per month).
  - User-set daily and monthly spend caps that stop non-essential LLM calls when hit; per-task token budget; retry limits and loop detection so an agent can never burn tokens in an endless loop.
- Use model aliases from config (Cheap / Balanced / Max). Never hardcode version strings.

## Stack
- **Language:** Swift, SwiftUI, targeting a recent macOS (confirm the user's macOS version first; see Open questions).
- **Mac control:** Accessibility API (`AXUIElement`), `CGEvent` for synthetic input, AppleScript/Shortcuts for scriptable apps, `ScreenCaptureKit` for screenshots, `NSWorkspace` to launch apps.
- **Speech-to-text:** Apple only.
  - macOS 26 or newer: `SpeechAnalyzer` (on-device, streaming partial transcripts).
  - Older macOS: `SFSpeechRecognizer` with on-device recognition required.
  - Hidden behind a `SpeechToText` protocol so the engine can be swapped without touching the rest of the app.
- **Text-to-speech:** `AVSpeechSynthesizer` with a female voice (for example the English-India voice "Veena" if installed; let the user pick any installed voice in settings). Behind a `TextToSpeech` protocol.
- **Storage:** SQLite (settings, memory, skills, audit log, cost ledger). Config and data in the standard macOS Application Support folder.
- **Secrets:** Anthropic API key in the macOS Keychain only. Never in plain config or logs. Redact secrets in logs and the audit log.
- **Browser automation (the one non-Swift piece):** a small helper process running Playwright (Apache-2.0) behind a `Browser` protocol, with a fake implementation for tests. Swift talks to it over a local pipe or socket.
- **Distribution:** direct download or build from source. It cannot go in the Mac App Store because it needs Accessibility and Screen Recording control. No paid certificates required for personal use; document the one-time "allow app" steps.

## Permissions Clara needs (one-time setup, then no windows needed)
Microphone, Speech Recognition, Accessibility, Screen Recording, and Automation (for AppleScript targets). Provide a first-run walkthrough that checks each permission and links to the right System Settings pane.

## Core modules
1. **Agent loop:** plan, tool call, observe, verify, respond. Streaming output. Cancellable at any time.
2. **Model layer:** one `ModelProvider` interface. Claude is the default. Three selectable tiers: Cheap / Balanced / Max.
3. **Instant commands:** a fast rule-based router for obvious requests (open app, move/resize window, play/pause media, volume, web search). No LLM call.
4. **Hands layer:** list/focus/move/resize windows, click, type, scroll, key combos, menu items. Prefer Accessibility API; fall back to screenshot plus coordinates. Every action returns a verifiable result (`ActionResult{ok, evidence, state_after}`).
5. **Screen awareness:**
   - Read accessibility text first; fall back to a screenshot of a display or one window sent to Claude for vision.
   - On demand only. Never continuous recording. Nothing stored unless the user saves it.
   - Act on the display the mouse is on. "This", "here", "this page" resolve to the active window at the moment the user spoke.
   - User-configurable blocklist of apps/windows (password managers, banking) that are never captured; say so instead of failing silently.
   - **Screen text is untrusted input.** Instructions found on a screen or web page never trigger actions without approval.
6. **Voice:** hotkey, wake word, streaming STT, spoken replies, barge-in. Full spec in Part 3.
7. **Browser automation (travel, forms, research):**
   - Prefer DOM/accessibility tree over screenshots; send trimmed page text, not full HTML.
   - Two profiles: an isolated Clara profile by default, and an opt-in mode using the user's own logged-in browser.
   - Credentials are never shown to or stored by the model. Passwords and card numbers come only from the Keychain or are typed by the user.
   - **Always stop before any payment, booking confirmation, or irreversible submit.** Read back a summary (what, price, dates, passengers, refund terms) and let the user make the final click themselves. This applies even if purchases are otherwise allowed.
   - CAPTCHAs, OTPs, two-factor, and bot-detection pages: do not bypass. Pause, tell the user, hand over the browser, resume afterward.
   - Respect site terms; polite rate limits.
   - Report honestly when a step fails or a layout changed; say where it stopped.
8. **Skill learner:** record successful, verified tool-call traces; generalize parameters (prices, dates, names stay as parameters); store as named skills; replay with zero LLM calls; auto-demote a skill that starts failing. The user can list, edit, and delete skills.
9. **Memory:** "remember X" stores facts locally; relevant facts are injected into later requests. Viewable and deletable.
10. **Action journal and undo:** every state-changing tool call records an inverse in an append-only journal. "Undo that" reverses window moves, file moves, setting changes, and app launches where possible. Deletes go to the Trash, never permanent. Anything irreversible (sent messages, submitted forms, purchases) is labelled irreversible. Every new tool must declare how it is undone or declare itself irreversible. Undo never costs LLM tokens.
11. **Dry-run mode:** "show me what you'd do" plans and validates, then lists every step, target, and risk level without executing state-changing steps. The plan shown is the same plan that would run.
12. **Background tasks and routines:** long tasks run in a worker with status and cancel. "Every weekday at 8, do X" and "tell me when Y happens" via an internal scheduler. Watchers poll with zero LLM calls.
13. **Minimal UI:** menu bar icon plus a small overlay (see Part 3 and the design section). An optional small activity-log and approvals window, since voice alone cannot show history. Settings window for permissions, voice choice, wake word, spend caps, blocklist, and safety mode.

## Safety (non-negotiable)
- **Risk levels:** read / write / destructive / external-send / purchase. Destructive, send, and purchase always require explicit approval.
- **Approval by voice:** Clara reads the details back ("Send this email to Ravi with subject 'Invoice', say confirm to send") and waits. Accept "confirm" or "cancel". Because "send/end" and "delete/repeat" are easy to mishear, always read back before risky actions.
- **Safety modes:** Careful (asks before every state change), Normal (default; asks only for risky actions), Full auto (never asks; allowed but discouraged and clearly labelled).
- **Policy gate** before every tool call. Rules (including per-app rules like "never touch Slack", "read-only in my banking app") are enforced in code, not in the prompt, so the model cannot talk its way past them.
- **Stop phrase:** "Clara stop" (and pressing the hotkey again) halts speech, agents, and automations immediately. It is handled before any LLM call, even when the model is busy.
- Visible "pause everything" kill switch in the menu bar.
- Shell commands (if any) run with an allowlist; block `rm -rf`, `sudo`, disk and shutdown tools.
- Full audit log of every action with timestamps.
- Voice audio stays on the Mac.
- Updates opt-in; no auto-update from a moving branch.
- Data control: export all data, delete all data, one-step uninstall that removes app data and the Keychain entry.
- Autostart at login is opt-in.

## Milestones (finish and test each before the next)
1. Project shell: menu bar app, Option+Space hotkey, Keychain API key, Claude streaming call
2. Tool and permission framework, policy gate, audit log, kill switch
3. Instant-command router
4. Hands layer (Accessibility, `CGEvent`) with a small fixture app for tests
5. Screen reading (accessibility text, then screenshots) and active-context targeting
6. Trust foundation: action journal and undo, dry-run mode, stop phrase, per-app rules. Retrofit every tool to declare its undo and dry-run behaviour before adding new features.
7. Voice: hold-to-talk, live transcript, spoken replies, then barge-in and wake word (Part 3)
8. Cost meter and spend caps
9. Browser automation with the money-safety rules, tested with a fake browser and a local test page that mimics a booking flow
10. Skill learner
11. Memory, background tasks, routines, watchers
12. Later (only if wanted): clipboard assistant, file organizer, daily briefing, meeting notes

## Quality bar
- Unit tests for every module; integration tests with a fake hands/capture backend so tests do not need real UI.
- Latency timing logs per voice stage (see Part 3).
- Evals: a scripted scenario suite measuring task success and skill-replay reliability.
- Modular files (no multi-thousand-line files), strict typing, lint and format in CI (GitHub Actions free runners).
- README with install steps, a permissions section, a cost section (only Claude API costs money), and a security model section. Include `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`.

## First task
Set up the repo using the layout in Part 2. Save Part 2 as `docs/ARCHITECTURE.md` and create `docs/DECISIONS.md` (record any change you make to this design and why). Define the typed protocols and data models first, then implement Milestone 1. Stop and summarize when done.

## Open questions to ask the user before coding
1. Which macOS version is the Mac running? (Decides `SpeechAnalyzer` vs `SFSpeechRecognizer`.)
2. Which language will the user mostly speak? Apple's recognizer handles one language at a time, so mixed Tamil and English in one sentence will often fail. Default to English (India) and make the language a setting.
3. Which female voice does the user prefer? Offer a few installed voices to preview.

---

# PART 2: ARCHITECTURE (original design)

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

---

# PART 3: VOICE AND "FEELS HUMAN" SPEC

## 3.1 Triggers
- **Hotkey:** Option + Space. Support hold-to-talk and press-to-toggle.
- **Wake word:** "Clara". Optional and off by default until the user enables it.
  - Implementation: keep the mic stream running, run on-device recognition, and match the wake word at the start of the transcript. The rest of the sentence is the command. (macOS has no wake-word API for third-party apps, so this is transcript matching.)
  - Add "Clara" to the recognizer's custom vocabulary so it is heard reliably.
  - Show a clear menu bar indicator while the mic is open. Provide a one-click toggle.
  - Reduce false triggers (TV, meetings): require the wake word as the first word, ignore it when a meeting app is using the mic if detectable, and let the user pause it.
  - Recognition sessions can time out or reset; restart them seamlessly with no gap in listening. Verify the actual limits during testing.
- **Follow-up window:** for about 8 seconds after Clara finishes speaking, the user can reply without saying "Clara" again. This is what makes it feel like a conversation.

## 3.2 Barge-in (hard requirement)
**If the user starts speaking while Clara is talking, Clara must stop talking immediately and listen.**
- Keep the mic open and processed while Clara speaks. Use the audio engine's voice-processing / echo-cancellation so Clara does not hear and react to her own voice.
- Run voice-activity detection on the mic. When the user's speech is detected for a short threshold (start around 150 to 250 ms, tune by testing), do all of the following at once:
  1. Stop speech playback immediately (cancel the synthesizer at once, not at the end of the word).
  2. Switch the overlay to "Listening".
  3. Start capturing the user's utterance. Keep a short rolling audio buffer (about 0.5 to 1 s) so the first words of the interruption are not lost.
- Barge-in works without the wake word during a conversation and during the follow-up window. When no conversation is active, the wake word is still required.
- Interrupting speech does not automatically cancel running actions. Clara says "Okay" or just listens; then:
  - "Stop" or "cancel" halts actions too.
  - A correction ("no, the other one") redirects the current task.
  - A new unrelated request starts a new task; ask before abandoning a task that is mid-way and risky.
- Remember what Clara had already said, so after an interruption she does not repeat herself and can answer "what did you say?".
- Tests: simulate the user speaking over TTS (fake audio), verify playback stops within the latency budget, no echo self-triggering, and the first words of the interruption are captured.

## 3.3 Make it feel like a human assistant
- **Short, natural replies.** "Done, Uber is open." "Sure, one second." Avoid long, formal, or list-like speech. Never read out URLs, IDs, or code unless asked.
- **Acknowledge fast.** Speak a brief acknowledgement ("On it", "Sure") as soon as the request is understood, before the work finishes. Vary the phrasing so it is not repetitive.
- **Stream speech.** As Claude's reply streams in, start speaking at the first complete sentence rather than waiting for the whole answer.
- **Narrate lightly during long tasks.** Short progress notes only when a task takes more than a few seconds ("Searching flights now"), never a play-by-play.
- **Ask one question at a time**, and only when truly needed. Make reasonable assumptions otherwise and say what she assumed.
- **Natural confirmations.** For risky actions read back only the key facts, then wait. Example: "That's IndiGo 6E-512 at 7:10, 3,450 rupees. I've stopped at the payment page, it's yours to tap."
- **Handle mishearing gracefully.** If unsure, say "I didn't catch that" or repeat what she heard and ask. Never guess on risky actions.
- **Interruptible everywhere.** Barge-in applies to every spoken response.
- **Consistent personality.** Warm, calm, concise, a little friendly. Not chatty, not robotic. No emoji in speech. Keep the persona in one editable config file.
- **Voice choice.** Female voice by default; the user can pick any installed system voice and speaking rate in settings. Prefer enhanced or premium Apple voices when installed.
- **Quiet by default.** In meetings or when the user is on a call, avoid speaking unless addressed; fall back to a notification where speech would be disruptive.

## 3.4 Latency budget (log every stage; CI fails on regressions)
- Hotkey press to first partial transcript
- Speech end to final transcript
- Final transcript to first model token
- First token to first spoken word
- First token to first action
- User starts speaking to Clara stops speaking (barge-in)

Targets (tune after measuring on real hardware): barge-in stop under about 250 ms; instant commands act within about 1 s of speech end.

## 3.5 Optional dictation mode
"Clara, dictate" types the user's words into the focused field. Use one quick, cheap model call to remove fillers and fix self-corrections. Reject any cleanup that drops a sentence the user said and fall back to the raw transcript.

## 3.6 Voice limits to handle honestly
- One recognition language at a time; mixed languages in a sentence may fail. Make the language a setting.
- Names of apps and places may be misheard. Maintain a custom vocabulary list (for example Uber, IndiGo, MakeMyTrip, contact names) and let the user add words.
- Anyone nearby can speak to the Mac. Keep the hotkey available as the more private trigger, and require read-back confirmation for risky actions.
- Noisy rooms reduce accuracy; prefer "I didn't catch that" over guessing.

---

# PART 4: VISUAL DESIGN SPEC (small UI only)

Clara is voice-first, so the UI is small: a menu bar icon, a voice overlay, an optional activity-log window, and settings.

## Mood
Dark, calm, minimal, a little technical. Near-black surfaces, thin borders, one mint accent, one amber warning color. Static and quiet; the only motion is the voice orb.

## Design tokens
- Background: `#0b0b0c` (app), `#141416` (panels and cards)
- Border and dividers: `#28282a`
- Text: `#ffffff` primary, `#c4c2c3` secondary, `#9a9a9c` muted
- Accent (success, verified, active): mint `#6ee7b7`
- Warning (approval needed, risk): amber `#f5b25b`
- Danger (deny, stop): a muted red, defined once as a token
- Provide a light theme with the same structure; dark is the default.
- Use the system font unless a bundled font is added later (bundle locally, record its license in `THIRD_PARTY.md`).
- 8px spacing grid, small radii, 1px borders, no heavy shadows, no decorative gradients.

## Voice overlay (small, always on top, does not steal focus)
- A live orb that breathes slowly when idle, reacts to the user's voice level, and shows soft rings while Clara speaks.
- State label ("Listening", "Thinking", "Acting", "Speaking"), the live transcript under it, and a hint line.
- Appears on the display where the mouse is, then fades away. Appears on every desktop/space above normal apps without stealing focus; where macOS blocks this (some fullscreen cases), fall back to a notification and a menu bar indicator.
- Respect Reduce Motion (disable the animation).
- Show the current target ("Screen 2, Chrome, Inbox") so the user can see what Clara is about to read or act on, and let them correct it by voice.

## Activity log and approvals window (optional)
- Compact steps with a mint "verified" tag, amber approval cards (what needs approval, risk label, key fields, Approve / Deny / Edit buttons), the cost meter, and permission states. Approvals can also be given by voice.

## Rules
- Every state needs an empty, loading, and error version, with a fix button on errors.
- Keyboard accessible, visible focus rings, VoiceOver labels, WCAG AA contrast.
