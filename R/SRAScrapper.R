library(tidyverse)
library(rentrez)
library(xml2)

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

.extract_fields_SRA= function (experiment_package)
{
   
  EXPERIMENT=experiment_package$EXPERIMENT
  SUBMISSION=experiment_package$SUBMISSION
  ORGANIZATION=experiment_package$Organization
  STUDY=experiment_package$STUDY
  SAMPLE=experiment_package$SAMPLE
  Pool=experiment_package$Pool
  RUN_SET=experiment_package$RUN_SET
  
  
  #TODO: errorproof this code
  all_info <- tibble(
    
    #Experiment,12 columns
    accession          = attr(EXPERIMENT, "accession"),
    alias              = attr(EXPERIMENT, "alias"),
    experiment_id      = EXPERIMENT$IDENTIFIERS$PRIMARY_ID[[1]],
    title              = EXPERIMENT$TITLE[[1]],
    study_id           = EXPERIMENT$STUDY_REF$IDENTIFIERS$PRIMARY_ID[[1]],
    sample_id          = EXPERIMENT$DESIGN$SAMPLE_DESCRIPTOR$IDENTIFIERS$PRIMARY_ID[[1]],
    design_description = EXPERIMENT$DESIGN$DESIGN_DESCRIPTION[[1]],
    library_name       = EXPERIMENT$DESIGN$LIBRARY_DESCRIPTOR$LIBRARY_NAME[[1]],
    library_strategy   = EXPERIMENT$DESIGN$LIBRARY_DESCRIPTOR$LIBRARY_STRATEGY[[1]],
    library_source     = EXPERIMENT$DESIGN$LIBRARY_DESCRIPTOR$LIBRARY_SOURCE[[1]],
    library_selection  = EXPERIMENT$DESIGN$LIBRARY_DESCRIPTOR$LIBRARY_SELECTION[[1]],
    instrument_model   = EXPERIMENT$PLATFORM$ILLUMINA$INSTRUMENT_MODEL[[1]],
    
    #Submission, 7 columns
    submission_accession = attr(SUBMISSION, "accession"),
    submission_alias     = attr(SUBMISSION, "alias"),
    submission_lab_name  = attr(SUBMISSION, "lab_name"),
    submission_center    = attr(SUBMISSION, "center_name"),
    submission_id        = SUBMISSION$IDENTIFIERS$PRIMARY_ID[[1]],
    submitter_id         = SUBMISSION$IDENTIFIERS$SUBMITTER_ID[[1]],
    submitter_namespace  = attr(SUBMISSION$IDENTIFIERS$SUBMITTER_ID, "namespace"),
    
    #Organization, 11 columns
    org_type             = attr(ORGANIZATION, "type"),
    org_name             = ORGANIZATION$Name[[1]],
    org_department       = ORGANIZATION$Address$Department[[1]],
    org_institution      = ORGANIZATION$Address$Institution[[1]],
    org_street           = ORGANIZATION$Address$Street[[1]],
    org_city             = ORGANIZATION$Address$City[[1]],
    org_country          = ORGANIZATION$Address$Country[[1]],
    org_postal_code      = attr(ORGANIZATION$Address, "postal_code"),
    contact_first_name   = ORGANIZATION$Contact$Name$First[[1]],
    contact_last_name    = ORGANIZATION$Contact$Name$Last[[1]],
    contact_email        = attr(ORGANIZATION$Contact, "email"),
    
    #Study, 10 columns
    study_center_name          = attr(STUDY, "center_name"),
    study_alias                = attr(STUDY, "alias"),
    study_accession            = attr(STUDY, "accession"),
    study_primary_id           = STUDY$IDENTIFIERS$PRIMARY_ID[[1]],
    study_external_id          = STUDY$IDENTIFIERS$EXTERNAL_ID[[1]],
    study_external_namespace   = attr(STUDY$IDENTIFIERS$EXTERNAL_ID, "namespace"),
    study_external_label       = attr(STUDY$IDENTIFIERS$EXTERNAL_ID, "label"),
    study_title                = STUDY$DESCRIPTOR$STUDY_TITLE[[1]],
    study_type                 = attr(STUDY$DESCRIPTOR$STUDY_TYPE, "existing_study_type"),
    study_abstract             = STUDY$DESCRIPTOR$STUDY_ABSTRACT[[1]],
    
    #Pool
    related_biosample_id=Pool$Member$IDENTIFIERS$EXTERNAL_ID[[1]],
    
    #RUN
    SRR_accession=attr(RUN_SET$RUN,"accession")
    
    
  )

  return(all_info)
}
.fetch_SRA_metadata = function(uid)
{
  #Dado un uid de bioproject, devolver un df de metadata de SRA
  result=entrez_link(dbfrom="bioproject",
                     id=uid,
                     db="sra",
                     cmd = "neighbor_history")
  Sys.sleep(0.1)
  web_history=result$web_histories$bioproject_sra_all
 
  SRA_xml=entrez_fetch(db="sra",
               web_history = web_history,
               rettype = "xml")
  Sys.sleep(0.1)
  metadata_xml=read_xml(SRA_xml)

  metadata_list=as_list(metadata_xml)

  SRAs=metadata_list$EXPERIMENT_PACKAGE_SET
  
  meta_df=map_dfr(SRAs,.extract_fields_SRA)

  return(meta_df)


}

get_SRA_metadata=function(bioproject_accessions)
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
    ret_list[[id]]=.fetch_SRA_metadata(local_uid)
  }
  return(ret_list)
}