# Findings — USA dam placeholders stopped being barriers in v0.7.7 (#15)

## Issue context

At `smnorris/bcfishpass@620dbe4` (v0.7.15-50), the five `cabd_additions.csv` dam placeholders (4 × Grand Coulee / Chief Joseph on KETL and LARL lines, 1 × Ross on SKGT) are loaded into `bcfishpass.dams` but never reach `bcfishpass.crossings`. So they are never in `barriers_dams` or `barriers_anthropogenic`, and segments below them carry no `DAM` mapping-code token. The comment in `load_dams.sql` says they were added so that these dams count.

## How it broke

| commit | what changed |
|---|---|
| `45002d5` (2023-07-25) | placeholders added in `user_barriers_anthropogenic.csv`. `load_crossings.sql` gets its own insert for them (`'MISC BARRIERS'`, `barrier_status = 'BARRIER'`), joining `dams_vw` to `user_barriers_anthropogenic` on blue line key and measure. They are barriers. |
| `9fdcbc7` (2026-01-05, upstream PR 740, first in v0.7.7) | placeholders move to `cabd_additions.csv`, and `load_dams.sql`'s `usa` CTE loads them from there. The crossings insert still joins `user_barriers_anthropogenic`, which no longer holds them, so it matches nothing. The CABD-dams insert can't pick them up either: it inner-joins `cabd.dams` on `cabd_id`, and takes `barrier_status` from `cabd.passability_status_code`. |
| `7e1cdfa` (2026-04-02, upstream issue 823, first in v0.7.13) | `user_barriers_anthropogenic` is folded into `user_crossings_misc`, which gains a `barrier_status` column, and the placeholder insert, which by then matched nothing, goes with it. |

## Reprex

On the reference DB (`v0.7.15-50-g620dbe43`, model run 144, completed 2026-10-20), run 2026-10-22:

```sql
select d.dam_id, d.dam_name_en, d.watershed_group_code as wsg,
       c.crossing_source as crossing_with_this_id
from bcfishpass.dams_vw d
left join bcfishpass.crossings c on c.aggregated_crossings_id = d.dam_id
where d.dam_id ~ '^12000000[0-9]{2}$'
order by d.dam_id;
```

```
   dam_id   |   dam_name_en    | wsg  | crossing_with_this_id
 1200000001 | Grand Coulee Dam | KETL |
 1200000002 | Grand Coulee Dam | LARL |
 1200000003 | Grand Coulee Dam | LARL | USER_CROSSINGS_MISC
 1200000004 | Grand Coulee Dam | LARL | USER_CROSSINGS_MISC
 1200000005 | Ross Dam         | SKGT | USER_CROSSINGS_MISC
```

No row of `bcfishpass.crossings` has one of these as its `dam_id` (count 0). `passability_status_code` is NULL on all five in `dams_vw`, so a fix has to take their status from `cabd_additions.barrier_ind`. The last three rows are the id overlap below, already visible.

## Options as we see them, and a trap

Not written or tested yet; these are what we can see from the code.

**1. A branch in `load_crossings.sql`** for `dams_vw` rows that have no `cabd.dams` match, with `barrier_status` taken from the CSV's `barrier_ind`. That means carrying `barrier_ind` through `load_dams.sql`'s `usa` CTE, or `passability_status_code = 1` where `barrier_ind` is true.

**2. Move them to `user_crossings_misc`** with `barrier_status = BARRIER`, the mechanism upstream issue 823 added. No new SQL, but they become barriers and not dams: `barriers_dams.sql` selects crossings with `dam_id IS NOT NULL`, and misc rows carry none, so no `DAM` token.

**ID collision.** The placeholders get `dam_id = row_number() + 1200000000`, which is the same space as `user_crossings_misc` (`user_crossing_misc_id + 1200000000`). Misc ids 3, 4 and 5 exist, so restoring the placeholders as crossings with `aggregated_crossings_id = dam_id` collides with three misc crossings. The dams insert runs first and both inserts use `on conflict do nothing`, so the three misc crossings would be dropped without any error. The placeholders need their own range. `row_number() over ()` also numbers rows in scan order, so it should be ordered by CSV row or by blue line key and measure.

## Also seen (latent today)

The CABD-dams insert in `load_crossings.sql` takes `barrier_status` from raw `cabd.passability_status_code`, not from `dams_vw.passability_status_code`, where `load_dams.sql` has already applied `cabd_passability_status_updates`. A dam passability update therefore never reaches `crossings`. Today the two dams in the updates file (Northey Lake Dam and `75e563a7…`) already carry the updated codes in CABD, so nothing changes yet.

## Link side

NewGraphEnvironment/link#244 and NewGraphEnvironment/link#367 (link 0.68.0): the `default` config treats the placeholders as barriers (`pipeline: cabd_additions_barriers`). The `bcfishpass` bundle leaves them off, to match the reference DB as it is built today. Flip the bundle once upstream fixes this.

