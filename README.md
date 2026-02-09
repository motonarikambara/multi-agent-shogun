# Paper Writing System

A multi-agent framework for academic paper writing, featuring one author agent and three reviewer agents that engage in rigorous rebuttal cycles to produce high-quality paper paragraphs.

## Overview

This system uses Claude Code with tmux to orchestrate multiple AI agents:

- **Author**: Writes paper paragraphs based on user-provided questions and answers
- **Reviewer 1**: Reviews for Technical Novelty
- **Reviewer 2**: Reviews for Experimental Rigor  
- **Reviewer 3**: Reviews for Clarity & Presentation

The reviewers are modeled as top Robot Learning researchers (PIs at leading American universities with many papers at CoRL, ICRA, RSS) who are hyper-logical and demand scientific rigor.

## Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: Writing                                           │
│  User → Author: Provide question + answer                   │
│  Author → User: Ask clarification if needed                 │
│  Author: Write paragraph draft                              │
│  User: Say "OK" to proceed                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: Initial Review (Parallel)                         │
│  Author → All Reviewers: Submit draft                       │
│  Reviewers: Review in parallel (also check paper/main.tex   │
│             for consistency with existing content)          │
│  Reviewers → Author: Submit reviews                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 3: Rebuttal (Loop until all approve)                 │
│  Author: Address comments, revise text                      │
│  Author → Reviewers: Submit revision                        │
│  Reviewers: Approve or request more changes                 │
│  (Author can ask user for additional info during rebuttal)  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 4: Completion                                        │
│  Author → User: "Save to drafts or which section?"          │
│  User: "drafts" or section name (introduction, method, etc) │
│  Author: Save to chosen location                            │
│  (User can later: "append para_XXX to introduction")        │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- tmux
- Claude Code CLI (`claude` command)

### Start the System

```bash
# Start all agents
./start.sh

# Start with clean queue (reset all state)
./start.sh -c

# Setup only (no Claude startup)
./start.sh -s
```

### Attach to Session

```bash
tmux attach-session -t paper
```

### Interact with the Author

1. Provide a **question** (what the paragraph should explain)
2. Provide an **answer** (technical information to address the question)
3. Author writes a draft paragraph
4. Say **"OK"** when satisfied to start the review phase
5. Wait for rebuttal to complete
6. Repeat for the next paragraph

## File Structure

```
paper-writing-system/
├── CLAUDE.md                 # System configuration
├── instructions/
│   ├── author.md             # Author instructions
│   └── reviewer.md           # Reviewer instructions
├── paper/
│   ├── main.tex              # Main document (uses \input for sections)
│   ├── drafts.md             # Approved drafts as reference
│   └── sections/             # Section files
│       ├── abstract.tex
│       ├── introduction.tex
│       ├── related_work.tex
│       ├── method.tex
│       ├── experiments.tex
│       ├── results.tex
│       ├── discussion.tex
│       └── conclusion.tex
├── queue/
│   ├── draft/
│   │   └── current.yaml      # Current draft
│   ├── reviews/
│   │   ├── reviewer1.yaml    # Reviewer 1 comments
│   │   ├── reviewer2.yaml    # Reviewer 2 comments
│   │   └── reviewer3.yaml    # Reviewer 3 comments
│   ├── rebuttal/
│   │   └── history.yaml      # Rebuttal history
│   └── control.yaml          # User intervention commands
├── config/
│   └── settings.yaml         # System settings
└── start.sh                  # Startup script
```

## Reviewer Personas

All reviewers share these characteristics:
- **Expertise**: Robot Learning
- **Track Record**: Many papers at CoRL, ICRA, RSS
- **Background**: PIs at top American universities
- **Thinking Style**: Hyper-logical, no tolerance for ambiguity

| Reviewer | Specialty | Focus |
|----------|-----------|-------|
| Reviewer 1 | Technical Novelty | Accuracy, novelty, prior work differentiation |
| Reviewer 2 | Experimental Rigor | Experiment design, reproducibility, statistics |
| Reviewer 3 | Clarity & Presentation | Structure, clarity, figures, notation |

## Key Features

- **Consistency Checking**: Reviewers read `paper/main.tex` to ensure new paragraphs are consistent with existing content
- **Parallel Review**: All 3 reviewers review simultaneously in the first round
- **Individual Rebuttal**: After initial review, author addresses each reviewer individually
- **Convergence Requirement**: All 3 reviewers must approve before a paragraph is finalized
- **Arsenal Building**: Approved paragraphs accumulate in `paper/main.tex` as reference for future writing
- **User Intervention**: PAUSE, REDIRECT, and SKIP commands to control the rebuttal process

## User Intervention

You can intervene at any point during the rebuttal process to correct the direction or provide additional feedback.

### Intervention Commands

| Command | Usage | Effect |
|---------|-------|--------|
| `PAUSE` | Type "PAUSE" | Stop immediately and wait for instructions |
| `redirect: [instruction]` | Type "redirect: focus on clarity" | Change rebuttal direction |
| `skip reviewer N` | Type "skip reviewer 2" | Ignore reviewer N's comments for this round |
| Direct feedback | Provide your own comments | Treated as highest priority (above reviewers) |

### Approval Gate

Before each rebuttal round, the Author will ask for your approval:

```
Ready for rebuttal round 2.

**Reviewer comments summary:**
- Reviewer 1 (Novelty): Claims lack empirical support
- Reviewer 2 (Rigor): Questions statistical significance
- Reviewer 3 (Clarity): Suggests restructuring

**Options:**
- "yes" or "ok" → Proceed with rebuttal
- "redirect: [instruction]" → Change direction
- "skip reviewer N" → Ignore reviewer N
- "PAUSE" → Stop and wait

Your response?
```

Quick responses:
- **"yes"** or **"ok"** → Proceed normally
- **"auto"** → Proceed and skip future approval gates for this paragraph

### Priority Hierarchy

When you provide direct feedback, it takes highest priority:

1. **User direct feedback** (highest) - Always addressed first
2. **User redirection instructions** - Overrides reviewer focus
3. **Reviewer comments** (standard)

### Example Intervention

```
User: "redirect: focus only on R2's statistical concerns. Also, we have p<0.001 for all results"

→ Author prioritizes Reviewer 2's comments
→ Uses your provided p-value information
→ Notes direction change in rebuttal history
```

## License

MIT License
