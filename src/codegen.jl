export add_special_form

SF = Dict{Symbol, Tuple{Bool, Function}}()

codegen(x::Atom, scope) = all(x->x=='.', x.name) ? scope[length(x.name)] : Symbol(x.name)
codegen(x::JuliaExpr, scope) = x.expr
codegen(x::S_Expr, scope) = SF[x.head][2](x.args, scope)
codegen(x::Affixed, scope) = error("unexpected " * string(x))
codegen(x::Chained, scope) = Expr(:., codegen(x.base), QuoteNode(Symbol(suffix)))

macro gen(x)
    :(codegen($x, scope))
end

add_special_form(t, f, cps=false) = SF[t] = cps, f

add_special_form(Symbol(""), (x, scope) -> begin
    isempty(x) && error("cannot do empty function call; if you need empty tuple, use `'()`")
    exp = Expr(:call)
    kw  = Expr(:parameters)

    i = 2
    while i <= length(x)
        if isa(x[i], Affixed)
            if x[i].affix == 0x00
                push!(exp.args, Expr(:..., @gen(x[i].token)))
                i += 1
            elseif x[i].affix == 0x01
                push!(kw.args, Expr(:..., @gen(x[i].token)))
                i += 1
            elseif x[i].affix == 0x02
                i+1 > length(x) && throw(ParseError("need argument after " * string(x)))
                push!(kw.args, Expr(:kw, @gen(x[i].token), @gen(x[i+1])))
                i += 2
            else
                error("BUG")
            end
        else
            push!(exp.args, @gen(x[i]))
            i += 1
        end
    end

    !isempty(kw.args) && unshift!(exp.args, kw)
    unshift!(exp.args, @gen(x[1]))
    exp
end)