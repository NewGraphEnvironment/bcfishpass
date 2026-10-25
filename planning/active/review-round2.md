## Checklist read

- `code-check-python.md` (7 KB): read in full.
- `code-check.md` (331 KB): read the prose of all 14 H3s under `## Mechanisms`, skipping the `|` table rows (about 61 KB of prose). Did not read the 24 headings under "Rules that stand alone", "Security" and "Spreadsheets and PDFs": none names a tool or pattern this diff uses.
- `code-check-shell.md` (124 KB): read "psql does not interpolate `:'var'` inside a dollar-quoted string, and `\quit N` exits 0", because the diff uses `:'wsg'`. Did not read the other 66 headings.
- `code-check-spatial.md` (156 KB): read "FWA `upstream_route_measure` misses the next segment's start", because the diff relies on FWA route measures. Did not read the other 92 headings.

## Clean

No issues found.

### What was checked (all held)

- **The anti-join selects only the placeholders.** `cabd_pts` in `load_dams.sql` inner-joins `cabd.dams` on `n.dam_id = cabd.cabd_id`. `cabd.dams.cabd_id` and `bcfishpass.dams.dam_id` are both `text`, and `dam_id` is copied directly from `cabd_id`. So every CABD row in `bcfishpass.dams` has a match, and `left join cabd.dams ... where cabd.cabd_id is null` returns only rows from `usa`. The CABD insert uses the same key as an inner join, so the two inserts cannot pick up the same row.
- **The insert matches the schema.** Every target column exists in `bcfishpass.crossings` with a compatible type. `geom` is a PointZM from `st_dump(st_locatealong(s.geom, ...))`, built the same way as in the CABD insert. `dam_name_en` maps to `dam_name`. `crossings` has no CHECK constraint on `crossing_source` or `barrier_status`.
- **The ids cannot collide with other ids.** The placeholders get `1100000001`–`1100000005`.
  - Modelled crossings are `+1000000000`, with a maximum id of about 24.8M.
  - Misc crossings are `+1200000000`.
  - PSCIS ids are below 205k, and CABD ids are UUID text.
  - Every id is below 2^31, so an integer cast of `aggregated_crossings_id` would not overflow.
  - `git grep` finds no reference to the old `12000000xx` dam ids in `data/`, `model/` or `jobs/`. `crossings` is truncated before every run.
- **The `usa` CTE is valid.** The `order by blue_line_key, downstream_route_measure` inside `over()` reads subquery `f`'s columns, so neither name is ambiguous. The added `a.barrier_ind` appears only in `f` and in the CTE's `*`. The final select lists its columns explicitly, so the insert column list still lines up.
- **The status reaches the consumers.** `barrier_ind` (boolean) maps true to 1 to `BARRIER` and false to 3 to `PASSABLE`. All five CSV rows are `t`.
  - `crossing_subtype_code = 'DAM'` gives `crossing_feature_type = 'DAM'` in the later update.
  - `barriers_dams.sql` filters on `dam_id IS NOT NULL AND barrier_status IN ('BARRIER','POTENTIAL')`, so the placeholders reach it. `barriers_anthropogenic.sql` filters on `barrier_status` alone, so they reach it too.
  - `barriers_pscis.sql` requires `stream_crossing_id`, so the placeholders do not appear there twice.
  - `barriers_dams_hydro.sql` needs `dam_use = 'Hydroelectricity'`, which the placeholders do not have. That gap is out of scope, as agreed.
- **Insert order and conflicts.** No row in any `data/*.csv` uses the five placeholder blue line keys apart from `cabd_additions.csv`. So moving the placeholders ahead of misc and modelled crossings does not displace a known row. The general exposure to `on conflict do nothing` was accepted.
- **psql variable.** `:'wsg'` is in plain SQL, not in a dollar-quoted body, so psql substitutes it.
- **Matching a measure to a segment** (`ROUND(a.dsm) >= ROUND(s.dsm) AND < ROUND(s.usm)`) is unchanged from before. The rounded ranges of adjacent segments are half-open intervals with no gaps or overlaps, so each placeholder matches at most one segment. The 1 cm drift between FWA segment measures does not matter at whole-metre rounding.

### Note (not a defect)

The new comment says the ids are "stable between runs". That holds only while `cabd_additions.csv` keeps the same dam rows. Adding a placeholder with a lower `(blue_line_key, measure)` renumbers every placeholder after it. Nothing in the repo keys on these ids, so nothing breaks today. The ids do appear as `aggregated_crossings_id` in the release exports, though, so external users of those exports would see them change.
