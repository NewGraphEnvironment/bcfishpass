## Outcome

**Parked, superseded upstream. Never merged and no PR opened.** We built the fix the maintainer first chose, option 1 on smnorris/bcfishpass#937, to get the five `cabd_additions.csv` US dam placeholders (Grand Coulee / Chief Joseph on KETL and LARL, Ross on SKGT) back into `bcfishpass.crossings`. `load_dams.sql` numbers them from `1100000000` in stream order and takes status from `barrier_ind`. `load_crossings.sql` adds an insert for `dams_vw` rows with no `cabd.dams` match, with `crossing_source = 'CABD'`; the user chose that after code-check round 3 found the web map styles dams only on `'CABD'`. On 2026-10-25 the maintainer withdrew the request. The dams are already in CABD, and the fix he wants is to add the Columbia and Skagit mainstems to fwapg (smnorris/fwapg#145) and snap the real CABD points, which retires the placeholders. Any stopgap would be option 1 using the real CABD ids, not a new range. The code is on `15-dam-placeholders-crossings` and the code-only `fix-dam-placeholders-crossings` (`d613ae28`), both on origin, for reference only.

What we learned: upstream's full-pipeline CI (`.github/workflows/ng-test-model.yaml`) runs on PRs touching `model/**`. It cannot run for PRs from this fork, because GitHub withholds secrets from fork PRs; it failed at `load-csv` on PR 939. An upstream PR from here can only be tested end to end by the maintainer.

## Measurement

`bcfishpass_dev` (model run 63, `v0.7.15-68-g6c8fd845`), KETL / LARL / SKGT, in a single transaction that rolled back. A control with unchanged `upstream/main` reproduced the stored 22,323 crossing ids exactly. The branch added exactly five ids, `1100000001`–`1100000005`, all `BARRIER` / `DAM` on mainstems, and lost none. CABD crossings went from 48 to 49 in KETL, 20 to 23 in LARL and 1 to 2 in SKGT. The `barriers_dams` selection went from 47 to 48, 20 to 23 and 1 to 2. Misc crossings 3–5 kept their `12000000xx` ids. Steps after `load_crossings.sql` were not run. The harness `.sql` lived in a session scratchpad that is gone; `findings.md` describes it fully.

## Owed

- Flip the link `bcfishpass` bundle to treat placeholders as barriers (NewGraphEnvironment/link#244, NewGraphEnvironment/link#367)
  - Now: when the upstream fix lands, make link's `bcfishpass` bundle follow it. Under the fwapg route that means the new mainstems and the real CABD points, not this one-setting flip. Both link issues are closed; fork #15 tracks this.
- Passability-updates latent point as its own upstream item (fork #15 "Also seen")
- Remove the `bcfishpass-15` worktree and sync fork `main` to upstream
  - The worktree is removed at archive. Syncing fork `main` is still owed.

Closed by: parked on fork #15 (comment 2026-11-19); no PR
