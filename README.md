# xfreerdp_docker
docker container which lets you rdp in

```bash
docker run -d --name rdp-container   -p 3389:3389   -e RDP_USER="myrdpuser"   -e RDP_PASSWORD="MySecurePassword123" freerdp-shadow-ubuntu

xfreerdp /v:localhost /u:myrdpuser /p:MySecurePassword123 +clipboard /workarea +home-drive
```
