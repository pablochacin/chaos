#!/bin/sh
set -x

function usage() {

cat <<EOF

    Execute chaos actions on a container

    Usage: $0 [OPTIONS...]

    Options:
    -d, --delay: introduce a delay in the packages from this container (in milliseconds)
    -i, --iface: interface to act on (default eth0)
    -r, --running-time: duration of the perturbation (in seconds, defaults to running undefinitely)
    -v,--variation: variation of delay time (in milliseconds. Defaults to 0 or fixed delay)
    -w, --warm-up: delay before starting perturbation (in seconds)
EOF
}

function parse_args() {
   while [[ $# != 0 ]] ; do
        case $1 in
        -d|--delay)
            DELAY="$2ms"
            shift
            ;;
        -i|--iface)
            IFACE=$2
            shift
            ;;
        -r|--running-time)
            RUNNING_TIME=$2
            shift
            ;;
        -v|--variation)
            VARIATION="$2ms"
            shift
            ;;
        -w|--warm-up)
            WARM_UP=$2
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
IFACE='eth0'
RUNNING_TIME=infinity
WARM_UP=
 
# parse all arguments passed to the script
parse_args $@

if [[ -z $DELAY ]]; then
    echo "delay must be specified"
    usage >&2
    exit 1
fi


if [[ ! -z $WARM_UP ]]; then
    sleep $WARM_UP
fi

if [[ ! -z $DELAY ]]; then
   tc qdisc add dev $IFACE root netem delay $DELAY $VARIATION 
fi

sleep $RUNNING_TIME

# remove injected failures
tc qdisc del dev eth0 root netem
