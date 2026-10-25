# Task: USA dam placeholders stopped being barriers in v0.7.7 (#15)

At `smnorris/bcfishpass@620dbe4` (v0.7.15-50), the five `cabd_additions.csv` dam placeholders (4 × Grand Coulee / Chief Joseph on KETL and LARL lines, 1 × Ross on SKGT) are loaded into `bcfishpass.dams` but never reach `bcfishpass.crossings`. So they are never in `barriers_dams` or `barriers_anthropogenic`, and segments below them carry no `DAM` mapping-code token. The comment in `load_dams.sql` says they were added so that these dams count.

## Context

The five `data/cabd_additions.csv` dam placeholders (4 × Grand Coulee/Chief Joseph on KETL/LARL, 1 × Ross on SKGT) load into `bcfishpass.dams` but never reach `bcfishpass.crossings`, so they never reach `barriers_dams` and get no `DAM` token. This broke in v0.7.7 (`9fdcbc7`), when they moved to `cabd_additions` and the only insert that handled them (removed in `7e1cdfa`) stopped matching anything. Their ids (`row_number() over () + 1200000000`) also overlap `user_crossings_misc` (`id + 1200000000`), so misc crossings 3–5 would collide at `on conflict do nothing`. The maintainer picked **option 1** on smnorris/bcfishpass#937 (2026-10-23) and asked for a PR. The plan of record is the "Plan inputs" comment on fork #15 (2026-10-24). I checked it against `upstream/main` (`3bd2824`) and it still holds.

What exploration turned up:
- `model/01_access/sql/load_dams.sql:108-130`, the `usa` CTE: unordered `row_number() over ()`, and `passability_status_code` is hard-coded `null` at line 166.
- `model/01_access/sql/load_crossings.sql:366-437`, the CABD dams insert: `inner join cabd.dams`, with status from raw `cabd.passability_status_code`.
- The removed placeholder insert at `7e1cdfa^:model/01_access/sql/load_crossings.sql:439-495` is the template: `crossing_source = 'MISC BARRIERS'`, `OTHER`/`DAM`, `BARRIER`.
- `+ 1100000000` is free, and it is historically the "dams bin" (`db/migrations/archive/v0.5.0/sql/tables/crossings.sql:14`).
- `git grep 12000000`: no code or fix CSV keys on the old placeholder dam ids. The only hits are schema/doc comments, which describe the misc offset.
- `dams_vw` is read only by `load_crossings.sql`, so setting `passability_status_code = 1` on the placeholders in `dams` has no other consumers.
- `load_falls.sql:120-140` takes `barrier_ind` straight from `cabd_additions`. That is the precedent for reading the CSV flag.
- Misc crossings 3–5 are in QUES/BOWR, not in the placeholder WSGs. The collision is on the global PK `aggregated_crossings_id`.
- `01_model_access_natural.sh:107-115` runs `load_dams.sql` once, then truncates crossings and runs `load_crossings.sql` per WSG.

## Decided at the gate

Decided by the user at plan approval, 2026-10-25.

- Branch `15-dam-placeholders-crossings` (plan of record), not the skill's title slug.
- The work happens in a **worktree** at `~/Projects/repo/bcfishpass-15`, because the main checkout is on `crossing_fixes_20260806` with uncommitted CSV edits I won't touch. Local `main` is fast-forwarded to `upstream/main` (`git fetch upstream main:main`, FF verified). I don't push fork `main`.
- `gh repo set-default NewGraphEnvironment/bcfishpass` (local git config), per the plan of record.
- `planning/` (README, `active/`, `archive/`) is created on the work branch only. It never goes on the submit branch. CLAUDE.md stays on `newgraph`.
- Placeholder ids become `row_number() over (order by blue_line_key, downstream_route_measure) + 1100000000`. The PR says the range is the maintainer's call.
- Placeholder status comes from `cabd_additions.barrier_ind` (true → 1, false → 3) into `dams.passability_status_code`. There's no new column and no migration.
- The new crossings branch uses `crossing_source = 'MISC BARRIERS'` (restores the pre-v0.7.7 value, which is in the documented domain) and `dam_name` from `dams_vw.dam_name_en`. The PR flags `'CABD'` as the alternative.
- Out of scope, staying on #15: the latent passability-updates point (the CABD insert reads raw `cabd`, not `dams_vw`), and placeholders lacking `dam_use` so not reaching `barriers_dams_hydro`.

