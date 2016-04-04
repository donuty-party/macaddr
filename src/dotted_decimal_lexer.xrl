Definitions.

INT = [0-9]+
DOT = \.

Rules.

{INT} : {token, {int, TokenLine, list_to_integer(TokenChars)}}.
{DOT} : {token, {'.', TokenLine}}.

Erlang code.