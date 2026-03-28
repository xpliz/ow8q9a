#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

IMAGE_DEV="servlet:dev"
IMAGE_PROD="servlet:1.3.1"
CONTAINER_DEV="servlet-dev"
CONTAINER_PROD="servlet"

show_banner() {
    echo -e "${CYAN}"
    echo -e "╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║            ${YELLOW}ServletMirror - Docker/Podman Manager${CYAN}              ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

usage() {
    show_banner
    echo -e "${BOLD}Usage:${NC} $0 <command> [runtime] [env]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo "  build [runtime]          Build image(s)"
    echo "  run [runtime] [env]      Run container"
    echo "  compose [runtime] [env]  Run with compose"
    echo "  kube [runtime] [env]     Run with podman play kube"
    echo "  stop [runtime]           Stop containers"
    echo "  logs [runtime]           Show logs"
    echo "  clean                    Remove containers and images"
    echo "  help                     Show this help message"
    echo ""
    echo -e "${BOLD}Runtime (optional):${NC} docker | podman (default: podman if available, else docker)"
    echo ""
    echo -e "${BOLD}Environment:${NC} dev | prod (default: prod)"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  $0 build                     # Build with default runtime"
    echo "  $0 build docker              # Build with Docker"
    echo "  $0 build podman              # Build with Podman"
    echo "  $0 run                       # Run prod with default runtime"
    echo "  $0 run dev                   # Run dev with default runtime"
    echo "  $0 run docker dev            # Run dev container with Docker"
    echo "  $0 run podman prod           # Run prod container with Podman"
    echo "  $0 compose dev               # Run dev with default runtime"
    echo "  $0 compose podman prod       # Run prod with Podman Compose"
    echo "  $0 kube dev                  # Run dev with Podman Kube"
    echo "  $0 kube podman prod          # Run prod with Podman Kube"
    echo "  $0 stop                      # Stop containers"
    echo "  $0 logs                      # Show logs"
    echo "  $0 clean                     # Clean up everything"
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

detect_runtime() {
    if command -v podman &> /dev/null; then
        echo "podman"
    elif command -v docker &> /dev/null; then
        echo "docker"
    else
        log_error "Neither podman nor docker is installed"
        exit 1
    fi
}

check_runtime() {
    local runtime=$1
    if ! command -v $runtime &> /dev/null; then
        log_error "$runtime is not installed"
        exit 1
    fi
}

get_runtime() {
    local runtime=$1
    if [ -z "$runtime" ] || [ "$runtime" = "dev" ] || [ "$runtime" = "prod" ]; then
        runtime=$(detect_runtime)
    fi
    echo "$runtime"
}

get_runtime_and_env() {
    local arg1=$1
    local arg2=$2
    local runtime=""
    local env="prod"

    if [ "$arg1" = "docker" ] || [ "$arg1" = "podman" ]; then
        runtime=$arg1
        env=${arg2:-prod}
    elif [ "$arg1" = "dev" ] || [ "$arg1" = "prod" ]; then
        runtime=$(detect_runtime)
        env=$arg1
    elif [ -n "$arg1" ]; then
        runtime=$(detect_runtime)
    else
        runtime=$(detect_runtime)
    fi

    echo "$runtime $env"
}

build() {
    local runtime=$(get_runtime "$1")

    show_banner
    echo -e "${BOLD}Building images with ${runtime}...${NC}"
    echo ""

    log_info "Building dev image: $IMAGE_DEV"
    $runtime build -t $IMAGE_DEV -f Dockerfile.dev .
    log_success "Dev image built: $IMAGE_DEV"

    log_info "Building prod image: $IMAGE_PROD"
    $runtime build -t $IMAGE_PROD -f Dockerfile .
    log_success "Prod image built: $IMAGE_PROD"

    echo ""
    log_success "All images built successfully!"
}

run_container() {
    read runtime env <<< $(get_runtime_and_env "$1" "$2")
    check_runtime $runtime

    local image=$([ "$env" = "dev" ] && echo $IMAGE_DEV || echo $IMAGE_PROD)
    local container=$([ "$env" = "dev" ] && echo $CONTAINER_DEV || echo $CONTAINER_PROD)
    local port=$([ "$env" = "dev" ] && echo "11080" || echo "8080")
    local memory=$([ "$env" = "dev" ] && echo "1g" || echo "512m")
    local cpus=$([ "$env" = "dev" ] && echo "1" || echo "0.5")

    show_banner
    echo -e "${BOLD}Running $env container with ${runtime}...${NC}"
    echo ""

    $runtime run -d \
        --name $container \
        -p ${port}:${port} \
        --restart unless-stopped \
        --memory=$memory \
        --cpus=$cpus \
        $image

    log_success "Container '$container' started on port $port"
    echo ""
    log_info "URL: http://localhost:$port"
    log_info "Resources: ${memory} memory, ${cpus} CPU"
}

compose() {
    read runtime env <<< $(get_runtime_and_env "$1" "$2")
    check_runtime $runtime

    local compose_cmd="$runtime compose"
    if [ "$runtime" = "podman" ]; then
        compose_cmd="$runtime compose"
    else
        compose_cmd="$runtime compose"
    fi

    show_banner
    echo -e "${BOLD}Running ${env} with Docker Compose...${NC}"
    echo ""

    case $env in
        dev)
            $compose_cmd up -d servlet-dev
            log_success "Dev service started"
            log_info "URL: http://localhost:11080"
            ;;
        prod)
            $compose_cmd up -d servlet
            log_success "Prod service started"
            log_info "URL: http://localhost:8080"
            ;;
    esac
}

