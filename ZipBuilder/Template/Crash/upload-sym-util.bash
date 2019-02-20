# Output a clickable message.  This will not count as a warning or
# error.

xcnote () {
    echo >&2 "${BASH_SOURCE[1]}:${BASH_LINENO[0]}: note: $*"
}

# Output a clickable message prefixed with a warning symbol (U+26A0)
# and highlighted yellow.  This will increase the overall warning
# count.  A non-zero value for the variable ERRORS_ONLY will force
# warnings to be treated as errors.

if ((ERRORS_ONLY)); then
    xcwarning () {
        echo >&2 "${BASH_SOURCE[1]}:${BASH_LINENO[0]}: error: $*"
    }
else
    xcwarning () {
        echo >&2 "${BASH_SOURCE[1]}:${BASH_LINENO[0]}: warning: $*"
    }
fi

# Output a clickable message prefixed with a halt symbol (U+1F6D1) and
# highlighted red.  This will increase the overall error count.  Xcode
# will flag the build as failed if the error count is non-zero at the
# end of the build, even if this script returns a successful exit
# code.  Set WARNINGS_ONLY to non-zero to prevent this.

if ((WARNINGS_ONLY)); then
    xcerror () {
        echo >&2 "${BASH_SOURCE[1]}:${BASH_LINENO[0]}: warning: $*"
    }
else
    xcerror () {
        echo >&2 "${BASH_SOURCE[1]}:${BASH_LINENO[0]}: error: $*"
    }
fi

xcdebug () {
    if ((VERBOSE)); then
        echo >&2 "${BASH_SOURCE[1]}:${BASH_LINENO[0]}: note: $*"
    fi
}

# Locate the script directory.

