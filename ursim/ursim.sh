#!/bin/bash

CONTAINER_NAME="ursim"

# Directories:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URCAP_DIR="${SCRIPT_DIR}/urcaps"
PROGRAM_DIR="${SCRIPT_DIR}/programs"
POLYSCOPE_DIR="${SCRIPT_DIR}/.polyscope"

# Versions & models:
URCAP_VERSION="1.0.6"         # 1.0.6 https://github.com/UniversalRobots/Universal_Robots_ExternalControl_URCap/releases
URSIM_VERSION=latest          # 5.26.1. https://hub.docker.com/r/universalrobots/ursim_e-series/tags
ROBOT_MODEL="ur5e"

# Network # ip addresses
NETWORK_NAME="ursim_net"
SUBNET="192.168.56.0/24"
IP_ADDRESS="192.168.56.101"   # URSim address
HOST_IP="192.168.56.1"        # host (and devcontainer) address on this network
 
IMAGE_NAME="universalrobots/ursim_e-series"
URCAP_FILE="${URCAP_DIR}/externalcontrol-${URCAP_VERSION}.jar"
URCAP_URL="https://github.com/UniversalRobots/Universal_Robots_ExternalControl_URCap/releases/download/v${URCAP_VERSION}/externalcontrol-${URCAP_VERSION}.jar"

PORT_FORWARDING_WITH_DASHBOARD="-p 30001-30004:30001-30004 -p 29999:29999"
PORT_FORWARDING=""

PROGRAM_DIR_ARG=""
URCAP_DIR_ARG=""

DETACHED=false
#----
help()
{
  # Display Help
  echo "Starts URSim inside a docker container"
  echo
  echo "Syntax: $(basename "$0") [-m|v|p|u|i|f|n|d|h]"
  echo "options:"
  echo "    -m <model>     Robot model. One of [ur3e, ur5e, ur7e, ur8long, ur10e, ur12e, ur16e, ur15, ur18, ur20, ur30]. Defaults to ${ROBOT_MODEL}."
  echo "    -v <version>   URSim version that should be used.
                   See https://hub.docker.com/r/universalrobots/ursim_e-series/tags
                   for available versions. Defaults to '${URSIM_VERSION}'"
  echo "    -p <folder>    Location from which programs are read / to which programs are written.
                   Defaults to ${PROGRAM_DIR}"
  echo "    -u <folder>    Location from which URCaps are read / to which URCaps are written.
                   Defaults to ${URCAP_DIR}"
  echo "    -i <ip>        IP address the container should get. Defaults to ${IP_ADDRESS}"
  echo "    -f <ports>     Port forwarding to use. Defaults to '${PORT_FORWARDING_WITH_DASHBOARD}'.
                   Set to \"DISABLED\" to disable port forwarding."
  echo "    -n <name>      Name of the docker container. Defaults to '${CONTAINER_NAME}'"
  echo "    -d             Detached mode - start in background"
  echo "    -h             Print this Help."
  echo
}

# Version comparison: true if $1 <= $2
verlte()
{
  [ "$1" = "$(printf "%s\n%s" "$1" "$2" | sort -V | head -n1)" ]
}


parse_arguments()
{
  while getopts ":hm:v:p:u:i:f:n:d" option; do
    case $option in
      h) # display Help
        help
        exit 0;;
      m) # robot model
        ROBOT_MODEL=${OPTARG}
        ;;
      v) # ursim_version
        URSIM_VERSION=${OPTARG}
        ;;
      p) # program_folder
        PROGRAM_DIR_ARG=${OPTARG}
        ;;
      u) # urcaps_folder
        URCAP_DIR_ARG=${OPTARG}
        ;;
      i) # IP address
        IP_ADDRESS=${OPTARG}
        ;;
      f) # forward ports
        PORT_FORWARDING=${OPTARG}
        ;;
      n) # container_name
        CONTAINER_NAME=${OPTARG}
        ;;
      d) # detached mode
        DETACHED=true
        ;;
      \?) # invalid option
        echo "Error: Invalid option"
        help
        exit 1
    esac
  done
}

# If the "latest" image is available locally, read its real version.
# The "latest" tag could hide an older version, so this is needed for validation.
get_version_from_latest()
{
  local IMAGE_URSIM_VERSION
  IMAGE_URSIM_VERSION=$(docker image inspect "${IMAGE_NAME}:${URSIM_VERSION}" 2>/dev/null \
    | grep -Po '"build_version": "URSim Version: \K[^"]*') || true
  if [ -n "$IMAGE_URSIM_VERSION" ]; then
    URSIM_VERSION="$IMAGE_URSIM_VERSION"
  fi
}
 
