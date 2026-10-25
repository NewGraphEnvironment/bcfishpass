# Progress — USA dam placeholders stopped being barriers in v0.7.7 (#15)

## Session 2026-10-25

- Plan-mode exploration — phases approved by user
- `gh repo set-default NewGraphEnvironment/bcfishpass`; local `main` fast-forwarded to `upstream/main` (`3bd2824c`)
- Created branch `15-dam-placeholders-crossings` off main in worktree `~/Projects/repo/bcfishpass-15`
- Scaffolded PWF baseline from issue #15 with approved phases
- Next: start Phase 1 (baseline capture on `bcfishpass_dev`)
- Phase 1: baseline captured on `bcfishpass_dev` (read-only), recorded in findings
- Phase 2: `load_dams.sql`: id range 1100000000, stream-order numbering, status from `barrier_ind` (`21f9fe70`)
- Phase 3: `load_crossings.sql`: placeholder insert (`d8eaff82`)
- Phase 4: rollback test passed on dev; control matches baseline exactly; branch adds exactly the five placeholders as dam barriers; misc 3–5 intact
- Next: Phase 5 (code-check, submit branch, PR body for approval)
- Phase 5: code-check 3 rounds Clean. The user amended `crossing_source` to `'CABD'` after round 3 (web map styling) and the re-test passed (`e4fdf27a`). Submit branch `fix-dam-placeholders-crossings` (`d613ae28`) pushed to origin
- Next: user approves the PR body, then open the PR to smnorris/bcfishpass and tick fork #15
