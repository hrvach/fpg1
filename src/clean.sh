#!/bin/bash

find -name "*.bak" -delete
find -name "*.orig" -delete
find -name "*.rej" -delete

rm -rf  db
rm -rf  incremental_db
rm -rf  output_files
rm -rf  output
rm -rf  simulation
rm -rf  greybox_tmp
rm -rf  hc_output
rm -rf  .qsys_edit
rm -rf  hps_isw_handoff
rm -rf  sys/.qsys_edit
rm -rf  sys/vip

rm -rf sys/pll_sim/

find -name "*_sim" -print0 | xargs -0 rm
find -name "*_sim" -delete

find -name build_id.v -delete
find -name c5_pin_morm_dump.txt -delete
find -name PLLJ_PLLSPE_INFO.txt -delete

find -iregex '.*\.\(qws\|ppf\|ddb\|cmp\|sip\|spd\|bsf\|f\|sopcinfo\|xml\|cdf\|csv\)$' -delete

find -name "new_rtl_netlist" -delete
find -name "old_rtl_netlist" -delete

rm *.cdf
rm sys/vip.qip
rm sys/sysmem.qip
rm sys/sdram.sv
rm sys/ddram.sv
