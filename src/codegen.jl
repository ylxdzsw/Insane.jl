export add_special_form, codegen!

SF = Dict{Symbol, Tuple{Int, Function}}() # Int is the number that desires. if arg num is less than that, continuation will be passed as the last argument

catch_continuation(::Token) = false
catch_continuation(x::S_Expr) = if SF[x.head][1] > length(x.args) + 1
    throw(ParseError("Too few arguments for $(x.head) expression"))
else
    SF[x.head][1] == length(x.args) + 1
end

macro gen(x)
    :(codegen!($x, scope))
end

function extend(f, scope, sym)
    unshift!(scope, sym)
    try
        f()
    finally
        shift!(scope)
    end
end

codegen!(x::Atom, scope) = all(x->x=='.', x.name) ? scope[length(x.name)] : Symbol(x.name)
codegen!(x::JuliaExpr, scope) = QuoteNode(x.expr)
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
        extend(scope, this) do
            Expr(:->, Expr(:tuple, this), @gen(x[1]))
        end
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
    extend(scope, this) do
        for i in x
            push!(exp.args, Expr(:(=), this, isa(i, Affixed) && i.affix == 0x00 ?
                sf_call(Token[i.token, Atom(".")], scope) : @gen(i)))
        end
    end
    exp
end

function sf_for(x, scope)
    if isa(x[2], Atom) && x[2].name in ("in", "=", "∈")
        Expr(:for, sf_assign(x[[1,3]], scope), sf_begin(x[4:end], scope))
    else
        throw(ParseError("malformed for expression"))
    end
end

function sf_each(x, scope)
    this = gensym()
    body = extend(scope, this) do
        map(x[2:end]) do i
            Expr(:(=), this, isa(i, Affixed) && i.affix == 0x00 ?
                sf_call(Token[i.token, Atom(".")], scope) : @gen(i))
        end
    end
    Expr(:for, Expr(:(=), this, @gen(x[1])), Expr(:block, body...))
end

function sf_while(x, scope)
    Expr(:while, @gen(x[1]), sf_begin(x[2:end], scope))
end

function sf_loop(x, scope)
    unshift!(x, JuliaExpr(true))
    sf_while(x, scope)
end

function sf_try(x, scope)
    e = gensym()
    extend(scope, e) do
        caught = @gen(x[2])
    end
    exp = Expr(:try, @gen(x[1]), e, caught)
    if length(x) == 3
        push!(exp.args, @gen(x[3]))
    end
    exp
end

function sf_cond(x, scope)
    cons(i) = if i+1 > length(x) # default
        @gen(x[i])
    elseif i+1 == length(x) # last
        Expr(:if, @gen(x[i]), @gen(x[i+1]))
    else
        Expr(:if, @gen(x[i]), @gen(x[i+1]), cons(i+2))
    end
    cons(1)
end

function sf_switch(x, scope)
    this = gensym()
    exp  = Expr(:block, Expr(:(=), this, @gen(x[1])))
    unshift!(scope, this)
    comp(x) = if isa(x, Affixed) && x.affix == 0x00
        sf_call(Token[Atom("=="), Atom("."), x.token], scope)
    else
        @gen(x)
    end
    cons(i) = if i+1 > length(x) # default
        @gen(x[i])
    elseif i+1 == length(x) # last
        Expr(:if, comp(x[i]), @gen(x[i+1]))
    else
        Expr(:if, comp(x[i]), @gen(x[i+1]), cons(i+2))
    end
    push!(exp.args, cons(2))
    shift!(scope)
    exp
end

function sf_return_star(x, scope)
    this = gensym()
    Expr(:block, Expr(:(=), this, @gen(x[1])), @gen(x[2]).args..., this)
end

function sf_macrodef(x, scope)
    Expr(:macro, Expr(:call, @gen(x[1]), map(x->@gen(x), x[2].args)...),
                 sf_begin(x[3:end], scope))
end

function sf_macrocall(x, scope)
    Expr(:macrocall, Symbol('@', x[1].name), map(x->@gen(x), x[2:end])...)
end

function sf_and(x, scope)
    cons(i) = if i == length(x)
        @gen(x[i])
    else
        Expr(:&&, @gen(x[i]), cons(i+1))
    end
    cons(1)
