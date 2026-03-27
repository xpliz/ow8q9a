# ServletMirror Containerization

## Table of Contents

- [ServletMirror Containerization](#servletmirror-containerization)
  - [Table of Contents](#table-of-contents)
  - [About](#about)
  - [Requirements](#requirements)
  - [Quick Start](#quick-start)
  - [Building Images](#building-images)
    - [Docker](#docker)
    - [Podman](#podman)
  - [Running Containers](#running-containers)
    - [Docker](#docker-1)
    - [Podman](#podman-1)
  - [Docker Compose](#docker-compose)
  - [Podman Play Kube](#podman-play-kube)
  - [Helper Script](#helper-script)
    - [Build](#build)
    - [Run](#run)
    - [Compose](#compose)
    - [Kube](#kube)
    - [Stop](#stop)
    - [Logs](#logs)
    - [Clean](#clean)
  - [Usage Examples](#usage-examples)
  - [Security Features](#security-features)
  - [Files Reference](#files-reference)
  - [Additional Scripts](#additional-scripts)
    - [getip.sh](#getipsh)

---

## About

**ServletMirror** is a Java servlet application that mirrors HTTP requests back to the client, similar to [httpbin](https://httpbin.org/). It's a useful development tool for testing and debugging HTTP clients.

**Source:** https://github.com/bostjans/javaServletMirror

**Features:**
- Returns request details (headers, body, method, etc.)
- Supports both HTTP and HTTPS
- Available endpoints: `/`, `/mirror/`, `/v1`, `/v1/secure`, `/show/v1`, `/monitor/v1`
- Built with Java and Jetty

---

## Requirements

- [docker](https://www.docker.com/) or [podman](https://podman.io/) with [podman-compose](https://github.com/containers/podman-compose)
- `curl` (for health checks and testing)

---

## Quick Start

The easiest way to get started is using the provided `run.sh` script:

```bash
# Build images (uses docker or podman automatically)
./run.sh build

# Run production container
./run.sh run

# Run development container
./run.sh run dev
```

---

## Building Images

### Docker

```bash
# Build both dev and prod images
docker build -t servlet:dev -f Dockerfile.dev .
docker build -t servlet:1.3.1 -f Dockerfile .

# Or use the script
./run.sh build docker
```

### Podman

```bash
# Build both dev and prod images
podman build -t servlet:dev -f Dockerfile.dev .
podman build -t servlet:1.3.1 -f Dockerfile .

# Or use the script
./run.sh build podman
```

---

## Running Containers

### Docker

```bash
# Run production container
docker run -d --name servlet -p 8080:8080 --restart unless-stopped servlet:1.3.1
# Access at: http://localhost:8080

# Run development container
docker run -d --name servlet-dev -p 11080:11080 --restart unless-stopped servlet:dev
# Access at: http://localhost:11080
```

### Podman

```bash
# Run production container
podman run -d --name servlet -p 8080:8080 --restart unless-stopped servlet:1.3.1
# Access at: http://localhost:8080

# Run development container
podman run -d --name servlet-dev -p 11080:11080 --restart unless-stopped servlet:dev
# Access at: http://localhost:11080
```

---

## Docker Compose

```bash
# Run development environment
docker compose up -d servlet-dev
# Access at: http://localhost:11080

# Run production environment
docker compose up -d servlet
# Access at: http://localhost:8080

# Stop all services
docker compose down
```

Or with Podman:

```bash
podman compose up -d servlet-dev
podman compose up -d servlet
podman compose down
```

---

## Podman Play Kube

First, ensure images are built, then:

```bash
# Run production pod
podman play kube --replace servlet.yaml

# This creates a pod named "servlet" running on port 8080
# Access at: http://localhost:8080

# Run development pod
podman play kube --replace - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: servlet-dev
spec:
  containers:
    - name: servlet-dev
      image: servlet:dev
      ports:
        - containerPort: 11080
          hostPort: 11080
EOF

# Stop and remove pods
podman pod ls | grep servlet
podman pod stop servlet servlet-dev
podman pod rm servlet servlet-dev
```

---

## Helper Script

The `run.sh` script provides a convenient interface for all container operations. It auto-detects the runtime (podman if available, else docker).

### Build

```bash
./run.sh build              # Build with default runtime
./run.sh build docker       # Build with Docker
./run.sh build podman       # Build with Podman
```

### Run

```bash
./run.sh run                # Run prod with default runtime (port 8080)
./run.sh run dev            # Run dev with default runtime (port 11080)
./run.sh run docker prod    # Run prod with Docker
./run.sh run podman dev     # Run dev with Podman
```

### Compose

```bash
./run.sh compose            # Run prod with default runtime
./run.sh compose dev        # Run dev with default runtime
./run.sh compose podman dev # Run dev with Podman
```

### Kube

```bash
./run.sh kube               # Run prod pod (requires podman)
./run.sh kube dev           # Run dev pod (requires podman)
```

### Stop

```bash
./run.sh stop               # Stop containers/pods with default runtime
```

### Logs

```bash
./run.sh logs               # View logs with default runtime
```

### Clean

```bash
./run.sh clean              # Remove all containers, pods, and images
```

---

## Usage Examples

```bash
# Test the mirror endpoint
curl -i http://localhost:8080

# Get JSON response
curl -i -H "Accept: application/json" http://localhost:8080/v1

# Check headers
curl -i -H "X-Custom-Header: test" http://localhost:8080/mirror/

# View all request details
curl -i http://localhost:8080/show/v1

# Monitor endpoint
curl -i http://localhost:8080/monitor/v1
```

---

## Security Features

The production container includes several security best practices:

| Feature | Implementation |
|---------|---------------|
| **Non-root user** | Runs as `nobody` user |
| **Resource limits** | Memory: 512MB, CPU: 0.1 cores |
| **Tmpfs mounts** | `/tmp` and `/var/tmp` in memory |
| **Security options** | `no-new-privileges:true` |
| **Health checks** | Built-in healthcheck with curl |

---

## Files Reference

| File | Description |
|------|-------------|
| `Dockerfile` | Production image build |
| `Dockerfile.dev` | Development image build |
| `compose.yaml` | Docker/Podman Compose configuration |
| `servlet.yaml` | Podman Kube configuration |
| `run.sh` | Convenience script for operations |
| `getip.sh` | Helper script to get server IP |

---

## Additional Scripts

### getip.sh

A shell script that displays the server's default network IP address.

**Features:**
- Excludes localhost/loopback IPs (127.0.0.0/8)
- No external queries (works offline)
- Multiple fallback methods for reliability

**Usage:**

```bash
# Make executable
chmod +x getip.sh

# Get IP address
./getip.sh

# Or source it in your shell
source getip.sh
echo "Server IP: $(getip)"
```

**How it works:**
1. Uses `ip route get` to find the IP of the interface used for the default gateway
2. Falls back to `ip addr` on the default interface
3. Falls back to `hostname -I`
4. Falls back to `ifconfig` on older systems
