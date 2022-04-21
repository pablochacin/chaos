# Use ephemeral containers for chaos

[Ephemeral containers](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/) are containers that can be added to running pods. They are intended to be used for debugging purposes (for example, the [`kubectl debug`](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-running-pod/#ephemeral-container) command adds an ephemeral container).

This project explores using ephemeral containers for chaos engineering. The main rationale for this approach is to be able to inject chaos behavior to specific pods without affecting other pods deployed in the same cluster.

Some uses cases that could be covered with this approach:
* Disconnect temporarily a replica of a database from the network without killing it and reconnect it after some time.
* Introduces delays in the responses from a service
* Introduce package loss in the communication between pods

For implementing these features we use an ephemeral container with the following tools: 

* [netem (network emulator)](https://man7.org/linux/man-pages/man8/tc-netem.8.html) to introduce network chaos (delays, package loss)

## Project status and roadmap

This project must be considered an educational tool. It can be used for small-scale chaos tests, but it lacks the features for running complex experiments.

### Known issues and limitations

* If the pod already has an ephemeral container (for example, because it was debugged using the `kubectl debug` command) the chaos agent cannot be installed and `/pod-chaos install` command will fail this this message:

   ```
   The Pod <pod name> is invalid: spec.ephemeralContainers: Forbidden: existing ephemeral containers <container name>  may not be removed
   ```
* The `chaos-agent` container needs to run with `NET_ADMIN` and `NET_RAW` capabilities. 

### Roadmap
[ ] Add command to disconnect pod from the network
[ ] Add command to kill a container in the pod
[ } Add command to consume pod resources (cpu, memory)

## Install

To use this tool you have to clone this repository, build the chaos agent image and made it available to your cluster.

```sh
$ docker build -t chaos-agent .
```

The directory`tools/` contains a Dockerfile for an image that provides tools for running experiments. Build it and make it available to your cluster.
```sh
$ docker build -t chaos-tools tools/
```

### Load images to minikube cluster

```sh
$ minikube image load chaos-agent
$ minikube image load chaos-tools
```

## Usage

Suppose you want to run experiments in an pod running nginx.

Start the pod:
```sh
$ kubectl run nginx --image nginx
```

Get the ip address of the pod 
```sh
$ kubectl get pod nginx -o wide
kubectl get pod nginx -o wide
NAME    READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
nginx   1/1     Running   0          5m    172.17.0.3   minikube   <none>           <none>
```

For this example we will use Apache benchmark tool available in the `chaos-tools` image:
```sh
$ kubectl run -ti ab chaos-tools 
``` 

Before running experiments you must install the chaos agent in the target pod:
```
$ ./pod-chaos install -p nginx
chaos agent installed.
```

Open another terminal and check the response from the nginx pod:
```sh
$ docker run -it -rm chaos-tools ab -n 10 http://172.17.0.3/ 
This is ApacheBench, Version 2.3 <$Revision: 1879490 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 172.17.0.3 (be patient).....done


Server Software:        nginx/1.21.6
Server Hostname:        172.17.0.3
Server Port:            80

Document Path:          /
Document Length:        615 bytes

Concurrency Level:      1
Time taken for tests:   0.034 seconds
Complete requests:      10
Failed requests:        0
Total transferred:      8480 bytes
HTML transferred:       6150 bytes
Requests per second:    295.34 [#/sec] (mean)
Time per request:       3.386 [ms] (mean)
Time per request:       3.386 [ms] (mean, across all concurrent requests)
Transfer rate:          244.58 [Kbytes/sec] received

Connection Times (ms)
              min   avg   max
Connect:        0     0    1
Processing:     0     3   22
Waiting:        0     2   21
Total:          0     3   24
```

To run an experiment introducing a delay of 100ms for a duration of 30 seconds:
```sh
pod-chaos disrupt -p nginx -d 100 -r 30 
```

In the other terminal run again the ab command:
```sh
$ ab -n 10 -S -d -k http://172.17.0.3/
This is ApacheBench, Version 2.3 <$Revision: 1879490 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 172.17.0.3 (be patient).....done


Server Software:        nginx/1.21.6
Server Hostname:        172.17.0.3
Server Port:            80

Document Path:          /
Document Length:        615 bytes

Concurrency Level:      1
Time taken for tests:   1.106 seconds
Complete requests:      10
Failed requests:        0
Keep-Alive requests:    10
Total transferred:      8530 bytes
HTML transferred:       6150 bytes
Requests per second:    9.04 [#/sec] (mean)
Time per request:       110.614 [ms] (mean)
Time per request:       110.614 [ms] (mean, across all concurrent requests)
Transfer rate:          7.53 [Kbytes/sec] received

Connection Times (ms)
              min   avg   max
Connect:        0    10  100
Processing:   100   101  101
Waiting:      100   100  101
Total:        100   111  201
```
**Note:** notice the `-k` option in the `ab` command. This option uses http keep-alive to reuse the connection across requests. If not used, each requests will stablish a connection and the observed delay would be the double of the one specified in the experiment.