## Upstream issue (posted 2026-10-22 as `smnorris/bcfishpass#937`)

Issue first, offering a pull request, because the id range for the placeholders is a choice for the maintainer. One upstream item at a time, so the latent passability point above stays here for now. Posted on the user's go-ahead, with the text below:

<details><summary>Upstream issue as posted</summary>

**Title:** US dam placeholders in `cabd_additions.csv` no longer reach `crossings`

The five placeholders in `data/cabd_additions.csv` (Grand Coulee / Chief Joseph on KETL and LARL, Ross on SKGT) load into `bcfishpass.dams` but not into `bcfishpass.crossings`, so they never reach `barriers_dams`, and segments below them carry no `DAM` token. On the reference DB (`v0.7.15-50-g620dbe43`, model run 144):

```sql
select d.dam_id, d.dam_name_en, d.watershed_group_code as wsg,
       c.crossing_source as crossing_with_this_id
from bcfishpass.dams_vw d
left join bcfishpass.crossings c on c.aggregated_crossings_id = d.dam_id
where d.dam_id ~ '^12000000[0-9]{2}$'
order by d.dam_id;
```

```
   dam_id   |   dam_name_en    | wsg  | crossing_with_this_id
 1200000001 | Grand Coulee Dam | KETL |
 1200000002 | Grand Coulee Dam | LARL |
 1200000003 | Grand Coulee Dam | LARL | USER_CROSSINGS_MISC
 1200000004 | Grand Coulee Dam | LARL | USER_CROSSINGS_MISC
 1200000005 | Ross Dam         | SKGT | USER_CROSSINGS_MISC
```

No crossing has one of these as its `dam_id`. As far as we can tell, they stopped being barriers when they moved to `cabd_additions.csv` in v0.7.7: the CABD insert in `load_crossings.sql` inner-joins `cabd.dams`, so rows without a CABD id drop out. The last three rows also show their ids overlapping `user_crossings_misc` (`id + 1200000000`), so giving them crossings under the same ids would drop misc crossings 3 to 5 at `on conflict do nothing`.

