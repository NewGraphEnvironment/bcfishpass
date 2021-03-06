-- Calculate "Barrier Severity" as
-- "the % of each barrier type that are barriers/potential barriers (out of those that have been assessed)"
-- (with further restriction that the barriers be on potentially accessible streams)

WITH totals AS
(
  SELECT
  watershed_group_code,
  wcrp_barrier_type,
  count(*) as n_total
FROM bcfishpass.crossings
WHERE watershed_group_code IN ('BULK','LNIC','HORS','ELKR')
AND (stream_crossing_id IS NOT NULL OR dam_id IS NOT NULL)
AND (accessibility_model_salmon IS NOT NULL
    OR
    accessibility_model_steelhead IS NOT NULL
    OR
    accessibility_model_wct IS NOT NULL
    )
GROUP BY watershed_group_code, wcrp_barrier_type
ORDER BY watershed_group_code, wcrp_barrier_type
),

barrier_potential AS
(
SELECT
  watershed_group_code,
  wcrp_barrier_type,
  count(*) as n_barrier
FROM bcfishpass.crossings
WHERE watershed_group_code IN ('BULK','LNIC','HORS','ELKR')
AND (stream_crossing_id IS NOT NULL OR dam_id IS NOT NULL)
AND barrier_status in ('BARRIER', 'POTENTIAL')
AND (accessibility_model_salmon IS NOT NULL
    OR
    accessibility_model_steelhead IS NOT NULL
    OR
    accessibility_model_wct IS NOT NULL
    )
GROUP BY watershed_group_code, wcrp_barrier_type
)

SELECT
  t.watershed_group_code,
  t.wcrp_barrier_type,
  COALESCE(b.n_barrier, 0) as n_assessed_barrier,
  t.n_total as n_assessed_total,
  ROUND((COALESCE(b.n_barrier, 0) * 100)::numeric / t.n_total, 1) AS pct_assessed_barriers
FROM totals t
LEFT OUTER JOIN barrier_potential b
ON t.watershed_group_code = b.watershed_group_code
AND t.wcrp_barrier_type = b.wcrp_barrier_type


