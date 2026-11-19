# Code review: round 3

## Checklist read
- code-check-python.md: read in full (7 KB).
- code-check.md (331 KB): read the prose of all 14 H3s under `## Mechanisms`, without the `|` table rows. Skipped the other headings (Rules that stand alone, Security, Spreadsheets and PDFs, about 25 H3s), because none of them names a tool or shape this diff uses.
- code-check-shell.md (124 KB): read 1 heading, "psql does not interpolate `:'var'` inside a dollar-quoted string, and `\quit N` exits 0". The diff uses `:'wsg'`, but not inside `$$`. Skipped the other 63 headings.
- code-check-spatial.md (156 KB): read 0 headings and skipped all 90. They cover terra, sf, GDAL and bcdata, and none applies to plain PostGIS SQL. The FWA-measure rules do not apply either: the diff copies the measure-to-segment join already used elsewhere in the file.

## Mechanism walked: the id offset and source label against everything that keys on them

| Place | Agrees? |
|---|---|
| `load_crossings.sql:510`: misc crossings use `user_crossing_misc_id + 1200000000` (largest misc id is 53) | Yes. Placeholders are now 1100000001 to 1100000005, so the two ranges no longer overlap. |
| `load_crossings.sql:627`: modelled crossings use `+ 1000000000` | Yes, as long as the largest modelled_crossing_id stays under 100,000,000 (it is about 24.7 M now). |
| PSCIS ids (`stream_crossing_id::text`, under 205k) and CABD ids (text UUIDs) | Yes. A numeric placeholder id cannot equal a UUID, so `left join cabd.dams ... where cabd.cabd_id is null` (`load_crossings.sql:495-496`) picks exactly the `usa` rows: load_dams.sql only lets CABD rows in through an inner join to `cabd.dams`. |
| `crossings_pkey` on aggregated_crossings_id, plus unique keys on (blue_line_key, measure), modelled_crossing_id, stream_crossing_id and user_crossing_misc_id (`db/schema.sql:15050-15147`) | Yes. The placeholder blue_line_key/measure pairs do not match any row in `user_crossings_misc.csv`, which was checked. |
| Types: `dams.passability_status_code integer`, `cabd.dams.passability_status_code integer` and `cabd_additions.barrier_ind boolean` | Yes. The `union all` in load_dams.sql gets integer from both branches. |
| `barriers_dams.sql` (`dam_id is not null`, BARRIER/POTENTIAL, mainstem) | Yes. Placeholders reach it with BARRIER. |
| `barriers_dams_hydro.sql` (`dam_use = 'Hydroelectricity'`) | Placeholders are left out because their dam_use is NULL. This was accepted as out of scope. |
| `barriers_anthropogenic.sql`, `02_model_access_anthropogenic.sh` barrier sets | Yes. They key on barrier_status, not on source or id range. |
| `crossing_feature_type` update (`load_crossings.sql:703-789`) | Yes. subtype DAM gives DAM. |
| Things that parse the id: casts, LIKE, ranges or length on aggregated_crossings_id anywhere in model/, db/, wcrp/ and jobs/ | None found. Every aggregated_crossings_id column and array is `text`. |
| Persisted references to the ids: data/*.csv with aggregated_crossings_id or dam_id columns (`crossings_sidechannel_upstream_startpoints.csv`), and wcrp tables | None refer to 1100000000 or 1200000000 ids. Crossings are truncated before every run. |
| `crossing_source` value set: schema comment `{PSCIS,MODELLED CROSSINGS,CABD,MISC BARRIERS}`, no CHECK constraint | Yes. This is the same label the pre-7e1cdfa9 insert used. |
| Pass-through consumers: crossings_vw, freshwater_fish_habitat_accessibility_model_crossings_vw, wcrp `load_crossings_wcrp.sql` and `rank_barriers.py`, jobs `release_fptwg` and `release_cwf` | Yes. None filters on CABD or on an id pattern. |
| `app/style_salmon.json:309` styles dams only where `crossing_source == 'CABD'` | Display only, and USER_CROSSINGS_MISC rows are unstyled in the same way. This follows from the accepted label choice and does not break anything. |
| Schema comments and `docs/tables/crossings_vw.csv` describing the offsets | Already stale upstream, and nothing functional reads them. Out of scope. |
| Run order (`01_model_access_natural.sh:107-114`): load_dams.sql once, then truncate, then load_crossings per wsg | Yes. Statuses and ids are fixed before any crossings insert. |

## Clean
No issues found.
