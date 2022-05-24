#!/bin/bash
set -euxo pipefail

# --------
# - load BC dam data compiled by CWF
# - match to FWA streams
# --------
PSQL_CMD="psql $DATABASE_URL -v ON_ERROR_STOP=1"

# ---------
# download CWF dam data and match to FWA streams
# ---------
ogr2ogr -f PostgreSQL \
  "PG:$DATABASE_URL" \
  -overwrite \
  -s_srs EPSG:4326 \
  -t_srs EPSG:3005 \
  -lco GEOMETRY_NAME=geom \
  -lco FID=bcdams_id \
  -nln bcfishpass.cwf_bcdams \
  /vsicurl/https://raw.githubusercontent.com/smnorris/bcdams/main/bcdams.geojson \
  bcdams

# match the dams to streams
$PSQL_CMD -f sql/dams.sql

# remove Merton Creek dam - it gets snapped to Salmon River and
# does not appear to be a barrier
$PSQL_CMD -c "delete from bcfishpass.dams where dam_id = 209"