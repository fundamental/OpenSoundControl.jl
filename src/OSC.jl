# OSC.jl
# Copyright (c) 2018, Mark McCurry, All rights reserved.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3.0 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.

module OSC

using Base.Printf
import Base: show, getindex
export OscMsg, path

macro incfp(x) quote begin
            local gensym_ = $(esc(x))
            $(esc(x)) = $(esc(x))+1
            gensym_
end end end

struct OscMsg
    data::Array{UInt8}
end

path(msg::OscMsg) = stringify(msg.data)

function stringify(data::Array{UInt8})
    zeroInd = findall(data.== 0)
    if length(zeroInd) == 0
        return string(map(Char, data)...)
    elseif zeroInd[1] == 0
        return nothing
    else
        return string(map(Char, data[1:zeroInd[1]-1])...)
    end
end

function names(msg::OscMsg) #::String
    pos = 1
    while(msg.data[pos += 1] != 0) end      #skip pattern
    while(msg.data[pos += 1] == 0) end      #skip null
    return stringify(msg.data[pos+1:end])   #skip comma
end

strip_args(args::AbstractString) = replace(replace(args,"]"=>""),"["=>"")

function narguments(msg::OscMsg)
    length(strip_args(names(msg)))
end

has_reserved(typeChar::Char) = typeChar in "isbfhtdSrmc"
nreserved(args::String) = sum(map(has_reserved, collect(args)))

function argType(msg::OscMsg, nargument::Int) #::Char
    @assert(nargument > 0 && nargument <= narguments(msg))
    return strip_args(names(msg))[nargument]
end

align(pos) = pos+(4-(pos-1)%4)
function arg_off(msg::OscMsg, idx::Int) #::Int
    if(!has_reserved(argType(msg,idx)))
        return 0
    end

    # Iterate to the right position
    args::String = names(msg)
    argc::Int = 1
    pos::Int  = 1

    # Get past the Argument String
    while(msg.data[pos] != UInt8(',')) pos += 1 end
    while(msg.data[pos] != 0)   pos += 1 end

    # Alignment
    pos = align(pos)

    # ignore any leading '[' or ']'
    while(args[argc] in "[]") argc += 1 end

    while(idx != 1)
        bundle_length::UInt32 = 0
        arg = args[argc]
        argc += 1
        if arg in "htd"
            pos +=8
        elseif(arg in "mrfci")
            pos += 4
        elseif(arg in "Ss")
            while(msg.data[pos += 1] != 0) end
            pos = align(pos)
        elseif arg == 'b'
            bundle_length |= (msg.data[@incfp(pos)] << 24)
            bundle_length |= (msg.data[@incfp(pos)] << 16)
            bundle_length |= (msg.data[@incfp(pos)] << 8)
            bundle_length |= (msg.data[@incfp(pos)])
            bundle_length += 4-bundle_length%4
            pos += bundle_length
        elseif(arg in "[]") # completely ignore array chars
            idx += 1
        else # TFI
        end
        idx -= 1
    end
    pos
end

# Calculate the size of the message without writing to a buffer
function vsosc_null(address::String,
                    arguments::String,
                    args...)
    pos::Int  = length(address) + 1
    pos       = align(pos)
    pos      += 1+length(arguments)
    pos       = align(pos)

    arg_pos = 1

    # Take care of varargs
    for arg in arguments
        if arg in "htd"
            arg_pos += 1
            pos     += 8
        elseif arg in "mrcfi"
            arg_pos += 1
            pos     += 4
        elseif arg in "sS"
            s::String = args[@incfp(arg_pos)]
            pos += length(s)
            pos =  align(pos)
        elseif arg in "b"
            i::Int32 = sizeof(args[@incfp(arg_pos)])
            pos += 4 + i
            pos  = align(pos)
        end # other args classes are ignored
    end

    return pos - 1
end

function rtosc_amessage(buffer::Array{UInt8},
                        len::Int,
                        address::String,
                        arguments::String,
                        args...)
    total_len::Int = vsosc_null(address, arguments, args...)

    for i=1:total_len
        buffer[i] = 0
    end

    # Abort if the message cannot fit
    if total_len > len
        return 0
    end

    pos::Int = 1
    #Address
    for C in address
        buffer[@incfp(pos)] = C
    end
    pos = align(pos)

    #Arguments
    buffer[@incfp(pos)] = UInt8(',')
    for A in arguments
        buffer[@incfp(pos)] = A
    end
    pos = align(pos)

    arg_pos::Int = 1
    for arg in arguments
        @assert(UInt32(arg) != 0)
        if arg in "htd"
            d::UInt64 = reinterpret(UInt64, args[@incfp(arg_pos)])
            buffer[@incfp(pos)] = ((d>>56) & 0xff)
            buffer[@incfp(pos)] = ((d>>48) & 0xff)
            buffer[@incfp(pos)] = ((d>>40) & 0xff)
            buffer[@incfp(pos)] = ((d>>32) & 0xff)
            buffer[@incfp(pos)] = ((d>>24) & 0xff)
            buffer[@incfp(pos)] = ((d>>16) & 0xff)
            buffer[@incfp(pos)] = ((d>>8) & 0xff)
            buffer[@incfp(pos)] = (d & 0xff)
        elseif arg in "rfci"
            i::Int32 = reinterpret(Int32, args[@incfp(arg_pos)])
            buffer[@incfp(pos)] = ((i>>24) & 0xff)
            buffer[@incfp(pos)] = ((i>>16) & 0xff)
            buffer[@incfp(pos)] = ((i>>8) & 0xff)
            buffer[@incfp(pos)] = (i & 0xff)
        elseif arg in "m"
            m = args[@incfp(arg_pos)]
            buffer[@incfp(pos)] = m[1]
            buffer[@incfp(pos)] = m[2]
            buffer[@incfp(pos)] = m[3]
            buffer[@incfp(pos)] = m[4]
        elseif arg in "Ss"
            s = args[@incfp(arg_pos)]
            for C in s
                buffer[@incfp(pos)] = C
            end
            pos = align(pos)
        elseif arg == 'b'
            b = args[@incfp(arg_pos)]
            i = sizeof(b)
            buffer[@incfp(pos)] = ((i>>24) & 0xff)
            buffer[@incfp(pos)] = ((i>>16) & 0xff)
            buffer[@incfp(pos)] = ((i>>8) & 0xff)
            buffer[@incfp(pos)] = (i & 0xff)
            for U in b
                buffer[@incfp(pos)] = UInt8(U)
            end
            pos = align(pos)
        end
    end

    return pos - 1
