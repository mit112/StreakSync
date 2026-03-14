# Claude Code: Complete Setup & Best Practices Guide

**Last updated**: March 13, 2026
**Context**: Set up for StreakSync (iOS/SwiftUI, Firebase backend) on Mac Mini M4, authenticated via Claude Enterprise (Northeastern University)

---

## Part 1: Core Concepts

Claude Code is Anthropic's terminal-based agentic coding tool. Unlike IDE-embedded AI, it operates as a full agent — reading your codebase, executing commands, editing files, and managing git autonomously. The single most important thing to understand: **context management is the fundamental skill**. Claude's ~200K token context window (1M on Opus) fills up, and performance degrades as it fills. Every best practice flows from this constraint.

### How Claude Code Works

- No pre-indexing or database — uses `glob` and `grep` to navigate just-in-time
- CLAUDE.md is loaded upfront as persistent context (survives compaction)
- Operates from whatever directory you launch it in
- Has full terminal access — can run builds, tests, git, and any CLI tool
- Creates checkpoint commits for instant rollback (Escape twice to undo)

---

## Part 2: Installation & Authentication

### Install (native binary, auto-updates)

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

If migrating from the old npm version: `npm uninstall -g @anthropic-ai/claude-code`

Verify health: `claude doctor`

### Authentication Options

| Method | How | Best for |
|--------|-----|----------|
| Subscription (Pro/Max/Enterprise) | OAuth via browser on first launch | Daily development |
| API key | `export ANTHROPIC_API_KEY=sk-...` | CI/CD, automation |
| Cloud providers | `CLAUDE_CODE_USE_BEDROCK=1` etc. | Enterprise |

**Critical**: If `ANTHROPIC_API_KEY` exists in your shell environment while on a subscription, Claude Code silently uses API billing. Check with `echo $ANTHROPIC_API_KEY` and use `/status` inside Claude Code to verify.

### Shell Integration

Run `/terminal-setup` inside Claude Code to enable Shift+Enter for multi-line input.

---

## Part 3: Configuration Files & What They Do

### CLAUDE.md — Your highest-leverage investment

Persistent memory that survives context compaction. Think of it as onboarding for an amnesiac but brilliant developer who joins fresh every session.

**Placement hierarchy** (files load in order of specificity):

| Location | Scope | Shared? |
|----------|-------|---------|
| `~/.claude/CLAUDE.md` | All projects | Personal |
| `./CLAUDE.md` (project root) | This project | Via git |
| `./CLAUDE.local.md` | This project, personal | Gitignored |
| `./subdirectory/CLAUDE.md` | Module-specific | Loaded on-demand |

**Best practices**:
- Keep under 200 lines (50 lines ≈ 2,000 tokens, <1% of context)
- Bullet points are 40% more likely to be followed than paragraphs
- Document what Claude gets wrong, not what it already does correctly
- Don't replicate what linters enforce
- Generate initial version with `/init`, then ruthlessly edit

### .claudeignore — Token saver

Works like .gitignore. Blocks files from Claude's view entirely. This is the single biggest token optimization.

### .claude/settings.json — Permissions & hooks

Controls what Claude can do without asking. Precedence: enterprise → project → local → user.

### Global settings (~/.claude/settings.json)

Model and effort level defaults.

---

## Part 4: What We Set Up for StreakSync

### File structure created

```
StreakSync/
├── CLAUDE.md                          # Project instructions (committed to git)
├── .claudeignore                      # Token savings (gitignored)
├── .claude/
│   ├── settings.json                  # Permissions + SwiftLint hook (gitignored)
│   ├── commands/
│   │   ├── fix-build.md               # /fix-build — iterative build error fixer
│   │   ├── fix-lint.md                # /fix-lint — SwiftLint violation fixer
│   │   ├── fix-tests.md              # /fix-tests — test failure diagnoser
│   │   ├── review.md                  # /review — code review on uncommitted changes
│   │   └── review-social.md           # /review-social — deep architectural review of friends/leaderboard
│   └── skills/
│       └── swiftui-pro/               # Paul Hudson's SwiftUI Agent Skill
│           ├── SKILL.md
│           ├── agents/
│           └── references/            # 9 reference docs (APIs, accessibility, performance, etc.)
~/.claude/
├── CLAUDE.md                          # Global personal preferences
└── settings.json                      # Model: Opus 4.6 (1M), effort: medium
```

