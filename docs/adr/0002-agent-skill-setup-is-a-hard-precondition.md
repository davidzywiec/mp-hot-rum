# Agent Skill Setup Is a Hard Precondition

The repository treats `setup-matt-pocock-skills` as a hard precondition before the installed engineering skills are considered usable. Skills that depend on issue-tracker, triage-label, or domain-doc configuration should not silently invent defaults when `docs/agents/*` is missing.

This makes missing configuration fail early instead of appearing halfway through a workflow. The rejected alternative was allowing each skill to recover independently with local defaults, which would reduce setup friction but risk inconsistent issue, triage, and domain-document behavior across agents.
