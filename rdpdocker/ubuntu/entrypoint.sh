#!/bin/bash
# Entrypoint script to start Xvfb, XFCE, and freerdp-shadow-cli
# This version uses NLA with a dynamically generated SAM-like file from ENV VARS.
# Starts XFCE4 session instead of Openbox.

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
Xvfb ${DISPLAY_NUM} -screen 0 ${SCREEN_RESOLUTION} +extension GLX -noreset -listen tcp &
XVFB_PID=$!

export DISPLAY=${DISPLAY_NUM}
sleep 3 # Wait for Xvfb

echo "Starting D-Bus session bus..."
# D-Bus is important for XFCE
eval $(dbus-launch --sh-syntax)

echo "Starting XFCE4 session..."
# Start the full XFCE4 session in the background
startxfce4 &
XFCE_PID=$!
sleep 5 # Give XFCE more time to initialize

# Removed explicit xterm start - XFCE should handle its environment

echo "Starting FreeRDP shadow server (freerdp-shadow-cli) with NLA..."
echo "Listening on port 3389. Using credentials from environment variables via generated SAM file for NLA."
# /auth: Clients must authenticate
# /sam-file: Use the generated file for NTLM authentication (NLA)
# /sec:nla: Enforce NLA security
freerdp-shadow-cli /port:3389 /auth /sam-file:$AUTH_FILE /sec:nla

# --- Cleanup (Docker usually handles this on container stop) ---
# echo "FreeRDP shadow server stopped. Cleaning up..."
# kill $XFCE_PID # Changed from OPENBOX_PID
# kill $XVFB_PID
# echo "Cleanup complete."

exit 0

