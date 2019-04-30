Terminals '(' ')' '[' ']' ',' '->' ' ' typename modifier letters digits 'x' 'begin' 'end' 'expecting selector' 'expecting type'.
Nonterminals dispatch selector nontrivial_selector comma_delimited_params param annotated_type pre_annotated_type pre_type_annotations post_type_annotations modifier_or_identifier type_with_subscripts array_subscripts tuple array_subscript type typespec arb_identifier safe_identifier safe_identifier_parts identifier_arb_parts identifier_arb_part identifier_safe_part identifier_conflicting_part.
Rootsymbol dispatch.

dispatch -> 'expecting type' 'begin' param 'end' : {type, '$3'}.
dispatch -> 'expecting selector' 'begin' selector 'end' : {selector, '$3'}.
dispatch -> 'begin' tuple 'end' : {selector, #{function => nil, types => ['$2'], returns => nil}}.
dispatch -> 'begin' nontrivial_selector 'end' : {selector, '$2'}.

selector -> typespec : #{function => nil, types => '$1', returns => nil}.
selector -> nontrivial_selector : '$1'.

nontrivial_selector -> '(' ')' '->' param : #{function => nil, types => '$1', returns => '$3'}.
nontrivial_selector -> arb_identifier typespec : #{function => '$1', types => '$2', returns => nil}.
nontrivial_selector -> arb_identifier typespec '->' param : #{function => '$1', types => '$2', returns => '$4'}.

typespec -> '(' ')' : [].
typespec -> '(' comma_delimited_params ')' : '$2'.

tuple -> '(' ')' : {tuple, []}.
tuple -> '(' comma_delimited_params ')' : {tuple, '$2'}.

comma_delimited_params -> param : ['$1'].
comma_delimited_params -> param ',' comma_delimited_params : ['$1' | '$3'].

param -> annotated_type : apply_annotations('$1').

annotated_type -> pre_annotated_type : '$1'.
annotated_type -> pre_annotated_type post_type_annotations : annotate('$1', '$2').

pre_annotated_type -> type_with_subscripts : '$1'.
pre_annotated_type -> pre_type_annotations type_with_subscripts : annotate('$2', '$1').

pre_type_annotations -> modifier ' ' : [v('$1')].
pre_type_annotations -> modifier ' ' pre_type_annotations : [v('$1') | '$3'].

post_type_annotations -> ' ' modifier_or_identifier : ['$2'].
post_type_annotations -> ' ' modifier_or_identifier post_type_annotations : ['$2' | '$3'].

modifier_or_identifier -> modifier : v('$1').
modifier_or_identifier -> safe_identifier : {name, '$1'}.

type_with_subscripts -> type : '$1'.
type_with_subscripts -> type array_subscripts : with_subscripts('$1', '$2').

array_subscripts -> array_subscript : ['$1'].
array_subscripts -> array_subscript array_subscripts : ['$1' | '$2'].

array_subscript -> '[' ']' : variable.
array_subscript -> '[' digits ']' : list_to_integer(v('$2')).

type -> typename :
  plain_type(list_to_atom(v('$1'))).
type -> typename digits :
  juxt_type(list_to_atom(v('$1')), list_to_integer(v('$2'))).
type -> typename digits 'x' digits :
  double_juxt_type(list_to_atom(v('$1')), v('$3'), list_to_integer(v('$2')), list_to_integer(v('$4'))).
type -> tuple : '$1'.

arb_identifier -> identifier_arb_parts : iolist_to_binary('$1').

safe_identifier -> safe_identifier_parts : iolist_to_binary('$1').

safe_identifier_parts -> identifier_safe_part : [v('$1')].
safe_identifier_parts -> identifier_safe_part identifier_arb_parts : [v('$1') | '$2'].
safe_identifier_parts -> identifier_conflicting_part identifier_safe_part : [v('$1'), v('$2')].
safe_identifier_parts -> identifier_conflicting_part identifier_safe_part identifier_arb_parts : [v('$1'), v('$2') | '$3'].

identifier_arb_parts -> identifier_arb_part : [v('$1')].
identifier_arb_parts -> identifier_arb_part identifier_arb_parts : [v('$1') | '$2'].

identifier_arb_part -> identifier_safe_part : '$1'.
identifier_arb_part -> identifier_conflicting_part : '$1'.

identifier_safe_part -> letters : '$1'.
identifier_safe_part -> digits : '$1'.
identifier_safe_part -> 'x' : {nil, nil, "x"}.

identifier_conflicting_part -> typename : '$1'.
identifier_conflicting_part -> modifier : '$1'.

Erlang code.

v({_Token, _Line, Value}) -> Value.

annotate({annotations, Type, Annotations0}, AddAnnotations) -> {annotations, Type, lists:umerge(Annotations0, lists:usort(AddAnnotations))};
annotate(Type, AddAnnotations) -> {annotations, Type, lists:usort(AddAnnotations)}.

apply_annotations({annotations, Type, Annots}) ->
  apply_annotations(Type, Annots, unnamed);
apply_annotations(Type) ->
  apply_annotations(Type, [], unnamed).

apply_annotations(Type, [], Name) ->
  {binding, Type, Name};
apply_annotations(Type, ["indexed" | RestAnnots], Name) ->
  apply_annotations({indexed, Type}, RestAnnots, Name);
apply_annotations(Type, ["seq" | RestAnnots], Name) ->
  apply_annotations({seq, Type}, RestAnnots, Name);
apply_annotations(Type, [{name, NewName} | RestAnnots], unnamed) ->
  apply_annotations(Type, RestAnnots, NewName).

plain_type(address) -> address;
plain_type(bool) -> bool;
plain_type(function) -> function;
plain_type(string) -> string;
plain_type(bytes) -> bytes;
plain_type(int) -> juxt_type(int, 256);
plain_type(uint) -> juxt_type(uint, 256);
plain_type(fixed) -> double_juxt_type(fixed, 'x', 128, 19);
plain_type(ufixed) -> double_juxt_type(ufixed, 'x', 128, 19).

with_subscripts(Type, []) -> Type;
with_subscripts(Type, [H | T]) -> with_subscripts(with_subscript(Type, H), T).

with_subscript(Type, variable) -> {array, Type};
with_subscript(Type, N) when is_integer(N), N >= 0 -> {array, Type, N}.

juxt_type(int, M) when M > 0, M =< 256, (M rem 8) =:= 0 -> {int, M};
juxt_type(uint, M) when M > 0, M =< 256, (M rem 8) =:= 0 -> {uint, M};
juxt_type(bytes, M) when M > 0, M =< 32 -> {bytes, M}.

double_juxt_type(fixed, 'x', M, N) when M >= 0, M =< 256, (M rem 8) =:= 0, N > 0, N =< 80 -> {fixed, M, N};
double_juxt_type(ufixed, 'x', M, N) when M >= 0, M =< 256, (M rem 8) =:= 0, N > 0, N =< 80 -> {ufixed, M, N}.
