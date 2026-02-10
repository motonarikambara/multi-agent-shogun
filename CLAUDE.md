# Paper Writing System - Multi-Agent Academic Writing Framework

> **Version**: 1.0
> **Last Updated**: 2026-02-05

## Overview

This system is a multi-agent framework specialized for academic paper writing.
One author and three reviewers collaborate to produce high-quality paper paragraphs through rigorous rebuttal cycles.

## Agent Configuration

```
User (You)
 │
 ▼ Provide question & answer
┌──────────────────────────────────────┐
│            AUTHOR                    │
│  - Write paragraphs                  │
│  - Ask user for clarification        │
│  - Engage in rebuttal with reviewers │
│  - Append approved text to tex       │
└──────────────┬───────────────────────┘
               │ Rebuttal Phase
   ┌───────────┼───────────┐
   ▼           ▼           ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│REVIEWER1│ │REVIEWER2│ │REVIEWER3│
│ Novelty │ │  Rigor  │ │ Clarity │
└─────────┘ └─────────┘ └─────────┘
     │           │           │
     └───────────┴───────────┘
       All Approve → Complete
```

## Session Start Protocol

When starting a new session, execute the following before any work:

1. **Verify your ID**: `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'`
   - `author` → You are the Author
   - `reviewer1` ~ `reviewer3` → You are Reviewer 1-3
2. **Read your instructions**:
   - Author → instructions/author.md
   - Reviewer → instructions/reviewer.md
3. **Begin work following your instructions**

## File Operation Rules

- **Always Read before Write/Edit.** Claude Code refuses Write/Edit on unread files.

## Communication Protocol

### Event-Driven Communication (YAML + send-keys)
- Polling is forbidden (saves API costs)
- Content is written to YAML files
- Notifications via tmux send-keys (always use Enter)
- **send-keys must be split into 2 Bash calls**:
  ```bash
  # Call 1: Send message
  tmux send-keys -t paper:0.1 'Message content'
  # Call 2: Send Enter
  tmux send-keys -t paper:0.1 Enter
  ```

### Pane Configuration

```
tmux session: paper
├── Pane 0: author
├── Pane 1: reviewer1 (Contributions & Claims)
├── Pane 2: reviewer2 (Technical Soundness & Methodology)
└── Pane 3: reviewer3 (Presentation & Language Authenticity)
```

## File Structure

```
paper/
  main.tex              # Main document (uses \input for sections)
  drafts.md             # Approved drafts as reference (append to section later)
  sections/
    abstract.tex        # Abstract content
    introduction.tex    # Introduction content
    related_work.tex    # Related Work content
    method.tex          # Method content
    experiments.tex     # Experiments content
    results.tex         # Results content
    discussion.tex      # Discussion content
    conclusion.tex      # Conclusion content

context/
  author_habits.yaml    # Author's writing habits checklist (updated by reviewers/user)
  glossary.yaml         # Terminology, notation, claims registry (for efficient consistency)
  references.md         # Reference text/examples (user pastes, Author consults)

queue/
  draft/
    current.yaml        # Current draft (Author → Reviewers)
  reviews/
    reviewer1.yaml      # Reviewer 1 comments
    reviewer2.yaml      # Reviewer 2 comments
    reviewer3.yaml      # Reviewer 3 comments
  rebuttal/
    history.yaml        # Discussion history
  control.yaml          # User intervention commands (PAUSE/REDIRECT/SKIP)

config/
  settings.yaml         # System settings

instructions/
  author.md             # Author instructions
  reviewer.md           # Reviewer instructions

web/
  server.py             # Web dashboard server (Flask + SocketIO)
  requirements.txt      # Python dependencies
  .venv/                # Virtual environment (auto-created by uv)
  templates/
    index.html          # Dashboard UI
```

## Model Selection

Available models (set via command line or Web UI):
- **opus** (default): Most capable, highest quality
- **sonnet**: Balanced capability/cost

```bash
# Command line
./start.sh --web -m sonnet

# Web UI: Header dropdown → Settings saved to config/settings.yaml
```

## Web Dashboard (Optional)

Start with `./start.sh --web` for a browser-based real-time view.

