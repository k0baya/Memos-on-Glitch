FILES_PATH=${FILES_PATH:-./}
CURRENT_VERSION=''
RELEASE_LATEST=''
CMD="$@"

get_current_version() {
    CURRENT_VERSION=$(cat VERSION)
}

get_latest_version() {
    # Get latest release version number
    RELEASE_LATEST=$(curl -s https://api.github.com/repos/k0baya/memos-binary/releases/latest | jq -r '.tag_name')
    if [[ -z "$RELEASE_LATEST" ]]; then
        echo "error: Failed to get the latest release version, please check your network."
        exit 1
    fi
}

download_web() {
    DOWNLOAD_LINK="https://github.com/k0baya/memos-binary/releases/latest/download/memos-linux-amd64.tar.gz"
    if ! wget -qO "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    curl -s https://api.github.com/repos/k0baya/memos-binary/releases/latest | jq -r '.tag_name' > VERSION
    return 0
}

decompression() {
    tar -zxf "$1" -C "$TMP_DIRECTORY"
    EXIT_CODE=$?
    if [ ${EXIT_CODE} -ne 0 ]; then
        "rm" -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
    fi
}

install_web() {
    install -m 755 ${TMP_DIRECTORY}/memos ${FILES_PATH}/app.js
    cp -R ${TMP_DIRECTORY}/dist ${FILES_PATH}/dist
}

run_web() { 
    killall app.js 2>/dev/null

    if [ "${DATABASE_URL}" != "" ]; then
        proto="$(echo $DATABASE_URL | grep '://' | sed -e's,^\(.*://\).*,\1,g')"
        chmod +x ./app.js && mkdir -p ${FILES_PATH}/data
        if [[ "${proto}" =~ postgres ]]; then
        exec ./app.js --mode prod --data ${FILES_PATH}/data --driver postgres --dsn ${DATABASE_URL}
        elif [[ "${proto}" =~ mysql ]]; then
        exec ./app.js --mode prod --data ${FILES_PATH}/data --driver mysql --dsn ${DATABASE_URL}
        fi
    fi

    chmod +x ./app.js && mkdir -p ${FILES_PATH}/data
    exec ./app.js --mode prod --data ${FILES_PATH}/data 2>&1 &
}

generate_autodel() {
  cat > auto_del.sh <<EOF
while true; do
  rm -rf /app/.git
  sleep 5
done
EOF
}
generate_autodel
[ -e auto_del.sh ] && bash auto_del.sh &

TMP_DIRECTORY="$(mktemp -d)"
ZIP_FILE="${TMP_DIRECTORY}/memos-linux-amd64.tar.gz"

if [ -d dist ] && [ -f app.js ]; then
    get_current_version
    get_latest_version
    if [ "${RELEASE_LATEST}" = "${CURRENT_VERSION}" ]; then
    run_web
    exit 0
    fi
elif [ -d dist ] || [ -f app.js ]; then
    rm -rf dist app.js
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
decompression "$ZIP_FILE"
install_web
"rm" -rf "$TMP_DIRECTORY"
run_web
