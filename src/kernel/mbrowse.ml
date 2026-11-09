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
open Typedtree
open Browse_raw

type node = Browse_raw.node
type t = (Env.t * node) list

let node_of_binary_part = Browse_raw.node_of_binary_part

let fold_node f env t acc =
  let acc =
    match
      Msupport.get_saved_types_from_attributes (Browse_raw.node_attributes t)
    with
    | [] -> acc
    | parts ->
      let rec aux acc = function
        | [] -> acc
        | part :: parts ->
          let t = node_of_binary_part env part in
          aux (f (Browse_raw.node_update_env env t) t acc) parts
      in
      aux acc parts
  in
  Browse_raw.fold_node f env t acc

module Typed = Mbrowse_generic.Make (struct
  type t = Env.t * node

  let fold f (env, node) acc =
    fold_node (fun env node acc -> f (env, node) acc) env node acc

  let real_loc loc0 (_, node) = Browse_raw.node_real_loc loc0 node
  let merlin_loc loc0 (_, node) = Browse_raw.node_merlin_loc loc0 node
  let is_hidden (_, node) = Browse_raw.has_attr ~name:"merlin.hide" node
  let is_focus (_, node) = Browse_raw.has_attr ~name:"merlin.focus" node
  let to_string (_, node) = Browse_raw.string_of_node node
end)

(* Locations do not depend on the environment *)
let node_loc node = Typed.loc (Env.empty, node)

let leaf_node = Typed.leaf_node
let drop_leaf = Typed.drop_leaf

module Tie_breaker = struct
  type tie_break = Mbrowse_generic.tie_break = Prefer_first | Prefer_second
  type t = node -> node -> tie_break option

  let prefer_expression node1 node2 : tie_break option =
    match (node1, node2) with
    | Expression _, Expression _ -> None
    | Expression _, _ -> Some Prefer_first
    | _, Expression _ -> Some Prefer_second
    | _ -> None
end

let lift_disambiguate disambiguate =
  Option.map disambiguate ~f:(fun disambiguate (_, node1) (_, node2) ->
      disambiguate node1 node2)

let enclosing ?disambiguate pos roots =
  Typed.enclosing ?disambiguate:(lift_disambiguate disambiguate) pos roots

let deepest_before ?disambiguate pos roots =
  Typed.deepest_before ?disambiguate:(lift_disambiguate disambiguate) pos roots

let range_enclosing = Typed.range_enclosing

(* Select open nodes *)

let rec select_open_node = function[@warning "-9"]
  | ( _,
      Structure_item
        ( { str_desc =
              Tstr_open
                { open_expr = { mod_desc = Tmod_ident (p, { txt = longident }) }
                }
          },
          _ ) )
    :: ancestors -> Some (p, longident, ancestors)
  | (_, Signature_item ({ sig_desc = Tsig_open op }, _)) :: ancestors ->
    let p, { Asttypes.txt = longident } = op.open_expr in
    Some (p, longident, ancestors)
  | ( _,
      Expression
        { exp_desc =
            Texp_struct_item
              ( { str_desc =
                    Tstr_open
                      { open_expr =
                          { mod_desc = Tmod_ident (p, { txt = longident }) }
                      }
                },
                _ );
          _
        } )
    :: _ as ancestors -> Some (p, longident, ancestors)
  | (_, Pattern { pat_extra; _ }) :: ancestors
    when List.exists pat_extra ~f:(function
           | Tpat_open _, _, _ -> true
           | _ -> false) ->
    let p, longident =
      List.find_map pat_extra ~f:(function
        | Tpat_open (p, { txt = longident }, _), _, _ -> Some (p, longident)
        | _ -> None)
    in
    Some (p, longident, ancestors)
  | [] -> None
  | _ :: ancestors -> select_open_node ancestors

let of_structure str =
  let env =
    match str.str_items with
    | [] -> str.str_final_env
    | item :: _ -> item.str_env
  in
  [ (env, Browse_raw.Structure str) ]

let of_signature sg =
  let env =
    match sg.sig_items with
    | [] -> sg.sig_final_env
    | item :: _ -> item.sig_env
  in
  [ (env, Browse_raw.Signature sg) ]

let of_typedtree = function
  | `Implementation str -> of_structure str
  | `Interface sg -> of_signature sg

let optional_label_sugar = function
  | Typedtree.Texp_construct (id, _, [ e ])
    when id.Location.loc.Location.loc_ghost
         && id.Location.txt = Longident.Lident "Some" -> Some e
  | _ -> None

let rec is_recovered_expression e =
  match e.Typedtree.exp_desc with
  (* Recovery on arbitrary expressions *)
  | Texp_tuple [ _ ] -> true
  (* Recovery on unbound identifier *)
  | Texp_ident (Path.Pident id, _, _) when Ident.name id = "*type-error*" ->
    true
  (* Recovery on desugared optional label application *)
  | Texp_construct _ as cstr when is_recovered_Texp_construct cstr -> true
  | _ -> false

and is_recovered_Texp_construct cstr =
  match optional_label_sugar cstr with
  | Some e -> is_recovered_expression e
  | _ -> false

let is_recovered = function
  | Expression e -> is_recovered_expression e
  | _ -> false

let print_node () node = Browse_raw.string_of_node node

let print = Typed.print
