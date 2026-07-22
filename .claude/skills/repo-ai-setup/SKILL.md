---
name: repo-ai-setup
description: Use when a collaborator asks how to set up Claude Code for this repo, or wants the recommended plugins installed. Not needed for day-to-day work.
---

# Setting up Claude Code for SushiScout 26

This repo ships shared Claude Code config in `.claude/` (hooks, agents, skills)
so collaborators get a consistent AI setup on clone. Plugins live in
`~/.claude/`, so they are not pulled in by cloning — install them separately.

```bash
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add mksglu/context-mode

# Core for this repo
claude plugin install firebase@claude-plugins-official        # enabled via settings.json
claude plugin install superpowers@claude-plugins-official     # TDD/debugging/review disciplines
claude plugin install context-mode@context-mode               # keeps large tool output out of context
claude plugin install context7@claude-plugins-official        # live library docs (Flutter/Firebase/Riverpod)
claude plugin install commit-commands@claude-plugins-official # /commit, /commit-push-pr
claude plugin install code-review@claude-plugins-official     # /code-review
```