end

function sf_or(x, scope)
    cons(i) = if i == length(x)
        @gen(x[i])
    else
        Expr(:||, @gen(x[i]), cons(i+1))
    end
    cons(1)
end

function sf_break(x, scope)
    Expr(:break)
end

function sf_continue(x, scope)
    Expr(:continue)
end

function sf_return(x, scope)
    Expr(:return, length(x) == 0 ? nothing : @gen(x[1]))
end

function sf_type(x, scope)
    gen_type!(x, scope, true)
end

function sf_immutable(x, scope)
    gen_type!(x, scope, false)
end

function sf_abstract(x, scope)
    Expr(:abstract, @gen(x[1]))
end

function sf_range(x, scope)
    Expr(:(:), @gen(x[1]), @gen(x[2]))
end

function sf_local(x, scope)
    Expr(:local, map(x->@gen(x), x)...)
end

function sf_global(x, scope)
    Expr(:global, map(x->@gen(x), x)...)
end

function sf_const(x, scope)
    Expr(:const, sf_assign(x, scope))
end

function sf_module(x, scope)
    Expr(:module, true, @gen(x[1]), @gen(x[2]))
end

function sf_baremodule(x, scope)
    Expr(:module, false, @gen(x[1]), @gen(x[2]))
end

function sf_import(x, scope)
    toplevel(x, scope, :import)
end

function sf_importall(x, scope)
    toplevel(x, scope, :importall)
end

function sf_using(x, scope)
    toplevel(x, scope, :using)
end

function sf_ref(x, scope)
    Expr(:ref, map(x->@gen(x), x)...)
end

function sf_quote(x, scope)
    Expr(:quote, sf_begin(x, scope))
end

add_special_form(t, f, cps=0) = SF[t] = cps, f

add_special_form(Symbol("")        , sf_call)
add_special_form(:function         , sf_function)
add_special_form(:f                , sf_function)
add_special_form(:begin            , sf_begin)
add_special_form(:>                , sf_begin)
add_special_form(:assign           , sf_assign)
add_special_form(:(=)              , sf_assign)
add_special_form(:tuple            , sf_tuple)
add_special_form(Symbol("'")       , sf_tuple)
add_special_form(:let              , sf_let, 3)
add_special_form(:l                , sf_let, 3)
add_special_form(:if               , sf_if)
add_special_form(:?                , sf_if)
add_special_form(:lambda           , sf_lambda)
add_special_form(:λ                , sf_lambda)
add_special_form(:pipe             , sf_pipe)
add_special_form(:.                , sf_pipe)
add_special_form(:for              , sf_for,   4)
add_special_form(:while            , sf_while, 2)
add_special_form(:loop             , sf_loop,  1)
add_special_form(:try              , sf_try)
add_special_form(:cond             , sf_cond)
add_special_form(:switch           , sf_switch)
add_special_form(Symbol("return*") , sf_return_star, 2)
add_special_form(:macrodef         , sf_macrodef)
add_special_form(:macro            , sf_macrodef)
add_special_form(:macrocall        , sf_macrocall)
add_special_form(Symbol("@")       , sf_macrocall)
add_special_form(:and              , sf_and)
add_special_form(:&                , sf_and)
add_special_form(:or               , sf_or)
add_special_form(:|                , sf_or)
add_special_form(:break            , sf_break)
add_special_form(:continue         , sf_continue)
add_special_form(:return           , sf_return)
add_special_form(:type             , sf_type)
add_special_form(:immutable        , sf_immutable)
add_special_form(:abstract         , sf_abstract)
add_special_form(:range            , sf_range)
add_special_form(:(:)              , sf_range)
add_special_form(:local            , sf_local)
add_special_form(:global           , sf_global)
add_special_form(:const            , sf_const)
add_special_form(:def              , sf_const)
add_special_form(:module           , sf_module,     2)
add_special_form(:baremodule       , sf_baremodule, 2)
add_special_form(:import           , sf_import)
add_special_form(:importall        , sf_importall)
add_special_form(:using            , sf_using)
add_special_form(:ref              , sf_ref)
add_special_form(:quote            , sf_quote)
add_special_form(Symbol("`")       , sf_quote)
add_special_form(:each             , sf_each)
