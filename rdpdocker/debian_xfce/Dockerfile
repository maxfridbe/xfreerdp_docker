# Dockerfile to set up a Debian 12 (Bookworm) container with freerdp-shadow-cli and XFCE Desktop
# This version uses NLA with a dynamically generated SAM-like file from ENV VARS.
# Optimized with separate update and install steps for better caching.
# Uses XFCE4 Desktop Environment.
# Installs firefox-esr and common icon themes.
# Added dos2unix to fix entrypoint.sh line endings.

# Use Debian 12 (Bookworm) as the base image
FROM debian:12

# Set environment variables to prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Step 1: Initial update and install basic tools (gnupg for general good practice, dos2unix for script conversion)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gnupg \
    dos2unix

# Step 2: Install Core RDP, X server, and base utilities
RUN apt-get install -y --no-install-recommends \
    freerdp2-shadow-x11 \
    winpr-utils \
    xvfb \
    dbus-x11 \
    xterm

# Step 3: Install the XFCE Desktop Environment
RUN apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies

# Step 4: Install Firefox (ESR version from Debian repos) and icon themes, then clean up
RUN apt-get install -y --no-install-recommends \
    firefox-esr \
    tango-icon-theme \
    gnome-icon-theme \
    # --- Add other desired GUI applications here ---
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user for the RDP session to enhance security
RUN useradd -m -s /bin/bash rdpuser && \
    mkdir -p /home/rdpuser/.config && \
    chown -R rdpuser:rdpuser /home/rdpuser

# Switch to the non-root user
USER rdpuser
WORKDIR /home/rdpuser

# Copy the entrypoint script into the container
# Ensure the entrypoint.sh file (from immersive id: freerdp_entrypoint_script_sam)
# exists in the same directory as the Dockerfile during build.
COPY --chown=rdpuser:rdpuser entrypoint.sh /home/rdpuser/entrypoint.sh

# Ensure entrypoint.sh has correct Unix line endings and is executable
RUN dos2unix /home/rdpuser/entrypoint.sh && \
    chmod +x /home/rdpuser/entrypoint.sh

# Expose the default RDP port (3389)
EXPOSE 3389

# Define the entrypoint script to start the servers
ENTRYPOINT ["/home/rdpuser/entrypoint.sh"]

