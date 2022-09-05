import click

@click.command()
@click.option(
    "--vcf-file",
    required = True,
    help = "VCF file")
@click.option(
    "--header-outfile",
    required = True,
    help = "output header")
@click.option(
    "--outfile",
    required = True,
    help = "output file")
def main(vcf_file, header_outfile, outfile):
    '''Main function'''
    i = 0
    with open(vcf_file, "r", encoding="utf-8") as my_file, open(outfile, "a", encoding = "utf-8") as ofile:
        for line in my_file:
            if line[0:2] == "#C":
                header = line.rstrip().split("\t")
                samples = header[9::]
                with open(header_outfile, "w", encoding = "utf-8") as hfile:
                    hfile.write("\t".join(["snp_id", "pos"] + samples))

            elif line[0:2] != "##":
                line = line.rstrip().split("\t")
                genotypes = line[9::]

                genotypes_varld = [ convert_genotype(x) for x in genotypes ]
                snp_id = "_".join([line[0], line[1], line[3], line[4]])

                ofile.write("\t".join([snp_id, line[1]] + genotypes_varld + ['\n']))

                if i % 10000 == 0:
                    print(f"{i} lines processed")

                i += 1

def convert_genotype(genotype_string):
    '''Convert 0/0 vcf format to 1,2,3,4 varLD format'''
    genotype1 = genotype_string[0]
    genotype2 = genotype_string[2]
    if genotype1 == ".":
        ld_genotype = 4
    elif genotype1 == "0" and genotype2 == "0":
        ld_genotype = 1
    elif genotype1 == "0" or genotype2 == "0":
        ld_genotype = 2
    else:
        ld_genotype = 3

    return str(ld_genotype)

main() # pylint: disable=no-value-for-parameter
