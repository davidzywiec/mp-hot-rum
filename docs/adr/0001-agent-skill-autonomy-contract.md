# Agent Skill Autonomy Contract

Repo skills may inspect, analyze, and propose autonomously, but they may only write docs, create issues, edit code, or commit after an explicit confirmation point in that skill flow. Composite skills preserve the strictest confirmation rule of any skill they invoke, so a router skill cannot bypass a child skill's human checkpoint.

This keeps agent workflows useful for exploration while making repository changes intentional. The rejected alternative was making skills autonomous by default, which would reduce friction but make it unclear when generated docs, issues, code edits, or commits were explicitly approved.