## Phase 1: Setup and baseline capture
- [x] `gh repo set-default`, ff local `main`, create the worktree + branch, scaffold `planning/` + PWF, commit baseline, push branch to origin
- [x] Confirm the tunnel (`localhost:63333`) and connect to **`bcfishpass_dev`** only
- [x] Read-only baseline for KETL/LARL/SKGT: counts by `crossing_source`, the full `aggregated_crossings_id` list (saved to scratchpad), `barriers_dams`-selection count, misc 3/4/5 rows, and the reprex query. Record in `findings.md`

## Phase 2: `load_dams.sql`: id range, stable order, status
- [x] `usa` CTE: `row_number() over (order by a.blue_line_key, a.downstream_route_measure) + 1100000000`, carry `a.barrier_ind`
- [x] Final select: `case when barrier_ind then 1 when not barrier_ind then 3 end as passability_status_code` in place of `null`
- [x] Update the CTE comment to name the id range

## Phase 3: `load_crossings.sql`: placeholder branch
- [ ] New insert after the CABD dams insert (after line 437), with the same column list as the CABD insert. Source is `dams_vw d` + stream join + `left join cabd.dams cabd on d.dam_id = cabd.cabd_id::text where cabd.cabd_id is null`, status from `d.passability_status_code` using the same case mapping, `'MISC BARRIERS'`, `OTHER`/`DAM`, dam attributes from `d`, `on conflict do nothing`
- [ ] Header comment matching the file's style

## Phase 4: Rollback test on `bcfishpass_dev`
- [ ] Script in scratchpad: `begin;` → `load_dams.sql` (own `begin`/`commit` stripped) → `delete from bcfishpass.crossings where watershed_group_code in ('KETL','LARL','SKGT')` → `load_crossings.sql` with `-v wsg=` for each of the three → acceptance queries → `rollback;`. Run as one `psql -1`-style session, never against production
- [ ] Acceptance: all 5 placeholders in `crossings` with `dam_id` set and `BARRIER`, and picked up by the `barriers_dams.sql` WHERE clause (incl. `blue_line_key = watershed_key`). Misc 3/4/5 still present under `12000000{03,04,05}`. KETL/LARL/SKGT otherwise identical to the baseline (counts by source; id set diff = exactly +5 placeholder ids)
- [ ] Before/after table in `findings.md` for the PR body

## Phase 5: Submit branch and PR
- [ ] `/code-check` on the code diff
- [ ] `fix-dam-placeholders-crossings` cut from `upstream/main`, `cherry-pick --no-commit` of the code commits, tree diff vs work branch = only `planning/`
- [ ] Commit message: no `#N`, no `Claude-Session:`, keeps `Co-Authored-By`, no Assisted-by offer
- [ ] Push to origin. **Show you the PR body and confirm before** opening the PR to smnorris/bcfishpass (referencing #937, before/after counts, id-range and `crossing_source` as his call)
- [ ] Tick the "Next" checkboxes on fork #15 and link the PR

## Owed at the end (reported, done after merge)
- [ ] Flip the link `bcfishpass` bundle to treat placeholders as barriers (NewGraphEnvironment/link#244, NewGraphEnvironment/link#367)
- [ ] Passability-updates latent point as its own upstream item (fork #15 "Also seen")
- [ ] Remove the `bcfishpass-15` worktree and sync fork `main` to upstream

## Validation
- [ ] No automated test suite for model SQL. Phase 4's rollback test on `bcfishpass_dev` is the proof, and its acceptance queries carry the evidence
- [ ] `/code-check` clean
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

### How each change is proved

- `load_dams.sql` + `load_crossings.sql`: Phase 4 rollback test on `bcfishpass_dev` against the Phase 1 baseline (acceptance queries listed in Phase 4).
