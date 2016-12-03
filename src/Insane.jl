module Insane

include("parser.jl")
include("util.jl")
include("codegen.jl")
include("repl.jl")

export @λ_str, insane, @insane_load, add_special_form

macro λ_str(code)
    insane(code)
end

function insane(code)
    parser = InsaneParser(code)
    parse_space!(parser)
    expr = parse_expr!(parser)
    codegen!(expr, [])
end

macro insane_load(path)
    code = open(readstring, joinpath(Base.source_dir(), path))
    insane(code)
end

if isdefined(Base, :active_repl)
    run_insane_REPL()
end

end