Two options we can see (you'll know better):

1. A branch in `load_crossings.sql` for `dams_vw` rows with no `cabd.dams` match, with status from `barrier_ind`, and the placeholders given their own id range.
2. Moving them to `user_crossings_misc` with `barrier_status = BARRIER`. That makes them barriers but not dams, since `barriers_dams` reads `dam_id`.

Happy to send a pull request for either, or to leave it with you. We used Claude Code to help trace this and run the queries.

</details>

## Next

- [x] Reprex on the reference DB (above)
- [x] Post the upstream issue (`smnorris/bcfishpass#937`)
- [ ] If a pull request is wanted: branch here from upstream `main` for the option chosen, with a test on KETL / LARL / SKGT; commits keep the `Co-Authored-By` Claude line, no `Claude-Session:` trailer
- [ ] Separately, later: the passability-updates point above


## Plan inputs comment (2026-10-24)

## Plan inputs (2026-10-24)

**Decision.** The maintainer chose option 1, 2026-10-23 on `smnorris/bcfishpass#937`: *"A PR for option 1 would be great if you can. Otherwise it might have to wait a couple of weeks for a fix."* Option 2 is out.

**Scope of the pull request**
1. `load_dams.sql` `usa` CTE: give the placeholders their own id range, numbered in a stable order (`row_number() over (order by blue_line_key, downstream_route_measure)`), and carry `barrier_ind` through, or set `passability_status_code = 1` where it is true.
2. `load_crossings.sql`: a branch after the CABD-dams insert (around line 431) for `dams_vw` rows with no `cabd.dams` match, with `crossing_source` and `barrier_status` from the placeholder row. Read the existing dams insert for the column list and match it.
3. Out of scope: the latent passability-updates point above. It stays here, one upstream item at a time.

**Id range.** Offsets in use: `+ 1000000000` modelled crossings (max id 24,764,060, so up to 1,024,764,060) and `+ 1200000000` misc crossings (max id 53). PSCIS ids are under 205,000, and CABD ids are UUIDs. **`+ 1100000000` is free.** Propose it in the pull request and say it is his call. Check nothing else keys on the old `12000000xx` dam ids (`git grep 12000000` and the fix CSVs).

**Test database: `bcfishpass_dev` on the db_newgraph server** (through the tunnel), not the production `bcfishpass` database. Dev's last model run is 63 (`v0.7.15-68-g6c8fd845`, 2026-10-06). The bug reproduces there: same five rows, misc ids 3 to 5 present as `BARRIER`, 5 placeholder rows in `cabd_additions`. Whatever runs dev's model is unconfirmed (its commits aren't on upstream's branches). Ask before leaving lasting changes there.

How to test without leaving changes: `load_crossings.sql` is per-WSG inserts with `on conflict do nothing` into a crossings table the shell script truncates first, and `load_dams.sql` wraps itself in `begin` / `truncate` / `commit`. So a single transaction, rolled back at the end, can:
```
begin;
  -- load_dams.sql from the branch with its own begin/commit stripped
  delete from bcfishpass.crossings where watershed_group_code in ('KETL','LARL','SKGT');
  -- load_crossings.sql from the branch, -v wsg=KETL / LARL / SKGT
  -- acceptance queries below
rollback;
```
Never run this against production: `truncate bcfishpass.dams` takes an exclusive lock even inside a transaction that rolls back.

**Acceptance**
- All five placeholders are in `crossings` with `dam_id` set and `barrier_status = 'BARRIER'`, and are picked up by the `barriers_dams.sql` selection (`dam_id is not null`).
- Misc crossings 3, 4 and 5 are still in `crossings` with their own ids.
- KETL / LARL / SKGT crossings otherwise match the pre-change set: counts by `crossing_source`, no other ids gained or lost.
- Before/after counts go in the pull request body, as with `smnorris/bcfishpass#939`.

**Branches** (agent-operations §4)
- Work and planning: `15-dam-placeholders-crossings` off `main` (= upstream `main`, which now includes `3bd2824`, the steelhead fix) in a worktree, with `planning/active/`. Push to our fork only.
- Submit: `fix-dam-placeholders-crossings`, cut from `upstream/main`, code only, brought over with `cherry-pick --no-commit`. Check the tree matches minus `planning/`. Commit message carries no `#N` and no `Claude-Session:`, and keeps `Co-Authored-By` with no `Assisted-by` offer (settled for this maintainer).
- In this checkout `gh` resolves to upstream. Run `gh repo set-default NewGraphEnvironment/bcfishpass` before `/planning-init 15`, or pass `--repo` everywhere.

**Link side:** once merged, flip the link `bcfishpass` bundle (NewGraphEnvironment/link#244, NewGraphEnvironment/link#367).



## Phase 1 baseline: bcfishpass_dev (2026-10-25)

Model run 63, `v0.7.15-68-g6c8fd845`, db_version `202609281615`. Read-only session (`default_transaction_read_only=on`). KETL/LARL/SKGT hold 22,323 crossings; total crossings 525,538, dams 2,557.

```
== counts by source, KETL/LARL/SKGT
 wsg  |   crossing_source   | count 
------+---------------------+-------
 KETL | CABD                |    48
 KETL | MODELLED CROSSINGS  | 12075
 KETL | PSCIS               |   743
 KETL | USER_CROSSINGS_MISC |     1
 LARL | CABD                |    20
 LARL | MODELLED CROSSINGS  |  8326
 LARL | PSCIS               |   414
 SKGT | CABD                |     1
 SKGT | MODELLED CROSSINGS  |   695
(9 rows)

== barriers_dams selection, KETL/LARL/SKGT
 wsg  | count 
------+-------
 KETL |    47
 LARL |    20
 SKGT |     1
(3 rows)

== misc 3/4/5
 aggregated_crossings_id | user_crossing_misc_id |   crossing_source   | barrier_status | watershed_group_code 
-------------------------+-----------------------+---------------------+----------------+----------------------
 1200000003              |                     3 | USER_CROSSINGS_MISC | BARRIER        | QUES
 1200000004              |                     4 | USER_CROSSINGS_MISC | BARRIER        | QUES
 1200000005              |                     5 | USER_CROSSINGS_MISC | BARRIER        | BOWR
(3 rows)

== reprex
   dam_id   |   dam_name_en    | wsg  | passability_status_code | blue_line_key | downstream_route_measure | crossing_with_this_id 
------------+------------------+------+-------------------------+---------------+--------------------------+-----------------------
 1200000001 | Grand Coulee Dam | KETL |                         |     356570045 |                    53510 | 
 1200000002 | Grand Coulee Dam | LARL |                         |     356570372 |                  1175649 | 
 1200000003 | Grand Coulee Dam | LARL |                         |     356566717 |                      303 | USER_CROSSINGS_MISC
 1200000004 | Grand Coulee Dam | LARL |                         |     356546366 |                    10971 | USER_CROSSINGS_MISC
 1200000005 | Ross Dam         | SKGT |                         |     356570000 |                   196792 | USER_CROSSINGS_MISC
(5 rows)

== crossings total, dams total
 crossings | dams 
-----------+------
    525538 | 2557
(1 row)

```

Phase 4 also runs a control: the unchanged `upstream/main` SQL through the same rollback harness, so any drift between dev's stored crossings and a fresh reload is separated from the effect of the fix.
