module OSC
import Base.show
macro incfp(x) quote begin
            local gensym_ = $(esc(x))
            $(esc(x)) = $(esc(x))+1
            gensym_
end end end

type OscMsg
    data::Array{Uint8}
end

function stringify(data::Array{Uint8})
    zeroInd = find(data.== 0)
    if(length(zeroInd) == 0)
        return string(map(char, data)...)
    elseif(zeroInd[1] == 0)
        return nothing
    else
        return string(map(char, data[1:zeroInd[1]-1])...)
    end
end

function names(msg::OscMsg)#::ASCIIString
    pos = 1
    while(msg.data[pos += 1] != 0) end      #skip pattern
    while(msg.data[pos += 1] == 0) end      #skip null
    return stringify(msg.data[pos+1:end]);  #skip comma
end

strip_args(args::ASCIIString) = replace(replace(args,"]",""),"[","")

function narguments(msg::OscMsg)
    length(strip_args(names(msg)))
end

has_reserved(typeChar::Char) = typeChar in "isbfhtdSrmc"
nreserved(args::ASCIIString) = sum(map(has_reserved, collect(args)))

function argType(msg::OscMsg, nargument::Int)#::Char
    @assert(nargument < narguments(msg));
    return strip_args(names(msg))[nargument+1]
end

align(pos) = pos+(4-(pos-1)%4)
function arg_off(msg::OscMsg, idx::Int)#::Int
    if(!has_reserved(argType(msg,idx)))
        return 0;
    end

    #Iterate to the right position
    args::ASCIIString = names(msg);
    argc::Int = 1
    pos::Int  = 1

    #Get past the Argument String
    while(msg.data[pos] != ',') pos += 1 end
    while(msg.data[pos] != 0)   pos += 1 end

    #Alignment
    pos = align(pos)

    #ignore any leading '[' or ']'
    while(args[argc] in "[]") argc += 1 end

    while(idx != 0)
        bundle_length::Uint32 = 0;
        arg = args[argc]
        argc += 1
        if(arg in "htd")
            pos +=8;
        elseif(arg in "mrfci")
            pos += 4;
        elseif(arg in "Ss")
            while(msg.data[pos += 1] != 0) end
            pos = align(pos)
        elseif(arg == 'b')
            bundle_length |= (msg.data[@incfp(pos)] << 24);
            bundle_length |= (msg.data[@incfp(pos)] << 16);
            bundle_length |= (msg.data[@incfp(pos)] << 8);
            bundle_length |= (msg.data[@incfp(pos)]);
            bundle_length += 4-bundle_length%4;
            pos += bundle_length;
        elseif(arg in "[]")#completely ignore array chars
            idx += 1;
        else #TFI
        end
        idx -= 1
    end
    pos;
end

#Calculate the size of the message without writing to a buffer
function vsosc_null(address::ASCIIString,
                    arguments::ASCIIString,
                    args...)
    pos::Int  = length(address)+1
    pos       = align(pos)
    pos      += 1+length(arguments)
    pos       = align(pos)

    arg_pos = 1;

    #Take care of varargs
    for(arg = arguments)
        if(arg in "htd")
            arg_pos += 1
            pos     += 8;
        elseif(arg in "mrcfi")
            arg_pos += 1
            pos     += 4;
        elseif(arg in "sS")
            s::ASCIIString = args[@incfp(arg_pos)];
            pos += length(s);
            pos =  align(pos)
        elseif(arg in "b")
            i::Int32 = sizeof(args[@incfp(arg_pos)])
            pos += 4 + i;
            pos  = align(pos)
        end #other args classes are ignored
    end

    return pos-1;
end

function rtosc_amessage(buffer::Array{Uint8},
                        len::Int,
                        address::ASCIIString,
                        arguments::ASCIIString,
                        args...)
    total_len::Int = vsosc_null(address, arguments, args...);

    for(i=1:total_len)
        buffer[i] = 0
    end

    #Abort if the message cannot fit
    if(total_len>len)
        return 0;
    end

    pos::Int = 1;
    #Address
    for(C = address) buffer[@incfp(pos)] = C end
    pos = align(pos)

    #Arguments
    buffer[@incfp(pos)] = ',';
    for(A=arguments) buffer[@incfp(pos)] = A; end
    pos = align(pos)

    arg_pos::Int = 1;
    for(arg = arguments)
        @assert(arg != 0);
        if(arg in "htd")
            d::Uint64 = reinterpret(Uint64, args[@incfp(arg_pos)]);
            buffer[@incfp(pos)] = ((d>>56) & 0xff);
            buffer[@incfp(pos)] = ((d>>48) & 0xff);
            buffer[@incfp(pos)] = ((d>>40) & 0xff);
            buffer[@incfp(pos)] = ((d>>32) & 0xff);
            buffer[@incfp(pos)] = ((d>>24) & 0xff);
            buffer[@incfp(pos)] = ((d>>16) & 0xff);
            buffer[@incfp(pos)] = ((d>>8) & 0xff);
            buffer[@incfp(pos)] = (d & 0xff);
        elseif(arg in "rfci")
            i::Int32 = reinterpret(Int32, args[@incfp(arg_pos)]);
            buffer[@incfp(pos)] = ((i>>24) & 0xff);
            buffer[@incfp(pos)] = ((i>>16) & 0xff);
            buffer[@incfp(pos)] = ((i>>8) & 0xff);
            buffer[@incfp(pos)] = (i & 0xff);
        elseif(arg in "m")
            m = args[@incfp(arg_pos)];
            buffer[@incfp(pos)] = m[1];
            buffer[@incfp(pos)] = m[2];
            buffer[@incfp(pos)] = m[3];
            buffer[@incfp(pos)] = m[4];
        elseif(arg in "Ss")
            s = args[@incfp(arg_pos)];
            for(C = s)
                buffer[@incfp(pos)] = C
            end
            pos = align(pos)
        elseif(arg == 'b')
            b = args[@incfp(arg_pos)];
            i = sizeof(b);
            buffer[@incfp(pos)] = ((i>>24) & 0xff);
            buffer[@incfp(pos)] = ((i>>16) & 0xff);
            buffer[@incfp(pos)] = ((i>>8) & 0xff);
            buffer[@incfp(pos)] = (i & 0xff);
            for(U = b)
                buffer[@incfp(pos)] = uint8(U);
            end
            pos = align(pos)
        end
    end

    return pos-1;
