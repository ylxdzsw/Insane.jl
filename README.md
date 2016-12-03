Insane.jl
=========

![Build Status](https://travis-ci.org/ylxdzsw/Insane.jl.svg?branch=master)

## installation

```
Pkg.clone("https://github.com/ylxdzsw/Insane.jl", "Insane")
```

## usage

### Inline into julia

```
using Insane

λ"""
(println "hey I'm insane!")
"""
```

### Load external insane file

```
using Insane

insane_load("relative/path/to/file.insane")
```

### REPL

Press `<` to enter Insane REPL. Note it won't exit automatically, press backspace to return to julia REPL.

## language reference

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
f(foo (x *y **z) nothing)  # function foo(x, y...; z...) nothing end, f is alias of function
```

### begin clause

```
begin((foo) bar)  # begin foo(); bar end
>((foo) bar)      # alias of begin
```

### assignment

```
assign(foo bar)  # foo = bar
=((a b) x)       # a,b = x, = is alias of assign
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
?(cond true)         # if cond true, ? is alias of if
```

### lambda (auto cps)

```
lambda(x (split x '\n'))  # x -> split(x, '\n')
λ(() 2)                   # () -> 2
```

### pipe (auto assign)

```
pipe(foo (split . '\n') (parse Int .) (+ . 4))  # parse(Int, split(foo, '\n')) + 4
|(foo (+ ..left ..right *.))                    # tmp = foo; +(tmp.left, tmp.right, tmp...)
```

### for (auto cps)

```
for(i in :(1 5) foo(i))  # for i in 1:5 foo(i) end
```

### while (auto cps)

```
while((< i 2) =(i (+ i 1)))  # while i < 2 i = i+1 end
loop((foo))                  # while true foo() end
```

### try (auto assign)

```
try(uncertainty caught anyway)  # try uncertainty catch caught finally anyway end
```

exception object will be assigned to `.`

### cond

```
cond(cond1 act1 cond2 act2 ...)
```

if provide odd arguments, last argument will be treated as default action

### switch (auto assign)

```
switch(var val1 action1 val2 action2)
```

val can be wither a value or a expression that contains `.`, in the latter case var will be assigned to `.`

### range

almost equivalent to call (colon foo bar)

```
:(2 5)  # 2:5
```

### and, or

logic operation with early stopping

```
and(foo bar)  # foo && bar
or(foo bar)   # foo || bar
```

### true, false, break, continue, return

```
true()
false()
break()
continue()
return(foo)
```

### type, immutable, abstract

```
type(Foo (x Int) (y Dict{Int, Float64}))
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

### embed julia

```
embed(for i in :(1 3) println(i) end)
$(continue)
```

note: only *one* julia expression per $(), use begin clause to combine multiple expressions if nessecery

### typename

```
(Dict{Int, Int} '('(2 3) '(3 4)))  # Dict{Int, Int}(((2,3), (3,4)))
```

note: expressions contains curly braces are in *julia*

### TODO:

module, import, using, const, local, global, currying, type annotation and defaults for function/lambda, type assertion, list comprehension/generator, array/set/dict literal

### identifier

identifier can be any sequence of unicode except those:

1. starting with [0-9] or `'` or `:` or `*`
2. including spaces or `(` or `"` or '{' or '.'
3. ending with `:`

all `-` in identifiers will be translated to `_`, thus `code_native` and `code-native` are the same identifier.
(of course, minus function `-` not affected)