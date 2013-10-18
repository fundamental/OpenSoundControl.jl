using Base.Test
require("OSC")

test_type = length(ARGS) == 1 ? ARGS[1] : "ALL"


#buffer = Array(Uint8,1024)
#buf_size = rtosc_amessage(buffer, 1024, "/random/address", "sif",
#                          "string", 0xdeadbeef, float32(12.0))
#println()
##println(buffer)
#println(string(map(x->(hex(x,2)), buffer[1:buf_size])...))
#println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), buffer[1:buf_size])...))
#println("argument string is=", rtosc_argument_string(buffer))
#
#println("arg 0=", rtosc_argument(buffer, 0))
#println("arg 1=", rtosc_argument(buffer, 1))
#println("arg 2=", rtosc_argument(buffer, 2))

#Fully check basics
function test_it_fat()
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

    buffer = Array(Uint8, 1024);
    len    = OSC.rtosc_amessage(buffer, 1024, "/dest",
    "[ifsbhtdScrmTFNI]", i,f,s,b,h,t,d,S,c,r,m);

    #println(string(map(x->(hex(x,2)), buffer[1:len])...))
    #println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), buffer[1:len])...))
    #println("argument string is=", rtosc_argument_string(buffer))

    @test OSC.rtosc_argument(buffer, 0)  == i
    @test OSC.rtosc_argument(buffer, 1)  == f
    @test OSC.rtosc_argument(buffer, 2)  == s
    @test OSC.stringify(OSC.rtosc_argument(buffer, 3)) == b
    @test OSC.rtosc_argument(buffer, 4)  == h
    @test OSC.rtosc_argument(buffer, 5)  == t
    @test OSC.rtosc_argument(buffer, 6)  == d
    @test OSC.rtosc_argument(buffer, 7)  == S
    @test OSC.rtosc_argument(buffer, 8)  == c
    @test OSC.rtosc_argument(buffer, 9)  == r
    @test OSC.rtosc_argument(buffer, 10) == m
    @test OSC.rtosc_type(buffer,11) == 'T'
    @test OSC.rtosc_type(buffer,12) == 'F'
    @test OSC.rtosc_type(buffer,13) == 'N'
    @test OSC.rtosc_type(buffer,14) == 'I'
end

function test_it_osc_spec()
    buffer::Array{Uint8} = Array(Uint8, 256)
    println("Starting OSC Spec...")
    message_one::Array{Uint8} = [
    0x2f, 0x6f, 0x73, 0x63,
    0x69, 0x6c, 0x6c, 0x61,
    0x74, 0x6f, 0x72, 0x2f,
    0x34, 0x2f, 0x66, 0x72,
    0x65, 0x71, 0x75, 0x65,
    0x6e, 0x63, 0x79, 0x00,
    0x2c, 0x66, 0x00, 0x00,
    0x43, 0xdc, 0x00, 0x00,
    ];

    message_two::Array{Uint8} = [
    0x2f, 0x66, 0x6f, 0x6f,
    0x00, 0x00, 0x00, 0x00,
    0x2c, 0x69, 0x69, 0x73,
    0x66, 0x66, 0x00, 0x00,
    0x00, 0x00, 0x03, 0xe8,
    0xff, 0xff, 0xff, 0xff,
    0x68, 0x65, 0x6c, 0x6c,
    0x6f, 0x00, 0x00, 0x00,
    0x3f, 0x9d, 0xf3, 0xb6,
    0x40, 0xb5, 0xb2, 0x2d,
    ];

    len=OSC.rtosc_amessage(buffer, 256, "/oscillator/4/frequency", "f", float32(440.0))

    println(string(map(x->(hex(x,2)), buffer[1:len])...))
    println(string(map(x->(hex(x,2)), message_one)...))
    println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), buffer[1:len])...))
    println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), message_one)...))
    @test len == length(message_one)
    @test buffer[1:length(message_one)] == message_one

    len = OSC.rtosc_amessage(buffer, 256, "/foo", "iisff",
                         int32(1000), int32(-1), "hello", float32(1.234), float32(5.678))
    println(string(map(x->(hex(x,2)), buffer[1:len])...))
    println(string(map(x->(hex(x,2)), message_two)...))
    println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), buffer[1:len])...))
    println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), message_two)...))
    @test len == length(message_two)
    @test buffer[1:len] == message_two
end

if test_type in ["ALL", "TEST", "INSTALL"]
    test_it_osc_spec()
    test_it_fat()
end
