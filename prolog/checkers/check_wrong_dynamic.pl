/*  Part of Tools for SWI-Prolog

    Author:        Edison Mera Menendez
    E-mail:        efmera@gmail.com
    WWW:           https://github.com/edisonm/refactor, http://www.swi-prolog.org
    Copyright (C): 2015, Process Design Center, Breda, The Netherlands.

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

    As a special exception, if you link this library with other files,
    compiled with a Free Software compiler, to produce an executable, this
    library does not by itself cause the resulting executable to be covered
    by the GNU General Public License. This exception does not however
    invalidate any other reasons why the executable file might be covered by
    the GNU General Public License.
*/

:- module(check_wrong_dynamic, []).

:- use_module(checkers(checker)).
:- use_module(library(apply)).
:- use_module(library(check), []).
:- use_module(library(prolog_codewalk)).
:- use_module(xlibrary(clambda)).
:- use_module(xlibrary(compact_pi_list)).
:- use_module(xlibrary(normalize_head)).
:- use_module(xlibrary(normalize_pi)).
:- use_module(xtools(checkable_predicate)).
:- use_module(xtools(current_defined_predicate)).
:- use_module(xtools(database_fact)).
:- use_module(xtools(extra_codewalk)).
:- use_module(xtools(location_utils)).
:- use_module(xtools(option_utils)).

:- multifile
    prolog:message//1,
    hide_wrong_dynamic/2,
    hide_var_dynamic/2.

hide_var_dynamic(list_strings(_), check).
hide_var_dynamic(collect_non_mutually_exclusive(_, _), check_non_mutually_exclusive).
hide_var_dynamic(mutually_exclusive(_, _, _), check_non_mutually_exclusive).
hide_var_dynamic(cu_caller_hook(_, _, _, _, _, _, _), check_trivial_fails).
hide_var_dynamic(implemented_in(_, _, _), implemented_in).
hide_var_dynamic(unfold_goal(_, _), ref_scenarios).
hide_var_dynamic(mark_caller(_), check_unused).
hide_var_dynamic(unmarked(_, _, _), check_unused).
hide_var_dynamic(duptype_elem(_, _, _, _, _, _), check_dupcode).
hide_var_dynamic(bind_type_names(_, _, _, _), foreign_generator).
hide_var_dynamic(no_backtrace_entry(_), filtered_backtrace).
hide_var_dynamic(mark_to_head(_, _), check_unused).
hide_var_dynamic(current_arc(_, _, _), check_unused).
hide_var_dynamic(match_clause(_, _, _, _, _), ontrace).
hide_var_dynamic(type_desc(_, _), foreign_props).
hide_var_dynamic(prepare_results(_, _, _), checker).
hide_var_dynamic(current_edge(_, _, _), check_unused).
hide_var_dynamic(commited_retract(_), commited_retract).
hide_var_dynamic(tabling(_, _), ntabling).
hide_var_dynamic(match_head_body(_, _, _), abstract_interpreter).
hide_var_dynamic(is_entry_caller(_), check_unused).
hide_var_dynamic(current_head_ctcheck(_, _, _), check_assertions).
hide_var_dynamic(unfold_call(_, _, _, _, _), unfold_calls).

:- dynamic
    wrong_dynamic_db/4,
    var_dynamic_db/2.

hide_wrong_dynamic(prolog_trace_interception(_, _, _, _), user).

cleanup_dynamic_db :-
    retractall(wrong_dynamic_db(_, _, _, _)),
    retractall(var_dynamic_db(_, _)).

checker:check(wrong_dynamic, Result, OptionL0) :-
    option_allchk(OptionL0, OptionL, FileChk),
    check_wrong_dynamic(from_chk(FileChk), OptionL, Result).

check_wrong_dynamic(FromChk, OptionL0, Pairs) :-
    ignore(option(module(M), OptionL0 )),
    merge_options(OptionL0,
		  [infer_meta_predicates(false),
		   autoload(false),
		   evaluate(false),
		   trace_reference(_)],
		  OptionL),
    prolog_walk_code([source(false),
		      on_trace(collect_wrong_dynamic(M, FromChk))|OptionL]),
    findall(CRef, ( current_static_as_dynamic(_, _, _, _, clause(CRef), _),
		    retractall(wrong_dynamic_db(clause(CRef), _, _, _))
		  ; retract(var_dynamic_db(clause(CRef), _))
		  ), Clauses),
    ( Clauses==[]
    ->true
    ; prolog_walk_code([clauses(Clauses),
			on_trace(collect_wrong_dynamic(M))|OptionL])
    ),
    decl_walk_code(collect_wrong_dynamic(M, FromChk), M),
    collect_result(M:_, FromChk, Pairs),
    cleanup_dynamic_db.

collect_result(Ref, FromChk, Pairs) :-
    findall(Type-(as_dynamic(DType)-((Loc/PI)-(MLoc/MPI))),
	    ( current_static_as_dynamic(Type, DType, Loc, PI, From, MPI),
	      from_location(From, MLoc)), Pairs, Pairs1),
    findall(warning-(dynamic_as_static-(Loc-PI)),
	    current_dynamic_as_static(Ref, FromChk, Loc, PI), Pairs1, Pairs2),
    findall(warning-(var_as_dynamic-(PI-(Loc/CI))),
	    ( retract(var_dynamic_db(From, PI)),
	      check:predicate_indicator(From, CI, []),
	      from_location(From, Loc)), Pairs2, []).