# Make sure that ROBOT_MODEL and URSIM_VERSION fit together (e-series only)
validate_parameters()
{
  local MIN_E_SERIES="5.9.4"
  local MIN_UR15="5.22.0"
  local MIN_UR20="5.14.0"
  local MIN_UR30="5.15.0"
  local MIN_UR7e="5.22.0"     # and UR12e
  local MIN_UR8LONG="5.23.0"  # and UR18
 
  local URSIM_VERSION_CHECK="$URSIM_VERSION"
  if [[ "$URSIM_VERSION" == "latest" ]]; then
    URSIM_VERSION_CHECK="$MIN_UR15"
  fi
 
  if ! [[ "$URSIM_VERSION_CHECK" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid URSim version given. Must be in the format X.Y.Z. Given: $URSIM_VERSION_CHECK"
    exit 1
  fi
 
  if [[ $ROBOT_MODEL != @(ur3e|ur5e|ur7e|ur8long|ur10e|ur12e|ur16e|ur15|ur18|ur20|ur30) ]]; then
    echo "$ROBOT_MODEL is no valid e-series model!" && exit 1
  fi
 
  local MIN_VERSION
  case $ROBOT_MODEL in
    ur15)          MIN_VERSION=$MIN_UR15 ;;
    ur20)          MIN_VERSION=$MIN_UR20 ;;
    ur30)          MIN_VERSION=$MIN_UR30 ;;
    ur7e|ur12e)    MIN_VERSION=$MIN_UR7e ;;
    ur8long|ur18)  MIN_VERSION=$MIN_UR8LONG ;;
    *)             MIN_VERSION=$MIN_E_SERIES ;;
  esac
 
  verlte "$MIN_VERSION" "$URSIM_VERSION_CHECK" && return 0
 
  echo "Illegal version given. For $ROBOT_MODEL the software version must be greater or equal to $MIN_VERSION. Given version: $URSIM_VERSION."
  exit 1
}
 
