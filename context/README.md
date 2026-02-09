# Context Directory

This directory manages project-specific context for efficient paper writing.

## Purpose

- Store terminology, notation, and claims for consistency checking
- Track Author's writing habits and user preferences
- Enable efficient reviews without reading the full paper every time

## File Structure

```
context/
├── README.md              ← This file
├── author_habits.yaml     ← Author's writing patterns (bad habits, user preferences)
└── glossary.yaml          ← Terminology, notation, claims registry
```

## Files

### author_habits.yaml

Tracks Author's recurring patterns:

| Section | Purpose | Updated By |
|---------|---------|------------|
| `bad_habits` | Patterns to avoid | Reviewers (when noticed) |
| `good_habits` | Patterns to maintain | Reviewers (when noticed) |
| `user_preferences` | User's writing preferences | User (via `habit:` command) |

**Usage:**
- Author reads before writing (self-check)
- Reviewers read before reviewing (catch habits)
- User adds preferences: `habit: Always use 'we show' instead of 'we demonstrate'`

### glossary.yaml

Single source of truth for paper terminology:

| Section | Purpose |
|---------|---------|
| `terminology` | Canonical terms and forbidden synonyms |
| `notation` | Mathematical symbols and their meanings |
| `abbreviations` | Acronyms and expansions |
| `claims` | Main claims (to prevent contradictions) |

**Usage:**
- Read this (~100 lines) instead of full paper (1000s lines)
- Author updates after each approved paragraph
- Enables consistency checking without token explosion

## Workflow

### When Writing a New Paragraph

1. Author reads `glossary.yaml` for terminology/notation
2. Author reads `author_habits.yaml` for patterns to avoid
3. Author writes using canonical terms
4. After approval, Author updates `glossary.yaml` with new terms

### When Reviewing

1. Reviewer reads `author_habits.yaml` (check for bad habits)
2. Reviewer reads `glossary.yaml` (check consistency)
3. Only read full `paper/sections/*.tex` if glossary is insufficient
4. If new recurring pattern noticed, add to `author_habits.yaml`

## Token Efficiency

| File | Approx. Size | Read Frequency |
|------|--------------|----------------|
| `author_habits.yaml` | ~50 lines | Every review |
| `glossary.yaml` | ~100 lines | Every review |
| `paper/sections/*.tex` | 1000+ lines | Only when needed |

This approach prevents context window overflow while maintaining rigor.
