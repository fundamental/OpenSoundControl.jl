OSC.jl -- Implementation of the Open Sound Control Serialization Format
-----------------------------------------------------------------------

[![Build Status](https://travis-ci.org/fundamental/OSC.jl.png)](https://travis-ci.org/fundamental/OSC.jl)

_OSC.jl_ provides an implementation of the OSC binary format commonly
used in networked control of musical applications.
The code is based on a relatively straightforward translation of
librtosc(https://github.com/fundamental/rtosc)

##Sample Usage

```julia
i::Int32          = 42;             #integer
f::Float32        = 0.25;           #float
s::ASCIIString    = "string";       #string
b                 = s;              #blob
h::Int64          = -125;           #long integer
t::Uint64         = 22412;          #timetag
d::Float64        = 0.125;          #double
S::ASCIIString    = "Symbol";       #symbol
c::Char           = 'J';            #character
r::Int32          = 0x12345678;     #RGBA
m::Array{Uint8,1} = [0x12,0x23,     #midi
0x34,0x45];
#true
#false
#nil
#inf

msg = OscMsg("/dest", "[ifsbhtdScrmTFNI]", i,f,s,b,h,t,d,S,c,r,m);
show(msg)
```

##Networked Usage

Most of the usage is going to involve sending the OSC messages over UDP to
another program.
To do this, first start two julia instances.
In the first one run

```julia
using OSC
sock2 = UdpSocket()
bind(sock2, ip"127.0.0.1", 7777)#should return true
msg2 = OscMsg(recv(sock2))
```

The first instance will now wait for the second to send an OSC message

```julia
using OSC
sock1 = UdpSocket()
msg1 = OSC.message("/hello world", "sSif", "strings", "symbols", 234,
float32(2.3))
send(sock1, ip"127.0.0.1", 7777, msg1.data)
```
To receive a message over port 7778


##TODO

- Port bundle message support from librtosc

##LICENSE

OSC.jl is licensed under the LGPLv3 License

