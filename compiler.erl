-module(compiler).
-export([tokenize/1, parse/1, print/1, eval/2, simplify/1, compile/1, execute/3]).

%
% TYPES
%

%
% Environment which holds values associated with variables in an expression
%
-type env()  :: [{atom(), integer()}].

%
% Expression
%
-type expr() :: {'num', integer()}
              | {'var', atom()}
              | {'add', expr(), expr()}
              | {'mul', expr(), expr()}.

%
% An instruction of our simple virtual machine
%
-type instruction() :: {'push', integer()}
                     | {'fetch', atom()}
                     | {'add'}
                     | {'mul'}.

%
% A program consisting of instructions
%
-type program()     :: [instruction()].

%
% Stack of our virtual machine
%
-type stack()       :: [integer()].

-type token()       :: bracket | digit | symbol | operator. 
-type tokens()      :: [token()].

%
% FUNCTIONS
%

%
% Tokenize string expression
%
-spec tokenize(string()) -> tokens().

tokenize([$\s | Rest]) -> 
    tokenize(Rest);
tokenize([T | Rest]) when T == $( ; T == $) -> 
    [{bracket, T} | tokenize(Rest)];
tokenize([T | Rest]) when T == $+ ; T == $* ; T == $- ; T == $/ -> 
    [{operator, T} | tokenize(Rest)];
tokenize([T | Rest]) when $0 =< T, T =< $9 ->
    {Succeeds, Remainder} = get_while(fun is_digit/1, Rest),
    [{digit, list_to_integer([T | Succeeds])} | tokenize(Remainder)];
tokenize([T | Rest]) when $a =< T, T =< $z ->
    {Succeeds, Remainder} = get_while(fun is_alpha/1, Rest),
    [{symbol, list_to_atom([T | Succeeds])} | tokenize(Remainder)];
tokenize([]) -> 
    [].


%
% Parses string expression
%
-spec parse(string()) -> {expr(), string()}.

parse([$\s | Rest]) ->
    parse(Rest);
parse([$( | Rest]) ->
    {E1,Rest1} = parse(Rest),
    [OP|Rest2] = Rest1,
    {E2, Rest3} = parse(Rest2),
    [$)|RestFinal] = Rest3,
    {case OP of 
         $+ -> {add, E1, E2}; 
         $* -> {mul, E1, E2} 
     end, RestFinal};
parse([Ch|Rest]) when $a =< Ch andalso Ch =< $z ->
    {Succeeds, Remainder} = get_while(fun is_alpha/1, Rest),
    {{var, list_to_atom([Ch | Succeeds])}, Remainder};
parse([Ch|Rest]) when $0 =< Ch andalso Ch =< $9 ->
    {Succeeds, Remainder} = get_while(fun is_digit/1, Rest),
    {{num, list_to_integer([Ch | Succeeds])}, Remainder}.


-spec get_while(fun ((T) -> boolean()), [T]) -> {[T], [T]}.

get_while(P, [Ch | Rest]) ->
    case P(Ch) of
        true ->
            {Succeeds, Remainder} = get_while(P, Rest),
            {[Ch | Succeeds], Remainder};
        false ->
            {[], [Ch | Rest]}
    end;
get_while(_P, []) ->
    {[], []}.

is_alpha(Ch) -> $a =< Ch andalso Ch =< $z.

is_digit(Ch) -> $0 =< Ch andalso Ch =< $9.


%
% Prints expression as a string
%
-spec print(expr()) -> string().

print({num, N}) ->
    integer_to_list(N);
print({var, V}) ->
    atom_to_list(V);
print({add, E1, E2}) ->
    "(" ++ print(E1) ++ " + " ++ print(E2) ++ ")";
print({mul, E1, E2}) ->
    "(" ++ print(E1) ++ " * " ++ print(E2) ++ ")".


%
% Evaluates expression
%
-spec eval(env(), expr()) -> integer().

