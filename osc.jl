macro incfp(x) quote begin
            local gensym_ = $(esc(x))
            $(esc(x)) = $(esc(x))+1
            gensym_
end end end

stringify(data::Array{Uint8}) = string(map(x->char(x), data[1:min(find(data.== 0))])...)

function rtosc_argument_string(msg::Array{Uint8})#::ASCIIString
    pos = 1
    while(msg[pos += 1] != 0) end      #skip pattern
    while(msg[pos += 1] == 0) end      #skip null
    return stringify(msg[pos+1:end]);  #skip comma
end

strip_args(args::ASCIIString) = replace(replace(args,"]",""),"[","")

function rtosc_narguments(msg::Array{Uint8})
    length(strip_args(rtosc_argument_string(msg)))
end

has_reserved(typeChar::Char) = typeChar in "isbfhtdSrmc"
nreserved(args::ASCIIString) = sum(map(has_reserved, collect(args)))

function rtosc_type(msg::Array{Uint8}, nargument::Int)#::Char
    @assert(nargument < rtosc_narguments(msg));
    return strip_args(rtosc_argument_string(msg))[nargument+1]
end


function arg_off(msg::Array{Uint8}, idx::Int)#::Int
    if(!has_reserved(rtosc_type(msg,idx)))
        return 0;
    end

    #Iterate to the right position
    args::ASCIIString = rtosc_argument_string(msg);
    argc::Int = 1
    pos::Int  = 1

    #Get past the Argument String
    while(msg[pos] != ',') pos += 1 end
    while(msg[pos] != 0)   pos += 1 end

    #Alignment
    pos += 4-pos%4;

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
            while(msg[pos += 1] != 0) end
            pos += 4-pos%4;
        elseif(arg == 'b')
            bundle_length |= (msg[@incfp(pos)] << 24);
            bundle_length |= (msg[@incfp(pos)] << 16);
            bundle_length |= (msg[@incfp(pos)] << 8);
            bundle_length |= (msg[@incfp(pos)]);
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
    pos::Int  = length(address)
    pos      += 4-pos%4#get 32 bit alignment
    pos      += 1+length(arguments)
    pos      += 4-pos%4

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
            pos += 4-pos%4;
        elseif(arg in "b")
            i::Int32 = sizeof(args[@incfp(arg_pos)])
            pos += 4 + i;
            pos += 4-pos%4;
        end #other args classes are ignored
    end

    return pos;
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
    pos += 4-pos%4;#get 32 bit alignment

    #Arguments
    buffer[@incfp(pos)] = ',';
    for(A=arguments) buffer[@incfp(pos)] = A; end
    pos += 4-pos%4;

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
            pos += 4-pos%4;
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
            pos += 4-pos%4;
        end
    end

    return pos;
end

function rtosc_argument(msg::Array{Uint8}, idx::Int)
    typeChar::Char = rtosc_type(msg, idx);
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
            t |= (uint64(msg[@incfp(arg_pos)]) << 56);
            t |= (uint64(msg[@incfp(arg_pos)]) << 48);
            t |= (uint64(msg[@incfp(arg_pos)]) << 40);
            t |= (uint64(msg[@incfp(arg_pos)]) << 32);
            t |= (uint64(msg[@incfp(arg_pos)]) << 24);
            t |= (uint64(msg[@incfp(arg_pos)]) << 16);
            t |= (uint64(msg[@incfp(arg_pos)]) << 8);
            t |= (uint64(msg[@incfp(arg_pos)]));
            if(typeChar == 'h')
                return int64(t)
            elseif(typeChar == 'd')
                return reinterpret(Float64, t);
            else
                return t;
            end
        elseif(typeChar in "f")
            return reinterpret(Float32,msg[arg_pos+(3:-1:0)])[1]
        elseif(typeChar in "rci")
            i::Int32 = 0
            i |= (uint32(msg[@incfp(arg_pos)]) << 24);
            i |= (uint32(msg[@incfp(arg_pos)]) << 16);
            i |= (uint32(msg[@incfp(arg_pos)]) << 8);
            i |= (uint32(msg[@incfp(arg_pos)]));
            if(typeChar == 'r')
                return uint32(i)
            elseif(typeChar == 'c')
                return char(i)
            else
                return i
            end
        elseif(typeChar in "m")
            m = Array(Uint8, 4)
            m[1] = msg[@incfp(arg_pos)]
            m[2] = msg[@incfp(arg_pos)]
            m[3] = msg[@incfp(arg_pos)]
            m[4] = msg[@incfp(arg_pos)]
            return m
        elseif(typeChar in "b")
            len::Int32 = 0
            len |= (msg[@incfp(arg_pos)] << 24);
            len |= (msg[@incfp(arg_pos)] << 16);
            len |= (msg[@incfp(arg_pos)] << 8);
            len |= (msg[@incfp(arg_pos)]);
            return msg[arg_pos+(0:len-1)];
        elseif(typeChar in "Ss")
            return stringify(msg[arg_pos:end]);
        end
    end

    return Nothing;
end

buffer = Array(Uint8,1024)
buf_size = rtosc_amessage(buffer, 1024, "/random/address", "sif",
                          "string", 0xdeadbeef, float32(12.0))
println()
#println(buffer)
println(string(map(x->(hex(x,2)), buffer[1:buf_size])...))
println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), buffer[1:buf_size])...))
println("argument string is=", rtosc_argument_string(buffer))

println("arg 0=", rtosc_argument(buffer, 0))
println("arg 1=", rtosc_argument(buffer, 1))
println("arg 2=", rtosc_argument(buffer, 2))

#Fully check basics
function test_it()
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
    len    = rtosc_amessage(buffer, 1024, "/dest",
    "[ifsbhtdScrmTFNI]", i,f,s,b,h,t,d,S,c,r,m);

    println(string(map(x->(hex(x,2)), buffer[1:len])...))
    println(string(map(x->(isprint(char(x&0x7f)) ? string(char(x&0x7f)," ") : ". "), buffer[1:len])...))
    println("argument string is=", rtosc_argument_string(buffer))

    println()
    println("---------------i-------------------");
    println(rtosc_argument(buffer, 0),   " | ", i);
    println("---------------f-------------------");
    println(rtosc_argument(buffer, 1),   " | ", f);
    println("---------------s-------------------");
    println(rtosc_argument(buffer, 2),   " | ", s);
    println("---------------b-------------------");
    println(rtosc_argument(buffer, 3)',  " | ", b);
    println("---------------h-------------------");
    println(rtosc_argument(buffer, 4),   " | ", h);
    println("---------------t-------------------");
    println(rtosc_argument(buffer, 5),   " | ", t);
    println("---------------d-------------------");
    println(rtosc_argument(buffer, 6),   " | ", d);
    println("---------------S-------------------");
    println(rtosc_argument(buffer, 7),   " | ", S);
    println("---------------c-------------------");
    println(rtosc_argument(buffer, 8),   " | ", c);
    println("---------------r-------------------");
    println(rtosc_argument(buffer, 9),   " | ", r);
    println("---------------m-------------------");
    println(rtosc_argument(buffer, 10)', " | ", m')
    println("---------------T-------------------");
    println(rtosc_type(buffer,11), " T");
    println("---------------F-------------------");
    println(rtosc_type(buffer,12), " F");
    println("---------------N-------------------");
    println(rtosc_type(buffer,13), " N");
    println("---------------I-------------------");
    println(rtosc_type(buffer,14), " I");
end

test_it()
