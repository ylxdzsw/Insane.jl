import Base: LineEdit, REPL

#==
Some of this code is derived from Cxx.jl.

> Copyright (c) 2013-2016: Keno Fischer and other contributors
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
==#

function process_line(line)
    try
        QuoteNode(eval(Main, insane(line*"\n")))
    catch e
        print_with_color(:red, STDERR, "ERROR: ", sprint(showerror, e), "\n")
    end
end

function create_insane_REPL(prompt, name, repl=Base.active_repl, main_mode=repl.interface.modes[1])
    mirepl = isdefined(repl,:mi) ? repl.mi : repl
    # Setup insane panel
    panel = LineEdit.Prompt(prompt;
        on_enter = s -> try
            insane(String(LineEdit.buffer(s).data)*"\n")
            true
        catch e
            isa(e, BoundsError) ? false : rethrow(e)
        end)

    panel.on_done = REPL.respond(process_line,repl,panel)

    main_mode == mirepl.interface.modes[1] &&
        push!(mirepl.interface.modes,panel)

    hp = main_mode.hist
    hp.mode_mapping[name] = panel
    panel.hist = hp

    search_prompt, skeymap = LineEdit.setup_search_keymap(hp)
    mk = REPL.mode_keymap(main_mode)

    b = Dict{Any,Any}[skeymap, mk, LineEdit.history_keymap, LineEdit.default_keymap, LineEdit.escape_defaults]
    panel.keymap_dict = LineEdit.keymap(b)
    
    panel
end

function run_insane_REPL(prompt="λ> ", name=:insane, key='<')
    repl = Base.active_repl
    mirepl = isdefined(repl,:mi) ? repl.mi : repl
    main_mode = mirepl.interface.modes[1]

    panel = create_insane_REPL(prompt, name)

    # Install this mode into the main mode
    const insane_keymap = Dict{Any,Any}(
        key => function (s,args...)
            if isempty(s) || position(LineEdit.buffer(s)) == 0
                buf = copy(LineEdit.buffer(s))
                LineEdit.transition(s, panel) do
                    LineEdit.state(s, panel).input_buffer = buf
                end
            else
                LineEdit.edit_insert(s,key)
            end
        end
    )
    main_mode.keymap_dict = LineEdit.keymap_merge(main_mode.keymap_dict, insane_keymap);
    nothing
end
