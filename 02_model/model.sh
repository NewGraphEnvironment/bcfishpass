#!/bin/bash
set -euxo pipefail


# create table for each type of definite (not generally fixable) barrier
psql -f sql/barriers_majordams.sql
psql -f sql/barriers_ditchflow.sql
psql -f sql/barriers_falls.sql
psql -f sql/barriers_gradient_15.sql
psql -f sql/barriers_gradient_20.sql
psql -f sql/barriers_gradient_30.sql
psql -f sql/barriers_intermittentflow.sql
psql -f sql/barriers_subsurfaceflow.sql
psql -f sql/barriers_other_definite.sql

# create a single tables of anthropogenic barriers / potential barriers for prioritization
# (smaller dams / pscis crossings / modelled culverts / other)
psql -f sql/barriers_anthropogenic.sql

# Create output streams table - edit sql file to specify watershed groups of interest
psql -f sql/streams.sql

# Create observations table with species of interest - edit sql file for spp of interest
psql -f sql/observations.sql

# break streams at observations
python bcfishpass.py segment-streams bcfishpass.streams bcfishpass.observations

# break streams at barriers (that are not already at end of stream lines, ditchflow, intermittentflow, subsurfaceflow)
python bcfishpass.py segment-streams bcfishpass.streams bcfishpass.barriers_falls
python bcfishpass.py segment-streams bcfishpass.streams bcfishpass.barriers_gradient_15
python bcfishpass.py segment-streams bcfishpass.streams bcfishpass.barriers_gradient_20
python bcfishpass.py segment-streams bcfishpass.streams bcfishpass.barriers_gradient_30
python bcfishpass.py segment-streams bcfishpass.streams bcfishpass.barriers_majordams
python bcfishpass.py segment-streams bcfishpass.streams bcfishpass.barriers_other_definite
python bcfishpass.py segment-streams bcfishpass.streams bcfishpass.barriers_anthropogenic
# also break streams at all PSCIS crossings - these are not necessarily barriers but
# we often want to report on PSCIS crossings regardless of barrier status
python bcfishpass.py segment-streams bcfishpass.streams bcfishpass.pscis_events_sp

# create a waterfalls table for evaluation, break streams at waterfalls
psql -f sql/waterfalls.sql
python bcfishpass.py segment-streams bcfishpass.streams bcfishpass.waterfalls

# add column tracking upstream observations
python bcfishpass.py add-upstream-ids bcfishpass.streams segmented_stream_id bcfishpass.observations fish_obsrvtn_pnt_distinct_id upstr_observation_id

# add columns tracking downstream barriers
python bcfishpass.py add-downstream-ids bcfishpass.streams segmented_stream_id bcfishpass.barriers_gradient_15 barriers_gradient_15_id dnstr_barriers_gradient_15 --include_equivalent_measure
python bcfishpass.py add-downstream-ids bcfishpass.streams segmented_stream_id bcfishpass.barriers_gradient_20 barriers_gradient_20_id dnstr_barriers_gradient_20 --include_equivalent_measure
python bcfishpass.py add-downstream-ids bcfishpass.streams segmented_stream_id bcfishpass.barriers_gradient_30 barriers_gradient_30_id dnstr_barriers_gradient_30 --include_equivalent_measure
python bcfishpass.py add-downstream-ids bcfishpass.streams segmented_stream_id bcfishpass.barriers_ditchflow barriers_ditchflow_id dnstr_barriers_ditchflow --include_equivalent_measure
python bcfishpass.py add-downstream-ids bcfishpass.streams segmented_stream_id bcfishpass.barriers_falls barriers_falls_id dnstr_barriers_falls --include_equivalent_measure
python bcfishpass.py add-downstream-ids bcfishpass.streams segmented_stream_id bcfishpass.barriers_intermittentflow barriers_intermittentflow_id dnstr_barriers_intermittentflow --include_equivalent_measure
python bcfishpass.py add-downstream-ids bcfishpass.streams segmented_stream_id bcfishpass.barriers_majordams barriers_majordams_id dnstr_barriers_majordams --include_equivalent_measure
python bcfishpass.py add-downstream-ids bcfishpass.streams segmented_stream_id bcfishpass.barriers_other_definite barriers_other_definite_id dnstr_barriers_other_definite --include_equivalent_measure
python bcfishpass.py add-downstream-ids bcfishpass.streams segmented_stream_id bcfishpass.barriers_subsurfaceflow barriers_subsurfaceflow_id dnstr_barriers_subsurfaceflow --include_equivalent_measure
python bcfishpass.py add-downstream-ids bcfishpass.streams segmented_stream_id bcfishpass.barriers_anthropogenic barriers_anthropogenic_id dnstr_barriers_anthropogenic --include_equivalent_measure

