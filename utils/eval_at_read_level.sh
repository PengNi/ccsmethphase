#!/bin/bash

# set -x
bsbedmethyl=${1}
ds_read_tsv=${2}
# dsname=${3}
result_file=${3}


echo "#### eval deepsignal at read level"

# get hc pos/neg poses
# hc_pos_file="${dsname}_${bsbedmethyl}.hc_pos.tsv"
# hc_neg_file="${dsname}_${bsbedmethyl}.hc_neg.tsv"
hc_pos_file="${bsbedmethyl}.hc_pos.tsv"
hc_neg_file="${bsbedmethyl}.hc_neg.tsv"

python utils/get_hc_positions_from_bedmethyl.py \
    --posinfo_fp ${bsbedmethyl} \
    --prmet 1.0 --nrmet 0.0 --coverage_lb 5 --is_only_chr yes \
    --wfile_pos ${hc_pos_file} --wfile_neg ${hc_neg_file}

# select sites in reads of hc pos/neg poses
# hc_pos_in_reads="${dsname}_${ds_read_tsv}.hc_pos.tsv"
# hc_neg_in_reads="${dsname}_${ds_read_tsv}.hc_neg.tsv"
hc_pos_in_reads="${ds_read_tsv}.hc_pos.tsv"
hc_neg_in_reads="${ds_read_tsv}.hc_neg.tsv"

python utils/filter_call_mods_by_positions.py \
    --cm_path ${ds_read_tsv} \
    --pos_fp ${hc_pos_file} \
    --wfile ${hc_pos_in_reads}
python utils/filter_call_mods_by_positions.py \
    --cm_path ${ds_read_tsv} \
    --pos_fp ${hc_neg_file} \
    --wfile ${hc_neg_in_reads}

# eval read level
# depth_cf is not needed for ont data, but need to set it a value as it is a required arg 
python utils/eval_at_read_level.py \
    --unmethylated ${hc_neg_in_reads} \
    --methylated ${hc_pos_in_reads} \
    --depth_cf -1 --prob_cf 0.66 \
    --result_file ${result_file}

# clean tmp files
rm ${hc_pos_file}
rm ${hc_neg_file}
rm ${hc_pos_in_reads}
rm ${hc_neg_in_reads}

echo "#### eval at read level, DONE"