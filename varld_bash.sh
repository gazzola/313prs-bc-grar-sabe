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

wd=$(dirname $(realpath $0))

main(){
    download_vcfs
    separate_vcfs
    convert_vcf_varldinput
    run_var_ld
    merge
}

download_vcfs(){
    mkdir ${wd}/00-vcfs
    aws s3 sync "<PATH_HAIL_OUT>" 00-vcfs
}

separate_vcfs(){
    my_dir="${wd}/01-separate-vcfs"
    mkdir -p ${my_dir}

    for my_file in $(find ${wd}/00-vcfs -name "*.vcf.gz"); do
        filename=$(sed 's|.*/||' <<< $my_file)
        python3 scripts/separate_vcf.py \
            --pop-file sample-data-grarbc-1kgp3-sabe.tsv  \
            --vcf-file <(zcat ${my_file} | grep -v "^##") \
            --prefix "${my_dir}/"$(sed 's/\:/-/g;s/\..*//g' <<< $filename)"_"
    done
}

convert_vcf_varldinput(){
    my_dir="${wd}/02-convert-vcf-varldinput"
    mkdir -p ${my_dir}/tmp
    for my_file in $(find "${wd}/01-separate-vcfs" -name "*.vcf"); do
        filename=$(sed 's|.*/||' <<< $my_file)
        cat ${my_file} > ${my_dir}/tmp/${filename/.vcf/.vcf}
        python3 ${wd}/scripts/vcf_to_varld_input.py \
            --vcf-file ${my_dir}/tmp/${filename/.vcf/.vcf} \
            --outfile ${my_dir}/${filename/.vcf/.tsv} \
            --header-outfile ${my_dir}/${filename/.vcf/_h.tsv}    
    done

    rm -rf ${my_dir}/tmp
}

run_var_ld(){
    # varLD Website: https://blog.nus.edu.sg/sshsphphg/varld/
    my_dir="${wd}/03-varLD"
    mkdir -p ${my_dir}/
    
    for my_file in $(find ${wd}/02-convert-vcf-varldinput/ -name "*_SABE.tsv"); do
        for pop in GRAR AFR EAS EUR; do
            java -jar ${wd}/scripts/varLD/rgenetics-1.0.jar \
                -p VarLD \
                --output "${my_dir}/"$(basename ${my_file/_SABE.tsv})"_SABE_${pop}_varld.txt" \
                $my_file\
                $(sed "s/_SABE/_"${pop}"/" <<< $my_file);
        done
    done
}

merge(){
    awk \
        'BEGIN{OFS=FS="\t"}
        (NR==1){print}
        (NR!=1 && FNR > 1){print}' \
        ${wd}/03-varLD/*.txt \
        > ${wd}/"<VAR_LD_OUTPUT>"
}

main