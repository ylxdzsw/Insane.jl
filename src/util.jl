import Base: string

string(x::Affixed) = x.affix == 0x00 ? "*$(x.token)" :
                     x.affix == 0x01 ? "**$(x.token)" :
                     x.affix == 0x02 ? "$(x.token):" :
                     error("bug")

gen_arg!(x::Atom, scope) = codegen!(x, scope)
gen_arg!(x::S_Expr, scope) = if length(x.args) == 2
    Expr(:(::), codegen!(x.args[1], scope), codegen!(x.args[2], scope))
elseif length(x.args) == 3
    default = pop!(x.args)
    Expr(:kw, gen_arg!(x, scope), codegen!(default, scope))
else
    throw(ParseError("malformed function arg"))
end

gen_type!(x, scope, mutable) = begin
    Expr(:type, mutable, if isa(x[1], S_Expr)
        Expr(:<:, map(x->codegen!(x, scope), x[1].args)...)
    else
        codegen!(x[1], scope)
    end, Expr(:block, map(x->begin
        (isa(x, Atom) || isa(x, S_Expr) && x.head == Symbol("") ? gen_arg! : codegen!)(x, scope)
    end, x[2:end])...))
end

dispatch_pipe!(x, scope, this) = if isa(x, Affixed) && x.affix == 0x00
    Expr(:(=), this, sf_call(Token[x.token, Atom(".")], scope))
elseif isa(x, Affixed) && x.affix == 0x01
    if isa(x.token, Affixed) && x.token.affix == 0x00
        sf_call(Token[x.token.token, Atom(".")], scope)
    else
        codegen!(x.token, scope)
    end
else
    Expr(:(=), this, codegen!(x, scope))
end

flat_chain(x::Atom, scope) = [codegen!(x, scope)]
flat_chain(x::Chained, scope) = begin
    p = flat_chain(x.base, scope)
    push!(p, Symbol(x.suffix))
end

toplevel(x, scope, key) = if isa(x[1], Affixed) && x[1].affix == 0x02
    prefix = codegen!(x[1].token, scope)
    Expr(:toplevel, map(x->begin
        Expr(key, prefix, codegen!(x, scope))
    end, x[2:end])...)
else
    Expr(:toplevel, map(x->begin
        Expr(key, flat_chain(x, scope)...)
    end, x)...)
end