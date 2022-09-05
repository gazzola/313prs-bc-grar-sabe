import hail as hl

hl.init()

def get_region(locus_string, window = 500000):
    '''Convert 'chr1:10506158' to 'chr1:10496158-10516158' '''
    my_chr, my_pos = locus_string.split(":")
    my_lower = str(int(my_pos) - window)
    my_upper = str(int(my_pos) + window)
    region = f"{my_chr}:{my_lower}-{my_upper}"
    return region

grar_mt  = hl.read_matrix_table("<GRAR MT>")
onekg_mt = hl.read_matrix_table("<1KGP3 MT>")
sabe_mt = hl.read_matrix_table("<SABE MT>")

mt = grar_mt.select_entries('GT').union_cols(onekg_mt.drop('sample_data'))
mt = mt.union_cols(sabe_mt.select_entries('GT'))
mt = mt.filter_rows(hl.len(mt.alleles) == 2)

snps = hl.import_table("<313-PRS LOCI>")
snps_list = snps.select(snps.locus_hg38).collect()
snps_list = [x.locus_hg38 for x in snps_list]

for my_snp in snps_list:
    my_region = get_region(my_snp)
    mt_region = hl.filter_intervals(
        mt,[hl.parse_locus_interval(my_region, reference_genome = "GRCh38")])
    mt_region = mt_region.key_rows_by(mt_region.locus, mt_region.alleles)
    hl.export_vcf(mt_region, f"<OUTPUT_DIR>/<OUTPUT_PREFIX>{my_region}.vcf.gz")
