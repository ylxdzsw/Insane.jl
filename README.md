Insane.jl
=========

## Installation

```
Pkg.clone("https://github.com/ylxdzsw/Insane.jl", "Insane")
```

## Usage

### inline into julia

```
using Insane

λ"""
(println "hey I'm insane!")
"""
```

### load external source file

```
using Insane

insane_load("relative/path/to/file.insane")
```

### REPL

Press `<` to enter Insane REPL. Note it won't exit automatically, press backspace to return to julia REPL.

## Language reference

### function call

An s-expr is a function call

```
(foo)           # foo()
(foo bar)       # foo(bar)
(foo bar: bar)  # foo(bar=bar)
(foo *bar)      # foo(bar...)
(foo **bar)     # foo(;bar...)
```

### function definition

```
function(foo (x) (+ x 1))  # function foo(x) x+1 end
f(foo (x *y **z) nothing)  # function foo(x, y...; z...) nothing end
f(foo{T} ((x T)) nothing)  # function foo{T}(x::T) nothing end
f(foo ((x Int 4) y: (Any 1) z: (Any (+ y 1))) nothing)
# function foo(x::Int=4; y::Any=1, z::Any=y+1) nothing end
```

### begin clause

```
begin((foo) bar)  # begin foo(); bar end
>((foo) bar)      # alias of begin
```

### assignment

```
assign(foo bar)  # foo = bar
=((a b) x)       # a,b = x
```

### tuple

tuples are so common that I made it a special form; it's almost equivilent to write `(Tuple foo bar)`

```
tuple(foo bar)  # (foo, bar)
'(foo bar)      # alias of tuple
```

### let (auto cps)

```
let(foo bar (baz foo))

===

let foo = bar
   baz(foo)
end
```

if only two arguments provided, all following expressions will be treat as the third argument.

```
>(
   l(foo bar)
   l(foo (baz foo))
   (baz foo)
)

===

begin
   let foo = bar
      let foo = baz(foo)
	      baz(foo)
	  end
   end
end
```

### if

```
if(cond true false)  # if cond true else false end
?(cond true)         # if cond true end, ? is alias of if
```

### lambda (auto assign)

```
lambda((split . '\n'))  # x -> split(x, '\n')
λ(() 2)                 # () -> 2
```

### pipe (auto assign) (vararg)

```
pipe(foo (split . '\n') (parse Int .) (+ . 4))  # parse(Int, split(foo, '\n')) + 4
.(foo (+ ..left ..right *.))                    # tmp = foo; +(tmp.left, tmp.right, tmp...)
.(foo *bar *(higher-order factory))             # *foo is equal to (foo .)
```

### for (auto cps) (vararg)

```
for(i in :(1 5) (foo i))  # for i in 1:5 foo(i) end
```

`in` can be replaced by `=` or `∈`

### each (auto cps) (auto assign) (vararg)

```
each(foo a b c)  # abbr for `for(tmp in foo .(tmp a b c))`
```

### while (auto cps) (vararg)

```
while((< i 2) =(i (+ i 1)))  # while i < 2 i = i+1 end
loop((foo) (bar))            # while true foo(); bar() end
```

### try (auto assign)

```
try(uncertainty caught anyway)  # try uncertainty catch caught finally anyway end
try(uncertainty (showerror .))  # try uncertainty catch e showerr(e) end
try(uncertainty >() (close x))  # try uncertainty finally close(x) end
```

exception object will be assigned to `.`

### cond

```
cond(cond1 act1 cond2 act2 ...)
```

if provide odd number of arguments, last argument will be treated as default action

### switch (auto assign)

```
switch(var exp1 action1 *val2 action2 ...)
```

`*val` is a short hand for `(== . val)`

`.` will be set to `var` in both vals and actions. 

if provide odd number of arguments, last argument will be treated as default action

### return* (auto cps)

```
>(
	return*(=(x (Dict)))
	(setindex! x value key)
)

===

begin
	tmp = x = Dict()
	x[key] = value
	tmp
end
```

### macro definition

```
macro(foo (x) `((+ 1 x)))  # macro foo(x) :(1+x) end
```

### macro call

```
@(printf "mo%d" 39)  # @printf("mo%d", 39)
```

### and, or (vararg)

logic operation with early stopping

```
and(foo bar)  # foo && bar
&(foo bar)    # foo && bar
or(foo bar)   # foo || bar
|(foo bar)    # foo || bar
```

### break, continue, return

```
break()
continue()
return(foo)
```

### type, immutable, abstract

```
type((Foo Super) (x Int) (y Dict{Int, Float64}))
immutable(Bar x f(Bar () (new 1)))
abstract(Foo)
```

### number literals

Just like julia. Actually they are parsed by julia parser :)

### string

```
"this is just a string\n"
r"and str macros"
"$("interpolations") just $works"
```

note: expressions inside interpolations are in *julia*

### range

almost equivalent to write `(colon foo bar)`

```
:(2 3)  # 2:3
```

### embed julia

```
julia(for i in :(1 3) println(i) end)
$(continue)
```

note: only *one* julia expression per $(), use begin clause to combine multiple expressions if nessecery

### type arg

```
(Dict{Int Int} '('(2 3) '(3 4)))  # Dict{Int, Int}(((2,3), (3,4)))
```

### local, global

```
local((foo Int) bar)  # local foo::Int, bar
global(foo bar baz)   # global foo, bar, baz
```

### const

```
const(foo 2)   # const foo = 2
def(foo (bar)) # const foo = bar()
```

### module (auto cps)

```
module(Foo =(x 1))        # module Foo x=1 end
baremodule(Bar def(x 2))  # module Bar const x=2 end
```

### import, importall, using (vararg)

```
import(Base)             # import Base
import(Base.== Base.!=)  # import Base.==, Base.!=
import(Base: == !=)      # import Base: ==, !=
importall(Base)          # importall Base
importall(Base.Meta)     # importall Base.Meta
importall(Base: Meta)    # importall Base.Meta
using(Base)              # using Base
using(Base.Meta)         # using Base.Meta
using(Base: Meta)        # using Base: Meta
```

### ref (auto assign) (vararg)

```
ref(foo :(2 end))  # foo[2:end]
ref(foo (.> . 2))  # foo[foo .> 2]
ref(Int 2 3 4 5)   # Int[2,3,4,5]
```

### quote (vararg)

```
`(=(foo bar))  # :(foo = bar)
```

### identifier

identifier can be any sequence of unicode except those:

1. starting with `[0-9]` or `'` or `*`
2. including spaces or `(` or `"` or `{` or `.` or `:`

all `-` in identifiers will be translated to `_`, thus `code_native` and `code-native` are the same identifier.
(of course, minus function `-` is not affected)

## TODO:

- currying
- list comprehension/generator
- array/set/dict literal # currently array can be constructed by `ref`