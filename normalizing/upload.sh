THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
ARG=$1
BQ_OUTPUT="world-fishing-827:scratch_matias_ttl_60_days.galapagos_shipplotter"


display_usage() {
  echo "sh upload.sh [FILE or DIRECTORY]"
  echo "             Will uploads the file or files under the diretory"
  echo "             to ${BQ_OUTPUT}"
}
upload() {
  local PROCESSED=$1
  local CSV_FILE=$2
  ################################################################################
  # Uploads from CSV to Big Query
  ################################################################################
  YYYYMMDD=20$(echo ${CSV_FILE} | grep -o "[0-9]*")
  echo "  Uploads CSV file in remote location ${CSV_FILE} year ${YYYYMMDD}"
  BQ_PATH=${BQ_OUTPUT}_${YYYYMMDD}
  SCHEMA=${THIS_SCRIPT_DIR}/galapagos_schema_normalized.json
  bq load \
    --field_delimiter "," \
    --source_format=CSV \
    ${BQ_PATH} \
    "${PROCESSED}/${CSV_FILE}" \
    ${SCHEMA}
  if [ "$?" -ne 0 ]; then
    echo "    Unable to upload to BigQuery ${BQ_PATH}"
    display_usage
    exit 1
  fi
  echo "    Uploaded to BigQuery in table ${BQ_PATH}"
}

if [ -d "${ARG}" ]
then
  local DIR=${ARG}/processed
  for processed_file in $(ls -1 ${DIR})
  do
    upload ${DIR} ${processed_file} &
  done
elif [ -f "${ARG}" ]
then
  filename=$(basename ${ARG})
  dir=$(dirname ${ARG})
  upload ${dir} ${filename}
else
  echo ">> ERROR: Not a file nor a directory. ${ARG}"
fi
