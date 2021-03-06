#!/bin/bash
THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
DIR=$1
PROCESSED="${DIR}/processed/csv"
BAD_PARSED_PROCESSED="${DIR}/processed/cannot_normalize"
DONE_DIR="${DIR}/processed/done"
BQ_OUTPUT="world-fishing-827:scratch_matias_ttl_60_days.galapagos_shipplotter"
IN_PROGRESS="${THIS_SCRIPT_DIR}/in_progress"
LAST_LINE_READ=${IN_PROGRESS}/last_line_read.txt
LINE_NUMBER_READ=0 # number of line read in file



################################################################################
# Defines trap control c
################################################################################
ctrl_c() {
  if [ ! -z "$(ls -1 ${IN_PROGRESS}/*.log)" ]
  then
    echo "Trapping ctrl-c and saving last line processed"
    echo "${LINE_NUMBER_READ}" > ${LAST_LINE_READ}
    break
  fi
}

# trap ctrl-c and call ctrl_c()
trap 'ctrl_c' INT

################################################################################
# Defines functions
################################################################################
display_usage() {
  echo "sh parser.sh [DIRECTORY]"
  echo "             Will uploads the files under the diretory"
  echo "             to ${BQ_OUTPUT}"
}

parse() {
  local logfile=$1
  local CSV_FILE_IN_PROGRESS=${IN_PROGRESS}/${logfile}.csv
  local CSV_FILE_IN_PROGRESS_NORMALIZER_FAILED=${IN_PROGRESS}/error_at_normalize_${logfile}.csv
  local normalizer_result=0
  local success=0 # how much lines has eleven or more fields
  local fails=0 # the opposite of success
  LINE_NUMBER_READ=0
  ################################################################################
  # Defines variables to detect how much lines must still process
  ################################################################################
  local ssd_disk_path=${IN_PROGRESS}/${logfile}
  local total_lines=$(wc -l ${ssd_disk_path} | cut -f1 -d\ )

  echo
  echo "== Reading the logfile <${logfile}>"
  ################################################################################
  # File in progress, read just the necessary
  ################################################################################
  if [ -f "${LAST_LINE_READ}" ]
  then
    local total_lines_already_read=$(cat ${LAST_LINE_READ})
    local missing_lines=$(( ${total_lines}-${total_lines_already_read} ))

    # This is needed to cut the file to process in the next try
    tail -n ${missing_lines} ${ssd_disk_path} > ${ssd_disk_path}.2
    mv -f ${ssd_disk_path}.2 ${ssd_disk_path}

    echo "== There is still a file IN PROGRESS"
    echo "==   total_lines_already_read=${total_lines_already_read}"
    echo "==   missing_lines=           ${missing_lines}"
    echo "==   total_lines=             ${total_lines}"
  fi


  ################################################################################
  # Reads line by line
  ################################################################################
  while IFS= read -r line
  do
    local HAS_ELEVEN_OR_MORE_FIELDS=$(echo ${line}  | sed 's/[^;]*//g' | wc -m)
    if [ "${HAS_ELEVEN_OR_MORE_FIELDS}" -ge 11 ]
    then
      # Parses the line
      normalizer_result=$(python -m ${THIS_SCRIPT_DIR}/normalize data "${line}")
      if [ "$?" -eq 0 ]
      then
        success=$(($success+1))
        # Writes the CSV
        echo "${normalizer_result}" >> ${CSV_FILE_IN_PROGRESS}
      else
        fails=$(($fails+1))
        echo "${LINE_NUMBER_READ}: ${line}" >> ${CSV_FILE_IN_PROGRESS_NORMALIZER_FAILED}
      fi

    else
      fails=$(($fails+1))
    fi
    LINE_NUMBER_READ=$(( ${LINE_NUMBER_READ} + 1 ))
    if [ "$(( ${LINE_NUMBER_READ} % 100 ))" -eq 0 ]
    then
      echo -n "."
    fi
  done < ${ssd_disk_path}
  echo
  echo "   total ${total_lines} success=${success} fails=${fails}"

  rm ${LAST_LINE_READ}
  echo "== Removes the last_line_read.txt"
}



