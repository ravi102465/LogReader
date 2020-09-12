#!/bin/bash 

#first parameter is old status
#second parameter is new status
get_new_log()
{
	while read new_log; do
		new_dets=($new_log)
		new_read_line=${new_dets[0]}
		new_file=${new_dets[1]}
		if [[ "$new_file" == "total" ]]; then
			continue
		fi
		already_present="false"
		while read old_log; do
			old_dets=($old_log)
			old_read_line=${old_dets[0]}			
			old_file=${old_dets[1]}
			if [[ "$old_file" == "total" ]]; then
				continue
			fi		
			if [[ "$old_file" == "$new_file" ]]; then
				already_present="true"
				if [[ $new_read_line -eq $old_read_line ]]; then
					break
				fi
				sed -n $(($old_read_line + 1)),"$new_read_line"p "$new_file"
				break
			fi
		done < $1
		if [[ "$already_present" == "false" ]]; then
			if [[ $new_read_line -gt 0 ]]; then
				sed -n 1,"$new_read_line"p "$new_file"
			fi
		fi
	done < $2

	mv $2 $1
}

LOG_SEND_STATUS="/logstat/"
GEOSERVER_LOG_PATH="/data_dir/geoserverlogs"

mkdir "${LOG_SEND_STATUS}"

touch "${LOG_SEND_STATUS}geoserverlogstat.log"
while true;
do
	if [[ $(ls -A "${GEOSERVER_LOG_PATH}"/* | head -c1 | wc -c) -ne 0  ]]; then
		wc -l "${GEOSERVER_LOG_PATH}"/* > "${LOG_SEND_STATUS}geoserverlogstat_new.log"
		get_new_log "${LOG_SEND_STATUS}geoserverlogstat.log" "${LOG_SEND_STATUS}geoserverlogstat_new.log"
	fi
	
	sleep 60
done

curl_command_for_blob_upload{

#!/usr/bin/env bash

FILENAME=${1}
# expected to be defined in the environment
#  - AZURE_STORAGE_ACCOUNT
#  - AZURE_CONTAINER_NAME
#  - AZURE_ACCESS_KEY

# inspired by
authorization="SharedKey"

HTTP_METHOD="PUT"
request_date=$(TZ=GMT date "+%a, %d %h %Y %H:%M:%S %Z")
storage_service_version="2015-02-21"

# HTTP Request headers
x_ms_date_h="x-ms-date:$request_date"
x_ms_version_h="x-ms-version:$storage_service_version"
x_ms_blob_type_h="x-ms-blob-type:BlockBlob"

FILE_LENGTH=$(wc --bytes < ${FILENAME})
FILE_TYPE=$(file --mime-type -b ${FILENAME})
FILE_MD5=$(md5sum -b ${FILENAME} | awk '{ print $1 }')

# Build the signature string
canonicalized_headers="${x_ms_blob_type_h}\n${x_ms_date_h}\n${x_ms_version_h}"
canonicalized_resource="/${AZURE_STORAGE_ACCOUNT}/${AZURE_CONTAINER_NAME}/${FILE_MD5}"

#######
# From: https://docs.microsoft.com/en-us/rest/api/storageservices/authentication-for-the-azure-storage-services
#
#StringToSign = VERB + "\n" +
#               Content-Encoding + "\n" +
#               Content-Language + "\n" +
#               Content-Length + "\n" +
#               Content-MD5 + "\n" +
#               Content-Type + "\n" +
#               Date + "\n" +
#               If-Modified-Since + "\n" +
#               If-Match + "\n" +
#               If-None-Match + "\n" +
#               If-Unmodified-Since + "\n" +
#               Range + "\n" +
#               CanonicalizedHeaders +
#               CanonicalizedResource;
string_to_sign="${HTTP_METHOD}\n\n\n${FILE_LENGTH}\n\n${FILE_TYPE}\n\n\n\n\n\n\n${canonicalized_headers}\n${canonicalized_resource}"

# Decode the Base64 encoded access key, convert to Hex.
decoded_hex_key="$(echo -n $AZURE_ACCESS_KEY | base64 -d -w0 | xxd -p -c256)"

# Create the HMAC signature for the Authorization header
signature=$(printf  "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary | base64 -w0)

authorization_header="Authorization: $authorization $AZURE_STORAGE_ACCOUNT:$signature"
OUTPUT_FILE="https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_CONTAINER_NAME}/${FILE_MD5}"

curl -X ${HTTP_METHOD} \
    -T ${FILENAME} \
    -H "$x_ms_date_h" \
    -H "$x_ms_version_h" \
    -H "$x_ms_blob_type_h" \
    -H "$authorization_header" \
    -H "Content-Type: ${FILE_TYPE}" \
    ${OUTPUT_FILE}

if [ $? -eq 0 ]; then
    echo ${OUTPUT_FILE}
    exit 0;
fi;
exit 1

}
