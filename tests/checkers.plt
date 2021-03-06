:- begin_tests(checkers).

:- use_module(library(checkers/checker)).
:- use_module(library(checkers/check_wrong_dynamic)).

checkable_predicate:application_predicate(M:_) :-
    application_module(M).

application_module(cwda).
application_module(cwdb).

:- use_module(cwda).
:- use_module(cwdb).
:- use_module(cwdc).

test(cwd_1) :-
    check_results(wrong_dynamic, Results, [files([xtools/tests/cwdb])]),
    assertion(Results = [_]).

test(cwd_2) :-
    check_results(wrong_dynamic, Results, [files([xtools/tests/cwda, xtools/tests/cwdb])]),
    assertion(Results = []).

test(cwd_3) :-
    check_results(wrong_dynamic, Results, [files([xtools/tests/cwda])]),
    assertion(Results = []).

test(cwd_4) :- % There is an issue that does not refers to module cwda
    check_results(wrong_dynamic, Results, [module(cwda), files([xtools/tests/cwdb])]),
    assertion(Results = []).

test(cwd_5) :-
    check_results(wrong_dynamic, Results, [files([xtools/tests/cwdc])]),
    assertion(Results = []).

:- end_tests(checkers).
