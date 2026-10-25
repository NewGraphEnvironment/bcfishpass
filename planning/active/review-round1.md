## Checklist read

- code-python.md (`code-check-python.md`, 7 KB): in full.
- `code-check.md` (331 KB): prose of all 14 H3s under `## Mechanisms`, with the `|` table rows skipped. I read every word of the first four and of "Zero-length, empty, and unset" and "Written data outlives the fix", and skimmed the rest. I read none of the 24 headings under "Rules that stand alone", "Security" and "Spreadsheets and PDFs", because none names a tool or pattern this diff uses.
- `code-check-shell.md` (124 KB): read "psql does not interpolate `:'var'` inside a dollar-quoted string, and `\quit N` exits 0" (the diff uses `:'wsg'`). Did not read the other 61 headings.
- `code-check-spatial.md` (156 KB): read "FWA `upstream_route_measure` misses the next segment's start" (the diff uses FWA route measures). Did not read the other 92 headings.

## Clean

No issues found.

### What was checked (all held)

- **Id range.** The ids `1100000001`–`1100000005` do not collide with modelled crossings (`+1000000000`, max about 1,024,764,060), misc crossings (`+1200000000`), PSCIS ids (under 205k) or CABD ids (text UUIDs). Nothing in `data/` or `model/` refers to the old `12000000xx` dam ids. Crossings are truncated on every run, and the placeholders have not reached crossings since v0.7.7, so no stored data still carries the old ids.
- **`usa` CTE.** `order by blue_line_key, downstream_route_measure` refers to subquery `f`'s columns, so it is not ambiguous. The added `barrier_ind` sits only inside `f` and the CTE's `*`. The final select lists its columns explicitly, so the `insert into bcfishpass.dams` column list still lines up. `dams_pkey (dam_id)` stays unique.
- **Status mapping.** `cabd_additions.barrier_ind` is `boolean`, and `dams.passability_status_code` is `integer`. `t`→1→`BARRIER` and `f`→3→`PASSABLE`. All five CSV rows are `t`, so all five become `BARRIER` and go into `barriers_dams.sql`, which filters on `dam_id IS NOT NULL AND barrier_status IN ('BARRIER','POTENTIAL')`. A NULL `barrier_ind` would give a NULL status, so the dam would not be a barrier. `load_falls.sql` handles `barrier_ind` from the same table the same way, so the behaviour is consistent and no current row triggers it.
- **New crossings insert.** The anti-join `left join cabd.dams ... where cabd.cabd_id is null` picks exactly the placeholder rows: `cabd_pts` inner-joins `cabd.dams`, and `cabd.dams.cabd_id` is `text`, so `::text` does nothing. The CABD insert inner-joins on the same key, so the two inserts cannot overlap. The column list matches the target types (`geom` PointZM comes from `st_locatealong` on the FWA geometry, the same as the CABD insert). `crossing_subtype_code = 'DAM'` gives `crossing_feature_type = 'DAM'` in the later update, so `barriers_dams.barrier_type` is filled. `:'wsg'` sits in plain SQL, not inside a dollar-quoted block, so psql substitutes it.
- **Insert order.** The placeholders now go in before misc crossings and modelled crossings. Only a crossing at exactly the same `(blue_line_key, downstream_route_measure)` could be pushed out by `on conflict do nothing`, which is the same exposure every other insert in this file has. The placeholder measures are whole metres on major main stems.
