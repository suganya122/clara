# Voice-first Mac assistant

A voice-first personal assistant for macOS. Status: **Milestone 1** (menu bar app, Option+Space hotkey, Keychain API key, streaming Claude call). Full plan: [docs/BUILD_BRIEF.md](docs/BUILD_BRIEF.md). Design: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Changes to the design: [docs/DECISIONS.md](docs/DECISIONS.md).

## Install and run (macOS 14+, macOS 26 recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/suganya122/clara/main/install.sh | bash
```

This downloads the source, builds it, then starts the menu bar app. Re-run to update. To build with tests instead: `git clone https://github.com/suganya122/clara.git && cd clara && ./scripts/mac-setup.sh`.

The app starts Look for the waveform icon. On first launch it asks for your Anthropic API key and stores it in the Keychain. Press **Option+Space**, type a request, press Return.

## Cost

Only the Claude API costs money. There is no telemetry, no hosted backend and no paid speech service. The default model tier is the cheapest, and the system prompt is prompt-cached.

## Security model

- The API key lives in the macOS Keychain only. It is never logged or written to disk.
- "Clara stop" is handled before any model call.
- Policy gate, audit log and approvals arrive in Milestone 2.

## Develop

```bash
swift build && swift test
```

CI runs the same two commands on GitHub's macOS runner. Licence: MIT.
