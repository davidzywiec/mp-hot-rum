# Grilling Is Human-Invoked Only

The `grilling` skill must only run after a human explicitly invokes it. The model should not decide on its own to start a grilling session, even when a prompt asks for stress-testing, critique, or design pressure.

This preserves grilling as an intentional collaboration mode rather than a surprise escalation in ordinary engineering work. Composite skills such as `grill-with-docs` may route into grilling only when the composite skill itself was explicitly invoked by the human.

The installed `grilling` skill content is left unmodified to preserve the installer-generated skill bundle. Enforcement must therefore come from repo policy, runtime routing, or future upstream metadata support rather than a local edit to `.agents/skills/grilling/SKILL.md`.