# Bring the model into the format URSim uses internally (e-series / PolyScope 5)
# e.g. ur5e -> UR5, ur12e -> UR12, ur20 -> UR20
strip_robot_model()
{
  local robot_model=$1
  ROBOT_MODEL=${robot_model^^}
  if [[ "$robot_model" = @(ur3e|ur5e|ur7e|ur10e|ur12e|ur16e) ]]; then
    ROBOT_MODEL=${ROBOT_MODEL:0:$((${#ROBOT_MODEL}-1))}
  fi
}
 
get_effective_url()
{
  curl -Ls -o /dev/null -w '%{url_effective}' "$1"
}
 
# Get the latest tag from a GitHub release page, e.g.
# https://github.com/UniversalRobots/Universal_Robots_ExternalControl_URCap/releases/latest
get_latest_release_tag()
{
  get_effective_url "$1" | grep -oP '\d+\.\d+\.\d+' | head -n 1
}
 
# Sets URCAP_VERSION and URCAP_DOWNLOAD_URL.
# $1 is either a version (e.g. 1.0.6) or "latest"
get_download_url_urcap()
{
  if [[ "$1" == "latest" ]]; then
    URCAP_VERSION=$(get_latest_release_tag "https://github.com/UniversalRobots/Universal_Robots_ExternalControl_URCap/releases/latest")
    # Empty if GitHub is not reachable (e.g. no internet); main() handles that
    [ -n "$URCAP_VERSION" ] || return 1
  else
    URCAP_VERSION=$1
  fi
  URCAP_DOWNLOAD_URL="https://github.com/UniversalRobots/Universal_Robots_ExternalControl_URCap/releases/download/v${URCAP_VERSION}/externalcontrol-${URCAP_VERSION}.jar"
}
 
# Ask whether an already present older URCap should be replaced.
# Without an answer within URCAP_PROMPT_TIMEOUT seconds (default 10) the old one is kept.
# returns 0 if the user accepted the update, 1 otherwise
prompt_urcap_update()
{
  local new_version=$1
  local timeout=${URCAP_PROMPT_TIMEOUT:-10}
  local answer=""
 
  echo "An older version of the External Control URCap is already present in ${URCAP_DIR}."
  echo "Do you want to remove it and download version ${new_version}? [y/N] (auto-N in ${timeout}s)"
  if ! read -r -t "$timeout" answer; then
    answer=""
    echo
    echo "No answer within ${timeout}s, continuing with the existing version."
  fi
  case "$answer" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *)                 return 1 ;;
  esac
}
 
post_setup()
{
  echo
  echo "Docker URSim is running"
  echo "  PolyScope:     http://${IP_ADDRESS}:6080/vnc.html"
  echo "  Driver:        ros2 launch ur_robot_driver ur_control.launch.py ur_type:=${ROBOT_MODEL_ARG} robot_ip:=${IP_ADDRESS} launch_rviz:=true"
  echo "  URCap Host IP: ${HOST_IP}"
  echo "  Order: robot ON + START -> driver -> Play"
  echo
}


main() {
    parse_arguments "$@"

    get_version_from_latest
 
    echo "ROBOT_MODEL:   $ROBOT_MODEL"
    echo "URSIM_VERSION: $URSIM_VERSION"

    validate_parameters

    ROBOT_MODEL_ARG="$ROBOT_MODEL"   # keep the ros2 name (ur5e) for the printout
    strip_robot_model "$ROBOT_MODEL"

    if [ -z "$PORT_FORWARDING" ]; then
        PORT_FORWARDING=$PORT_FORWARDING_WITH_DASHBOARD
    fi

    if [ "$PORT_FORWARDING" == "DISABLED" ]; then
        echo "Port forwarding disabled"
        PORT_FORWARDING=""
    fi

    if [ -n "$PROGRAM_DIR_ARG" ]; then
        PROGRAM_DIR="$PROGRAM_DIR_ARG"
    fi
    if [ -n "$URCAP_DIR_ARG" ]; then
        URCAP_DIR="$URCAP_DIR_ARG"
    fi

      # Check whether network already exists
    if ! docker network inspect "${NETWORK_NAME}" &> /dev/null; then
        echo "Creating ${NETWORK_NAME}"
        docker network create --subnet="${SUBNET}" "${NETWORK_NAME}" || exit 1
    fi

    # Create local storage for programs, URCaps and PolyScope settings
    mkdir -p "${PROGRAM_DIR}" "${URCAP_DIR}" "${POLYSCOPE_DIR}"
    # Needed when -p / -u gets a relative path: docker -v requires absolute paths
    URCAP_DIR=$(realpath "$URCAP_DIR")
    PROGRAM_DIR=$(realpath "$PROGRAM_DIR")

    # Download external_control URCap
    download_urcap=false
    if ! get_download_url_urcap "$URCAP_VERSION"; then
        # "latest" could not be resolved (offline): use an existing URCap if there is one
        if compgen -G "${URCAP_DIR}/externalcontrol-*.jar" > /dev/null; then
        echo "Could not check the latest URCap version (no internet?). Using the existing one."
        else
        echo "Error: could not determine the latest URCap version and no URCap is present in ${URCAP_DIR}"
        exit 1
        fi
    elif [[ ! -f "${URCAP_DIR}/externalcontrol-${URCAP_VERSION}.jar" ]]; then
        # If externalcontrol-<version>.jar exists with another version, ask whether
        # the newer version should be downloaded and used.
        shopt -s nullglob
        existing_urcaps=( "${URCAP_DIR}"/externalcontrol-*.jar )
        shopt -u nullglob
        if ((${#existing_urcaps[@]})); then
        if prompt_urcap_update "$URCAP_VERSION"; then
            download_urcap=true
        else
            echo "Continuing without downloading. The older version will be used."
        fi
        else
        download_urcap=true
        fi
        if [[ $download_urcap = true ]]; then
        echo "Downloading and installing External Control URCap version ${URCAP_VERSION}"
        if curl -fL -o "${URCAP_DIR}/externalcontrol-${URCAP_VERSION}.jar" "$URCAP_DOWNLOAD_URL"; then
            if ((${#existing_urcaps[@]})); then
            rm -f "${existing_urcaps[@]}"
            fi
        else
            rm -f "${URCAP_DIR}/externalcontrol-${URCAP_VERSION}.jar"
            echo "Error: download failed: ${URCAP_DOWNLOAD_URL}"
            exit 1
        fi
        fi
    fi
 
    # Remove an old container with the same name (otherwise docker run fails)
    if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
        echo "Removing old ${CONTAINER_NAME} container"
        docker rm -f "${CONTAINER_NAME}" > /dev/null
    fi

    docker_args=(docker run --rm -d
      --hostname "${CONTAINER_NAME}"
      --net "${NETWORK_NAME}" --ip "${IP_ADDRESS}"
      -e "ROBOT_MODEL=${ROBOT_MODEL}"
      -v "${URCAP_DIR}:/urcaps"
      -v "${PROGRAM_DIR}:/ursim/programs"
      -v "${POLYSCOPE_DIR}:/ursim/.polyscope"
    )

    # PORT_FORWARDING is a space-separated list of -p flags; word-splitting is intentional
    # shellcheck disable=SC2206
    [[ -n "$PORT_FORWARDING" ]] && docker_args+=($PORT_FORWARDING)
    docker_args+=(--name "$CONTAINER_NAME" "${IMAGE_NAME}:${URSIM_VERSION}")
    
    "${docker_args[@]}" > /dev/null || exit 2
    
    # Stop container when interrupted
    TRAP_CMD="
    echo \"killing ursim\";
    docker container kill $CONTAINER_NAME >> /dev/null;
    docker container wait $CONTAINER_NAME >> /dev/null 2>&1;
    echo \"done\";
    exit
    "
    # shellcheck disable=SC2064
    trap "$TRAP_CMD" SIGINT SIGTERM
    
    post_setup
    
    if [ "$DETACHED" = false ]; then
        echo "To exit, press CTRL+C"
        while :
        do
        sleep 1
        done
    else
        echo "To kill it, please execute 'docker stop $CONTAINER_NAME'"
    fi
}
 
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  main "$@"
fi