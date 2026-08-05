# Skill Lockfile Covers Full Skill Provenance

`skills-lock.json` is intended to guarantee the full installed skill directory content plus upstream provenance. Each entry should mean that the local skill directory matches an upstream skill path at a known source revision, not merely that a single `SKILL.md` entrypoint had a recorded hash.

This makes skill installs auditable and reproducible when a skill depends on sibling templates, scripts, references, or agent metadata. The rejected alternative was treating the lockfile as an entrypoint hash only, which is simpler but lets supporting files drift without the lockfile making that drift visible.

The current `skills-lock.json` is still the installer-generated transitional format and should be committed as-is rather than hand-edited. Future installer work should make the file satisfy this contract by writing an upstream source revision, declaring the hash scope, and hashing the full installed skill directory.
