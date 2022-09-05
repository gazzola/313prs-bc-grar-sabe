"""Script for variant selection to PRS"""
import hail as hl

# setting hail environment
hl.init(
    sc = sc, # pylint:disable=invalid-name,used-before-assignment,undefined-variable
    default_reference = "GRCh38")

# Inputs
PRS_FILE = "s3://...//mavaddat2019-313snps-liftover.tsv" # pylint:disable=line-too-long
TARGET_COHORT = "s3://.../<COHORT>.vcf.gz"
OUTPUT_DIR = "s3://..."
OUTPUT_NAME = "<COHORT>_prs.vcf.gz"


# Input files
mt_target = hl.import_vcf(TARGET_COHORT, force_bgz=True)
mt_target = mt_target.key_rows_by(mt_target.locus)

ht_selected_variants = hl.import_table(PRS_FILE, delimiter = "\t", impute = True)
ht_selected_variants = ht_selected_variants.annotate(
    locus = hl.locus(ht_selected_variants.chr, ht_selected_variants.pos_hg38)
)
ht_selected_variants = ht_selected_variants.key_by(ht_selected_variants.locus)

# Filtering variants
mt_target = mt_target.key_rows_by(mt_target.locus)
mt_target_selected = mt_target.semi_join_rows(
    ht_selected_variants
)

# Write output file
mt_target_selected = mt_target_selected.key_rows_by(
    mt_target_selected.locus,
    mt_target_selected.alleles
)

hl.export_vcf(mt_target_selected, OUTPUT_DIR+OUTPUT_NAME)
