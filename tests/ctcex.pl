:- module(ctcex, [a/2, q/0]).

:- use_module(library(swi/assertions)).
:- use_module(library(swi/nativeprops)).
:- use_module(library(swi/basicprops)).

:- set_prolog_flag(check_assertions, [defined,
				      is_prop,
				      ctcheck
				     ]). % Now tighten the screws

:- pred a(int, list).

a(1,[]).
a(a, b).

q :-
    a(1,b),
    b(2,3).

% :- prop is_3/1.
is_3(3).

is_2(2).

:- prop is_num(int, int).

is_num(X, X).

:- pred b(int, is_3).

:- pred b(is_2, int).

:- pred b(is_num(2), is_num(3)).

:- pred b(is_num(a), is_num(b)).

b(2, 3) :- c.