- **URL**: http://127.0.0.1:5050 (default)
- **Real-time**: Uses WebSocket to push updates when YAML files change
- **Terminal Output**: Shows all 4 agent terminals in browser (no tmux attach needed)
- **Notifications**: 🔔 button enables sound/browser alerts when waiting for input
- **Environment**: Uses `uv` for Python package management (auto-installed)

**Server Commands:**
```bash
# Stop web server
pkill -f "server.py --port 5050"

# Start web server
cd web && uv run python server.py --port 5050 &

# Restart
pkill -f "server.py --port 5050"; sleep 1; cd web && uv run python server.py --port 5050 &
```

## Efficient Consistency Checking

To avoid token explosion from reading full paper every time:

| File | Size | Purpose |
|------|------|---------|
| `context/references.md` | Variable | User's style examples (Author reads for style) |
| `context/author_habits.yaml` | ~50 lines | Author's bad habits to check |
| `context/glossary.yaml` | ~100 lines | Canonical terms, notation, claims |
| `paper/sections/*.tex` | 1000s lines | Full paper (read only when needed) |

**Workflow:**
1. Author reads references.md for style guidance
2. Read habits + glossary for consistency checking
3. Only read full sections if glossary doesn't answer your question
4. Author updates glossary after each approved paragraph

## Workflow

### Phase 1: Writing

1. User provides "question" and "answer" to Author
2. Author asks for clarification if needed
3. Author writes the paragraph
4. User says "OK" → Proceed to Phase 2

### Phase 2: Initial Review (Parallel)

1. Author writes draft to `queue/draft/current.yaml`
2. Author notifies all 3 reviewers via send-keys
3. Reviewers review in parallel (each writes to `queue/reviews/reviewerN.yaml`)
4. **Reviewers must also read `paper/main.tex` to check consistency with existing content**
5. When all reviews are complete, notify Author

### Phase 3: Rebuttal (Auto)

After user says "ok", rebuttal runs automatically until all reviewers approve:

1. Author checks `queue/control.yaml` for intervention commands (PAUSE/REDIRECT/SKIP)
2. Author responds to each comment & revises text (user feedback = highest priority)
3. Author updates `queue/draft/current.yaml`
4. Reviewers: Approve or provide additional comments
5. All Approve → Phase 4
6. Not all approve → Loop from step 1

User can intervene at any time with `PAUSE`, `redirect:`, `skip reviewer N`.

### Phase 4: Completion

1. Author auto-saves to the section specified in the Q&A input (`section:` field)
2. If no section was specified, saves to `paper/drafts.md`
3. Author reports completion to user

## User Intervention Mechanism

The user can intervene at any point during the rebuttal process.

### Available Commands

| Command | Effect |
|---------|--------|
| `PAUSE` | Stop immediately and wait for instructions |
| `redirect: [instruction]` | Change rebuttal direction |
| `skip reviewer N` | Ignore reviewer N's comments for this round |
| `habit: [preference]` | Add writing preference to Author's habits checklist |
| Direct feedback | Treated as highest priority (above reviewers) |

### Adding Writing Preferences

User can add permanent writing preferences:
```
habit: Always use 'we show' instead of 'we demonstrate'
habit: Avoid sentences longer than 30 words
habit: Use present tense for method descriptions
```

These are saved to `context/author_habits.yaml` → `user_preferences` and checked on every review.

### Approval Gate

User says "ok" once after reviewing the initial draft. After that, rebuttal rounds run automatically.
- "ok" → Approve draft and start auto-rebuttal
- `PAUSE` / `redirect:` / `skip reviewer N` → Intervene at any time during auto-rebuttal

### Priority Hierarchy

1. **User direct feedback** (highest)
2. **User redirection instructions**
3. **Reviewer comments** (standard)

### Control File (queue/control.yaml)

```yaml
command: null  # null | PAUSE | REDIRECT | SKIP_REVIEWER
redirect_instruction: ""
skip_reviewers: []
user_comment: ""
```

## Reviewer Personas

