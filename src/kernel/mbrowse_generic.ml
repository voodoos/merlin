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

open Std

type tie_break = Prefer_first | Prefer_second

module type NODE = sig
  type t

  val fold : (t -> 'a -> 'a) -> t -> 'a -> 'a
  val real_loc : Location.t -> t -> Location.t
  val merlin_loc : Location.t -> t -> Location.t
  val is_hidden : t -> bool
  val is_focus : t -> bool
  val to_string : t -> string
end

module type S = sig
  type node
  type t = node list
  type disambiguate = node -> node -> tie_break option

  val loc : node -> Location.t
  val merlin_loc : node -> Location.t
  val leaf_node : t -> node
  val drop_leaf : t -> t option
  val enclosing : ?disambiguate:disambiguate -> Lexing.position -> t list -> t

  val deepest_before :
    ?disambiguate:disambiguate -> Lexing.position -> t list -> t

  val range_enclosing :
    start:Lexing.position -> stop:Lexing.position -> t list -> t

  val print : unit -> t -> string
end

module Make (N : NODE) = struct
  type node = N.t
  type t = node list
  type disambiguate = node -> node -> tie_break option

  let approximate_loc get_loc node =
    let loc = get_loc Location.none node in
    if loc == Location.none then
      let rec aux node acc =
        let loc = get_loc Location.none node in
        if loc != Location.none then Location_aux.union loc acc
        else N.fold aux node acc
      in
      aux node Location.none
    else loc

  let loc node = approximate_loc N.real_loc node

  (* Fuzzy locations, more likely to locate the appropriate node *)
  let merlin_loc node = approximate_loc N.merlin_loc node

  let leaf_node = List.hd

  let drop_leaf t =
    match t with
    | [] | [ _ ] -> None
    | _leaf :: parents -> Some parents

  let select_leafs pos root =
    let branches = ref [] in
    let rec select_child branch node has_selected =
      let loc = merlin_loc node in
      if Location_aux.compare_pos pos loc = 0 && not (N.is_hidden node) then (
        traverse (node :: branch);
        true)
      else has_selected
    and traverse branch =
      let node = leaf_node branch in
      if N.is_focus node then (
        branches := [];
        let has_leaves = N.fold (select_child branch) node false in
        if not has_leaves then branches := [ branch ];
        raise Exit)
      else if not (N.is_hidden node) then
        let has_leaves = N.fold (select_child branch) node false in
        if not has_leaves then branches := branch :: !branches
    in
    (try traverse root with Exit -> ());
    !branches

  let compare_locations ?tie_break pos l1 l2 =
    let t2_first = 1 in
    let t1_first = -1 in
    match
      (Location_aux.compare_pos pos l1, Location_aux.compare_pos pos l2)
    with
    (* Cursor inside both locations: favor non-ghost, fallback to user-provided
       tie-break, fallback to being closer to the end *)
    | 0, 0 ->
      begin match (tie_break, l1.Location.loc_ghost, l2.Location.loc_ghost) with
      | _, true, false -> 1
      | _, false, true -> -1
      | Some Prefer_first, _, _ -> t1_first
      | Some Prefer_second, _, _ -> t2_first
      | _ -> Lexing.compare_pos l1.Location.loc_end l2.Location.loc_end
      end
    (* Cursor inside one location: it has priority *)
    | 0, _ -> t1_first
    | _, 0 -> t2_first
    (* Cursor outside locations: favor before *)
    | n, m when n > 0 && m < 0 -> t1_first
    | n, m when m > 0 && n < 0 -> t2_first
    (* Cursor is after both, select the closest one *)
    | _, _ -> Lexing.compare_pos l2.Location.loc_end l1.Location.loc_end

  let best_node ?disambiguate pos = function
    | [] -> []
    | init :: xs ->
      let f acc x =
        let node1 = leaf_node acc and node2 = leaf_node x in
        let tie_break =
          Option.bind
            ~f:(fun disambiguate -> disambiguate node1 node2)
            disambiguate
        in
        if compare_locations ?tie_break pos (loc node1) (loc node2) <= 0 then
          acc
        else x
      in
      List.fold_left ~f ~init xs

  let enclosing ?disambiguate pos roots =
    match best_node ?disambiguate pos roots with
    | [] -> []
    | root -> best_node ?disambiguate pos (select_leafs pos root)

  let deepest_before ?disambiguate pos roots =
    match enclosing ?disambiguate pos roots with
    | [] -> []
    | root ->
      let rec aux path =
        let node0 = leaf_node path in
        let loc0 = merlin_loc node0 in
        let select_candidate node acc =
          let loc = merlin_loc node in
          if
            path == root
            || Location_aux.compare_pos pos loc = 0
            || Lexing.compare_pos loc.Location.loc_end loc0.Location.loc_end = 0
          then
            match acc with
            | Some (loc', node') ->
              (* Note: the tie-break is asked about (candidate, accumulator)
                 while the locations are compared as (accumulator, candidate).
                 This asymmetry is historical and preserved as is. *)
              let tie_break =
                Option.bind
                  ~f:(fun disambiguate -> disambiguate node node')
                  disambiguate
              in
              if compare_locations ?tie_break pos loc' loc <= 0 then acc
              else Some (loc, node)
            | None -> Some (loc, node)
          else acc
        in
        match N.fold select_candidate node0 None with
        | None -> path
        | Some (_, node) -> aux (node :: path)
      in
      aux root

  let range_enclosing ~start ~stop roots =
    List.filter
      ~f:(fun node ->
        let loc = loc node in
        let nstart = loc.Location.loc_start and nend = loc.Location.loc_end in
        let a = Lexing.compare_pos start nstart
        and b = Lexing.compare_pos stop nend in
        a >= 0 && b <= 0)
      (enclosing start roots)

  let print () t = List.print (fun () node -> N.to_string node) () t
end
