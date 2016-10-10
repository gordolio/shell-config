__sdkman_secure_curl_download() {
   if [[ "${sdkman_insecure_ssl}" = 'true' ]]
   then
      wget -O- --no-check-certificate "$1"
   else
      wget -O- "$1"
   fi
}

function __sdkman_secure_curl {
   if [[ "${sdkman_insecure_ssl}" == 'true' ]]; then
      wget -O- --no-check-certificate --quiet "$1"
   else
      wget -O- --quiet "$1"
   fi
}

 __sdkman_secure_curl_with_timeouts() {
    if [[ "${sdkman_insecure_ssl}" = 'true' ]]
    then
       wget -O- --no-check-certificate --quiet --connect-timeout=${sdkman_curl_connect_timeout} --timeout=${sdkman_curl_max_time} "$1"
    else
       wget -O- --quiet --connect-timeout ${sdkman_curl_connect_timeout} --timeout ${sdkman_curl_max_time} "$1"
    fi
}

