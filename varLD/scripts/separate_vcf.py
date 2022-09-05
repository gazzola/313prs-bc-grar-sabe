"""Separate populations on different vcf files"""
import click
import pandas as pd

@click.command()
@click.option(
    "--vcf-file",
    required = True,
    help = "VCF file with all samples")

@click.option(
    "--pop-file",
    required = True,
    help = "TSV file with <id> <TAB> <pop>. Pop will be utilized as a prefix")

@click.option(
    "--prefix",
    required = True,
    help = "prefix for separted files")

def main(vcf_file, pop_file, prefix):
    """Main function"""

    pop_file_df = pd.read_csv(pop_file, sep = "\t")
    my_pops = pop_file_df["cohort"].unique()
    vcf_file_df = pd.read_csv(vcf_file, sep = "\t")

    for my_pop in my_pops:
        fixed_filds = ['#CHROM','POS', 'ID', 'REF', 'ALT', 'QUAL', 'FILTER']
        my_pop_samples = pop_file_df[pop_file_df['cohort'] == my_pop]['s'].to_list()
        vcf_file_df[fixed_filds + my_pop_samples].to_csv( prefix+my_pop+".vcf", sep = '\t', index = False)

main() # pylint: disable=no-value-for-parameter