end

OscMsg(address, arguments, args...) = message(address, arguments, args...)

function message(address::ASCIIString,
                 arguments::ASCIIString,
                 args...)
    len::Int = vsosc_null(address, arguments, args...);
    data::Vector{Uint8} = Array(Uint8, len);
    rtosc_amessage(data,len,address,arguments,args...);
    return OscMsg(data)
end

function rtosc_argument(msg::OscMsg, idx::Int)
    typeChar::Char = argType(msg, idx);
    #trivial case
    if(!has_reserved(typeChar))
        if(typeChar == 'T')
            return true
        elseif(typeChar == 'F')
            return false;
        end
    else
        arg_pos::Int = arg_off(msg, idx)

        if(typeChar in "htd")
            t::Uint64 = 0
            t |= (uint64(msg.data[@incfp(arg_pos)]) << 56);
            t |= (uint64(msg.data[@incfp(arg_pos)]) << 48);
            t |= (uint64(msg.data[@incfp(arg_pos)]) << 40);
            t |= (uint64(msg.data[@incfp(arg_pos)]) << 32);
            t |= (uint64(msg.data[@incfp(arg_pos)]) << 24);
            t |= (uint64(msg.data[@incfp(arg_pos)]) << 16);
            t |= (uint64(msg.data[@incfp(arg_pos)]) << 8);
            t |= (uint64(msg.data[@incfp(arg_pos)]));
            if(typeChar == 'h')
                return int64(t)
            elseif(typeChar == 'd')
                return reinterpret(Float64, t);
            else
                return t;
            end
        elseif(typeChar in "f")
            return reinterpret(Float32,msg.data[arg_pos+(3:-1:0)])[1]
        elseif(typeChar in "rci")
            i::Int32 = 0
            i |= (uint32(msg.data[@incfp(arg_pos)]) << 24);
            i |= (uint32(msg.data[@incfp(arg_pos)]) << 16);
            i |= (uint32(msg.data[@incfp(arg_pos)]) << 8);
            i |= (uint32(msg.data[@incfp(arg_pos)]));
            if(typeChar == 'r')
                return uint32(i)
            elseif(typeChar == 'c')
                return char(i)
            else
                return i
            end
        elseif(typeChar in "m")
            m = Array(Uint8, 4)
            m[1] = msg.data[@incfp(arg_pos)]
            m[2] = msg.data[@incfp(arg_pos)]
            m[3] = msg.data[@incfp(arg_pos)]
            m[4] = msg.data[@incfp(arg_pos)]
            return m
        elseif(typeChar in "b")
            len::Int32 = 0
            len |= (msg.data[@incfp(arg_pos)] << 24);
            len |= (msg.data[@incfp(arg_pos)] << 16);
            len |= (msg.data[@incfp(arg_pos)] << 8);
            len |= (msg.data[@incfp(arg_pos)]);
            return msg.data[arg_pos+(0:len-1)];
        elseif(typeChar in "Ss")
            return stringify(msg.data[arg_pos:end]);
        end
    end

    return nothing;
end

getindex(msg::OscMsg, idx::Int) = rtosc_argument(msg, idx)

function show(io::IO, msg::OscMsg)
    println(io, "OSC Message to ", stringify(msg.data))
    println(io, "    Arguments:");
    for i=1:narguments(msg)
        showField(io, msg,i)
    end
end

function showField(io::IO, msg::OscMsg, arg_id)
    map = ['i' Int32; 'f' Float32; 's' String; 'b' :Blob; 'h' Int32; 't' Uint64;
    'd' Float64; 'S' Symbol; 'c' Char; 'r' :RBG; 'm' :Midi; 'T' true;
    'F' false; 'N' Nothing]
    dict = Dict{Char, Any}(map[:,1][:],map[:,2][:])
    dict['I'] = Inf
    typeChar::Char = argType(msg, arg_id-1)
    value = msg[arg_id-1]
    if(issubtype(typeof(value), Array))
        value = value'
    end
    @printf(io, "    #%2d %c:", arg_id, typeChar);
    print(dict[typeChar]," - ", value)
    if(!issubtype(typeof(value), Array))
        println()
    end

end

export OscMsg

end
