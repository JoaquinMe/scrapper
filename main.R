#!/usr/bin/env Rscript
here::i_am("main.R")

library(tidyverse)
library(rentrez)
library(xml2)
library(here)

#Source R files
biosample_filename=here("R","BioSampleScrapper.R")
#TODO: Agregar y hacer este script
#SRA_filename=here("R","SRAScrapper.R")
accessions_filename=here("data","raw","bioproject_accessions.tsv")

source(biosample_filename)

accessions=read_tsv(accessions_filename)

# Setup API key
entrez_key <- Sys.getenv("ENTREZ_KEY")
if (entrez_key == "") {
  stop("ENTREZ_KEY environment variable not set")
}
set_entrez_key(entrez_key)

####INPUT####
#Procesar

# if (sys.nframe() == 0) { # Only run if executed directly
#   accessions_test=c(accessions$id)[1:3]
#   
#   biosample_ldf <- get_biosample_metadata(accessions)#lista de dfs
#   
#     
#   
#   
#   
# }

accessions_test=c(accessions$id)[1:3]
biosample_ldf=get_biosample_metadata(accessions_test[[2]])

