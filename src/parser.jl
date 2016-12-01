type InsaneParser
    code::String
    i::Int64

    InsaneParser(x::String) = new(x, 1, 1)
end

abstract Token

immutable Atom <: Token
    t::Symbol
    name::String
end

immutable JuliaExpr <: Token
    expr::Any
end

immutable S_Expr <: Token
    head::Symbol
    args::Vector{Token}
end

function parse_expr!(p::InsaneParser)
    c, i = next(p.code, p.i)

    if isnumber(c)
        return parse_number!(p)
    elseif c == ':'
        return parse_symbol!(p)
    elseif c == '\''
        return parse_quote!(p)
    elseif c == '{'
        throw(ParseError("expected '{'"))
    end

    while true
        if c == '('
            return parse_parentheses!(p, i)
        elseif c == '"'
            return parse_quote!(p)
        elseif c == '{'
            return parse_brace!(p)
        elseif isspace(c)
            return parse_atom!(p, i)
        end
        c, i = next(p.code, i)
    end
end

function parse_space!(p::InsaneParser)
    i = p.i
    while true
        c, i = next(p.code, i)
        if isspace(c)
            p.i = i
        else
            return
        end
    end
end

function parse_parentheses!(p::InsaneParser, i::Int64)
    head = p.code[p.i:i-2]
    p.i = i
    c, i = next(p.code, i)
    if 

end

function parse_brace!(p::InsaneParser)
    exp, p.i = parse(p.code, p.i, greedy=false)
    return JuliaExpr(exp)
end

function parse_quote!(p::InsaneParser)
    exp, p.i = parse(p.code, p.i, greedy=false)
    return JuliaExpr(exp)
end

function parse_number!(p::InsaneParser)
    exp, p.i = parse(p.code, p.i, greedy=false)
    return JuliaExpr(exp)
end

function parse_symbol!(p::InsaneParser)
    exp, p.i = parse(p.code, p.i, greedy=false)
    return JuliaExpr(exp)
end

function parse_atom!(p::InsaneParser, i::Int64)
    name = p.code[p.i:i-1]
    # TODO: deal with * and : operator
    atom = if startswith(name, "**")
        Atom(Symbol("**"), check_identifier(name[3:end]))
    elseif startswith(name, '*')
        Atom(Symbol('*'), check_identifier(name[2:end]))
    elseif endswith(name, ':')
        Atom(Symbol(':'), check_identifier(name[2:end]))
    p.i = i
    return atom
end

function check_identifier(x)
    # TODO
    x
end