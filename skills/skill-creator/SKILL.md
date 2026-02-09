---
name: skill-creator
description: Auto-generate reusable Claude Code skills when discovering generic work patterns. Use when creating skills for repeatable workflows, best practices, or domain knowledge.
---

# Skill Creator

## Overview

Save generic patterns discovered during work as reusable Claude Code skills.
This improves quality and efficiency when repeating similar tasks.

## When to Create a Skill

Consider creating a skill when the following conditions are met:

1. **Reusability**: Pattern applicable to other projects
2. **Complexity**: Non-trivial; requires specific steps or knowledge
3. **Stability**: Procedures or rules that don't change frequently
4. **Value**: Clear benefit from skill-ifying

## Skill Structure

Generated skills follow this structure:

```
skill-name/
├── SKILL.md          # Required
├── scripts/          # Optional (execution scripts)
└── resources/        # Optional (reference files)
```

## SKILL.md Template

```markdown
---
name: {skill-name}
description: {When to use this skill; specific use cases}
---

# {Skill Name}

## Overview
{What this skill does}

## When to Use
{Trigger situations, keywords, or contexts}

## Instructions
{Step-by-step procedures}

## Examples
{Input and output examples}

## Guidelines
{Rules to follow, edge cases}
```

## Creation Process

1. **Identify the Pattern**
   - What is generic/reusable?
   - Where can it be applied?

2. **Choose Skill Name**
   - Use kebab-case (e.g., `api-error-handler`)
   - Format: verb+noun or noun+noun

3. **Write Description (Most Important)**
   - This is how Claude decides when to use the skill
   - Include specific use cases, file types, action verbs
   - BAD: "Document processing skill"
   - GOOD: "Extract tables from PDF and convert to CSV. Used in data analysis workflows."

4. **Write Instructions**
   - Clear step-by-step procedures
   - Decision criteria
   - Edge case handling

5. **Save**
   - Path: `~/.claude/skills/{skill-name}/` or project-local `skills/`
   - Verify no naming conflicts with existing skills

## Usage in This Project

### For Reviewers

When you notice a recurring Author pattern worth tracking:

1. Check if it belongs in `context/author_habits.yaml` (project-specific)
2. If it's a generic pattern useful across projects → consider creating a skill

### For Author

When you develop a writing technique that works well:

1. Document it in your workflow
2. If reusable across papers → propose as a skill

## Examples of Good Skills

### Example 1: API Response Handler

```markdown
---
name: api-response-handler
description: REST API response processing patterns. Includes error handling, retry logic, and response normalization. Use during API integration work.
---
```

### Example 2: Academic Writing Checker

```markdown
---
name: academic-writing-checker
description: Check academic writing for AI-sounding patterns, passive voice overuse, and unclear claims. Use when reviewing paper drafts.
---
```

### Example 3: Terminology Consistency Checker

```markdown
---
name: terminology-checker
description: Verify terminology consistency across documents using a glossary file. Use when writing multi-section papers or documentation.
---
```

## Skill vs. Project-Specific Files

| Type | Location | Scope | Example |
|------|----------|-------|---------|
| **Skill** | `~/.claude/skills/` | All projects | Generic academic writing patterns |
| **Project file** | `context/*.yaml` | This project only | Author's specific bad habits |

**Rule of thumb**: If it's useful for other papers/projects → skill. If it's specific to this paper → project file.

## Reporting Format

When creating a skill, report:

```
New skill created:
- Name: {name}
- Purpose: {description}
- Path: {path}
```
