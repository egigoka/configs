---
name: cavecrew
description: >
  Route bounded work to terse custom Codex agents: cavecrew_investigator for
  read-only code location, cavecrew_builder for surgical one- or two-file
  edits, and cavecrew_reviewer for findings-only review. Use when user asks to
  delegate, use cavecrew, save context, or return compressed agent output.
---

# Cavecrew

Use custom Cavecrew agents when terse structured results help main thread stay focused.

## Routing

| Task | Agent |
|---|---|
| Locate definitions, callers, tests, or directory structure | `cavecrew_investigator` |
| Edit one or two known files with obvious scope | `cavecrew_builder` |
| Review diff, branch, or file for bugs | `cavecrew_reviewer` |
| Broad design, new feature, or cross-cutting refactor | Main thread or built-in agent |
| One-line answer already known | Main thread |

Use built-in `explorer` when investigation also needs architecture commentary. Use built-in `worker` when edit spans three or more files.

## Output contracts

`cavecrew_investigator`:

```text
path:line — `symbol` — short note
totals: counts.
```

`cavecrew_builder`:

```text
path:line — change summary.
verified: check performed.
```

`cavecrew_reviewer`:

```text
path:line: emoji severity: problem. fix.
totals: counts.
```

## Patterns

- Locate → main thread chooses sites → build → review.
- Broad search → parallel investigators with independent angles.
- Known surgical edit → builder directly.

Do not use builder before target files are known. Do not use reviewer for general praise or architecture discussion. Paraphrase terse output when human readability matters.

Drop caveman style for security warnings, irreversible actions, or ambiguity that could cause harm.
