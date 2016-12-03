type InsaneParser
    code::String
    i::Int64

    InsaneParser(x::String) = new(x, 1)
end

abstract Token

immutable Atom <: Token
    name::String
end

immutable JuliaExpr <: Token
    expr::Any
end

immutable S_Expr <: Token
    head::Symbol
    args::Vector{Token}
end

immutable Affixed <: Token
    affix::UInt8 # 0x00: `*`, 0x01: `**`, 0x02: `:`
    token::Token
end

immutable Chained <: Token
    base::Token
    suffix::String
end

function parse_expr!(p::InsaneParser)
    c, i = next(p.code, p.i)

    if isnumber(c) || c == ':' || c == '\''
        return parse_julia!(p)
    elseif c == '{'
        throw(ParseError("expected '{'"))
    elseif c == '*'
        c, i = next(p.code, i)
        if c == '*'
            p.i += 2
            return Affixed(0x01, parse_expr!(p))
        else
            p.i += 1
            return Affixed(0x00, parse_expr!(p))
        end
    elseif isspace(c)
        throw(ParseError("unexpected space"))
    end

    while true
        if c == '('
            exp = parse_parentheses!(p, i)
            break
        elseif c == '"' || c == '{'
            exp = parse_julia!(p)
            break
        elseif isspace(c) || c == ':' || c == '#' || c == ')'
            exp = parse_atom!(p, i)
            break
        end
        c, i = next(p.code, i)
    end

    done(p.code, p.i) && return exp

    c, i = next(p.code, p.i)
    
    if c == ':'
        if isa(exp, Atom)
            p.i = i
            c, i = next(p.code, i)
            exp = Affixed(0x02, exp)
        else
            throw(ParseError("unexpected ':'"))
        end
    end
    
    isspace(c) || c == ')' || c == '#' ? exp : throw(ParseError("unexpected '$c', spaces are required between expressions"))
end

function parse_space!(p::InsaneParser)
    i = p.i
    while true
        c, i = next(p.code, i)
        if isspace(c)
            p.i = i
        elseif c == '#'
            while c != '\n'
                c, i = next(p.code, i)
            end
        else
            return
        end
    end
end

function parse_parentheses!(p::InsaneParser, i::Int64)
    head = p.code[p.i:i-2]
    p.i = i

    if head == "\$" # embed julia
        try
            p.i -= 1
            return parse_julia!(p)
        catch
            throw(ParseError("invalid embed julia expression. note: only one expression allowed, use begin clause to combine multiple expressions."))
        end
    end

    children = Token[]
    while true
        parse_space!(p)
        c, i = next(p.code, p.i)
        if c == ')'
            p.i = i
            return S_Expr(head, children)
        else
            push!(children, parse_expr!(p))
        end
    end
end

function parse_julia!(p::InsaneParser)
    exp, p.i = parse(p.code, p.i, greedy=false)
    return JuliaExpr(exp)
end

function parse_atom!(p::InsaneParser, i::Int64)
    p.code[p.i:i-2] == "-" && return Atom("-") # special rule for the '-' funciton
    name = replace(p.code[p.i:i-2], '-', '_')
    p.i = i-1

    m = match(r"^([^\.]+|\.+)(\.[^.]+)*$", name)

    m == nothing && throw(ParseError("invalid identifier"))

    exp = Atom(m[1])

    if m[2] != nothing # parse chain
        i = sizeof(m[1]) + 1
        c, i = next(name, i)
        while c == '.'
            start = i
            while !done(name, i)
                c, i = next(name, i)
                if c == '.'
                    break
                end
            end
            exp = Chained(exp, name[start:i-(c=='.'?2:1)])
        end
    end

    return exp
end