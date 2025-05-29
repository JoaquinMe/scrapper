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
  Organization=experiment_package$Organization
  STUDY=experiment_package$STUDY
  SAMPLE=experiment_package$SAMPLE
  Pool=experiment_package$Pool
  RUN_SET=experiment_package$RUN_SET
  
  
  
  all_info <- list(
    experiment_title=

    # # Experiment info
    # experiment_accession = attr(EXPERIMENT, "accession"),
    # experiment_title = EXPERIMENT$TITLE[[1]],
    # experiment_design = EXPERIMENT$DESIGN$DESIGN_DESCRIPTION[[1]],
    # library_name = EXPERIMENT$DESIGN$LIBRARY_DESCRIPTOR$LIBRARY_NAME[[1]],
    # library_strategy = EXPERIMENT$DESIGN$LIBRARY_DESCRIPTOR$LIBRARY_STRATEGY[[1]],
    # library_source = EXPERIMENT$DESIGN$LIBRARY_DESCRIPTOR$LIBRARY_SOURCE[[1]],
    # library_selection = EXPERIMENT$DESIGN$LIBRARY_DESCRIPTOR$LIBRARY_SELECTION[[1]],
    # platform = EXPERIMENT$PLATFORM$ILLUMINA$INSTRUMENT_MODEL[[1]],
    # 
    # # Study info
    # study_accession = STUDY$IDENTIFIERS$PRIMARY_ID[[1]],
    # bioproject_accession = STUDY$IDENTIFIERS$EXTERNAL_ID[[1]],
    # study_title = STUDY$DESCRIPTOR$STUDY_TITLE[[1]],
    # study_abstract = STUDY$DESCRIPTOR$STUDY_ABSTRACT[[1]],
    # 
    # # Sample info
    # sample_accession = SAMPLE$IDENTIFIERS$PRIMARY_ID[[1]],
    # biosample_accession = SAMPLE$IDENTIFIERS$EXTERNAL_ID[[1]],
    # sample_title = SAMPLE$DESCRIPTION[[1]],
    # organism = SAMPLE$SAMPLE_NAME$SCIENTIFIC_NAME[[1]],
    # tax_id = SAMPLE$SAMPLE_NAME$TAXON_ID[[1]],
    # 
    # # Run info
    # run_accession = RUN_SET$RUN$IDENTIFIERS$PRIMARY_ID[[1]],
    # total_spots = RUN_SET$RUN$Statistics$nspots,
    # total_bases = RUN_SET$RUN$Statistics$nreads,
    # run_size = attr(RUN_SET$RUN, "size"),
    # run_url = RUN_SET$RUN$SRAFiles$SRAFile[[3]]$url,
    # 
    # # Submission info
    # submission_center = attr(SUBMISSION, "center_name"),
    # submission_lab = attr(SUBMISSION, "lab_name"),
    # 
    # # Organization info
    # organization_name = Organization$Name[[1]],
    # organization_department = Organization$Address$Department[[1]],
    # organization_address = paste(Organization$Address$Street[[1]], 
    #                              Organization$Address$City[[1]], 
    #                              Organization$Address$Country[[1]]),
    # contact_name = paste(Organization$Contact$Name$First[[1]], 
    #                      Organization$Contact$Name$Last[[1]]),
    # contact_email = attr(Organization$Contact, "email")
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
  
  return(SRAs)
  meta_df=map_dfr(SRAs,.extract_fields)

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
  
  
  #bioproject_uid=.fetch_bioproject_uid_from_accession(valid_ids)
  
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