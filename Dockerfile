FROM alpine:3.15

RUN apk update && apk add iproute2
COPY chaos-agent.sh . 
CMD chaos-agent.sh