### CLAUDE.md highlights

The project CLAUDE.md includes:
- **Critical Rules**: Never touch .xcodeproj/.pbxproj, never edit assets/storyboards/xcstrings
- **API Standards**: Modern SwiftUI APIs enforced (NavigationStack, @Observable, foregroundStyle, async/await)
- **Observation pattern protection**: AppContainer stays ObservableObject (required by @EnvironmentObject), AppState/GameCatalog stay @Observable — explicitly noted to prevent Claude from "helpfully" unifying them
- **Workflow Rules**: Auto-consult swiftui-pro skill when writing/modifying SwiftUI views
- **Build commands**: Full xcodebuild commands with correct flags (CODE_SIGNING_ALLOWED=NO, -skipPackagePluginValidation)
- **Architecture**: Targets, DI pattern, AppState decomposition, service layer, Share Extension pipeline, game system, social/leaderboard, Firestore rules
- **Code conventions**: SwiftLint rules, file headers, Logger over print, @MainActor requirements

### .claudeignore contents

Blocks: build artifacts, DerivedData, all .xcresult bundles (~30+ in project), .xcodeproj internals, asset catalogs, .xcstrings, storyboards, xibs, node_modules, Pods, Cursor artifacts, session notes, module analysis docs.

### Permissions (.claude/settings.json)

**Allowed without prompting**: Read all files, xcodebuild, swift, git, grep, find, cat, swiftlint, xcpretty, ls, head, tail, wc.

**Denied**: Reading .env files, `rm -rf`.

**File writes still prompt** — intentional for early trust-building. Add `"Write(StreakSync/**)"` to allow list once comfortable.

### SwiftLint hook

Runs automatically after every `.swift` file write:
```json
"PostToolUse": [{
  "matcher": "Write(*.swift)",
  "hooks": [{
    "type": "command",
    "command": "swiftlint lint --quiet --path \"$CLAUDE_FILE_PATH\" 2>/dev/null || true"
  }]
}]
```

Claude sees lint violations in real-time and self-corrects before you review.

### MCP Servers

| Server | Status | Purpose |
|--------|--------|---------|
| XcodeBuildMCP | ✅ Connected | Build, test, debug, simulator screenshots — essential for iOS |
| Context7 | ⬜ To configure | Live API docs to prevent deprecated API hallucination |

**XcodeBuildMCP** provides ~59 tools. Without it, Claude can edit Swift files but is blind to the build system. Multiple iOS developers call it "critical to being productive at all."

