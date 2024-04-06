FILES_PATH=${FILES_PATH:-./}
CURRENT_VERSION=''
RELEASE_LATEST=''
CMD="$@"

get_current_version() {
    chmod +x ./app.js 2>/dev/null
    CURRENT_VERSION=$(./app.js version | grep -o v[0-9]*\.*.)
}

get_latest_version() {
    # Get latest release version number
    RELEASE_LATEST="$(curl -IkLs -o ${TMP_DIRECTORY}/NUL -w %{url_effective} https://github.com/synctv-org/synctv/releases/latest | grep -o "[^/]*$")"
    RELEASE_LATEST="v${RELEASE_LATEST#v}"
    if [[ -z "$RELEASE_LATEST" ]]; then
        echo "error: Failed to get the latest release version, please check your network."
        exit 1
    fi
}

download_web() {
    DOWNLOAD_LINK="https://github.com/synctv-org/synctv/releases/latest/download/synctv-linux-amd64"
    if ! wget -qO "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    return 0
}

install_web() {
    install -m 755 ${ZIP_FILE} ${FILES_PATH}/app.js
}

PARSE_DB_URL() {
    export SYNCTV_DATABASE_CUSTOM_DSN=${DATABASE_URL}
}

run_web() {
    if [ "$CMD" = "server" ]; then   
        killall app.js 2>/dev/null
    fi

    if [ "${DATABASE_URL}" != "" ]; then
        PARSE_DB_URL
    fi

    export SYNCTV_LOG_ENABLE=false
    export SYNCTV_RTMP_RTMP_PLAYER=true
    export TEMP_DIR=/tmp/web
    chmod +x ./app.js
    exec ./app.js $CMD 2>&1 &
}

TMP_DIRECTORY="$(mktemp -d)"
ZIP_FILE="${TMP_DIRECTORY}/synctv-linux-amd64"

get_current_version
get_latest_version
if [ "${RELEASE_LATEST}" = "${CURRENT_VERSION}" ]; then
    "rm" -rf "$TMP_DIRECTORY"
    run_web
    exit
fi
download_web
EXIT_CODE=$?
if [ ${EXIT_CODE} -eq 0 ]; then
    :
else
    "rm" -r "$TMP_DIRECTORY"
    run_web
    exit
fi
install_web
"rm" -rf "$TMP_DIRECTORY"
run_web
