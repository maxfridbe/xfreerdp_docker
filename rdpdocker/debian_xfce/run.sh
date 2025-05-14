podman stop rdp-container
podman rm rdp-container
podman run -d --name rdp-container \
  -p 3389:3389 \
  -e RDP_USER="myrdpuser" \
  -e RDP_PASSWORD="MySecurePassword123" \
  -e RDP_WIDTH="1920" \
  -e RDP_HEIGHT="1080" \
  -e RDP_DEPTH="24" \
  localhost/freerdp-shadow-ubuntu
