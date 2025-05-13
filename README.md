# XFCE Desktop via RDP in Docker

This repository provides Docker configurations to run a full XFCE desktop environment accessible via RDP (Remote Desktop Protocol) using `freerdp-shadow-cli`. It includes setups for Ubuntu and Debian (x86_64 and ARM64).

This allows you to have a containerized Linux desktop that you can connect to from any RDP client, useful for development, testing, or running GUI applications in an isolated environment.

## Features

* **Full XFCE Desktop Environment:** Provides a lightweight and complete desktop experience.
* **RDP Access:** Uses `freerdp-shadow-cli` for efficient RDP server capabilities.
* **NLA Authentication:** Securely authenticates users using Network Level Authentication with credentials passed via environment variables.
* **Customizable:** Easily add more applications by modifying the Dockerfile.
* **Cross-Platform Support:**
    * Ubuntu (x86_64)
    * Debian 12 (Bookworm, x86_64)
    * Debian 12 (Bookworm, ARM64) - Ideal for devices like Raspberry Pi or ARM-based cloud servers.
* **Includes common applications:**
    * Firefox web browser
    * Xterm (terminal emulator)
    * Standard icon themes (Tango, GNOME)

## Prerequisites

* **Docker:** You need Docker installed and running on your host machine.
* **RDP Client:** An RDP client (e.g., Remmina on Linux, Microsoft Remote Desktop on Windows/macOS, `xfreerdp` command-line tool).

## Directory Structure

The repository is organized as follows:

* `ubuntu_xfce/`: Contains `Dockerfile`, `entrypoint.sh`, and `build.sh` for an Ubuntu-based XFCE RDP server.
* `debian_xfce/`: Contains `Dockerfile`, `entrypoint.sh`, and `build.sh` for a Debian 12 (x86_64) based XFCE RDP server.
* `debian_xfce_arm64/`: Contains `Dockerfile` (referencing `arm64v8/debian:12`), `entrypoint.sh`, and `build.sh` for a Debian 12 (ARM64) based XFCE RDP server.

*(Please adjust the directory names above to match your actual repository structure if they are different.)*

## Build Instructions

Navigate to the directory of the version you want to build (e.g., `debian_xfce_arm64`).

1.  **Ensure `entrypoint.sh` has Unix line endings:**
    If you've edited `entrypoint.sh` on Windows, convert its line endings:
    ```bash
    # If you have dos2unix installed:
    dos2unix entrypoint.sh
    # Otherwise, ensure your editor saves with LF line endings.
    ```

2.  **Make `build.sh` executable:**
    ```bash
    chmod +x build.sh
    ```

3.  **Run the build script:**
    ```bash
    ./build.sh
    ```
    This script will call `docker build` with the appropriate image name and tag. For ARM64 builds, it should include the `--platform linux/arm64` flag if you are cross-compiling from an x86_64 host.

    Alternatively, you can build manually. For example, for the ARM64 Debian version:
    ```bash
    cd debian_xfce_arm64
    docker build --platform linux/arm64 -t freerdp-shadow-debian-arm64:latest .
    ```

## Running the Container

Once the image is built, you can run the container using the `docker run` command. You **must** provide `RDP_USER` and `RDP_PASSWORD` environment variables.

**Example for Debian ARM64:**

```bash
docker run -d --rm --name rdp-debian-arm-container \
  -p 3389:3389 \
  -e RDP_USER="your_rdp_user" \
  -e RDP_PASSWORD="YourSecurePassword123" \
  freerdp-shadow-debian-arm64:latest
Replace your_rdp_user and YourSecurePassword123 with your desired credentials.Replace freerdp-shadow-debian-arm64:latest with the appropriate image name if you used a different one.-d: Run in detached mode (in the background).--rm: Automatically remove the container when it exits.--name: Assign a name to the container for easier management.-p 3389:3389: Map port 3389 on the host to port 3389 in the container (standard RDP port).-e RDP_USER: Sets the username for RDP login.-e RDP_PASSWORD: Sets the password for RDP login.Connecting to the RDP SessionUse your preferred RDP client to connect to the IP address of your Docker host on port 3389.Use the RDP_USER and RDP_PASSWORD you specified when running the container.Using xfreerdp (command-line client):xfreerdp /v:<docker_host_ip> /u:your_rdp_user /p:YourSecurePassword123 /dynamic-resolution
Replace <docker_host_ip> with the IP address of the machine running Docker. If connecting from the same machine, you can use localhost.The /dynamic-resolution flag is often helpful.You might encounter a certificate warning on the first connection, which is normal for the self-signed certificate used by default.CustomizationAdding More ApplicationsTo add more applications to your desktop environment:Open the Dockerfile for the desired version (e.g., debian_xfce_arm64/Dockerfile).Find the apt-get install section where firefox-esr and icon themes are installed.Add the package names of the applications you want to install to this list.# Example: adding gedit text editor
RUN apt-get install -y --no-install-recommends \
    firefox-esr \
    tango-icon-theme \
    gnome-icon-theme \
    gedit \ # <--- Added gedit here
    # --- Add other desired GUI applications here ---
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*
Rebuild the Docker image using ./build.sh or docker build ....TroubleshootingExec format error on entrypoint.sh: This usually means the script has Windows-style line endings (CRLF). Convert it to Unix-style (LF) using dos2unix entrypoint.sh or a text editor.Black Screen after Connection (Older versions/Openbox): This typically means the window manager or desktop environment isn't starting correctly or isn't being captured by the RDP server. The XFCE versions should resolve this.Authentication Failures: Double-check that RDP_USER and RDP_PASSWORD environment variables are correctly passed to the docker run command.Missing Icons/Themes: Ensure packages like tango-icon-theme and gnome-icon-theme are installed in the Dockerfile. XFCE might require a logout/login or a settings adjustment to pick up new themes.ContributingContributions are welcome! Please feel free to submit pull requests or open issues for bugs, feature requests, or improvements.LicenseConsider adding a LICENSE file to your repository (e.g., MIT, Apache 2.0). For example, to use the MIT License, create a file named LICENSE with the following content:MIT License

Copyright (c) [Year] [Your Name/Organization]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
