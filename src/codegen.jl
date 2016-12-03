export add_special_form

SF = Dict{Symbol, Tuple{Bool, Function}}()

catch_continuation(::Token) = false
catch_continuation(x::S_Expr) = SF[x.head][1]

macro gen(x)
    :(codegen!($x, scope))
end

codegen!(x::Atom, scope) = all(x->x=='.', x.name) ? scope[length(x.name)] : Symbol(x.name)
codegen!(x::JuliaExpr, scope) = x.expr
codegen!(x::Affixed, scope) = error("unexpected " * string(x))
codegen!(x::Chained, scope) = Expr(:., @gen(x.base), QuoteNode(Symbol(x.suffix)))
codegen!(x::Curly, scope) = Expr(:curly, x.head, map(x->@gen(x), x.tail)...)
codegen!(x::S_Expr, scope) = SF[x.head][2](x.args, scope)
codegen!(x::S_Expr, scope, continuation) = begin
    push!(x.args, S_Expr("begin", continuation))
    @gen(x)
end

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

function sf_assign(x, scope)
    Expr(:(=), @gen(x[1]), @gen(x[2]))
end

function sf_tuple(x, scope)
    Expr(:tuple, map(x->@gen(x), x)...)
end

function sf_let(x, scope)
    Expr(:let, @gen(x[3]), sf_assign(x, scope))
end

function sf_if(x, scope)
    Expr(:if, map(x->@gen(x), x)...)
end

function sf_lambda(x, scope)
    if length(x) == 1
        this = gensym()
        unshift!(scope, this)
        body = @gen(x[1])
        shift!(scope)
        Expr(:->, Expr(:tuple, this), body)
    else
        args = []
        for i in x[1].args
            if isa(i, Affixed)
                if i.affix == 0x00
                    push!(arg, Expr(:..., gen_arg!(i.token, scope)))
                elseif i.affix == 0x01 || i.affix == 0x02
                    throw(ParseError("lambda expressions cannot accept keyword arguments"))
                else
                    error("BUG")
                end
            else
                push!(args, gen_arg!(i, scope))
            end
        end
        Expr(:->, Expr(:tuple, args...), @gen(x[2]))
    end
end

function sf_pipe(x, scope)
    this = gensym()
    exp  = Expr(:block, Expr(:(=), this, @gen(shift!(x))))
    unshift!(scope, this)
    for i in x
        push!(exp.args, Expr(:(=), this, @gen(i)))
    end
    shift!(scope)
    exp
end

add_special_form(t, f, cps=false) = SF[t] = cps, f

add_special_form(Symbol("")  , sf_call)
add_special_form(:function   , sf_function)
add_special_form(:f          , sf_function)
add_special_form(:begin      , sf_begin)
add_special_form(:>          , sf_begin)
add_special_form(:assign     , sf_assign)
add_special_form(:(=)        , sf_assign)
add_special_form(:tuple      , sf_tuple)
add_special_form(Symbol("'") , sf_tuple)
add_special_form(:let        , sf_let,    true)
add_special_form(:l          , sf_let,    true)
add_special_form(:if         , sf_if)
add_special_form(:?          , sf_if)
add_special_form(:lambda     , sf_lambda, true)
add_special_form(:λ          , sf_lambda, true)
add_special_form(:pipe       , sf_pipe)
add_special_form(:|          , sf_pipe)