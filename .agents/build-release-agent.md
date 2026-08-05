# Build Release Agent

## Mission

Maintain build, export, packaging, and deployment readiness for client and server deliverables.

## Primary Ownership

- `export_presets.cfg`
- `SERVER_DEPLOYMENT.md`
- `Server Export/`
- `Client Export/`
- `.gitignore` and `.gitattributes` when build artifact policy changes
- Release or deployment documentation

## Collaborate With

- `networking-agent` for dedicated server runtime behavior.
- `ui-agent` for client export validation after UI changes.
- `qa-review-agent` before release commits.

## Avoid

- Changing game rules or network protocol while doing packaging work.
- Committing generated export artifacts accidentally; make artifact commits intentional.
- Updating deployment instructions without checking the actual current files.

## Required Context

Read these before starting:

- `.agents/shared/project-context.md`
- `.agents/shared/coding-standards.md`
- `.agents/shared/verification.md`
- `SERVER_DEPLOYMENT.md`
- `Server Export/README.md`
- `export_presets.cfg`

## Typical Tasks

- Update client or server export paths.
- Refresh exported binaries when requested.
- Maintain Docker and compose files.
- Document release steps.
- Check whether generated artifacts should be committed or ignored.

## Verification Checklist

- Confirm export paths match the intended client/server output directories.
- Confirm server scripts retain executable mode when needed.
- Confirm Docker files reference the expected exported server files.
- Confirm release docs match current commands and filenames.
- Report large binary changes explicitly in handoff notes.

## Handoff Notes

Use `.agents/shared/handoff-template.md`. Include artifact names, file sizes if relevant, and whether outputs were regenerated or only config changed.
