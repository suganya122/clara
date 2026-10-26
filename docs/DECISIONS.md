# Decisions

Changes to the original design, and why.

## 1. Swift Package instead of an Xcode project
`Package.swift` with `Sources/<Module>` replaces the `Clara/` layout in Part 2. One command (`swift build`, `swift test`, `swift run`) works on a Mac and on GitHub's runners with no Xcode project to maintain. Voice, Hands, Capture, Skills and BrowserHelper modules are added in the milestone that needs them (SwiftPM does not allow empty targets). The rule that Core imports only Contracts is kept.

## 2. Neutral package and target names
The brief says the assistant's name must not appear in package names. The package is `Assistant`, the executable is `assistant-app`, and the Keychain service is `app.assistant.anthropic`. The name "Clara" appears only in `Core/AppConfig.swift`.

## 3. Temporary text overlay for Milestone 1
Voice is Milestone 7. Until then, Option+Space opens a small panel with a text field so the hotkey, Keychain and streaming call can be tested end to end. It is replaced by the live-transcript overlay later.

## 4. Option+Space via Carbon `RegisterEventHotKey`
It needs no Accessibility permission and reports key press and release, which hold-to-talk needs. If another app owns Option+Space the menu bar tooltip says so.

## 5. Model names live in `ClaudeConfig`
`ClaudeConfig.defaultTierModels` holds one alias per tier (no dates or version numbers). A test fails if a date-pinned name is added. These aliases should be checked against the API once, and a settings override added in Milestone 8.

## 6. Swift 5 language mode
`swift-tools-version:5.9` keeps strict-concurrency errors out while the code is written without a local compiler. Revisit once CI is green.

## 7. Run via `swift run`, no app bundle yet
Microphone and Speech permissions need an `Info.plist` with usage strings, so an app bundle script arrives with Milestone 7. Milestone 1 needs no permissions.
