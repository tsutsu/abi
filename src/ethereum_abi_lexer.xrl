Definitions.

INT        = [0-9]+
LETTERS    = [a-zA-Z_]+
WHITESPACE = [\s\t\n\r]+
TYPES      = uint|int|address|bool|fixed|ufixed|bytes|function|string
MODIFIERS  = indexed|anonymous|seq

Rules.

{TYPES}       : {token, {typename,   TokenLine, TokenChars}}.
{MODIFIERS}   : {token, {modifier,   TokenLine, TokenChars}}.
{INT}         : {token, {digits,     TokenLine, TokenChars}}.
x             : {token, {'x',        TokenLine, "x"}}.
{LETTERS}     : {token, {letters,    TokenLine, TokenChars}}.
\[            : {token, {'[',        TokenLine}}.
\]            : {token, {']',        TokenLine}}.
\(            : {token, {'(',        TokenLine}}.
\)            : {token, {')',        TokenLine}}.
,             : {token, {',',        TokenLine}}.
->            : {token, {'->',       TokenLine}}.
{WHITESPACE}  : {token, {' ',        TokenLine}}.

Erlang code.
