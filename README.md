# CCSessionCounter

A lightweight macOS menu bar app that shows your Claude Code usage at a glance — utilization %, reset times, and rate limit status — without needing to open the Claude desktop app.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **5-hour and 7-day utilization** with colour-coded progress bars
- **Reset countdowns** so you know exactly when your window clears
- **Rate limit status** — allowed or limited at a glance
- **Monochrome or colour icon** to match your menu bar preference
- **Configurable refresh interval** (5–30 minutes; bumps to 1 min automatically when you're over 80%)

## Requirements

- macOS 13 Ventura or later
- [Claude Code](https://claude.ai/code) installed and signed in at least once (the app reads your OAuth token from the macOS Keychain)

## Installation

```bash
git clone https://github.com/JoshTickles/cc-session-counter.git
cd cc-session-counter
make install
```

This builds a release binary, bundles the `.app`, and copies it to `/Applications`.

## First launch — two prompts you'll see

### 1. Gatekeeper warning

Because the app is not notarized, macOS will block it on first open:

> *"CCSessionCounter" can't be opened because Apple cannot check it for malicious software.*

**Fix:** Right-click (or Control-click) the app in Finder → **Open** → **Open** again in the dialog. You only need to do this once.

### 2. Keychain access prompt

The app reads your Claude Code OAuth token from the macOS Keychain to make lightweight API calls and retrieve your rate-limit headers. On first launch you'll see:

> *CCSessionCounter wants to use your confidential information stored in "Claude Code-credentials" in your keychain.*

Click **Always Allow** so it doesn't prompt on every refresh.

## How it works

On each refresh, the app makes a minimal API call (`max_tokens: 1`) to `api.anthropic.com` using your existing Claude Code OAuth token. The response headers contain your current utilization and reset times — no body content is processed. The token is read-only from the Keychain and never transmitted anywhere other than Anthropic's API.

## Settings

Click **Settings** in the menu dropdown to configure:

- **Monochrome icon** — matches the style of most macOS menu bar apps
- **Refresh every** — 5, 10, 15, or 30 minutes

## Building from source

```bash
# Debug build
swift build

# Release + bundle
make bundle

# Release + bundle + install to /Applications
make install
```

## Created by

[Josh Angel](https://github.com/JoshTickles)
