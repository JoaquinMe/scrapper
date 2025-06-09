#!/usr/bin/env bash

# Como usar:
# ./descargar_multiple.sh inputfile outputfolder
# inputfile taken as a textfile with an SRA accession per line

if [ "$#" -eq 0 ]; then
  echo "Error: No argument provided.Expecting: descargar_multiple.sh inputfile outfile"
  echo "Usage: $0 <argument>"
  exit 1
elif [ "$#" -gt 2 ]; then
  echo "Error: Too many arguments provided. Expecting: descargar_multiple.sh inputfile outfile"
  echo "Usage: $0 <argument>"
  exit 1
fi

file=$1
outfile=$2
echo "prefetching..."
while read -r line; do
  prefetch "$line"
done <"$file"

mkdir -p "$outfile"
echo "cleaning up..."
for folder in *RR*/; do
  cp "$folder"* "$outfile"
  rm -rf "$folder"
done

echo "extracting .fastq from .sra"
for file in "$outfile"/*.sra; do
  fastq-dump "$file" --split-files --skip-technical --outdir "$outfile"
  rm "$file"
done

echo "gzip on fastq files.."
gzip "$outfile"/*.fastq
echo "Done"
