#OSC.jl
#Copyright (c) 2014, Mark McCurry, All rights reserved.
#
#This library is free software; you can redistribute it and/or
#modify it under the terms of the GNU Lesser General Public
#License as published by the Free Software Foundation; either
#version 3.0 of the License, or (at your option) any later version.
#
#This library is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#Lesser General Public License for more details.
#
#You should have received a copy of the GNU Lesser General Public
#License along with this library.


using Base.Test
require("OSC")
using OSC

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

    msg = OscMsg("/dest", "[ifsbhtdScrmTFNI]", i,f,s,b,h,t,d,S,c,r,m);
    show(msg)

    #println(string(map(x->(hex(x,2)), buffer[1:len])...))
    #println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), buffer[1:len])...))
    #println("argument string is=", rtosc_argument_string(buffer))

    @test msg[1]  == i
    @test msg[2]  == f
    @test msg[3]  == s
    @test OSC.stringify(msg[4]) == b
    @test msg[5]  == h
    @test msg[6]  == t
    @test msg[7]  == d
    @test msg[8]  == S
    @test msg[9]  == c
    @test msg[10]  == r
    @test msg[11] == m
    @test OSC.argType(msg,12) == 'T'
    @test OSC.argType(msg,13) == 'F'
    @test OSC.argType(msg,14) == 'N'
    @test OSC.argType(msg,15) == 'I'
end

function test_it_osc_spec()
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
    0x2f, 0x66, 0x6f, 0x6f, #4
    0x00, 0x00, 0x00, 0x00, #8
    0x2c, 0x69, 0x69, 0x73,
    0x66, 0x66, 0x00, 0x00, #16
    0x00, 0x00, 0x03, 0xe8,
    0xff, 0xff, 0xff, 0xff,
    0x68, 0x65, 0x6c, 0x6c,
    0x6f, 0x00, 0x00, 0x00, #32
    0x3f, 0x9d, 0xf3, 0xb6, #36
    0x40, 0xb5, 0xb2, 0x2d, #40
    ];

    osc=OscMsg("/oscillator/4/frequency", "f", float32(440.0))

    println(string(map(x->(hex(x,2)), osc.data)...))
    println(string(map(x->(hex(x,2)), message_one)...))
    println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), osc.data)...))
    println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), message_one)...))
    @test length(osc.data) == length(message_one)
    @test osc.data == message_one
    show(osc)

    osc = OscMsg("/foo", "iisff", int32(1000), int32(-1), "hello", float32(1.234), float32(5.678))
    println(string(map(x->(hex(x,2)), osc.data)...))
    println(string(map(x->(hex(x,2)), message_two)...))
    println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ".  "), osc.data)...))
    println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), message_two)...))
    @test length(osc.data) == length(message_two)
    @test osc.data == message_two
    show(osc)
end

if test_type in ["ALL", "TEST", "INSTALL"]
    test_it_osc_spec()
    test_it_fat()
    println("Done...")
end
