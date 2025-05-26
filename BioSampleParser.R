library(tidyverse)
library(rentrez)
library(xml2)

rm(list=ls())


###

EntrezResult = entrez_search(db="bioproject", term = "PRJNA1251497")
BioProjectID = EntrezResult$ids
if (length(BioProjectID) == 0){
  warning("NCBI BioProject found zero hits for the specified query")
  return(NULL)
}

EntrezResult=entrez_link(dbfrom="bioproject",id=BioProjectID,db="biosample")
BioSampleList = EntrezResult$links$bioproject_biosample_all
if (length(BioSampleList) == 0){
  warning("Unable to find any associated BioSamples for the specified BioProject ID")
  return(NULL)
}
####biosample####
meta_xml = entrez_fetch(db="biosample", id = BioSampleList, rettype = "xml")
meta=read_xml(meta_xml)

meta_list=as_list(meta)

biosamples=meta_list$BioSampleSet

extract_fields= function (sample)
{
  ids=sample$Ids
  desc=sample$Description
  owner=sample$Owner
  contact=owner$Contacts$Contact %||% list()
  organism=tryCatch(desc$Organism[[1]],error=function(e) NA_character_)
  atributos=sample$Attributes
  
  attr_values=list()
  for (atri in atributos)
  {
    key=attr(atri,"attribute_name")
    value=atri[[1]]
    if(!is.null(key)&& !is.null(value))
    {
      attr_values[[key]]=value
    }
  }
  
  
  
  
  base_info=tibble(
    biosample_accession = ids[[1]][[1]] %||% NA_character_,
    sample_name = ids[[2]][[1]] %||% NA_character_,
    sra_id = ids[[3]][[1]] %||% NA_character_,
    title = desc[[1]][[1]] %||% NA_character_,
    organism_name = organism %||% NA_character_,
    comment = tryCatch(desc[[3]][[1]][[1]], error = function(e) NA_character_),
    keywords = tryCatch(desc[[3]][[2]][[1]], error = function(e) NA_character_),
    institute = owner$Name[[1]] %||% NA_character_,
    first_name = contact$Name$First[[1]] %||% NA_character_,
    last_name = contact$Name$Last[[1]] %||% NA_character_,
    package = sample$Package[[1]] %||% NA_character_
  )
  all_info=bind_cols(base_info,as_tibble(attr_values))
  return(all_info)
}

meta_df=map_dfr(biosamples,extract_fields)


View(meta_df)


