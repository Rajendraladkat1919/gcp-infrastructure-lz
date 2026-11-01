## What and why

<!-- One or two sentences. Link the ticket. -->

## Stages touched

- [ ] 1-network-hub
- [ ] 2-network-spokes
- [ ] Workflows / tooling / docs only

## Checklist

- [ ] The plan comment on this PR was read, and every change in it is intended
- [ ] No new `roles/owner`, `roles/editor` or broad network role without an entry in `docs/controls.md` (Exceptions)
- [ ] No secrets, keys or state files in the diff
- [ ] CIDR ranges were checked against `docs/ip-plan.md` for overlap
- [ ] Docs updated (`terraform-docs` output, controls) where behaviour changed
- [ ] Rollback is understood (revert this PR, or the manual step is written below)

## Rollback

<!-- "Revert the PR" is the usual answer. Say so, or describe the manual step. -->
