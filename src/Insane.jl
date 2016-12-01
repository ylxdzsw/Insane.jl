module Insane

include("parser.jl")

export λ_str, insane

macro λ_str(code) end

function insane(code)
    parser = InsaneParser(code)
    parse_space!(parser)
    expr = parse_expr!(parser)
end

end