end

OscMsg(address, arguments, args...) = message(address, arguments, args...)

function message(address::String,
                 arguments::String,
                 args...)
    len::Int = vsosc_null(address, arguments, args...)
    data::Vector{UInt8} = Array{UInt8}(undef, len)
    rtosc_amessage(data,len,address,arguments,args...)
    return OscMsg(data)
end

function rtosc_argument(msg::OscMsg, idx::Int)
    typeChar::Char = argType(msg, idx)
    # trivial case
    if(!has_reserved(typeChar))
        if typeChar == 'T'
            return true
        elseif typeChar == 'F'
            return false
        end
    else
        arg_pos::Int = arg_off(msg, idx)

        if typeChar in "htd"
            t::UInt64 = 0
            t |= (UInt64(msg.data[@incfp(arg_pos)]) << 56)
            t |= (UInt64(msg.data[@incfp(arg_pos)]) << 48)
            t |= (UInt64(msg.data[@incfp(arg_pos)]) << 40)
            t |= (UInt64(msg.data[@incfp(arg_pos)]) << 32)
            t |= (UInt64(msg.data[@incfp(arg_pos)]) << 24)
            t |= (UInt64(msg.data[@incfp(arg_pos)]) << 16)
            t |= (UInt64(msg.data[@incfp(arg_pos)]) << 8)
            t |= (UInt64(msg.data[@incfp(arg_pos)]))
            if typeChar == 'h'
                return reinterpret(Int64, t)
            elseif typeChar == 'd'
                return reinterpret(Float64, t)
            else
                return t
            end
        elseif typeChar in "f"
            return read(IOBuffer(msg.data[arg_pos.+(3:-1:0)]), Float32)
        elseif typeChar in "rci"
            i::UInt32 = 0
            i |= (UInt32(msg.data[@incfp(arg_pos)]) << 24)
            i |= (UInt32(msg.data[@incfp(arg_pos)]) << 16)
            i |= (UInt32(msg.data[@incfp(arg_pos)]) << 8)
            i |= (UInt32(msg.data[@incfp(arg_pos)]))
            if typeChar == 'r'
                return UInt32(i)
            elseif typeChar == 'c'
                return Char(i/(2^24))
            else
                return reinterpret(Int32, i)
            end
        elseif typeChar in "m"
            m = Array{UInt8}(undef, 4)
            m[1] = msg.data[@incfp(arg_pos)]
            m[2] = msg.data[@incfp(arg_pos)]
            m[3] = msg.data[@incfp(arg_pos)]
            m[4] = msg.data[@incfp(arg_pos)]
            return m
        elseif typeChar in "b"
            len::Int32 = 0
            len |= (msg.data[@incfp(arg_pos)] << 24)
            len |= (msg.data[@incfp(arg_pos)] << 16)
            len |= (msg.data[@incfp(arg_pos)] << 8)
            len |= (msg.data[@incfp(arg_pos)])
            return msg.data[arg_pos.+(0:len-1)]
        elseif typeChar in "Ss"
            return stringify(msg.data[arg_pos:end])
        end
    end

    return nothing
end

getindex(msg::OscMsg, idx::Int) = rtosc_argument(msg, idx)

function show(io::IO, msg::OscMsg)
    println(io, "OSC Message to ", stringify(msg.data))
    println(io, "    Arguments:")
    for i=1:narguments(msg)
        showField(io, msg,i)
    end
end

function showField(io::IO, msg::OscMsg, arg_id)
    map = Any['i' Int32;
           'f' Float32;
           's' String;
           'b' :Blob;
           'h' Int32;
           't' UInt64;
           'd' Float64;
           'S' Symbol;
           'c' Char;
           'r' :RBG;
           'm' :Midi;
           'T' true;
           'F' false;
           'I' Inf;
           'N' Void]
    dict = Dict{Char, Any}(zip(Vector{Char}(map[:,1][:]),map[:,2][:]))
    typeChar::Char = argType(msg, arg_id)
    value = msg[arg_id]
    if typeof(value) <: Array
        value = value'
    end
    if(value == nothing)
        value = "nothing"
    end
    @printf(io, "    #%2d %c:", arg_id, typeChar)
    println(dict[typeChar]," - ", value)
end


end
