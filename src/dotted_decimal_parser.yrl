Nonterminals dotted_decimal elem elems.
Terminals int '.'.
Rootsymbol dotted_decimal.

dotted_decimal -> '$empty' : [].
dotted_decimal -> elems : '$1'.

elems -> elem : ['$1'].
elems -> elem '.' elems: ['$1' | '$3'].

elem -> int : extract_token('$1').

Erlang code.

extract_token({_Token, _Line, Value}) -> Value.