#!/usr/bin/env bash

set -e # Exit on error

folder=$1

# Ensure folder ends with /
[[ "${folder}" != */ ]] && folder="${folder}/"

project_accession=$(basename "$folder")
sra_file="${folder}${project_accession}_sra_metadata.tsv"

if [[ ! -f "$sra_file" ]]; then
  echo "File not found: $sra_file"
  exit 1
fi

# Get column numbers for SRR_accession and alias
srr_col=$(head -n1 "$sra_file" | tr '\t' '\n' | awk '/^SRR_accession$/ {print NR}')
alias_col=$(head -n1 "$sra_file" | tr '\t' '\n' | awk '/^alias$/ {print NR}')
echo "SRR_accession column: $srr_col"
echo "alias column: $alias_col"

# Create downloads folder if it doesn't exist
downloads_folder="${folder}downloads"
mkdir -p "$downloads_folder"

# Loop through the file and download each SRR using the alias as filename
tail -n +2 "$sra_file" | awk -F'\t' -v srr="$srr_col" -v alias="$alias_col" '{print $srr "\t" $alias}' | while IFS=$'\t' read -r acc alias; do
  echo "Downloading and converting $acc to FASTQ..."
  prefetch "$acc" -O "$downloads_folder"
  fasterq-dump "$downloads_folder/$acc/$acc.sra" --outdir "$downloads_folder" --threads 4 --split-files
  #rm -rf $downloads_folder/$acc/
  mv "$downloads_folder/${acc}_1.fastq" "$downloads_folder/${alias}_1.fastq"
  mv "$downloads_folder/${acc}_2.fastq" "$downloads_folder/${alias}_2.fastq"
  gzip "$downloads_folder/${alias}_1.fastq"
  gzip "$downloads_folder/${alias}_2.fastq"
  sleep 5
done

echo "Done"
