Insane.jl
=========

![Build Status](https://travis-ci.org/ylxdzsw/Insane.jl.svg?branch=master)

## installation

## usage

## language reference

### function call

an s-expr is a function call

```
(foo)        # foo()
(foo bar)    # foo(bar)
(foo *bar)   # foo(bar...)
(foo **bar)  # foo(;bar...)
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

tuples are so common that I made it a special form; it almost equivilent to write `(Tuple foo bar)`

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

### pipe

```
pipe(foo (split . '\n') (parse Int .) (+ . 4))  # parse(Int, split(foo, '\n')) + 4
|(foo (+ ..left ..right *.[2:5]))               # tmp = foo; +(tmp.left, tmp.right, tmp[2:5]...)
```

### for (auto cps)

```
for(i in 1:5 foo(i))  # for i in 1:5 foo(i) end
```

### while (auto cps)

```
while((< i 2) (+= i 1))  # while i < 2 i += 1 end
```

### try

```
try(uncertainty caught anyway)  # try uncertainty catch caught finally anyway end
```

### break, continue, return

```
break()
continue()
return(foo)
```

### type, immutable

```
type(Foo (x Int) (y Dict{Int, Float64}))
immutable(Bar x )
```


### TODO:

module, import, using, const, local, global, type annotation for function/lambda, type assertion

### identifier

identifier can be any sequence of unicode except those:

1. starting with [0-9]
2. including spaces