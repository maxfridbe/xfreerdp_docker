#!/bin/bash
# Entrypoint script to start Xvfb, XFCE, and freerdp-shadow-cli
# This version uses NLA with a dynamically generated SAM-like file from ENV VARS.
# Starts XFCE4 session.
# Added cleanup for stale RDP server certificates and X server lock files.
# Added signal trapping for graceful shutdown.

# set -x # Keep commented out unless debugging hash generation

# --- Configuration ---
# Path for the dynamically generated RDP authentication file for /sam-file
AUTH_FILE="/home/rdpuser/.config/rdp-auth-sam.txt"
# Path for temporary hash output
HASH_OUTPUT_FILE="/home/rdpuser/.config/hash_output.tmp"
# Screen resolution for the virtual display
SCREEN_RESOLUTION="1280x1024x24"
# Display number for Xvfb
DISPLAY_NUM=":1" # Using :1 to avoid potential conflicts with host display :0
# Standard empty LM hash
EMPTY_LM_HASH="AAD3B435B51404EEAAD3B435B51404EE"
# FreeRDP server config directory
FREERDP_SERVER_CONFIG_DIR="/home/rdpuser/.config/freerdp/server"
# Xvfb lock file
XVFB_LOCK_FILE="/tmp/.X${DISPLAY_NUM#:}-lock"


