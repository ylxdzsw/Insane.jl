import Base: string

string(x::Affixed) = x.affix == 0x00 ? "*$(x.token)" :
                     x.affix == 0x01 ? "**$(x.token)" :
                     x.affix == 0x02 ? "$(x.token):" :
                     error("bug")
