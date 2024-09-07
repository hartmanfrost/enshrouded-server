#!/bin/bash
set -exo pipefail

# Quick function to generate a timestamp
timestamp () {
  date +"%Y-%m-%d %H:%M:%S,%3N"
}

shutdown () {
    echo ""
    echo "$(timestamp) INFO: Recieved SIGTERM, shutting down gracefully"
    kill -2 $enshrouded_pid
}

# Set our trap
trap 'shutdown' TERM

# Validate arguments
if [ -z "$RUNTIME" ]; then
    echo "$(timestamp) ERROR: RUNTIME not set, exiting"
    exit 1
else
    echo "$(timestamp) INFO: Using runtime: $RUNTIME"
fi

if [ -z "$SERVER_NAME" ]; then
    SERVER_NAME='Enshrouded Containerized'
    echo "$(timestamp) WARN: SERVER_NAME not set, using default: Enshrouded Containerized"
fi

if [ -z "$SERVER_USER_PASSWORD" ]; then
    echo "$(timestamp) WARN: $SERVER_USER_PASSWORD not set, server will be passwordless"
fi

if [ -z "$SERVER_ADMIN_PASSWORD" ]; then
    echo "$(timestamp) WARN: $SERVER_ADMIN_PASSWORD not set, server will be passwordless"
fi

if [ -z "$GAME_PORT" ]; then
    GAME_PORT='15636'
    echo "$(timestamp) WARN: GAME_PORT not set, using default: 15636"
fi

if [ -z "$QUERY_PORT" ]; then
    QUERY_PORT='15637'
    echo "$(timestamp) WARN: QUERY_PORT not set, using default: 15637"
fi

if [ -z "$SERVER_SLOTS" ]; then
    SERVER_SLOTS='16'
    echo "$(timestamp) WARN: SERVER_SLOTS not set, using default: 16"
fi

if [ -z "$SERVER_IP" ]; then
    SERVER_IP='0.0.0.0'
    echo "$(timestamp) WARN: SERVER_IP not set, using default: 0.0.0.0"
fi

if [ -z "$VALIDATE" ]; then
    VALIDATE=''
    echo "$(timestamp) WARN: VALIDATE not set, skipping validation"
else
    echo "$(timestamp) INFO: VALIDATE set, validating server files"
    VALIDATE='+validate'
fi

# Install/Update Enshrouded
echo "$(timestamp) INFO: Updating Enshrouded Dedicated Server"
if [ "$RUNTIME" == "wine" ]; then
    /home/steam/steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType windows +force_install_dir "$ENSHROUDED_PATH" +login anonymous +app_update ${VALIDATE} +quit ${STEAM_APP_ID}
elif [ "$RUNTIME" == "proton" ]; then
    steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$ENSHROUDED_PATH" +login anonymous app_update ${VALIDATE} +quit ${STEAM_APP_ID}
fi

# Check that steamcmd was successful
if [ $? != 0 ]; then
    echo "$(timestamp) ERROR: steamcmd was unable to successfully initialize and update Enshrouded"
    exit 1
fi

# Copy example server config if not already present
if ! [ -f "${ENSHROUDED_PATH}/enshrouded_server.json" ]; then
    echo "$(timestamp) INFO: Enshrouded server config not present, copying example"
    cp /home/steam/enshrouded_server_example.json ${ENSHROUDED_PATH}/enshrouded_server.json
fi

# Check for proper save permissions
if ! touch "${ENSHROUDED_PATH}/savegame/test"; then
    echo ""
    echo "$(timestamp) ERROR: The ownership of /home/steam/enshrouded/savegame is not correct and the server will not be able to save..."
    echo "the directory that you are mounting into the container needs to be owned by 10000:10000"
    echo "from your container host attempt the following command 'chown -R 10000:10000 /your/enshrouded/folder'"
    echo ""
    exit 1
fi

rm "${ENSHROUDED_PATH}/savegame/test"

# Modify server config to match our arguments
echo "$(timestamp) INFO: Updating Enshrouded Server configuration"
tmpfile=$(mktemp)
jq --arg serverName "$SERVER_NAME" \
   --arg userPassword "$SERVER_USER_PASSWORD" \
   --arg adminPassword "$SERVER_ADMIN_PASSWORD" \
   --arg gamePort "$GAME_PORT" \
   --arg queryPort "$QUERY_PORT" \
   --arg slotCount "$SERVER_SLOTS" \
   --arg serverIp "$SERVER_IP" \
   --indent 2 \
  '
    .name = $serverName |
    .gamePort = ($gamePort | tonumber) |
    .queryPort = ($queryPort | tonumber) |
    .slotCount = ($slotCount | tonumber) |
    .ip = $serverIp |
    .userGroups |= map(
        if .name == "Default" then .password = $userPassword
        else if .name == "Admin" then .password = $adminPassword
        else . end end
    )
  ' "${ENSHROUDED_CONFIG}" > "$tmpfile" && mv "$tmpfile" "$ENSHROUDED_CONFIG"


# Wine talks too much and it's annoying
export WINEDEBUG=-all

# Check that log directory exists, if not create
if ! [ -d "${ENSHROUDED_PATH}/logs" ]; then
    mkdir -p "${ENSHROUDED_PATH}/logs"
fi

# Check that log file exists, if not create
if ! [ -f "${ENSHROUDED_PATH}/logs/enshrouded_server.log" ]; then
    touch "${ENSHROUDED_PATH}/logs/enshrouded_server.log"
fi

# Link logfile to stdout of pid 1 so we can see logs
ln -sf /proc/1/fd/1 "${ENSHROUDED_PATH}/logs/enshrouded_server.log"

# Launch Enshrouded
echo "$(timestamp) INFO: Starting Enshrouded Dedicated Server"

if [ "$RUNTIME" == "wine" ]; then
    wine ${ENSHROUDED_PATH}/enshrouded_server.exe &
elif [ "$RUNTIME" == "proton" ]; then
    ${STEAM_PATH}/compatibilitytools.d/GE-Proton${GE_PROTON_VERSION}/proton run ${ENSHROUDED_PATH}/enshrouded_server.exe &
fi

# Find pid for enshrouded_server.exe
timeout=0
while [ $timeout -lt 11 ]; do
    if ps -e | grep "enshrouded_server"; then
        enshrouded_pid=$(ps -e | grep "enshrouded_server" | awk '{print $1}')
        break
    elif [ $timeout -eq 10 ]; then
        echo "$(timestamp) ERROR: Timed out waiting for enshrouded_server.exe to be running"
        exit 1
    fi
    sleep 6
    ((timeout++))
    echo "$(timestamp) INFO: Waiting for enshrouded_server.exe to be running"
done

# Hold us open until we recieve a SIGTERM
wait

# Handle post SIGTERM from here
# Hold us open until WSServer-Linux pid closes, indicating full shutdown, then go home
tail --pid=$enshrouded_pid -f /dev/null

# o7
echo "$(timestamp) INFO: Shutdown complete."
exit 0