# --- Cleanup function for graceful shutdown ---
cleanup() {
    echo "INFO: Received termination signal. Cleaning up..."
    # Kill child processes
    if [ -n "$FREERDP_PID" ]; then
        kill "$FREERDP_PID" 2>/dev/null
    fi
    if [ -n "$XFCE_PID" ]; then
        kill "$XFCE_PID" 2>/dev/null
        # Attempt to kill all processes in XFCE session group
        pkill -P "$XFCE_PID" 2>/dev/null
    fi
    if [ -n "$DBUS_SESSION_BUS_PID" ]; then
        kill "$DBUS_SESSION_BUS_PID" 2>/dev/null
    fi
    if [ -n "$XVFB_PID" ]; then
        kill "$XVFB_PID" 2>/dev/null
    fi
    # Additional cleanup for X sockets and lock files
    rm -f /tmp/.X11-unix/X${DISPLAY_NUM#:} "$XVFB_LOCK_FILE"
    echo "INFO: Cleanup finished."
    exit 0
}

# Trap SIGTERM and SIGINT to call the cleanup function
trap cleanup SIGTERM SIGINT

# --- Initial Cleanup for robust restart ---
echo "INFO: Performing initial cleanup for robust restart..."
# Kill any lingering processes from a previous unclean shutdown
pkill -f "Xvfb ${DISPLAY_NUM}" 2>/dev/null
pkill -f "startxfce4" 2>/dev/null
pkill -f "xfce4-session" 2>/dev/null
# dbus-daemon can be tricky, ensure it's tied to the session later
# pkill -f "dbus-daemon --fork" 2>/dev/null # Be cautious with this

# Remove stale X server lock file and socket
rm -f "$XVFB_LOCK_FILE"
rm -f "/tmp/.X11-unix/X${DISPLAY_NUM#:}"
# Remove stale RDP server certificate/key files
rm -f "${FREERDP_SERVER_CONFIG_DIR}/shadow.key"
rm -f "${FREERDP_SERVER_CONFIG_DIR}/shadow.crt"
echo "INFO: Initial cleanup complete."


# --- Authentication Setup from Environment Variables ---
if [ -n "$RDP_USER" ] && [ -n "$RDP_PASSWORD" ]; then
  echo "INFO: RDP_USER and RDP_PASSWORD environment variables are set."
  echo "INFO: Attempting to generate NTHASH for user '$RDP_USER' using short options -u and -p..."

  # Execute winpr-hash using short options -u and -p.
  winpr-hash -u "$RDP_USER" -p "$RDP_PASSWORD" > "$HASH_OUTPUT_FILE" 2>&1
  WINPR_EXIT_CODE=$? # Capture exit code immediately

  echo "INFO: winpr-hash finished with exit code: $WINPR_EXIT_CODE"

  # Read the raw output from the temporary file
  RAW_WINPR_OUTPUT=$(cat "$HASH_OUTPUT_FILE")
  # Clean up the temporary file
  rm -f "$HASH_OUTPUT_FILE"

  # Check if winpr-hash command was successful (exit code 0)
  if [ $WINPR_EXIT_CODE -ne 0 ]; then
      echo "ERROR: winpr-hash command failed with exit code $WINPR_EXIT_CODE."
      echo "       Raw winpr-hash output was: ['$RAW_WINPR_OUTPUT']"
      exit 1
  fi

  # Trim all whitespace
  NTHASH=$(echo "$RAW_WINPR_OUTPUT" | tr -d '[:space:]')

  # Validate NTHASH format
  if ! [[ "$NTHASH" =~ ^[0-9a-fA-F]{32}$ ]]; then
    echo "ERROR: Parsed NTHASH is not a valid 32-character hexadecimal hash."
    echo "       Raw winpr-hash output was: ['$RAW_WINPR_OUTPUT']"
    echo "       Processed (trimmed) NTHASH was: ['$NTHASH']"
    exit 1
  fi
  echo "INFO: NTHASH generated and validated successfully: $NTHASH"

  # Create the SAM-like file content: username::LMHASH:NTHASH:::
  SAM_LINE_CONTENT="$RDP_USER::$EMPTY_LM_HASH:$NTHASH:::"

  echo "INFO: Creating SAM-like auth file at $AUTH_FILE with simplified format (no UID)."
  echo "$SAM_LINE_CONTENT" > "$AUTH_FILE"
  chmod 600 "$AUTH_FILE"
  echo "INFO: Auth file for NLA created successfully."

else
  echo "ERROR: RDP_USER and RDP_PASSWORD environment variables MUST be set for this configuration."
  exit 1
fi

# --- Server Startup ---
echo "Starting Xvfb virtual display (${DISPLAY_NUM}) with resolution ${SCREEN_RESOLUTION}..."
# The -nolisten tcp option is generally recommended for security if X clients are local.
# However, freerdp-shadow-cli might need it if it acts as a remote X client to Xvfb.
# Let's keep -listen tcp for now as it was working.
Xvfb ${DISPLAY_NUM} -screen 0 ${SCREEN_RESOLUTION} +extension GLX -noreset -listen tcp &
XVFB_PID=$!
echo "INFO: Xvfb PID: $XVFB_PID"

export DISPLAY=${DISPLAY_NUM}
# Wait for Xvfb to be ready by checking for the lock file
echo "INFO: Waiting for Xvfb to be ready..."
WAIT_COUNT=0
MAX_WAIT=20 # Wait for a maximum of 10 seconds (20 * 0.5s)
while [ ! -f "$XVFB_LOCK_FILE" ] && [ "$WAIT_COUNT" -lt "$MAX_WAIT" ]; do
    sleep 0.5
    ((WAIT_COUNT++))
done

if [ ! -f "$XVFB_LOCK_FILE" ]; then
    echo "ERROR: Xvfb failed to start or create lock file $XVFB_LOCK_FILE in time."
    cat /tmp/Xvfb.log 2>/dev/null # Attempt to show Xvfb log if it exists
    exit 1
fi
echo "INFO: Xvfb is ready."


echo "Starting D-Bus session bus..."
# D-Bus is important for XFCE. Capture its PID.
eval $(dbus-launch --sh-syntax --exit-with-session)
# The previous line exports DBUS_SESSION_BUS_ADDRESS and DBUS_SESSION_BUS_PID
echo "INFO: D-Bus Session Bus PID: $DBUS_SESSION_BUS_PID (from env)"


echo "Starting XFCE4 session..."
# Ensure the config dir for freerdp server exists before XFCE starts,
mkdir -p "${FREERDP_SERVER_CONFIG_DIR}"
chown rdpuser:rdpuser "${FREERDP_SERVER_CONFIG_DIR}" -R
# Start the full XFCE4 session in the background
startxfce4 &
XFCE_PID=$!
echo "INFO: XFCE PID: $XFCE_PID"
# Give XFCE some time to initialize. A more robust check would be better if possible.
sleep 5


echo "Starting FreeRDP shadow server (freerdp-shadow-cli) with NLA..."
echo "Listening on port 3389. Using credentials from environment variables via generated SAM file for NLA."
# /auth: Clients must authenticate
# /sam-file: Use the generated file for NTLM authentication (NLA)
# /sec:nla: Enforce NLA security
# Run freerdp-shadow-cli in the foreground so the script waits for it
freerdp-shadow-cli /port:3389 /auth /sam-file:$AUTH_FILE /sec:nla &
FREERDP_PID=$!
echo "INFO: freerdp-shadow-cli PID: $FREERDP_PID"

# Wait for freerdp-shadow-cli to exit
wait "$FREERDP_PID"

# If freerdp-shadow-cli exits, call cleanup
cleanup
