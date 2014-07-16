:- module(check_deprecated, []).

:- use_module(library(prolog_codewalk)).
:- use_module(library(check), []).
:- use_module(library(auditable_predicate)).
:- use_module(library(current_defined_predicate)).
:- use_module(library(implementation_module)).
:- use_module(library(normalize_head)).
:- use_module(library(location_utils)).
:- use_module(library(referenced_by)).

:- multifile
    prolog:message//1,
    deprecated_predicate/2,
    audit:check/4.

audit:check(deprecated, Ref, Result, OptionL0) :-
    option_allchk(OptionL0, OptionL, FileChk),
    check_deprecated(Ref, FileChk, OptionL, Result).

check_deprecated(Ref0, FileChk, OptionL0, Pairs) :-
    normalize_head(Ref0, Ref),
    merge_options(OptionL0,
		  [infer_meta_predicates(false),
		   autoload(false),
		   evaluate(false),
		   trace_reference(Ref)
		  ], OptionL),
    prolog_walk_code([source(false),
		      on_trace(have_deprecated(FileChk))
		     |OptionL]),
    findall(CRef, retract(deprecated_db(clause(CRef))), Clauses),
    ( Clauses==[]
    ->Pairs=[]
    ; prolog_walk_code([clauses(Clauses),
			on_trace(collect_deprecated)
		       |OptionL]),
      findall(information-(Call/Alt-(Loc/CI)),
	      ( retract(deprecated_db(Call, Alt, From)),
		from_location(From, Loc),
		check:predicate_indicator(From, CI, [])
	      ), Pairs)
    ),
    cleanup_locations(_, dynamic(_, _), _).

predicate_head(Module:Head) -->
    { nonvar(Head),
      arg(_, Head, Arg),
      nonvar(Arg)
    },
    !,
    ['~w'-[Module:Head]].
predicate_head(Head) -->
    check:predicate(Head).

prolog:message(acheck(deprecated)) -->
    ['---------------------',nl,
     'Deprecated Predicates',nl,
     '---------------------',nl,
     'The predicates below are marked as deprecated, so you have to', nl,
     'avoid its usage in new code, and to refactorize old code.', nl, nl].
prolog:message(acheck(deprecated, PI/Alt-LocCIs)) -->
    predicate_head(PI),
    [' deprecated, use ~q instead. Referenced by'-[Alt], nl],
    referenced_by(LocCIs).

:- dynamic deprecated_db/1, deprecated_db/3.

:- public have_deprecated/4.
:- meta_predicate have_deprecated(1, +, +, +).

have_deprecated(FileChk, MGoal, _, From) :-
    from_to_file(From, File),
    call(FileChk, File),
    deprecated_predicate(MGoal, _),
    assertz(deprecated_db(From)),
    fail.
have_deprecated(_, _, _, _).

:- public collect_deprecated/3.

collect_deprecated(MGoal, _, From) :-
    deprecated_predicate(MGoal, Alt),
    assertz(deprecated_db(MGoal, Alt, From)),
    fail.
collect_deprecated(_, _, _).