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

(** Generic cursor navigation over a tree of located nodes.

    The navigation algorithms ([enclosing], [deepest_before], [range_enclosing])
    only need a way to enumerate the direct children of a node and to compute
    its location. This module abstracts over these operations so that the same
    code can be instantiated over the Typedtree (see {!Mbrowse}) and over the
    Parsetree (see {!Mbrowse_parsetree}). *)

(** Some nodes may share the same, non-ghost, location, while being different.
    One example of this is let-punning:

    {@ocaml[
    let+ x in
    ]}

    Both [x] as an expression and as a pattern share the exact same location.

    Tie-breaking selects the node that we want in those cases. *)
type tie_break = Prefer_first | Prefer_second

(** The operations a tree must provide to be navigable. [t] is a {e path
    entry}: whatever the instance wants to store along the path from the leaf
    to the root (a node, or a node together with its environment). *)
module type NODE = sig
  type t

  (** [fold f node acc] folds over the {e direct} children of [node] only. *)
  val fold : (t -> 'a -> 'a) -> t -> 'a -> 'a

  (** [real_loc loc0 node] is the location of [node], or [loc0] if the node
      carries no location. *)
  val real_loc : Location.t -> t -> Location.t

  (** [merlin_loc loc0 node] is a relaxed location, more likely to match the
      concrete syntax the user sees (for instance honoring the [merlin.loc]
      attribute). *)
  val merlin_loc : Location.t -> t -> Location.t

  (** Nodes with the [merlin.hide] attribute are never selected. *)
  val is_hidden : t -> bool

  (** When a node with the [merlin.focus] attribute is encountered, selection
      is restricted to its subtree. *)
  val is_focus : t -> bool

  val to_string : t -> string
end

module type S = sig
  type node

  (** A path in the tree: the selected node first, then its ancestors up to
      the root. *)
  type t = node list

  (** If [f : disambiguate], then [f node1 node2] answers:
      - [Some Prefer_first] to select [node1]
      - [Some Prefer_second] to select [node2]
      - [None] to let the default disambiguation mechanism break the tie. *)
  type disambiguate = node -> node -> tie_break option

  (** Location of a node. If the node carries no location, the union of the
      locations of its children is used instead. *)
  val loc : node -> Location.t

  (** Same as [loc], using relaxed locations. *)
  val merlin_loc : node -> Location.t

  val leaf_node : t -> node
  val drop_leaf : t -> t option

  (** The innermost node whose location contains the cursor, with its
      ancestors. Returns the empty list if no root is given. *)
  val enclosing : ?disambiguate:disambiguate -> Lexing.position -> t list -> t

  (** The deepest context inside or before the node, for instance, navigating
      through:
      {v foo bar (baz :: tail) <cursor> v}
      asking for node from cursor position will return context of "tail".
      Returns the matching node and all its ancestors or the empty list. *)
  val deepest_before :
    ?disambiguate:disambiguate -> Lexing.position -> t list -> t

  (** The nodes enclosing the whole [start]-[stop] range, innermost first. *)
  val range_enclosing :
    start:Lexing.position -> stop:Lexing.position -> t list -> t

  val print : unit -> t -> string
end

module Make (N : NODE) : S with type node = N.t
