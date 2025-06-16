library(tidyverse)
library(rentrez)
library(xml2)

#TODO: Si hay un error en un PRJNA, devolver la lista de dfs sin ese PRJNA y notificar.
#No explotar
#TODO: Migrar todo a un solo scrapper. O BiosampleScrapper o SRAScrapper


.fetch_bioproject_uid_from_accession <- function(ids) 
{
  results <- list()
  for (id in ids) 
  {
    res <- entrez_search(db = "bioproject", term = paste0(id, "[Accession]"))
    Sys.sleep(0.1)
    if (length(res$ids) == 0) 
    {
      warning("BioProject not found: ", id)
      results[[id]] <- NULL
    } else 
    {
      results[[id]] <- res$ids
    }
    
  }
  return(results)
}

.extract_fields_biosample= function (sample)
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
.fetch_biosample_metadata = function(uid)
{
  #Dado un uid de bioproject, devolver un df de metadata de biosample
  result=entrez_link(dbfrom="bioproject",
                     id=uid,
                     db="biosample",
                     cmd = "neighbor_history")
  Sys.sleep(0.1)  
  web_history=result$web_histories$bioproject_biosample_all

  biosample_xml=entrez_fetch(db="biosample",
               web_history = web_history,
               rettype = "xml")
  Sys.sleep(0.1)
  
  metadata_xml=read_xml(biosample_xml)

  metadata_list=as_list(metadata_xml)

  biosamples=metadata_list$BioSampleSet
  meta_df=map_dfr(biosamples,.extract_fields)

  return(meta_df)


}

get_biosample_metadata=function(bioproject_accessions)
{
  #####VALIDATION
  #TODO: Arreglar para aceptar también accessions de EBI y DDBJ
  
  #valid_pattern <- "^PRJ[EDN][A-Z][0-9]+$"
  valid_pattern= "^PRJNA[0-9]+$"
  valid_ids <- bioproject_accessions[grepl(valid_pattern, bioproject_accessions)]
  invalid_ids <- setdiff(bioproject_accessions, valid_ids)
  
  # Error if none valid
  if (length(valid_ids) == 0) {
    stop(" None of the provided IDs match the expected format: PRJNA[0-9]+")
  }
  
  # Optional: warn about invalid ones
  if (length(invalid_ids) > 0) {
    warning("Ignoring invalid IDs: ", paste(invalid_ids, collapse = ", "))
  }
  
  # Proceed with only valid IDs
  # Example: return the valid ones, or replace this with your real logic
  message("Proceeding with valid BioProject IDs: ", paste(valid_ids, collapse = ", "))
  
  
  bioproject_uid=.fetch_bioproject_uid_from_accession(valid_ids)
  
  if (length(bioproject_uid) == 0){#TODO: Chequear esto mejor, mandar un warning mejor.
    warning("NCBI BioProject found zero hits for the specified query")
    return(NULL)
  }
  
  ret_list=list()
  
  for (id in valid_ids)
  {
    local_uid=bioproject_uid[[id]][1]
    message("Processing ID: ",paste(id))
    ret_list[[id]]=.fetch_biosample_metadata(local_uid)
  }
  return(ret_list)
}