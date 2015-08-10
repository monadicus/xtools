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

:- module(audit_codewalk, [audit_walk_code/4,
			   audit_wcsetup/4,
			   decl_walk_code/2,
			   record_issues/1]).

:- use_module(library(extra_location)).
:- use_module(library(option_utils)).
:- use_module(library(prolog_codewalk)).

:- thread_local
    issues/1.

:- meta_predicate
    decl_walk_code(3,-),
    audit_walk_code(+,3,-,-).

audit_walk_code(OptionL0, Tracer, M, FromChk) :-
    audit_wcsetup(OptionL0, OptionL1, M, FromChk),
    select_option(source(S), OptionL1, OptionL, false),
    optimized_walk_code(S, [on_trace(Tracer)|OptionL]),
    decl_walk_code(Tracer, M).

optimized_walk_code(false, OptionL) :-
    prolog_walk_code([source(false)|OptionL]).
optimized_walk_code(true, OptionL) :-
    prolog_walk_code([source(false)|OptionL]),
    findall(CRef, retract(issues(CRef)), ClausesU),
    sort(ClausesU, Clauses),
    ( Clauses==[]
    ->true
    ; prolog_walk_code([clauses(Clauses)|OptionL])
    ).

audit_wcsetup(OptionL0, OptionL, M, FromChk) :-
    option_fromchk(OptionL0, OptionL1, FromChk),
    select_option(module(M), OptionL1, OptionL2, M),
    merge_options(OptionL2,
		  [infer_meta_predicates(false),
		   autoload(false),
		   evaluate(false),
		   trace_reference(_),
		   module_class([user, system, library])
		  ], OptionL).

decl_walk_code(Tracer, M) :-
    forall(loc_declaration(Head, M, goal, From),
	   ignore(call(Tracer, M:Head, _:'<declaration>', From))).

record_issues(CRef) :-
    assertz(issues(CRef)).