script_dir () {
    local SCRIPT="$0" SCRIPT_DIR="$(dirname "$0")"

    while SCRIPT="$(readlink "${SCRIPT}")"; do
        [[ "${SCRIPT}" != /* ]] && SCRIPT="${SCRIPT_DIR}/${SCRIPT}"
        SCRIPT_DIR="$(dirname "${SCRIPT}")"
    done

    ( cd "${SCRIPT_DIR}"; pwd -P )
}

# Timestamp needed for various operations. Does not need to be exact,
# but does need to be consistent across web service calls.

readonly NOW="$(/bin/date +%s)"

# All files created by fcr_mktemp will be listed in FCR_TEMPORARY_FILES.
# Delete these when the enclosing script exits.  (You may manually
# add files to this array as well to have them cleaned up on exit.)

typeset -a FCR_TEMPORARY_FILES
trap 'STATUS=$?; rm -rf "${FCR_TEMPORARY_FILES[@]}"; exit ${STATUS}' 0 1 2 15

# Create a temporary file and add it to the list of files to delete when the
# script finishes.
#
# usage: fcr_mktemp VARNAME...

fcr_mktemp () {
    for VAR; do
        eval "${VAR}=\$(mktemp -t com.google.FIRCrash) || return 1"
        FCR_TEMPORARY_FILES+=("${!VAR}")
    done
}

# Create a temporary directory and add it to the list of files to
# delete when the script finishes.
#
# usage: fcr_mktempdir VARNAME...

fcr_mktempdir () {
    for VAR; do
        eval "${VAR}=\$(mktemp -d -t com.google.FIRCrash) || return 1"
        FCR_TEMPORARY_FILES+=("${!VAR}")
    done
}

# The keys we care about in the JSON objects.  There are others that
# we do not use.  Note that 'expires_at' and 'app_id' are not part of
# the original payload, but are computed from the environment used to
# make the call.

FCR_SVC_KEYS=(client_email private_key private_key_id token_uri type)
FCR_TOK_KEYS=(access_token expires_at token_type app_id)

# Extract a value from the property list.
#
# usage: property *name* *file*

property () {
    [[ -f "$2" ]] || echo '{}' >|"$2" # keeps PlistBuddy quiet
    /usr/libexec/PlistBuddy "$2" -c "Print :$1" 2>/dev/null
}

# Retrieve the property from the service account property list.
#
# usage: svc_property *name*

svc_property () {
    property "$1" "${SVC_PLIST}"
}

# Does the same as svc_property above but for the token cache
# property list.
#
# usage: tok_property *name*

tok_property () {
    property "$1" "${TOK_PLIST}"
}

# Verify that the service account property list has values for the
# required keys.  Does not check the values themselves.

fcr_verify_svc_plist () {
    for key in "${FCR_SVC_KEYS[@]}"; do
        if ! svc_property "${key}" >/dev/null; then
            xcdebug "${key} not found in ${SVC_PLIST}. Service account invalid."
            return 1
        fi
    done
}

# Verify that the token cache property list has values for the
# required keys.  If the token_type is incorrect, the expiration date
# has been passed, or the application id does not match, return
# failure.

fcr_verify_tok_plist () {
    for key in "${FCR_TOK_KEYS[@]}"; do
        if ! tok_property "${key}" >/dev/null; then
            xcdebug "${key} not found in ${TOK_PLIST}. Token invalid."
            return 1
        fi
    done

    if [[ "$(tok_property token_type)" != "Bearer" ]]; then
        xcwarning "Invalid token type '$(tok_property token_type)'."
        return 1
    fi

    if (($(tok_property expires_at) <= NOW)); then
        xcdebug "Token well-formed but expired at $(date -jf %s "$(tok_property expires_at)")."
        echo '{}' >|"${TOK_PLIST}"
        return 1
    fi

    if [[ "$(tok_property app_id)" != "${FIREBASE_APP_ID}" ]]; then
        xcdebug "Cached token is for a different application."
        echo '{}' >|"${TOK_PLIST}"
        return 1
    fi
}

# Convert a JSON certificate file to a PList certificate file.
#
# usage: fcr_load_certificate VARNAME

fcr_load_certificate () {
    : "${SERVICE_ACCOUNT_FILE:?must be the path to the service account JSON file.}"
    fcr_mktemp "$1"

    if ! /usr/bin/plutil -convert binary1 "${SERVICE_ACCOUNT_FILE}" -o "${!1}"; then
        xcerror "Unable to read service account file ${SERVICE_ACCOUNT_FILE}."
        return 2
    fi
}

# BASE64URL uses a sligtly different character set than BASE64, and
# uses no padding characters.

function base64url () {
    /usr/bin/base64 | sed -e 's/=//g; s/+/-/g; s/\//_/g'
}

# Assemble the JSON Web Token (RFC 1795)
#
# usage: fcr_create_jwt *client-email* *token-uri*

fcr_create_jwt () {
    local JWT_HEADER="$(base64url <<<'{"alg":"RS256","typ":"JWT"}')"
    local JWT_CLAIM="$(base64url <<<'{'"\"iss\":\"${1:?}\",\"aud\":\"${2:?}\",\"exp\":\"$((NOW + 3600))\",\"iat\":\"${NOW}\",\"scope\":\"https://www.googleapis.com/auth/mobilecrashreporting\""'}')"
    local JWT_BODY="${JWT_HEADER}.${JWT_CLAIM}"
    local JWT_SIG="$(echo -n "${JWT_BODY}" | openssl dgst -sha256 -sign <(svc_property private_key) -binary | base64url)"

    echo "${JWT_BODY}.${JWT_SIG}"
}

# Set the BEARER_TOKEN variable for authentication.
#
# usage: fcr_authenticate

fcr_authenticate () {
    : "${FIREBASE_APP_ID:?required to select authentication credentials}"

    local SVC_PLIST

    fcr_load_certificate SVC_PLIST || return 2

    local TOK_PLIST="${HOME}/Library/Preferences/com.google.SymbolUploadToken.plist"

    if ((VERBOSE > 2)); then
        CURLOPT='--trace-ascii /dev/fd/2'
    elif ((VERBOSE > 1)); then
        CURLOPT='--verbose'
    else
        CURLOPT=''
    fi

    # If the token will expire in the next sixty seconds (or already
    # has), reload it.
    if ! fcr_verify_tok_plist; then
        xcdebug "Token cannot be used.  Requesting OAuth2 token using installed credentials."

        if ! fcr_verify_svc_plist; then
            xcerror "Incorrect/incomplete service account file."
            return 2
        else
            xcdebug "Certificate information appears valid."
        fi

        TOKEN_URI="$(svc_property token_uri)"
        CLIENT_EMAIL="$(svc_property client_email)"

        # Assemble the JSON Web Token (RFC 1795)
        local JWT="$(fcr_create_jwt "${CLIENT_EMAIL}" "${TOKEN_URI}")"

        fcr_mktemp TOKEN_JSON

        HTTP_STATUS="$(curl ${CURLOPT} -o "${TOKEN_JSON}" -s -d grant_type='urn:ietf:params:oauth:grant-type:jwt-bearer' -d assertion="${JWT}" -w '%{http_code}' "${TOKEN_URI}")"

        if [[ "${HTTP_STATUS}" == 403 ]]; then
            xcerror "Invalid certificate. Unable to retrieve OAuth2 token."
            return 2
        elif [[ "${HTTP_STATUS}" != 200 ]]; then
            cat >&2 "${TOKEN_JSON}"
            return 2
        fi

        # Store the token in the preferences directory for future use.
        /usr/bin/plutil -convert binary1 "${TOKEN_JSON}" -o "${TOK_PLIST}"

        EXPIRES_IN="$(tok_property expires_in)"
        EXPIRES_AT="$((EXPIRES_IN + NOW))"

        /usr/libexec/PlistBuddy \
            -c "Add :app_id string \"${FIREBASE_APP_ID}\"" \
            -c "Add :expires_at integer ${EXPIRES_AT}" \
            -c "Add :expiration_date date $(TZ=GMT date -jf %s ${EXPIRES_AT})" \
            "${TOK_PLIST}"

        if ! fcr_verify_tok_plist; then
            ((VERBOSE)) && /usr/libexec/PlistBuddy -c 'Print' "${TOK_PLIST}"

            echo '{}' >|"${TOK_PLIST}"
            xcwarning "Token returned is not valid."
            xcnote "If this error persists, download a fresh certificate."

            return 2
        fi
    else
        xcdebug "Token still valid."
        EXPIRES_AT="$(tok_property expires_at)"
    fi

    xcdebug "Token will expire on $(date -jf %s "${EXPIRES_AT}")."
    xcdebug "Using service account with key $(svc_property private_key_id)."

    BEARER_TOKEN="$(tok_property access_token)"

    if [[ ! "${BEARER_TOKEN}" ]]; then
        if ((VERBOSE)); then
            xcwarning "Current malformed token cache:"
            tok_property | while read; do xcnote "${REPLY}"; done
        fi
        xcerror "Unable to retrieve authentication token from server."
        return 2
    fi

    return 0
}

# Upload the files to the server.
#
# Arguments: Names of files to upload.

fcr_upload_files() {
    fcr_authenticate || return $?

    : "${FCR_PROD_VERS:?}"
    : "${FCR_BUNDLE_ID:?}"
    : "${FIREBASE_APP_ID:?}"
    : "${FIREBASE_API_KEY:?}"
    : "${FCR_BASE_URL:=https://mobilecrashreporting.googleapis.com}"

    fcr_mktemp FILE_UPLOAD_LOCATION_PLIST META_UPLOAD_RESULT_PLIST

    if ((VERBOSE > 2)); then
        CURLOPT='--trace-ascii /dev/fd/2'
    elif ((VERBOSE > 1)); then
        CURLOPT='--verbose'
    else
        CURLOPT=''
    fi

    for FILE; do
        xcdebug "Get signed URL for uploading."

        URL="${FCR_BASE_URL}/v1/apps/${FIREBASE_APP_ID}"

        HTTP_STATUS="$(curl ${CURLOPT} -o "${FILE_UPLOAD_LOCATION_PLIST}" -sL -H "X-Ios-Bundle-Identifier: ${FCR_BUNDLE_ID}" -H "Authorization: Bearer ${BEARER_TOKEN}" -X POST -d '' -w '%{http_code}' "${URL}/symbolFileUploadLocation?key=${FIREBASE_API_KEY}")"
        STATUS=$?

        if [[ "${STATUS}" == 22 && "${HTTP_STATUS}" == 403 ]]; then
            xcerror "Unable to access resource. Token invalid."
            xcnote "Please verify the service account file."
            return 2
        elif [[ "${STATUS}" != 0 ]]; then
            xcerror "curl exited with non-zero status ${STATUS}."
            ((STATUS == 22)) && xcerror "HTTP response code is ${HTTP_STATUS}."
            return 2
        fi

        /usr/bin/plutil -convert binary1 "${FILE_UPLOAD_LOCATION_PLIST}" || return 1

        UPLOAD_KEY="$(property uploadKey "${FILE_UPLOAD_LOCATION_PLIST}")"
        UPLOAD_URL="$(property uploadUrl "${FILE_UPLOAD_LOCATION_PLIST}")"
        ERRMSG="$(property error:message "${FILE_UPLOAD_LOCATION_PLIST}")"

        if [[ "${ERRMSG}" ]]; then
            if ((VERBOSE)); then
                xcnote "Server response:"
                /usr/bin/plutil -p "${FILE_UPLOAD_LOCATION_PLIST}" >&2
            fi
            xcerror "symbolFileUploadLocation: ${ERRMSG}"
            xcnote "symbolFileUploadLocation: Failed to get upload location."
            return 1
        fi

        xcdebug "Upload symbol file."

        HTTP_STATUS=$(curl ${CURLOPT} -sfL -H 'Content-Type: text/plain' -H "Authorization: Bearer ${BEARER_TOKEN}" -w '%{http_code}' -T "${FILE}" "${UPLOAD_URL}")
        STATUS=$?

        if ((STATUS == 22)); then # exit code 22 is a non-successful HTTP response
            xcerror "upload: Unable to upload symbol file (HTTP Status ${HTTP_STATUS})."
            return 1
        elif ((STATUS != 0)); then
            xcerror "upload: Unable to upload symbol file (reason unknown)."
            return 1
        fi

        xcdebug "Upload metadata information."

        curl ${CURLOPT} -sL -H 'Content-Type: application/json' -H "X-Ios-Bundle-Identifier: ${FCR_BUNDLE_ID}" -H "Authorization: Bearer ${BEARER_TOKEN}" -X POST -d '{"upload_key":"'"${UPLOAD_KEY}"'","symbol_file_mapping":{"symbol_type":2,"app_version":"'"${FCR_PROD_VERS}"'"}}' "${URL}/symbolFileMappings:upsert?key=${FIREBASE_API_KEY}" >|"${META_UPLOAD_RESULT_PLIST}" || return 1
        /usr/bin/plutil -convert binary1 "${META_UPLOAD_RESULT_PLIST}" || return 1

        ERRMSG="$(property error:message "${META_UPLOAD_RESULT_PLIST}")"

        if [[ "${ERRMSG}" ]]; then
            xcerror "symbolFileMappings:upsert: ${ERRMSG}"
            xcnote "symbolFileMappings:upsert: The metadata for the symbol file failed to update."
            return 1
        fi
    done
}
