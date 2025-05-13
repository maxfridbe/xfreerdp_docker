# Dockerfile to set up an Ubuntu container with freerdp-shadow-cli and XFCE Desktop
# This version uses NLA with a dynamically generated SAM-like file from ENV VARS.
# Optimized with separate update and install steps for better caching.
# Replaced Openbox with XFCE4.
# Added gnome-icon-theme and firefox from Mozilla PPA.
# Split package installs into logical layers.
# Added gnupg for PPA key import.
# Reordered PPA addition to be before the main package list update.

# Use the latest Ubuntu LTS as the base image
FROM ubuntu:22.04

# Set environment variables to prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Step 1: Initial update and install tools for PPA management (software-properties-common, gnupg)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    gnupg

# Step 2: Add Mozilla PPA and set preferences
RUN add-apt-repository ppa:mozillateam/ppa -y && \
    # Create a preference file to prioritize the PPA version of Firefox
    echo 'Package: firefox*' > /etc/apt/preferences.d/mozillateamppa && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozillateamppa && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozillateamppa

# Step 3: Main update to fetch lists from all sources including the new PPA
RUN apt-get update

# Step 4: Install Core RDP, X server, and base utilities
RUN apt-get install -y --no-install-recommends \
    freerdp2-shadow-x11 \
    winpr-utils \
    xvfb \
    dbus-x11 \
    xterm

# Step 5: Install the XFCE Desktop Environment
RUN apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies

# Step 6: Install Firefox (from PPA) and icon themes, then clean up
RUN apt-get install -y --no-install-recommends \
    firefox \
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

# Copy the entrypoint script into the container and make it executable
# Ensure the entrypoint.sh file exists in the same directory as the Dockerfile during build
COPY --chown=rdpuser:rdpuser entrypoint.sh /home/rdpuser/entrypoint.sh
RUN chmod +x /home/rdpuser/entrypoint.sh

# Expose the default RDP port (3389)
EXPOSE 3389

# Define the entrypoint script to start the servers
ENTRYPOINT ["/home/rdpuser/entrypoint.sh"]
