import os
import sys

import pandas as pd

# Argumentos
# - El archivo tsv
# El nombre del archivo donde quiero poner el .txt


def make_accession_file(tsv_file, out_file):
    df = pd.read_csv(tsv_file, sep="\t")
    accs = df["SRR_accession"]

    accs.to_csv(out_file, sep="\t", header=False, index=False)


x = os.listdir("output")

for id in x:
    ...
    infile = os.path.join("output", id)
    infile += "/" + id + "_sra_metadata.tsv"

    outfile = "sra_accessions/" + id + "_sra_accessions.tsv"
    make_accession_file(infile, outfile)