current_static_as_dynamic(Type, DType, Loc, PI, MFrom, MPI) :-
    wrong_dynamic_db(MFrom, TypeDB, PI, MPI),
    memberchk(TypeDB,[def,retract]),
    PI = M:F/A,
    functor(H,F,A),
    Ref = M:H,
    \+ predicate_property(Ref, dynamic),
    \+ predicate_property(Ref, volatile),
    ( predicate_property(Ref, number_of_clauses(N)),
      N > 0 ->
      Type = error,
      DType = static,
      predicate_location(Ref, Loc)
    ; Type = warning,
      DType  = unknown,
      once(property_location(PI, _, Loc))      
    ).

:- meta_predicate current_dynamic_as_static(?, 1, -, ?).
current_dynamic_as_static(Ref, FromChk, Loc, PI) :-
    Ref = M:H,
    PI = M:F/A,
    ( var(H) ->
      current_defined_predicate(PI),
      functor(H, F, A)
    ; functor(H, F, A),
      current_defined_predicate(PI)
    ),
    checkable_predicate(Ref),
    predicate_property(Ref, dynamic),
    property_from(PI, dynamic, From),
    call(FromChk, From),
    %% ignore predicates with the following properties:
    \+ predicate_property(Ref, multifile),
    % \+ predicate_property(Ref, exported),
    \+ predicate_property(Ref, public),
    \+ ( wrong_dynamic_db(_, Type, PI, _),
	 memberchk(Type,[def,retract])
       ),
    from_location(From, Loc).

prolog:message(acheck(wrong_dynamic, Type-List)) -->
    wrong_dynamic_message(Type, List).

as_dynamic(DType, Loc/PI-MLocPIs) -->
    ['\t'|Loc], ['~w ~q modified by'-[DType, PI], nl],
    foldl(show_locpi, MLocPIs).

show_locpi(Loc/PI) --> ['\t\t'|Loc], check:predicate(PI), [nl].

show_locci(Loc/CI) --> ['\t\t'|Loc], CI, [nl].

dynamic_as_static(Loc-PIs) -->
    {compact_pi_list(PIs, CPIs)},
    ['\t'|Loc], ['predicates ~w'-[CPIs], nl].

wrong_dynamic_message(as_dynamic(DType), LocPIs) -->
    ['Predicates are ~w, but never declared dynamic and modified:'-DType, nl],
    foldl(as_dynamic(DType), LocPIs).
wrong_dynamic_message(dynamic_as_static, LocPIs) -->
    ['Predicates declared dynamic, but never modified:', nl],
    foldl(dynamic_as_static, LocPIs).
wrong_dynamic_message(var_as_dynamic, PILocCIs) -->
    ['Predicates called with a variable in a module-sensitive argument:', nl],
    foldl(var_as_dynamic, PILocCIs).

var_as_dynamic(PI-LocCIs) -->
    ['\t~w called with a variable in'-[PI], nl],
    foldl(show_locci, LocCIs).

prolog:message(acheck(wrong_dynamic)) -->
    ['--------------------------', nl,
     'Wrong Dynamic Declarations', nl,
     '--------------------------', nl,
     'The predicates below present inconsistencies between its', nl,
     'usage and the dynamic declarations. Could be that they are', nl,
     'being used as dynamic without a proper declaration, being', nl,
     'declared as dynamic but never asserted, retracted, or using', nl,
     'a variable argument in a database predicate, making it', nl,
     'difficult to analyze.', nl, nl].

:- public collect_wrong_dynamic/5.
:- meta_predicate collect_wrong_dynamic(?,1,+,+,+).
collect_wrong_dynamic(M, FromChk, MGoal, Caller, From) :-
    call(FromChk, From),
    collect_wrong_dynamic(M, MGoal, Caller, From).

collect_wrong_dynamic(M, MGoal, Caller, From) :-
    record_location_meta(MGoal, M, From, \T^G^M^_^F^database_fact_ort(T,G,M,F),
			 record_location_wd(Caller)),
    fail.
collect_wrong_dynamic(_, _, _, _). % avoid side effects

record_location_wd(Caller, M:Fact, _, Type, IM:Goal, _, From) :-
    MGoal = IM:Goal,
    Def = dynamic(Type, _, MGoal),
    normalize_pi(MGoal, MPI),
    ( atom(M),
      callable(Fact)
    ->functor(Fact, F, A),
      record_location(Fact, M, Def, From),
      \+ hide_wrong_dynamic(Fact, M),
      assertz(wrong_dynamic_db(From, Type, M:F/A, MPI))
    ; \+ database_fact(Caller) ->
      normalize_head(Caller, CM:HC),
      \+ hide_var_dynamic(HC, CM),
      assertz(var_dynamic_db(From, MPI))
    ; true
    ).