**Context7** correct install command: `claude mcp add context7 -- npx -y @upstash/context7-mcp`
(The `@anthropic-ai/context7-mcp` package doesn't exist — use `@upstash/context7-mcp`)

### Custom Slash Commands

| Command | What it does |
|---------|-------------|
| `/fix-build` | Builds project, reads errors, fixes iteratively until green. Won't touch .xcodeproj. |
| `/fix-lint` | Runs SwiftLint, auto-corrects with `--fix`, manually fixes the rest. |
| `/fix-tests` | Runs tests, diagnoses failures, asks before deleting/modifying tests. |
| `/review` | Reviews `git diff` for correctness, conventions, deprecated APIs, test coverage. |
| `/review-social` | Deep architectural review of the entire friends/leaderboard module (18+ files). Uses "ultrathink" for maximum reasoning. |
| `/swiftui-pro` | From the SwiftUI Agent Skill — reviews SwiftUI code against 9 reference documents. |

### Global CLAUDE.md (~/.claude/CLAUDE.md)

Personal preferences applied to all projects:
- Direct and concise communication
- Swift/SwiftUI primary stack
- Value types over classes, async/await over GCD
- Protocol-oriented with prod + mock implementations
- OSLog Logger over print
- Descriptive commit messages in imperative mood

### .gitignore additions

Added `.claude/` and `.claudeignore` to StreakSync's .gitignore so personal config stays local.

---

## Part 5: Daily Workflow

### The explore → plan → code → commit loop

This is the #1 consensus best practice across all sources:

1. **Explore**: "Read the files related to [X] and explain the current implementation. Don't write code yet."
2. **Plan**: Shift+Tab twice (or `/plan`). Use "ultrathink" for complex decisions.
3. **Code**: "Implement the plan. After changes, build to verify."
4. **Commit**: Review diffs, commit with descriptive message.

Skipping steps 1-2 produces measurably worse results.

### Essential commands

| Command | When to use |
|---------|-------------|
| `/cost` | Check token usage and estimated cost |
| `/compact` | At ~70% context capacity (don't wait for auto-compact at 95%) |
| `/clear` | Between unrelated tasks (use liberally) |
| `/model` | Switch models mid-session |
| `/context` | See what's consuming your context window |
| `/mcp` | Check MCP server status |
| `/skills` | View installed skills |
| Escape | Interrupt mid-generation |
| Escape × 2 | Undo last changes (checkpoint rollback) |
| Option+P | Switch model while typing |

### Thinking keywords (progressive budget)

Include in prompts for progressively deeper reasoning:
"think" < "think hard" < "think harder" < "ultrathink"

These are per-turn — include in every prompt where you need deep reasoning.

### Prompting strategies

- **Be specific**: "Fix the null check on line 45 of AuthService.swift" >> "fix the bug"
- **Reference files directly**: Use `@filename` to include file content
- **Drag-and-drop screenshots** for visual feedback
- **Paste URLs** to docs or Stack Overflow for context
- **Interview pattern** for complex features: "I want to build [X]. Interview me about requirements before planning."
- **If correcting more than twice**: `/clear` and write a better initial prompt

### Git workflow

- Claude handles git natively — branches, commits, pushes, PR creation (via `gh` CLI)
- Commits include Co-Authored-By attribution automatically
- **Always review diffs** before approving commits
- **Work on feature branches** — never let Claude commit to main
- **Worktrees for parallel work**: `claude --worktree feature-auth` for isolated instances

---

## Part 6: iOS-Specific Knowledge

### Swift/SwiftUI strengths and blind spots

Claude handles most Swift features up to 5.5 well. Specific problem areas:
- **Swift Concurrency (5.5+)**: Struggles with async/await, actors, Sendable. Falls back to GCD.
- **Deprecated APIs**: Defaults to @StateObject/ObservableObject, NavigationView, foregroundColor()
- **Legacy mixing**: Uses UIKit/AppKit where SwiftUI exists

All mitigated by the API Standards section in CLAUDE.md and the swiftui-pro skill.

### The .pbxproj rule

**Never let Claude edit .xcodeproj/.pbxproj.** This is the #1 cited issue. Solutions:
- Xcode 16+: Use folder references (blue folders) — files added on disk auto-appear in Xcode
- XcodeGen/Tuist: Generate from manifest
- SPM: Package.swift is plain Swift, Claude handles it well

### For storyboards, XIBs, asset catalogs, .xcstrings

Manage manually. No one reports Claude successfully editing these.

### XcodeBuildMCP

Closes the build-test feedback loop. Install: `claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp`

### Paul Hudson's SwiftUI Agent Skill

Install by cloning into `.claude/skills/swiftui-pro/`. Ensure `SKILL.md` is directly inside (not nested). Provides 9 reference docs: deprecated APIs, views, data flow, navigation, design/HIG, accessibility, performance, Swift patterns, hygiene.

Invoked automatically when CLAUDE.md includes the workflow rule, or manually via `/swiftui-pro`.

---

## Part 7: Advanced Features (Learn When Needed)

### Custom skills

Reusable slash commands in `.claude/skills/<name>/SKILL.md` or `.claude/commands/<name>.md`. Support dynamic context injection with `!` prefix (runs shell commands during preprocessing).

### Hooks

Shell commands at lifecycle points: `SessionStart`, `UserPromptSubmit`, `PreToolUse` (can block with exit 2), `PostToolUse`, `SubagentStop`. Configure in settings.json or via `/hooks`.

### Subagents

Define in `.claude/agents/<name>.md`. Run in separate context windows for parallel tasks. Good for exploration that would bloat main context.

### GitHub Actions

`/install-github-app` for automated PR reviews. `@claude` in issues triggers fixes. Action: `anthropics/claude-code-action@v1`.

### Git worktrees

`claude --worktree feature-name` for isolated parallel instances.

---

## Part 8: Pricing & Cost Control

### Plan comparison

| Plan | Price | Claude Code | Opus | Best for |
|------|-------|-------------|------|----------|
| Pro | $20/mo | ✅ | ❌ | Learning, light use |
| Max 5x | $100/mo | ✅ | ✅ | Professional daily dev |
| Max 20x | $200/mo | ✅ | ✅ | Heavy full-time coding |
| API | Pay-per-token | ✅ | ✅ | CI/CD, full cost control |

Subscription uses rolling 5-hour windows + weekly caps. Pro users can hit limits in ~30 minutes of intensive coding.

### API pricing (March 2026)

| Model | Input/MTok | Output/MTok | Cache Read/MTok |
|-------|-----------|-------------|-----------------|
| Opus 4.6 | $5.00 | $25.00 | $0.50 |
| Sonnet 4.6 | $3.00 | $15.00 | $0.30 |
| Haiku 4.5 | $1.00 | $5.00 | $0.10 |

Cache reads are 90%+ of Claude Code tokens, making effective costs much lower.

### Cost optimization

- **Model selection is the primary lever**: Sonnet for routine work, Opus for complex architecture/debugging
- **Context hygiene**: `/compact` at 70%, `/clear` between tasks, `.claudeignore` for token savings
- **Disable unused MCP servers** via `/mcp` — each adds tokens per turn
- **Use `/cost`** regularly to monitor session spend
- Average API spend: ~$6/developer/day (90% under $12/day)

---

## Part 9: Common Mistakes to Avoid

1. **No CLAUDE.md** — Claude rediscovers your stack every session
2. **Kitchen-sink sessions** — mixing unrelated tasks pollutes context
3. **Marathon sessions without compacting** — quality degrades after 30+ minutes
4. **Correcting more than twice** — `/clear` and rewrite the prompt instead
5. **Using Opus for everything** — Sonnet handles most tasks at ~1/5 the cost
6. **Trusting auto-accept on important code** — always review diffs manually
7. **Overloading CLAUDE.md** — past 200 lines, adherence drops
8. **Installing too many MCP servers** — each adds context overhead; start with 2-3

---

## Part 10: Quick Reference Card

```
# Start a session
cd /path/to/project && claude

# Key shortcuts
Escape           → interrupt generation
Escape × 2       → undo last changes
Shift+Tab × 2    → toggle plan mode
Option+P          → switch model while typing

# Session management
/cost             → token usage
/compact          → compress context (use at 70%)
/clear            → full reset
/model            → switch model
/context          → see context breakdown

# Custom commands (StreakSync)
/fix-build        → build + fix errors iteratively
/fix-lint         → SwiftLint fix
/fix-tests        → run + fix test failures
/review           → review uncommitted changes
/review-social    → deep friends/leaderboard audit
/swiftui-pro      → SwiftUI best practices review

# MCP management
/mcp              → server status
claude mcp add    → add server
claude mcp remove → remove server

# Git via Claude
"create a branch called feature-xyz"
"commit these changes"
"show me the diff"
"create a PR for this branch"
```