# classify streams per accessibility model based on the upstream / downstream features processed above
psql -f sql/model.sql

# add downstream ids to barrier tables too - handy for reporting
python bcfishpass.py add-downstream-ids bcfishpass.barriers_falls barriers_falls_id bcfishpass.barriers_falls barriers_falls_id dnstr_barriers_falls_id
python bcfishpass.py add-downstream-ids bcfishpass.barriers_gradient_15 barriers_gradient_15_id bcfishpass.barriers_gradient_15 barriers_gradient_15_id dnstr_barriers_gradient_15_id
python bcfishpass.py add-downstream-ids bcfishpass.barriers_gradient_20 barriers_gradient_20_id bcfishpass.barriers_gradient_20 barriers_gradient_20_id dnstr_barriers_gradient_20_id
python bcfishpass.py add-downstream-ids bcfishpass.barriers_gradient_30 barriers_gradient_30_id bcfishpass.barriers_gradient_30 barriers_gradient_30_id dnstr_barriers_gradient_30_id
python bcfishpass.py add-downstream-ids bcfishpass.barriers_majordams barriers_majordams_id bcfishpass.barriers_majordams barriers_majordams_id dnstr_barriers_majordams_id
python bcfishpass.py add-downstream-ids bcfishpass.barriers_other_definite barriers_other_definite_id bcfishpass.barriers_other_definite barriers_other_definite_id dnstr_barriers_other_definite_id
python bcfishpass.py add-downstream-ids bcfishpass.barriers_anthropogenic barriers_anthropogenic_id bcfishpass.barriers_anthropogenic barriers_anthropogenic_id dnstr_barriers_anthropogenic_id
python bcfishpass.py add-downstream-ids bcfishpass.barriers_intermittentflow barriers_intermittentflow_id bcfishpass.barriers_intermittentflow barriers_intermittentflow_id dnstr_barriers_intermittentflow_id
python bcfishpass.py add-downstream-ids bcfishpass.barriers_ditchflow barriers_ditchflow_id bcfishpass.barriers_ditchflow barriers_ditchflow_id dnstr_barriers_ditchflow_id
python bcfishpass.py add-downstream-ids bcfishpass.barriers_subsurfaceflow barriers_subsurfaceflow_id bcfishpass.barriers_subsurfaceflow barriers_subsurfaceflow_id dnstr_barriers_subsurfaceflow_id

# for qa, report on how much is upstream of various definite barriers
python bcfishpass.py report bcfishpass.barriers_ditchflow barriers_ditchflow_id
python bcfishpass.py report bcfishpass.barriers_falls barriers_falls_id
python bcfishpass.py report bcfishpass.barriers_gradient_15 barriers_gradient_15_id
python bcfishpass.py report bcfishpass.barriers_gradient_20 barriers_gradient_20_id
python bcfishpass.py report bcfishpass.barriers_gradient_30 barriers_gradient_30_id
python bcfishpass.py report bcfishpass.barriers_intermittentflow barriers_intermittentflow_id
python bcfishpass.py report bcfishpass.barriers_majordams barriers_majordams_id
python bcfishpass.py report bcfishpass.barriers_subsurfaceflow barriers_subsurfaceflow_id

# and waterfalls
python bcfishpass.py report bcfishpass.waterfalls falls_id