#!/usr/bin/env bash

#################### SETUP ####################

# print status
s="START"
PS4='+  ${s}    ${LINENO}       $( date "+%Y.%m.%d %R") | '
set -x

# command fails -> exit
set -o errexit
# undeclared variables -> exit
set -o nounset
# mysqldump fails -> exit
set -o pipefail

###############################################

wd=$(pwd)

main(){
    my_dir="${wd}/prs_calculation"
    mkdir -p ${my_dir}

    aws s3 cp s3://.../mavaddat2019-313snps-liftover.tsv ${my_dir}
    aws s3 cp s3://.../<GRAR/SABE>.vcf.bgz ${my_dir}

    python3 prs_calculator.py \
        --effect-sizes ${my_dir}/mavaddat2019-313snps-liftover.tsv  \
        --vcf ${my_dir}/<GRAR/SABE>.vcf.bgz \
        > ${my_dir}/<GRAR/SABE>_output.tsv
}

main
