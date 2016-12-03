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