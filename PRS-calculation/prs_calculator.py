"""Script for calculation PRS in a additive fashion"""
import gzip
import click
import pandas as pd

@click.command()
@click.option(
    '--effect-sizes',
    required=True,
    help='Effect size file (column names are very specific).'
)
@click.option(
    '--vcf',
    required=True,
    help='VCF filename.'
)
def main(effect_sizes, vcf):
    """Main function"""
    effect_sizes = load_effect_sizes(effect_sizes)
    calc_vcf_prs(vcf, effect_sizes)

def load_effect_sizes(effect_sizes):
    """Get effect size for each variant"""
    effect_sizes = pd.read_csv(effect_sizes, sep = "\t")
    effect_sizes = effect_sizes[['chr', 'pos_hg38', 'risk_allele', 'weight']]
    effect_sizes['chr'] = effect_sizes['chr'].astype(str)
    effect_sizes['pos_hg38'] = effect_sizes['pos_hg38'].astype(int)
    effect_sizes['locus'] = effect_sizes['chr'].astype(str) + ':' + effect_sizes['pos_hg38'].astype(str) # pylint: disable=line-too-long

    effect_sizes_dict = effect_sizes[['locus', 'weight','risk_allele']].set_index('locus').T.to_dict() # pylint: disable=line-too-long

    return effect_sizes_dict

def calc_vcf_prs(vcf,effect_sizes):
    """Print output file"""
    i = 0
    with gzip.open(vcf, 'rt') as vcf_file:
        for raw_line in vcf_file:
            line = raw_line.split('\t')

            if raw_line[0:2] == '##':
                continue

            if i == 0:
                vcf_names = get_and_print_header(line)
                index_chr = vcf_names.index('CHROM')
                index_pos = vcf_names.index('POS')

                i += 1
            else:
                print_output_line(line, vcf_names, effect_sizes, index_chr, index_pos)

def print_output_line(line, vcf_names, effect_sizes, index_chr, index_pos):
    """Print output line"""
    locus = line[index_chr]+":"+line[index_pos]

    effect_size_locus = effect_sizes[locus]['weight']
    effect_allele = effect_sizes[locus]['risk_allele']

    # get risk_allele index
    effect_allele_index = get_effect_allele_index(line, effect_allele, vcf_names)

    n_samples = len(vcf_names)

    sample_effects = [
        sum_effect_allele_index(
            sample_genotype = x.split(":")[0],
            effect_allele_index = effect_allele_index,
            effect_size_locus = effect_size_locus) for x in line[9:n_samples]
    ]

    print("\t".join(line[0:9]+ [str(x) for x in sample_effects]))

def get_and_print_header(line):
    """Print header"""
    vcf_names = [x.strip() for x in line]
    vcf_names[0] = 'CHROM'

    print("\t".join(vcf_names))
    return vcf_names

def sum_effect_allele_index(sample_genotype, effect_allele_index, effect_size_locus):
    """Calc additive model"""
    return sample_genotype.count(str(effect_allele_index)) * effect_size_locus

def get_effect_allele_index(line, effect_allele, vcf_names):
    """Get index for effect allele in multiallelic fields"""
    try:
        effect_allele_index = line[vcf_names.index('ALT')].split(",").index(effect_allele) + 1
    except ValueError:
        effect_allele_index = -1

    return effect_allele_index


if __name__ == "__main__":
    main() # pylint: disable=no-value-for-parameter
