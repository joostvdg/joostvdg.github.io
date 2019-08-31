title: Java Networking
description: Java Networking - What You Should Know

# Java Networking

## General Remarks

* Network API works for IPv4 (32-bit adrressing) and IPv6 (128-bit addressing)
* Java only supports ```TCP/IP``` and ```UDP/IP```
 
## Java proxy system params

* socksProxyHost
* socksProxyPort
* http.proxySet
* http.proxyHost
* http.proxyPort
* https.proxySet
* https.proxyHost
* https.proxyPort
* ftpProxySet
* ftpProxyHost
* ftpProxyPort
* gopherProxySet 
* gopherProxyHost
* gopherProxyPort 
 
## Special IPv4 segments
 
### Internal

* 10.*.*.* 
* 172.17.*.* - 172.31.*.*
* 192.168.*.*
 
### Local
 
* 127.*.*.*
 
### Broadcast
 
* 255.255.255.255
    > Packets sent to this address are received by all nodes on the local network, though they are not routed beyond the local network
 
## Special IPv6 segments
 
### Local
 
* 0:0:0:0:0:0:0:1 (or ::::::1 or ::1)
 