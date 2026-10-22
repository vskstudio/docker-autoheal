# Docker Autoheal

Monitor and restart unhealthy docker containers.
This functionality was proposed to be included with the addition of `HEALTHCHECK`, however didn't make the cut.
This container is a stand-in till there is native support for `--exit-on-unhealthy` https://github.com/docker/docker/pull/22719.

Maintained fork of [willfarrell/docker-autoheal](https://github.com/willfarrell/docker-autoheal) by [VSK Studio](https://github.com/vskstudio).
The upstream image stays on an end-of-life Alpine base and its pull requests are no longer reviewed.
This fork keeps the base on the latest Alpine release, rebuilds every night to pick up security fixes, and carries the upstream fixes worth having.

## Image

```
ghcr.io/vskstudio/autoheal
```

Platforms: `linux/amd64`, `linux/arm64`.

## Supported tags and Dockerfile links
| Tag | Built from | Rebuilt |
| --- | --- | --- |
| `latest` | [`main`](https://github.com/vskstudio/docker-autoheal/blob/main/Dockerfile) | on every push to `main` and every night |
| `1.3.0`, `1.3`, `1` | [`v1.3.0`](https://github.com/vskstudio/docker-autoheal/blob/v1.3.0/Dockerfile) | on release |
| `sha-<commit>` | the matching commit | once |

Pin a version tag (or a `sha-*` tag) in production. Use `latest` to follow the nightly rebuilds.

## Changes from upstream
- Alpine 3.24 base (upstream: 3.18, end of life). The CA bundle no longer trusts the distrusted emSign/eMudhra intermediates.
- SIGTERM handler kills the sleep child instead of re-signalling itself, so the container stops cleanly (upstream [#131](https://github.com/willfarrell/docker-autoheal/pull/131)).
- Refuses to start when the Docker unix socket exists but is not writable (upstream [#146](https://github.com/willfarrell/docker-autoheal/pull/146), rewritten in POSIX sh).
- Image published to GHCR with OCI labels, multi-arch, nightly rebuild.

## How to use

### 1. Docker CLI
#### UNIX socket passthrough
```bash
docker run -d \
    --name autoheal \
    --restart=always \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -v /var/run/docker.sock:/var/run/docker.sock \
    ghcr.io/vskstudio/autoheal:1
```
#### TCP socket 
```bash
docker run -d \
    --name autoheal \
    --restart=always \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -e DOCKER_SOCK=tcp://$HOST:$PORT \
    -v /path/to/certs/:/certs/:ro \
    ghcr.io/vskstudio/autoheal:1
```
#### TCP with mTLS (HTTPS)
```bash
docker run -d \
    --name autoheal \
    --restart=always \
    --tlscacert=/certs/ca.pem \
    --tlscert=/certs/client-cert.pem \
    --tlskey=/certs/client-key.pem \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -e DOCKER_HOST=tcp://$HOST:2376 \
    -e DOCKER_SOCK=tcps://$HOST:2376 \
    -e DOCKER_TLS_VERIFY=1 \
    -v /path/to/certs/:/certs/:ro \
    ghcr.io/vskstudio/autoheal:1
```
The certificates and keys need these names and resides under /certs inside the container:
* ca.pem
* client-cert.pem
* client-key.pem

> See https://docs.docker.com/engine/security/https/ for how to configure TCP with mTLS

### Change Timezone
If you need the timezone to match the local machine, you can map the `/etc/localtime` into the container.
```bash
docker run ... -v /etc/localtime:/etc/localtime:ro
```

### 2. Use in your container image
Choose one of the three alternatives:

a) Apply the label `autoheal=true` to your container to have it watched;<br/>
b) Set ENV `AUTOHEAL_CONTAINER_LABEL=all` to watch all running containers;<br/>
c) Set ENV `AUTOHEAL_CONTAINER_LABEL` to existing container label that has the value `true`;<br/>

> Note: You must apply `HEALTHCHECK` to your docker images first.<br/>
> See https://docs.docker.com/engine/reference/builder/#healthcheck for details.

#### Docker Compose (example)
```yaml
services:
  app:
    extends:
      file: ${PWD}/services.yml
      service: app
    labels:
      autoheal-app: true

  autoheal:
    deploy:
      replicas: 1
    environment:
      AUTOHEAL_CONTAINER_LABEL: autoheal-app
    image: ghcr.io/vskstudio/autoheal:1
    network_mode: none
    restart: always
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock
```

#### Optional Container Labels
|`autoheal.stop.timeout=20`            |Per containers override for stop timeout seconds during restart|
| --- | --- |

## Environment Defaults
|Variable                              |Description|
| --- | --- |
|`AUTOHEAL_CONTAINER_LABEL=autoheal`   |set to existing label name that has the value `true`|
|`AUTOHEAL_INTERVAL=5`                 |check every 5 seconds|
|`AUTOHEAL_START_PERIOD=0`             |wait 0 seconds before first health check|
|`AUTOHEAL_DEFAULT_STOP_TIMEOUT=10`    |Docker waits max 10 seconds (the Docker default) for a container to stop before killing during restarts (container overridable via label, see below)|
|`AUTOHEAL_ONLY_MONITOR_RUNNING=false` |All containers monitored by default. Set this to true to only monitor running containers. This will result in paused containers being ignored.|
|`DOCKER_SOCK=/var/run/docker.sock`    |Unix socket for curl requests to Docker API|
|`CURL_TIMEOUT=30`                     |--max-time seconds for curl requests to Docker API|
|`WEBHOOK_URL=""`                      |post message to the webhook if a container was restarted (or restart failed)|

## Testing (building locally)
```bash
docker buildx build -t autoheal .

docker run -d \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -v /var/run/docker.sock:/var/run/docker.sock \
    autoheal
```

## Releasing
Push a semver tag; the workflow publishes `X.Y.Z`, `X.Y` and `X`:
```bash
git tag v1.3.1
git push origin v1.3.1
```
