# CC Session Counter — macOS Menu Bar App

## Goal
A lightweight macOS menu bar app that shows Claude Code usage at a glance — utilization %, reset times, and rate limit status — without needing to open the Claude desktop app.

---

## Research Findings

### The golden data source: API response headers

Every Claude Code API call returns these rate-limit headers:

```
anthropic-ratelimit-unified-status: allowed          # current status (allowed/rejected)
anthropic-ratelimit-unified-5h-status: allowed       # 5-hour window status
anthropic-ratelimit-unified-5h-reset: 1775696400     # Unix timestamp when 5h window resets
anthropic-ratelimit-unified-5h-utilization: 0.19     # 5h window: 19% used
anthropic-ratelimit-unified-7d-status: allowed       # 7-day window status
anthropic-ratelimit-unified-7d-reset: 1775790000     # Unix timestamp when 7d window resets
anthropic-ratelimit-unified-7d-utilization: 0.51     # 7d window: 51% used
anthropic-ratelimit-unified-representative-claim: five_hour  # which window is the binding constraint
anthropic-ratelimit-unified-fallback-percentage: 0.5 # fallback threshold
anthropic-ratelimit-unified-reset: 1775696400        # overall reset time
anthropic-ratelimit-unified-overage-status: rejected  # overage billing status
anthropic-ratelimit-unified-overage-disabled-reason: org_level_disabled
anthropic-organization-id: 523c9068-6425-418c-a53b-c872d5bf2637
```

### How to get this data

**Option A: Direct API call with OAuth token (preferred)**
- OAuth token stored in macOS Keychain under `"Claude Code-credentials"`
- Token works against `api.anthropic.com/v1/messages` when the `anthropic-beta: oauth-2025-04-20` header is included
- Make a minimal API call (1 token max_tokens, cheapest model) to get rate-limit headers back
- Token includes `refreshToken` and `expiresAt` for automatic refresh
- Keychain also reveals: `subscriptionType: "team"`, `rateLimitTier: "default_claude_max_5x"`

**Option B: Piggyback on Claude Code debug logs**
- `ANTHROPIC_LOG=debug claude -p "hi"` dumps full response headers to stderr
- Parse the headers from stderr output
- Downside: spawns a full Claude Code process, slower, uses tokens

**Option C: Watch for headers passively (hooks)**
- Claude Code supports hooks (PostToolUse, SessionStart, etc.)
- Could install a hook that captures rate-limit headers from every real Claude Code call
- Zero extra API cost — piggybacks on organic usage
- Downside: only updates when user is actively using Claude Code

### Supplementary local data (free, no API calls)

| Source | Data | How to use |
|--------|------|------------|
| `~/.claude/sessions/*.json` | `{pid, sessionId, cwd, startedAt, kind}` | Show active sessions, session duration |
| `~/.claude/history.jsonl` | Commands with timestamps + sessionIds | Activity feed, session count |
| Keychain `Claude Code-credentials` | `subscriptionType`, `rateLimitTier`, `expiresAt` | Show plan tier, token expiry |
| `--print --output-format json` | Per-call `usage.input_tokens`, `usage.output_tokens`, `total_cost_usd` | Per-call cost tracking |

---

## Architecture

### Tech Stack
| Component | Choice | Why |
|-----------|--------|-----|
| Language | **Swift** | Native macOS, Keychain access, process spawning. You already know Swift (SwipeControl). |
| UI | **SwiftUI + MenuBarExtra** | Built-in menu bar support (macOS 13+) |
| Data fetch | **URLSession** | Direct HTTPS to `api.anthropic.com` with OAuth token |
| Keychain | **Security.framework** | Read Claude Code's stored OAuth credentials |
| Local data | **FileManager + JSONDecoder** | Watch `~/.claude/sessions/` and `history.jsonl` |

### Data Flow

```
┌─────────────────────────────┐
│  macOS Keychain              │
│  "Claude Code-credentials"   │
│  → OAuth access/refresh token│
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐     ┌──────────────────────────┐
│  Lightweight API probe       │────▶│ Parse response HEADERS   │
│  POST /v1/messages           │     │ (not the body)           │
│  model: claude-haiku-4-5     │     │ → utilization %          │
│  max_tokens: 1               │     │ → reset timestamps       │
│  "hi"                        │     │ → status (allowed/reject)│
└─────────────────────────────┘     └──────────┬───────────────┘
                                               │
┌─────────────────────────────┐                │
│  ~/.claude/sessions/*.json   │────┐          │
│  ~/.claude/history.jsonl     │    │          │
│  Keychain metadata           │    │          ▼
└─────────────────────────────┘    │  ┌───────────────────────┐
                                   └─▶│  Menu Bar UI           │
                                      │  ◉ 19% (5h) · 51% (7d)│
                                      └───────────────────────┘
```

### Menu Bar Design

**Icon:** Custom-drawn 16px circular progress arc using `NSImage` + `CGContext`. The arc fills proportionally to the binding constraint's utilization %. Color shifts green→yellow→red:
- 0–50%: green
- 50–80%: yellow  
- 80–100%: red

The arc is drawn fresh on each data update via `CGContext` and set as the `MenuBarExtra` image.

**Dropdown:**
```
┌──────────────────────────────────┐
│  Claude Code Usage          Max5x│
│──────────────────────────────────│
│  5h window     19%  ██░░░░░░░░  │
│  Resets in 2h 15m                │
│                                  │
│  7d window     51%  █████░░░░░  │
│  Resets in 1d 4h                 │
│──────────────────────────────────│
│  Status: ✅ Allowed              │
│  Binding: 5-hour window          │
│  Overage: Disabled (org)         │
│──────────────────────────────────│
│  Active sessions: 1              │
│  This session: 45m               │
│  Today: 4 sessions               │
│──────────────────────────────────│
│  ⟳ Refresh      ⚙ Settings      │
│  Quit                            │
└──────────────────────────────────┘
```

### Polling Strategy
- **On launch:** Fetch immediately
- **Passive mode:** Every 5 minutes (configurable)
- **Watch `~/.claude/sessions/`:** When new session files appear, fetch fresh data
- **Smart backoff:** If utilization > 90%, poll more frequently (every 1 min) to catch the reset

### Token Refresh
- Keychain stores `expiresAt` — check before each API call
- If expired, use `refreshToken` to get new access token
- Store updated token back to Keychain (so Claude Code picks it up too)

---

## Implementation Phases

### Phase 1: Core MVP
1. Read OAuth token from Keychain
2. Make probe API call, parse rate-limit headers
3. Display utilization in menu bar icon + dropdown
4. Timer-based polling

### Phase 2: Local enrichment
5. Watch `~/.claude/sessions/` for active session tracking
6. Parse `history.jsonl` for daily session count
7. Show session info in dropdown

### Phase 3: Polish
8. Dynamic icon (color-coded utilization)
9. Notification when approaching limit (e.g., 80%)
10. Notification when rate limit resets
11. Settings (poll interval, notifications)

### Phase 4: Zero-cost mode (optional)
12. Claude Code hook that captures headers from organic usage
13. Fall back to probe API call only when no recent organic data
