# expression-compiler-erlang
Simple arithmetic expression compiler in Erlang as explained in this [Erlang Master Class](https://www.youtube.com/playlist?list=PLR812eVbehlwEArT3Bv3UfcM9wR3AEZb5)

This compiler implements the following functionality:
- string expression parsing
- expression serialization back to string 
- expression evaluation
- expression simplification
- expression compilation into a program
- execution of the compiled program

## Limitations

- Parser only recognizes addition and multiplication operations
- Parser doesn't follow operator precedence rules and thus the whole expression and all subexpressions should be enclosed into parenthesis and there should be no spaces, e.g.: `(1+(2*3))`

## Running

I consider that you are going to run compiler in Erlang shell.

The first thing you have to do is compile module:

```
1> c(compiler).
```

Next you can start playing with these functions which are exported from `compiler` module:
- `parse/1` - parses a string expressiong
- `print/1` - convers parsed expression back into string
- `eval/2` - evaluates parsed expression
- `simplify/1` - applies rules to simplify original expression and returns a simplified expression
- `compile/1` - compiles parsed expression into a program for our small virtual machine
- `execute/3` - executes a program

Here is an example that parses expression, compiles and executes:

```
1> {Expression, _} = compiler:parse("(2+((2*3)+x))").
{{add,{num,1},{add,{mul,{num,2},{num,3}},{var,x}}},[]}

2> compiler:print(Expression).
"(2 + ((2 * 3) + x))"

3> SimplifiedExpression = compiler:simplify(Expression).
{add,{num,8},{var,x}}

5> compiler:print(SimplifiedExpression).
"(8 + x)"

6> compiler:eval([{x, 10}], Expression).
18

7> compiler:eval([{x, 10}], SimplifiedExpression).
18

8> Program = compiler:compile(Expression).
[{push,2},{push,2},{push,3},{mul},{fetch,x},{add},{add}]

9> SimplifiedProgram = compiler:compile(SimplifiedExpression).
[{push,8},{fetch,x},{add}]

10> compiler:execute(Program, [{x, 10}], []).
18

11> compiler:execute(SimplifiedProgram, [{x, 10}], []).
18
```
