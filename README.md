OSC.jl
------

Open Sound Control serialization library for Julia


To send a message over port 7777

````julia
require("OSC")
using OSC
sock1 = UdpSocket()
msg1 = OSC.message("/hello world", "sSif", "strings", "symbols", 234,
float32(2.3))
send(sock1, ip"127.0.0.1", 7777, msg1.data)
````
To receive a message over port 7778

````julia
sock2 = UdpSocket()
bind(sock2, ip"127.0.0.1", 7778)#should return true
msg2 = OscMsg(recv(sock2))
````
[![Build Status](https://travis-ci.org/fundamental/OSC.jl.png)](https://travis-ci.org/fundamental/OSC.jl)
