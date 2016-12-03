export add_special_form

SF = Dict{Symbol, Tuple{Bool, Function}}()

catch_continuation(::Token) = false
catch_continuation(x::S_Expr) = SF[x.head][1]

codegen!(x::Atom, scope) = all(x->x=='.', x.name) ? scope[length(x.name)] : Symbol(x.name)
codegen!(x::JuliaExpr, scope) = x.expr
codegen!(x::Affixed, scope) = error("unexpected " * string(x))
codegen!(x::Chained, scope) = Expr(:., codegen!(x.base), QuoteNode(Symbol(suffix)))
codegen!(x::Curly, scope) = Expr(:curly, x.head, map(x->codegen!(x, scope), x.tail)...)
codegen!(x::S_Expr, scope) = SF[x.head][2](x.args, scope)
codegen!(x::S_Expr, scope, continuation) = begin
    push!(x.args, S_Expr("begin", continuation))
    codegen!(x, scope)
end

macro gen(x)
    :(codegen!($x, scope))
end

add_special_form(t, f)    = SF[t] = false, f
add_special_form(t, c, f) = SF[t] = c, f

function sf_call(x, scope)
    isempty(x) && error("cannot do empty function call; if you need empty tuple, use `'()`")
    exp = Expr(:call)
    kw  = Expr(:parameters)

    i = 2
    while i <= length(x)
        if isa(x[i], Affixed)
            if x[i].affix == 0x00
                push!(exp.args, Expr(:..., @gen(x[i].token)))
            elseif x[i].affix == 0x01
                push!(kw.args, Expr(:..., @gen(x[i].token)))
            elseif x[i].affix == 0x02
                i+1 > length(x) && throw(ParseError("need argument after " * string(x[i])))
                push!(kw.args, Expr(:kw, @gen(x[i].token), @gen(x[i+1])))
                i += 1
            else
                error("BUG")
            end
        else
            push!(exp.args, @gen(x[i]))
        end
        i += 1
    end

    !isempty(kw.args) && unshift!(exp.args, kw)
    unshift!(exp.args, @gen(x[1]))
    exp
end

function sf_function(x, scope)
    exp = Expr(:function, Expr(:call))
    args = exp.args[1].args

    push!(args, @gen(shift!(x)))

    arg, kw, i = [], [], 1
    tokens = shift!(x).args
    while i <= length(tokens)
        a = tokens[i]
        if isa(a, Affixed)
            if a.affix == 0x00
                push!(arg, Expr(:..., gen_arg!(a.token, scope)))
            elseif a.affix == 0x01
                push!(kw, Expr(:..., gen_arg!(a.token, scope)))
            elseif a.affix == 0x02
                i+1 > length(tokens) && throw(ParseError("need argument after " * string(a)))
                b = tokens[i+1]
                unshift!(b.args, a.token)
                push!(kw, gen_arg!(b, scope))
                i += 1
            else
                error("BUG")
            end
        else
            push!(arg, gen_arg!(a, scope))
        end
        i += 1
    end

    if !isempty(kw)
        push!(args, Expr(:parameters, kw...))
    end

    append!(args, arg)

    push!(exp.args, sf_begin(x, scope))

    exp
end

function sf_begin(x, scope)
    exp = Expr(:block)
    while !isempty(x)
        i = shift!(x)
        if catch_continuation(i)
            push!(exp.args, codegen!(i, scope, x))
            break
        else
            push!(exp.args, codegen!(i, scope))
        end
    end
    exp
end

add_special_form(Symbol("") , sf_call)
add_special_form(:function  , sf_function)
add_special_form(:f         , sf_function)
add_special_form(:begin     , sf_begin)
add_special_form(:>         , sf_begin)