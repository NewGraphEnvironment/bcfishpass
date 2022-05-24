INSERT INTO bcfishpass.barrier_load
(
    barrier_load_id,
    barrier_type,
    barrier_name,
    linear_feature_id,
    blue_line_key,
    watershed_key,
    downstream_route_measure,
    wscode_ltree,
    localcode_ltree,
    watershed_group_code,
    geom
)

SELECT
    aggregated_crossings_id,
    crossing_feature_type as barrier_type,
    crossing_source as barrier_name,
    linear_feature_id,
    blue_line_key,
    watershed_key,
    downstream_route_measure,
    wscode_ltree,
    localcode_ltree,
    watershed_group_code as watershed_group_code,
    geom as geom
FROM bcfishpass.crossings
-- note that we only include crossings that are still passable,
-- any remediations that have failed are not displayed
WHERE
  pscis_status = 'REMEDIATED' AND
  barrier_status = 'PASSABLE' AND
  watershed_group_code = :'wsg'
ON CONFLICT DO NOTHING;