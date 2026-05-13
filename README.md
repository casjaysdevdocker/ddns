## 👋 Welcome to ddns 🚀  

ddns README  
  
  
## Install my system scripts  

```shell
 sudo bash -c "$(curl -q -LSsf "https://github.com/systemmgr/installer/raw/main/install.sh")"
 sudo systemmgr --config && sudo systemmgr install scripts  
```
  
## Automatic install/update  
  
```shell
dockermgr update ddns
```
  
## Install and run container
  
```shell
dockerHome="/var/lib/srv/$USER/docker/casjaysdevdocker/ddns/ddns/latest/rootfs"
mkdir -p "/var/lib/srv/$USER/docker/ddns/rootfs"
git clone "https://github.com/dockermgr/ddns" "$HOME/.local/share/CasjaysDev/dockermgr/ddns"
cp -Rfva "$HOME/.local/share/CasjaysDev/dockermgr/ddns/rootfs/." "$dockerHome/"
docker run -d \
--restart always \
--privileged \
--name casjaysdevdocker-ddns-latest \
--hostname ddns \
-e TZ=${TIMEZONE:-America/New_York} \
-v "$dockerHome/data:/data:z" \
-v "$dockerHome/config:/config:z" \
-p 80:80 \
casjaysdevdocker/ddns:latest
```
  
## via docker-compose  
  
```yaml
version: "2"
services:
  ProjectName:
    image: casjaysdevdocker/ddns
    container_name: casjaysdevdocker-ddns
    environment:
      - TZ=America/New_York
      - HOSTNAME=ddns
    volumes:
      - "/var/lib/srv/$USER/docker/casjaysdevdocker/ddns/ddns/latest/rootfs/data:/data:z"
      - "/var/lib/srv/$USER/docker/casjaysdevdocker/ddns/ddns/latest/rootfs/config:/config:z"
    ports:
      - 80:80
    restart: always
```
  
## Get source files  
  
```shell
dockermgr download src casjaysdevdocker/ddns
```
  
OR
  
```shell
git clone "https://github.com/casjaysdevdocker/ddns" "$HOME/Projects/github/casjaysdevdocker/ddns"
```
  
## Build container  
  
```shell
cd "$HOME/Projects/github/casjaysdevdocker/ddns"
buildx 
```
  
## Authors  
  
🤖 casjay: [Github](https://github.com/casjay) 🤖  
⛵ casjaysdevdocker: [Github](https://github.com/casjaysdevdocker) [Docker](https://hub.docker.com/u/casjaysdevdocker) ⛵  
