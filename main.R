#!/usr/bin/env Rscript
here::i_am("main.R")
rm(list=ls())
library(tidyverse)
library(rentrez)
library(xml2)
library(here)

#Source R files
biosample_filename=here("R","BioSampleScrapper.R")
SRA_filename=here("R","SRAScrapper.R")

accessions_filename=here("data","raw","bioproject_accessions.tsv")

source(biosample_filename)
source(SRA_filename)
accessions=read_tsv(accessions_filename)

#TODO: manejar cli args


# Setup API key
entrez_key <- Sys.getenv("ENTREZ_KEY")
if (entrez_key == "") {
  stop("ENTREZ_KEY environment variable not set")
}
set_entrez_key(entrez_key)


#Procesar

#TODO: arreglar los errores que dan con estos ids
accessions_test=accessions%>%
  filter(!id %in% c("PRJNA627456", "PRJNA388250","PRJNA242868")) %>% 
  pull(id)

biosample_ldf=get_biosample_metadata(accessions_test)
SRA_ldf=get_SRA_metadata(accessions_test)

for (name in names(biosample_ldf))
{
  folder_path=here("output",name)
  biosample_metadata_file_path=here(folder_path,paste0(name,"_biosample_metadata",".tsv"))
  sra_metadata_file_path=here(folder_path,paste0(name,"_sra_metadata",".tsv"))
  if(!dir.exists(folder_path))
  {
    dir.create(folder_path)
  }
  df_biosample=biosample_ldf[[name]]
  df_SRA=SRA_ldf[[name]]
  write_tsv(df_biosample,file = biosample_metadata_file_path)
  write_tsv(df_SRA,file = sra_metadata_file_path)
}