################################################################################
# Crates processed directory if not exists
################################################################################
mkdir -p ${PROCESSED}
mkdir -p ${DONE_DIR}
mkdir -p ${BAD_PARSED_PROCESSED}

if [ ! -d "${DIR}" ]
then
  echo ">> ERROR: This is not a directory."
  display_usage
  exit 1
fi
echo "DIR=${DIR}"

# We need to upload the files with the filename with format shipplotterYYMMDD.log, exclude the ones with shipplotteralertYYMMDD.log
################################################################################
# Filters by filename
################################################################################
FILTERED=$(ls "${DIR}" | grep "shipplotter[0-9]*.log")
echo "Amount of file filtered $(echo ${FILTERED} | wc -w)/$(ls -1 ${DIR} | wc -l)"


################################################################################
# CASE 1: Analyze if there is one file still in_progress
################################################################################
if [ -f "${LAST_LINE_READ}" ]
then
  logfile_in_progress=$(ls ${IN_PROGRESS}/shipplotter*.log)
  logfile=$(basename ${logfile_in_progress})
  CSV_FILE=${PROCESSED}/${logfile}.csv
  CSV_FILE_IN_PROGRESS=${IN_PROGRESS}/${logfile}.csv

  parse "${logfile}"

  ################################################################################
  # Removes the copy
  ################################################################################
  rm -f ${logfile_in_progress}
  echo "== Removes the <${logfile_in_progress}>"

  ################################################################################
  # Moves the CSV resultant to Hard Disk
  ################################################################################
  mv ${CSV_FILE_IN_PROGRESS} ${CSV_FILE}
  echo "== Moves the CSV resultant to Hard Disk"
  mv ${IN_PROGRESS}/error_at_normalize_${logfile}.csv ${BAD_PARSED_PROCESSED}/error_at_normalize_${logfile}.csv

  ################################################################################
  # Uploads to bigquery
  ################################################################################
  echo "== STARTS UPLOAD TO BQ"
  sh ${THIS_SCRIPT_DIR}/upload.sh ${CSV_FILE} >> ${THIS_SCRIPT_DIR}/upload.log
  echo "== ENDS UPLOAD TO BQ"

  ################################################################################
  # moves to remove it
  ################################################################################
  mv ${DIR}/${logfile} ${DONE_DIR}/${logfile}
  echo "    Moved to <${DONE_DIR}/${logfile}>"
fi

################################################################################
# CASE 2: Filter the files that matches with the pattern and parse them
################################################################################
# IT=$(echo ${FILTERED} | cut -f1 -d\ )
IT=${FILTERED}
for logfile in ${IT}
do
  CSV_FILE=${PROCESSED}/${logfile}.csv
  CSV_FILE_IN_PROGRESS=${IN_PROGRESS}/${logfile}.csv

  ################################################################################
  # Copies to ssd_disk to process quickly
  ################################################################################
  ssd_disk_path=${IN_PROGRESS}/${logfile}
  cp ${DIR}/${logfile} ${ssd_disk_path}
  echo "== Copy to SSD disk"

  parse ${logfile}

  ################################################################################
  # Removes copy
  ################################################################################
  rm -f ${ssd_disk_path}
  echo "== Removes copy"

  ################################################################################
  # Moves the CSV resultant to Hard Disk
  ################################################################################
  mv ${CSV_FILE_IN_PROGRESS} ${CSV_FILE}
  echo "== Moves the CSV resultant to Hard Disk"
  mv ${IN_PROGRESS}/error_at_normalize_${logfile}.csv ${BAD_PARSED_PROCESSED}/error_at_normalize_${logfile}.csv

  ################################################################################
  # Uploads to bigquery
  ################################################################################
  echo "== STARTS UPLOAD TO BQ"
  sh ${THIS_SCRIPT_DIR}/upload.sh ${CSV_FILE} >> ${THIS_SCRIPT_DIR}/upload.log
  echo "== ENDS UPLOAD TO BQ"

  ################################################################################
  # moves to remove it
  ################################################################################
  mv ${DIR}/${logfile} ${DONE_DIR}/${logfile}
  echo "    Moved to ${DONE_DIR}/${logfile}"
done
