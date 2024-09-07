# enshrouded-server

[![Static Badge](https://img.shields.io/badge/DockerHub-blue)](https://hub.docker.com/r/sknnr/enshrouded-dedicated-server) ![Docker Pulls](https://img.shields.io/docker/pulls/sknnr/enshrouded-dedicated-server) [![Static Badge](https://img.shields.io/badge/GitHub-green)](https://github.com/jsknnr/enshrouded-server) ![GitHub Repo stars](https://img.shields.io/github/stars/jsknnr/enshrouded-server)


Run Enshrouded dedicated server in a container. Optionally includes helm chart for running in Kubernetes.

**Disclaimer:** This is not an official image. No support, implied or otherwise is offered to any end user by the author or anyone else. Feel free to do what you please with the contents of this repo.
## Usage

The processes within the container do **NOT** run as root. Everything runs as the user steam (gid:10000/uid:10000 by default). If you exec into the container, you will drop into `/home/steam` as the steam user. Enshrouded will be installed to `/home/steam/enshrouded`. Any persistent volumes should be mounted to `/home/steam/enshrouded/savegame` and be owned by 10000:10000. 


### Proton and Wine based images

The `latest` tag is now based on the Proton build instead of Wine. This should be seamless. Outside of `latest`, there is `wine-$realease_version` and `proton-$release_version` with `$release_version` being the version of the release from GitHub.

### Ports

| Port | Protocol | Default |
| ---- | -------- | ------- |
| Game Port | UDP | 15636 |
| Query Port | UDP | 15637 |

### Environment Variables

| Name | Description | Default | Required |
| ---- | ----------- | ------- | -------- |
| SERVER_NAME | Name for the Server | Enshrouded Containerized | False |
| SERVER_USER_PASSWORD | Password for the server | None | False |
| SERVER_ADMIN_PASSWORD | Password for the admin | None | False |
| GAME_PORT | Port for server connections | 15636 | False |
| QUERY_PORT | Port for steam query of server | 15637 | False |
| SERVER_SLOTS | Number of slots for connections (Max 16) | 16 | False |
| SERVER_IP | IP address for server to listen on | 0.0.0.0 | False |

**Note:** SERVER_IP is ignored if using Helm because that isn't how Kubernetes works.

### Docker

To run the container in Docker, run the following command:

```bash
docker volume create enshrouded-persistent-data
docker run \
  --detach \
  --name enshrouded-server \
  --mount type=volume,source=enshrouded-persistent-data,target=/home/steam/enshrouded/savegame \
  --publish 15636:15636/udp \
  --publish 15637:15637/udp \
  --env=SERVER_NAME='Enshrouded Containerized Server' \
  --env=SERVER_SLOTS=16 \
  --env=SERVER_USER_PASSWORD='ChangeThisPlease' \
  --env=SERVER_ADMIN_PASSWORD='ChangeThisPlease2' \
  --env=GAME_PORT=15636 \
  --env=QUERY_PORT=15637 \
  sknnr/enshrouded-dedicated-server:latest
```

### Docker Compose

To use Docker Compose, either clone this repo or copy the `docker-compose.yaml` file out of the `docker` directory to your local machine. Edit the compose file to change the environment variables to the values you desire and then save the changes. Once you have made your changes, from the same directory that contains the compose and the env files, simply run:

```bash
docker-compose up -d
```

To bring the container down:

```bash
docker-compose down
```

docker-compose.yaml file:
```yaml
services:
  enshrouded:
    image: sknnr/enshrouded-dedicated-server:latest
    ports:
      - "15636:15636/udp"
      - "15637:15637/udp"
    environment:
      - SERVER_NAME=Enshrouded Containerized
      - SERVER_USER_PASSWORD=PleaseChangeMe
      - SERVER_ADMIN_PASSWORD=PleaseChangeMe2
      - GAME_PORT=15636
      - QUERY_PORT=15637
      - SERVER_SLOTS=16
      - SERVER_IP=0.0.0.0
    volumes:
      - enshrouded-persistent-data:/home/steam/enshrouded
      - enshrouded-savegame:/home/steam/enshrouded/savegame

volumes:
  enshrouded-persistent-data:
  enshrouded-savegame:
```

### Podman

To run the container in Podman, run the following command:

```bash
podman volume create enshrouded-persistent-data
podman volume create enshrouded-savegame
podman run \
  --detach \
  --name enshrouded-server \
  --mount type=volume,source=enshrouded-persistent-data,target=/home/steam/enshrouded \
  --mount type=volume,source=enshrouded-savegame,target=/home/steam/enshrouded/savegame \
  --publish 15636:15636/udp \
  --publish 15637:15637/udp \
  --env=SERVER_NAME='Enshrouded Containerized Server' \
  --env=SERVER_SLOTS=16 \
  --env=SERVER_USER_PASSWORD='ChangeThisPlease' \
  --env=SERVER_ADMIN_PASSWORD='ChangeThisPlease2' \
  --env=GAME_PORT=15636 \
  --env=QUERY_PORT=15637 \
  docker.io/sknnr/enshrouded-dedicated-server:latest
```

### Quadlet
To run the container with Podman's new quadlet subsystem, make a file under (when running as root) /etc/containers/systemd/enshrouded.container containing:
```text
[Unit]
Description=Enshrouded Game Server

[Container]
Image=docker.io/sknnr/enshrouded-dedicated-server:latest
Volume=enshrouded-persistent-data:/home/steam/enshrouded/savegame
PublishPort=15636-15637:15636-15637/udp
ContainerName=enshrouded-server
Environment=SERVER_NAME="Enshrouded Containerized Server"
Environment=SERVER_USER_PASSWORD="ChangeThisPlease"
Environment=SERVER_ADMIN_PASSWORD="ChangeThisPlease2"
Environment=GAME_PORT=15636
Environment=QUERY_PORT=15637
Environment=SERVER_SLOTS=16

[Service]
# Restart service when sleep finishes
Restart=always
# Extend Timeout to allow time to pull the image
TimeoutStartSec=900

[Install]
# Start by default on boot
WantedBy=multi-user.target default.target
```

### Kubernetes

I've built a Helm chart and have included it in the `charts` directory within this repo. Modify the `values.yaml` file to your liking and install the chart into your cluster. Be sure to create and specify a namespace as I did not include a template for provisioning a namespace.

## Troubleshooting

### Connectivity

If you are having issues connecting to the server once the container is deployed, I promise the issue is not with this image. You need to make sure that the ports 15636 and 15637 (or whichever ones you decide to use) are open on your router as well as the container host where this container image is running. You will also have to port-forward the game-port and query-port from your router to the private IP address of the container host where this image is running. After this has been done correctly and you are still experiencing issues, your internet service provider (ISP) may be blocking the ports and you should contact them to troubleshoot.

For additional help, refer to this closed issue where some folks were able to debug their issues. It may be of help. <br>
https://github.com/jsknnr/enshrouded-server/issues/16

### Storage

I recommend having Docker or Podman manage the volume that gets mounted into the container. However, if you absolutely must bind mount a directory into the container you need to make sure that on your container host the directory you are bind mounting is owned by 10000:10000 by default (`chown -R 10000:10000 /path/to/directory`). If the ownership of the directory is not correct the container will not start as the server will be unable to persist the savegame.

## Contributing

### Hooks

This part is also **required**. Thanks for all these tweaks, we have:

1. Automated helm chart documentation generation
2. Automated checks for secrets in the repository

> How does it work?

Git executes pre-commit program before every commit made locally, no matter are you going to push it or not. Pre-commit read content of `.pre-commit-config.yaml` file in the root of the repository and executes all hooks listed.

### Installation procedure

1. Install [pre-commit framework](https://pre-commit.com)
2. Install [gitleaks](https://github.com/zricethezav/gitleaks)
3. Install [helm-docs](https://github.com/norwoodj/helm-docs)
4. Enable pre-commit hook in the repository
    ```shell
    pre-commit install
    pre-commit install-hooks
    ```
5. Check that hooks work

    You can either make a dummy commit, or execute the command below.

    ```shell
    pre-commit run -a
    ```
    
    When some step is failed, you have to fix what it says or Git won't finish commit creation for you. In some cases there is nothing to fix. For example, docs hook have changed some README.md file because you changed variables description. Hook will be marked as failed because there is a new file that is to be included in the commit, but it won't be done implicit, you have to run *git commit* once again. On the second attempt it will pass without issues. So in this case, failure is not a failure, but a disclaimer that you have to add extra files to the commit.
