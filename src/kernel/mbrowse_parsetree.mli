(* {{{ COPYING *(

     This file is part of Merlin, an helper for ocaml editors

     Copyright (C) 2013 - 2015  Frédéric Bour  <frederic.bour(_)lakaban.net>
                                Thomas Refis  <refis.thomas(_)gmail.com>
                                Simon Castellan  <simon.castellan(_)iuwt.fr>

     Permission is hereby granted, free of charge, to any person obtaining a
     copy of this software and associated documentation files (the "Software"),
     to deal in the Software without restriction, including without limitation the
     rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
     sell copies of the Software, and to permit persons to whom the Software is
     furnished to do so, subject to the following conditions:

     The above copyright notice and this permission notice shall be included in
     all copies or substantial portions of the Software.

     The Software is provided "as is", without warranty of any kind, express or
     implied, including but not limited to the warranties of merchantability,
     fitness for a particular purpose and noninfringement. In no event shall
     the authors or copyright holders be liable for any claim, damages or other
     liability, whether in an action of contract, tort or otherwise, arising
     from, out of or in connection with the software or the use or other dealings
     in the Software.

   )* }}} *)

(** Cursor navigation over the {!Parsetree}, the counterpart of {!Mbrowse} for
    the untyped AST.

    The mutually recursive types of the Parsetree are wrapped into the
    constructors of the type {!node}; {!fold_node} enumerates the direct
    children of a node. The navigation functions ([enclosing],
    [deepest_before], [range_enclosing], ...) come from {!Mbrowse_generic} and
    behave exactly as their {!Mbrowse} counterparts.

    Differences with the typed tree worth knowing about:
    - there is no environment: a path is a plain list of nodes;
    - attributes are never traversed, but the payload of an extension node
      ([\[%ext ...\]]) is: its content appears as children of the node carrying
      the extension;
    - nodes without a location (structures, cases, ...) get the union of the
      locations of their children. *)

open Parsetree

type node =
  | Structure of structure
  | Signature of signature
  | Structure_item of structure_item
  | Signature_item of signature_item
  | Expression of expression
  | Pattern of pattern
  | Core_type of core_type
  | Case of case
  | Value_binding of value_binding
  | Binding_op of binding_op
  | Module_expr of module_expr
  | Module_type of module_type
  | Module_binding of module_binding
  | Module_declaration of module_declaration
  | Module_substitution of module_substitution
  | Module_type_declaration of module_type_declaration
  | Open_declaration of open_declaration
  | Open_description of open_description
  | Include_declaration of include_declaration
  | Include_description of include_description
  | Value_description of value_description
  | Type_declaration of type_declaration
  | Type_kind of type_kind
  | Type_extension of type_extension
  | Type_exception of type_exception
  | Extension_constructor of extension_constructor
  | Label_declaration of label_declaration
  | Constructor_declaration of constructor_declaration
  | Row_field of row_field
  | Object_field of object_field
  | Package_type of package_type
  | With_constraint of with_constraint
  | Class_declaration of class_declaration
  | Class_description of class_description
  | Class_type_declaration of class_type_declaration
  | Class_expr of class_expr
  | Class_structure of class_structure
  | Class_field of class_field
  | Class_type of class_type
  | Class_signature of class_signature
  | Class_type_field of class_type_field

(** [fold_node f node acc] folds [f] over the {e direct} children of [node],
    in source order. *)
val fold_node : (node -> 'a -> 'a) -> node -> 'a -> 'a

(** [node_real_loc loc0 node] is the location carried by [node], or [loc0] if
    it has none (or an empty one). *)
val node_real_loc : Location.t -> node -> Location.t

(** Same as [node_real_loc], but honoring the [merlin.loc] attribute. *)
val node_merlin_loc : Location.t -> node -> Location.t

val node_attributes : node -> attribute list
val has_attr : name:string -> node -> bool
val string_of_node : node -> string

(** {1 Navigation} *)

include Mbrowse_generic.S with type node := node

(** Alias of [loc], for parity with {!Mbrowse.node_loc}. *)
val node_loc : node -> Location.t

module Tie_breaker : sig
  (** See {!Mbrowse.Tie_breaker}. *)

  type t = disambiguate

  (** Tie-break by preferring expression over other nodes *)
  val prefer_expression : t
end

val of_structure : structure -> t
val of_signature : signature -> t
val of_parsetree : Mreader.parsetree -> t

(** {1 Dump} *)

val print_node : unit -> node -> string
