Terminals '(' ')' '[' ']' ',' '->' int atom binary.
Nonterminals selector comma_delimited_types type_with_subscripts array_subscripts tuple array_subscript identifier type typespec.
Rootsymbol selector.

selector -> typespec : #{function => nil, types => '$1', returns => nil}.
selector -> typespec '->' type : #{function => nil, types => '$1', returns => '$3'}.
selector -> identifier typespec : #{function => '$1', types => '$2', returns => nil}.
selector -> identifier typespec '->' type : #{function => '$1', types => '$2', returns => '$4'}.

typespec -> '(' ')' : [].
typespec -> '(' comma_delimited_types ')' : '$2'.

tuple -> '(' ')' : {tuple, []}.
tuple -> '(' comma_delimited_types ')' : {tuple, '$2'}.

comma_delimited_types -> type_with_subscripts : ['$1'].
comma_delimited_types -> type_with_subscripts ',' comma_delimited_types : ['$1' | '$3'].

identifier -> atom :
  atom_to_list(v('$1')).
identifier -> binary :
  v('$1').

type_with_subscripts -> type : '$1'.
type_with_subscripts -> type array_subscripts : with_subscripts('$1', '$2').

array_subscripts -> array_subscript : ['$1'].
array_subscripts -> array_subscript array_subscripts : ['$1' | '$2'].

array_subscript -> '[' ']' : variable.
array_subscript -> '[' int ']' : v('$2').

type -> atom :
  plain_type(v('$1')).
type -> atom int :
  juxt_type(v('$1'), v('$2')).
type -> atom int identifier int :
  double_juxt_type(v('$1'), v('$4'), v('$2'), v('$3')).
type -> tuple : '$1'.


Erlang code.

v({_Token, _Line, Value}) -> Value.

plain_type(address) -> address;
plain_type(bool) -> bool;
plain_type(function) -> function;
plain_type(string) -> string;
plain_type(bytes) -> bytes;
plain_type(int) -> juxt_type(int, 256);
plain_type(uint) -> juxt_type(uint, 256);
plain_type(fixed) -> double_juxt_type(fixed, "x", 128, 19);
plain_type(ufixed) -> double_juxt_type(ufixed, "x", 128, 19).

with_subscripts(Type, []) -> Type;
with_subscripts(Type, [H | T]) -> with_subscripts(with_subscript(Type, H), T).

with_subscript(Type, variable) -> {array, Type};
with_subscript(Type, N) when is_integer(N), N >= 0 -> {array, Type, N}.

juxt_type(int, M) when M > 0, M =< 256, (M rem 8) =:= 0 -> {int, M};
juxt_type(uint, M) when M > 0, M =< 256, (M rem 8) =:= 0 -> {uint, M};
juxt_type(bytes, M) when M > 0, M =< 32 -> {bytes, M}.

double_juxt_type(fixed, "x", M, N) when M >= 0, M =< 256, (M rem 8) =:= 0, N > 0, N =< 80 -> {fixed, M, N};
double_juxt_type(ufixed, "x", M, N) when M >= 0, M =< 256, (M rem 8) =:= 0, N > 0, N =< 80 -> {ufixed, M, N}.
