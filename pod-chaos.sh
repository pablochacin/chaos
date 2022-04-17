#!/bin/bash

function gen_container() {
cat <<EOF
{
    "apiVersion": "v1",
    "kind": "Pod",
    "metadata": {
            "name": "$POD",
            "namespace": "$NAMESPACE"
    },
    "spec": {
      "ephemeralContainers": [{
          "command": [
            "sh"
          ],
          "image": "chaos-agent",
          "imagePullPolicy": "IfNotPresent",
          "name": "chaos",
          "stdin": true,
          "tty": true,
          "terminationMessagePolicy": "File",
          "securityContext" :{
            "privileged": true,
            "capabilities": {
          "add": ["NET_ADMIN","NET_RAW"]
            }
          }
      }]
    }
}
EOF
}

function install() {
    gen_container | kubectl replace --raw /api/v1/namespaces/$NAMESPACE/pods/$POD/ephemeralcontainers --validate=false $POD -f - > /dev/null
    echo "chaos agent installed."
}

function disrupt() {
    AGENT_OPTS="$DELAY $VARIATION $IFACE $WARM_UP $RUNNING_TIME"
    kubectl -n $NAMESPACE exec $POD -c chaos  -- chaos-agent.sh $AGENT_OPTS
}

function usage() {

cat <<EOF

    Execute chaos actions on a container

    Usage: $0 CMD [OPTIONS...]
    CMD:
    install: install chaos agent
    disrupt: execute disruption

    OPTIONS:
      COMMON:
      -h,--help: display this help
      -n,--namesapce: namespace where the pod runs
      -p,--pod: pod to disturb
      INSTALL:
      -g,--image: image tobe used for launching the chaos agent container (default 'chaos-agent')
      DISRUPT: 
        -d ,--delay: introduce a delay in the packages from this container (milliseconds) 
        -i,--iface: interface to act on (default eth0)
        -r, --running-time: duration of the perturbation (in seconds, defaults to running undefinitely)
        -v,--variation: variation of delay time (in milliseconds. Default, none)
        -w, --warm-up: delay before starting perturbation (in seconds)
EOF
}

function parse_args() {
    case $1 in
        disrupt)
            CMD="disrupt"
            ;;
        install)
            CMD="install"
            ;;
        -h|--help)
            usage >&2
            exit 0
            ;;
        *)
            echo "Error: Invalid parameter ${1}" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift

    while [[ $# != 0 ]] ; do
        case $1 in
            -d|--delay)
                DELAY="-d $2"
                shift
                ;;
            -g|--image)
                IMAGE=$2
                shift
                ;;
            -h|--help)
                usage >&2
                exit 0
                ;;
            -i|--iface)
                IFACE="-i $2"
                shift
                ;;
            -n|--namespace)
                NAMESPACE=$2
                shift
                ;;
            -p|--pod)
                POD=$2
                shift
                ;;
            -r|--running-time)
                RUNNING_TIME="-r $2"
                shift
                ;;
            -v|--variation)
                VARIATION="-v $2"
                shift
                ;;
            -w|--warm-up)
                WARMUP="-w $2"
                shift
                ;; 
            *)
                echo "Error: Invalid parameter ${1}" >&2
                usage >&2
                exit 1
                ;;
        esac
        shift
    done
}

DELAY=
VARIATION=
IFACE=
RUNNING_TIME=
WARM_UP=
IMAGE="chaos-agent"
POD=
NAMESPACE="default"
CMD=

parse_args $@

if [[ -z $CMD ]]; then
    echo "a command must be specified" >&2
    usage >&2
    exit 1
fi

if [[ -z $POD ]]; then
    echo "Pod name is required" >&2
    usage >&2
    exit 1
fi

$CMD