All three reviewers are expert reviewers for top-tier venues (CoRL, ICRA, RSS, NeurIPS).
They adopt a **strict but polite** evaluation stance:
- **Expertise**: Robot Learning (manipulation, locomotion, embodied AI)
- **Track Record**: Senior researchers with extensive reviewing experience
- **Background**: PIs (Principal Investigators) at top American universities
- **Thinking Style**: Hyper-logical. Skeptical of overclaims. Demand evidence for every claim.
- **Tone**: Polite and constructive, but never lenient. Specific and actionable feedback.
- **Language**: Native American English. Immediately notice AI-generated language patterns.

Each reviewer focuses on different aspects:
| Reviewer | Specialty | Focus Areas |
|----------|-----------|-------------|
| Reviewer 1 | Contributions & Claims | Novelty scope, overclaiming, differentiation from prior work |
| Reviewer 2 | Technical Soundness & Methodology | Technical accuracy, method description, experiments, reproducibility |
| Reviewer 3 | Presentation & Language Authenticity | Structure, clarity, native English, AI-language detection |

**Critical Principles**:
- Reviewers do not take author claims at face value. They narrow contributions to the minimal defensible scope.
- **ALL reviewers** rigorously check paper-wide consistency (terminology, notation, claims) and logical flow (premise→conclusion, no gaps). These are non-negotiable regardless of specialty.

## YAML Formats

### Draft (queue/draft/current.yaml)

```yaml
paragraph:
  id: para_001
  question: "Why does this method outperform prior work?"
  answer: "User-provided information..."
  target_section: "method"  # Section to save to (from user input). null → drafts.md
  draft: |
    Our approach outperforms prior methods because...
  status: review  # draft | review | rebuttal | approved
  round: 1
  timestamp: "2026-02-05T10:00:00"
```

### Review (queue/reviews/reviewerN.yaml)

```yaml
review:
  paragraph_id: para_001
  round: 1
  decision: major_revision  # approve | minor_revision | major_revision
  timestamp: "2026-02-05T10:30:00"
  comments:
    - category: novelty  # novelty | methodology | experiments | presentation | language_authenticity | consistency | logic
      severity: major    # major | minor | suggestion
      comment: "The claim lacks empirical support..."
      suggestion: "Add ablation study to demonstrate..."
    - category: consistency  # ALL reviewers check this
      severity: major
      comment: "Term 'action embedding' conflicts with 'action representation' in para_001."
      suggestion: "Unify terminology throughout the paper."
    - category: logic  # ALL reviewers check this
      severity: major
      comment: "Conclusion doesn't follow from premises — missing causal link."
      suggestion: "Explain why X leads to Y before making this claim."
```

### Rebuttal History (queue/rebuttal/history.yaml)

```yaml
history:
  - paragraph_id: para_001
    round: 1
    author_response: |
      We thank the reviewers for their insightful comments...
    changes_made:
      - "Added ablation study in Section 4.2"
      - "Fixed notation consistency"
    timestamp: "2026-02-05T11:00:00"
```

## Forbidden Actions (All Agents)

| ID | Forbidden Action | Reason |
|----|------------------|--------|
| F001 | Polling | Wastes API costs |
| F002 | Non-author editing tex | Author's responsibility |
| F003 | Reviewer reporting directly to user | Must go through Author |
| F004 | Working without reading context | Causes quality issues |
| F005 | Ignoring user intervention (PAUSE/REDIRECT) | User control is paramount |
| F006 | Author skipping initial draft approval | User must say "ok" before rebuttal starts |

## Instructions

- instructions/author.md - Author instructions
- instructions/reviewer.md - Reviewer instructions

## Timestamp Retrieval

Always use the `date` command to get timestamps:

```bash
# YAML format (ISO 8601)
date "+%Y-%m-%dT%H:%M:%S"
# Output: 2026-02-05T15:46:30
```

## send-keys Delivery Confirmation

Wait 5 seconds after sending → `tmux capture-pane -t <target> -p | tail -8`
- **Delivery OK**: Spinner symbols, "thinking" status visible
- **Delivery Failed**: `❯` prompt at final line
- If not delivered, **resend only once**

## Compaction Recovery Protocol

After compaction, execute the following before work:

1. **Verify your ID**: `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'`
2. **Read your instructions**
3. **Check current status**:
   - Author: Check `queue/draft/current.yaml` status
   - Reviewer: Check `queue/draft/current.yaml` and your `queue/reviews/reviewerN.yaml`
4. **Resume work**