kube() {
    read runtime env <<< $(get_runtime_and_env "$1" "$2")

    if [ "$runtime" != "podman" ]; then
        if command -v podman &> /dev/null; then
            runtime="podman"
        else
            log_error "podman play kube requires Podman"
            exit 1
        fi
    fi
    check_runtime $runtime

    show_banner
    echo -e "${BOLD}Running ${env} with Podman Kube...${NC}"
    echo ""

    local pod_name=$([ "$env" = "dev" ] && echo "servlet-dev" || echo "servlet")
    local port=$([ "$env" = "dev" ] && echo "11080" || echo "8080")

    $runtime play kube --replace servlet.yaml

    log_success "Pod '$pod_name' started"
    log_info "URL: http://localhost:$port"
}

stop() {
    local runtime=$(get_runtime "$1")
    if [ -z "$runtime" ] || [ "$runtime" = "dev" ] || [ "$runtime" = "prod" ]; then
        runtime=$(detect_runtime)
    fi
    check_runtime $runtime

    show_banner
    echo -e "${BOLD}Stopping containers and pods...${NC}"
    echo ""

    if command -v podman &> /dev/null; then
        local pods=$(podman pod ls --format "{{.Name}}" 2>/dev/null | grep -E "^servlet(-dev)?$" || true)
        for p in $pods; do
            podman pod stop $p 2>/dev/null && log_success "Stopped pod: $p" || true
            podman pod rm -f $p 2>/dev/null && log_success "Removed pod: $p" || true
        done
    fi

    $runtime compose -f compose.yaml down 2>/dev/null || true

    local containers=$($runtime ps -a --format "{{.Names}}" 2>/dev/null | grep -E "^servlet(-dev)?$" || true)
    for c in $containers; do
        $runtime stop $c 2>/dev/null && log_success "Stopped: $c" || true
        $runtime rm -f $c 2>/dev/null && log_success "Removed: $c" || true
    done

    log_success "All containers and pods stopped"
}

logs() {
    local runtime=$(get_runtime "$1")
    if [ -z "$runtime" ] || [ "$runtime" = "dev" ] || [ "$runtime" = "prod" ]; then
        runtime=$(detect_runtime)
    fi
    check_runtime $runtime

    local container=$($runtime ps --format "{{.Names}}" | grep -E "^servlet(-dev)?$" | head -1)
    if [ -z "$container" ]; then
        log_error "No running servlet container found"
        exit 1
    fi

    $runtime logs -f $container
}

clean() {
    show_banner
    echo -e "${BOLD}Cleaning up...${NC}"
    echo ""

    if command -v podman &> /dev/null; then
        log_info "Cleaning pods..."
        podman pod ls --format "{{.Name}}" | grep -E "^servlet(-dev)?$" | xargs -r podman pod rm -f 2>/dev/null || true
    fi

    for runtime in docker podman; do
        if command -v $runtime &> /dev/null; then
            log_info "Cleaning $runtime..."
            $runtime ps -a --format "{{.Names}}" | grep -E "^servlet(-dev)?$" | xargs -r $runtime rm -f 2>/dev/null || true
            $runtime rmi $IMAGE_DEV $IMAGE_PROD 2>/dev/null || true
            log_success "$runtime cleaned"
        fi
    done

    log_success "Cleanup complete"
}

main() {
    local cmd=${1:-help}
    shift || true

    case $cmd in
        build)
            build "$@"
            ;;
        run)
            run_container "$@"
            ;;
        compose)
            compose "$@"
            ;;
        kube)
            kube "$@"
            ;;
        stop)
            stop "$@"
            ;;
        logs)
            logs "$@"
            ;;
        clean)
            clean
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"