eval(_, {num, N}) ->
    N;
eval(Env, {var, V}) ->
    lookup(V, Env);
eval(Env, {add, E1, E2}) ->
    eval(Env, E1) + eval(Env, E2);
eval(Env, {mul, E1, E2}) ->
    eval(Env, E1) * eval(Env, E2).


%
% Returns a value associated with a variable
%
-spec lookup(atom(), env()) -> integer().

lookup(K, [{K,V}|_]) ->
    V;
lookup(K, [_|Rest]) ->
    lookup(K, Rest).


%
% Simplifies an expression
%
-spec simplify(expr()) -> expr().

simplify({add, {num, 0}, E}) -> E;
simplify({add, E, {num, 0}}) -> E;
simplify({mul, {num, 1}, E}) -> E;
simplify({mul, E, {num, 1}}) -> E;
simplify({mul, {num, 0}, _}) -> {num, 0};
simplify({mul, _, {num, 0}}) -> {num, 0};
simplify({add, {var, _}, {var, _}}=E) -> E;
simplify({mul, {var, _}, {var, _}}=E) -> E;
simplify({add, {num, N1}, {num, N2}}) -> 
    {num, N1 + N2};
simplify({mul, {num, N1}, {num, N2}}) -> 
    {num, N1 * N2};
simplify({add, {num, N1}, {add, {num, N2}, {var, V}}}) -> 
    {add, {num, N1 + N2}, {var, V}};
simplify({add, {num, N1}, {add, {var, V}, {num, N2}}}) -> 
    {add, {num, N1 + N2}, {var, V}};
simplify({add, {add, {num, N2}, {var, V}}, {num, N1}}) -> 
    {add, {num, N1 + N2}, {var, V}};
simplify({add, {add, {var, V}, {num, N2}}, {num, N1}}) -> 
    {add, {num, N1 + N2}, {var, V}};
simplify({mul, {num, N1}, {mul, {num, N2}, {var, V}}}) -> 
    {mul, {num, N1 * N2}, {var, V}};
simplify({mul, {num, N1}, {mul, {var, V}, {num, N2}}}) -> 
    {mul, {num, N1 * N2}, {var, V}};
simplify({mul, {mul, {num, N2}, {var, V}}, {num, N1}}) -> 
    {mul, {num, N1 * N2}, {var, V}};
simplify({mul, {mul, {var, V}, {num, N2}}, {num, N1}}) -> 
    {mul, {num, N1 * N2}, {var, V}};
simplify({_, {num, _}, {var, _}}=E) -> E;
simplify({_, {var, _}, {num, _}}=E) -> E;
simplify({O, E1, E2}=E) ->
    SE1 = simplify(E1),
    SE2 = simplify(E2),
    case {SE1, SE2} of
        {E1, E2} -> E;
        _ -> simplify({O, SE1, SE2})
    end;
simplify(E) ->
    E.


%
% Compiles an expression into a program
%
-spec compile(expr()) -> program().

compile({num, N}) ->
    [{push, N}];
compile({var, V}) ->
    [{fetch, V}];
compile({add, E1, E2}) ->
    compile(E1) ++ compile(E2) ++ [{add}];
compile({mul, E1, E2}) ->
    compile(E1) ++ compile(E2) ++ [{mul}].


%
% Executes a program
%
-spec execute(program(), env(), stack()) -> integer().

execute([{push, N} | Continue], Env, Stack) ->
    execute(Continue, Env, [N | Stack]);
execute([{fetch, V} | Continue], Env, Stack) ->
    execute(Continue, Env, [lookup(V, Env) | Stack]);
execute([{add} | Continue], Env, [N1,N2 | Stack]) ->
    execute(Continue, Env, [N1 + N2 | Stack]);
execute([{mul} | Continue], Env, [N1,N2 | Stack]) ->
    execute(Continue, Env, [N1 * N2 | Stack]);
execute([], _,  [N]) ->
    N.
