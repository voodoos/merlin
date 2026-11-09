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

(** {1 Accessors} *)

let string_of_node = function
  | Structure _ -> "structure"
  | Signature _ -> "signature"
  | Structure_item _ -> "structure_item"
  | Signature_item _ -> "signature_item"
  | Expression _ -> "expression"
  | Pattern _ -> "pattern"
  | Core_type _ -> "core_type"
  | Case _ -> "case"
  | Value_binding _ -> "value_binding"
  | Binding_op _ -> "binding_op"
  | Module_expr _ -> "module_expr"
  | Module_type _ -> "module_type"
  | Module_binding _ -> "module_binding"
  | Module_declaration _ -> "module_declaration"
  | Module_substitution _ -> "module_substitution"
  | Module_type_declaration _ -> "module_type_declaration"
  | Open_declaration _ -> "open_declaration"
  | Open_description _ -> "open_description"
  | Include_declaration _ -> "include_declaration"
  | Include_description _ -> "include_description"
  | Value_description _ -> "value_description"
  | Type_declaration _ -> "type_declaration"
  | Type_kind _ -> "type_kind"
  | Type_extension _ -> "type_extension"
  | Type_exception _ -> "type_exception"
  | Extension_constructor _ -> "extension_constructor"
  | Label_declaration _ -> "label_declaration"
  | Constructor_declaration _ -> "constructor_declaration"
  | Row_field _ -> "row_field"
  | Object_field _ -> "object_field"
  | Package_type _ -> "package_type"
  | With_constraint _ -> "with_constraint"
  | Class_declaration _ -> "class_declaration"
  | Class_description _ -> "class_description"
  | Class_type_declaration _ -> "class_type_declaration"
  | Class_expr _ -> "class_expr"
  | Class_structure _ -> "class_structure"
  | Class_field _ -> "class_field"
  | Class_type _ -> "class_type"
  | Class_signature _ -> "class_signature"
  | Class_type_field _ -> "class_type_field"

let node_real_loc loc0 node =
  let loc =
    match node with
    | Structure _
    | Signature _
    | Case _
    | Type_kind _
    | With_constraint _
    | Class_structure _
    | Class_signature _ -> loc0
    | Structure_item { pstr_loc = loc; _ }
    | Signature_item { psig_loc = loc; _ }
    | Expression { pexp_loc = loc; _ }
    | Pattern { ppat_loc = loc; _ }
    | Core_type { ptyp_loc = loc; _ }
    | Value_binding { pvb_loc = loc; _ }
    | Binding_op { pbop_loc = loc; _ }
    | Module_expr { pmod_loc = loc; _ }
    | Module_type { pmty_loc = loc; _ }
    | Module_binding { pmb_loc = loc; _ }
    | Module_declaration { pmd_loc = loc; _ }
    | Module_substitution { pms_loc = loc; _ }
    | Module_type_declaration { pmtd_loc = loc; _ }
    | Open_declaration { popen_loc = loc; _ }
    | Open_description { popen_loc = loc; _ }
    | Include_declaration { pincl_loc = loc; _ }
    | Include_description { pincl_loc = loc; _ }
    | Value_description { pval_loc = loc; _ }
    | Type_declaration { ptype_loc = loc; _ }
    | Type_extension { ptyext_loc = loc; _ }
    | Type_exception { ptyexn_loc = loc; _ }
    | Extension_constructor { pext_loc = loc; _ }
    | Label_declaration { pld_loc = loc; _ }
    | Constructor_declaration { pcd_loc = loc; _ }
    | Row_field { prf_loc = loc; _ }
    | Object_field { pof_loc = loc; _ }
    | Package_type { ppt_loc = loc; _ }
    | Class_declaration { pci_loc = loc; _ }
    | Class_description { pci_loc = loc; _ }
    | Class_type_declaration { pci_loc = loc; _ }
    | Class_expr { pcl_loc = loc; _ }
    | Class_field { pcf_loc = loc; _ }
    | Class_type { pcty_loc = loc; _ }
    | Class_type_field { pctf_loc = loc; _ } -> loc
  in
  (* Some nodes synthesized by the parser carry an empty location, for instance
     the [open] item of [M.(e)]. Treat them as if they had no location at all,
     so that their location is approximated from their children. *)
  if loc = Location.none then loc0 else loc

let node_attributes = function
  | Structure _
  | Signature _
  | Case _
  | Type_kind _
  | With_constraint _
  | Class_structure _
  | Class_signature _
  | Binding_op _ -> []
  | Structure_item
      { pstr_desc = Pstr_eval (_, attrs) | Pstr_extension (_, attrs); _ }
  | Signature_item { psig_desc = Psig_extension (_, attrs); _ } -> attrs
  | Structure_item { pstr_desc = Pstr_attribute attr; _ }
  | Signature_item { psig_desc = Psig_attribute attr; _ } -> [ attr ]
  | Structure_item _ | Signature_item _ -> []
  | Expression { pexp_attributes = attrs; _ }
  | Pattern { ppat_attributes = attrs; _ }
  | Core_type { ptyp_attributes = attrs; _ }
  | Value_binding { pvb_attributes = attrs; _ }
  | Module_expr { pmod_attributes = attrs; _ }
  | Module_type { pmty_attributes = attrs; _ }
  | Module_binding { pmb_attributes = attrs; _ }
  | Module_declaration { pmd_attributes = attrs; _ }
  | Module_substitution { pms_attributes = attrs; _ }
  | Module_type_declaration { pmtd_attributes = attrs; _ }
  | Open_declaration { popen_attributes = attrs; _ }
  | Open_description { popen_attributes = attrs; _ }
  | Include_declaration { pincl_attributes = attrs; _ }
  | Include_description { pincl_attributes = attrs; _ }
  | Value_description { pval_attributes = attrs; _ }
  | Type_declaration { ptype_attributes = attrs; _ }
  | Type_extension { ptyext_attributes = attrs; _ }
  | Type_exception { ptyexn_attributes = attrs; _ }
  | Extension_constructor { pext_attributes = attrs; _ }
  | Label_declaration { pld_attributes = attrs; _ }
  | Constructor_declaration { pcd_attributes = attrs; _ }
  | Row_field { prf_attributes = attrs; _ }
  | Object_field { pof_attributes = attrs; _ }
  | Package_type { ppt_attrs = attrs; _ }
  | Class_declaration { pci_attributes = attrs; _ }
  | Class_description { pci_attributes = attrs; _ }
  | Class_type_declaration { pci_attributes = attrs; _ }
  | Class_expr { pcl_attributes = attrs; _ }
  | Class_field { pcf_attributes = attrs; _ }
  | Class_type { pcty_attributes = attrs; _ }
  | Class_type_field { pctf_attributes = attrs; _ } -> attrs

let has_attr ~name node =
  List.exists (node_attributes node) ~f:(fun attr ->
      let str, _ = Ast_helper.Attr.as_tuple attr in
      str.Location.txt = name)

let node_merlin_loc loc0 node =
  let loc = node_real_loc loc0 node in
  let pred { attr_name; _ } = Location_aux.is_relaxed_location attr_name in
  match List.find (node_attributes node) ~f:pred with
  | { attr_name; _ } -> attr_name.Location.loc
  | exception Not_found -> loc

(** {1 One-level fold}

    Rather than duplicating the traversal of every Parsetree constructor, the
    direct children of a node are enumerated with {!Ast_iterator}: the
    [collector] iterator records the nodes it is given instead of recursing
    into them, and [dispatch] applies the {e default} iterator to the node, which
    visits exactly its direct children through [collector].

    The children are collected in a global accumulator, then folded over. No
    user code runs during the collection, so re-entrancy is not a concern. *)

let children : node list ref = ref []

let push node = children := node :: !children

let collector =
  let open Ast_iterator in
  { default_iterator with
    (* Attributes are never traversed. *)
    attribute = (fun _ _ -> ());
    attributes = (fun _ _ -> ());
    structure = (fun _ x -> push (Structure x));
    signature = (fun _ x -> push (Signature x));
    structure_item = (fun _ x -> push (Structure_item x));
    signature_item = (fun _ x -> push (Signature_item x));
    expr = (fun _ x -> push (Expression x));
    pat = (fun _ x -> push (Pattern x));
    typ = (fun _ x -> push (Core_type x));
    case = (fun _ x -> push (Case x));
    value_binding = (fun _ x -> push (Value_binding x));
    binding_op = (fun _ x -> push (Binding_op x));
    module_expr = (fun _ x -> push (Module_expr x));
    module_type = (fun _ x -> push (Module_type x));
    module_binding = (fun _ x -> push (Module_binding x));
    module_declaration = (fun _ x -> push (Module_declaration x));
    module_substitution = (fun _ x -> push (Module_substitution x));
    module_type_declaration = (fun _ x -> push (Module_type_declaration x));
    open_declaration = (fun _ x -> push (Open_declaration x));
    open_description = (fun _ x -> push (Open_description x));
    include_declaration = (fun _ x -> push (Include_declaration x));
    include_description = (fun _ x -> push (Include_description x));
    value_description = (fun _ x -> push (Value_description x));
    type_declaration = (fun _ x -> push (Type_declaration x));
    type_kind = (fun _ x -> push (Type_kind x));
    type_extension = (fun _ x -> push (Type_extension x));
    type_exception = (fun _ x -> push (Type_exception x));
    extension_constructor = (fun _ x -> push (Extension_constructor x));
    label_declaration = (fun _ x -> push (Label_declaration x));
    constructor_declaration = (fun _ x -> push (Constructor_declaration x));
    row_field = (fun _ x -> push (Row_field x));
    object_field = (fun _ x -> push (Object_field x));
    package_type = (fun _ x -> push (Package_type x));
    with_constraint = (fun _ x -> push (With_constraint x));
    class_declaration = (fun _ x -> push (Class_declaration x));
    class_description = (fun _ x -> push (Class_description x));
    class_type_declaration = (fun _ x -> push (Class_type_declaration x));
    class_expr = (fun _ x -> push (Class_expr x));
    class_structure = (fun _ x -> push (Class_structure x));
    class_field = (fun _ x -> push (Class_field x));
    class_type = (fun _ x -> push (Class_type x));
    class_signature = (fun _ x -> push (Class_signature x));
    class_type_field = (fun _ x -> push (Class_type_field x))
  }

let dispatch node =
  let d = Ast_iterator.default_iterator in
  match node with
  | Structure x -> d.structure collector x
  | Signature x -> d.signature collector x
  | Structure_item x -> d.structure_item collector x
  | Signature_item x -> d.signature_item collector x
  | Expression x -> d.expr collector x
  | Pattern x -> d.pat collector x
  (* The default iterator visits the fields of variant and object types
     inline, without going through the [row_field] and [object_field] hooks.
     Expose them as nodes anyway. *)
  | Core_type { ptyp_desc = Ptyp_variant (fields, _, _); _ } ->
    List.iter fields ~f:(fun x -> push (Row_field x))
  | Core_type { ptyp_desc = Ptyp_object (fields, _); _ } ->
    List.iter fields ~f:(fun x -> push (Object_field x))
  | Core_type x -> d.typ collector x
  | Case x -> d.case collector x
  | Value_binding x -> d.value_binding collector x
  | Binding_op x -> d.binding_op collector x
  | Module_expr x -> d.module_expr collector x
  | Module_type x -> d.module_type collector x
  | Module_binding x -> d.module_binding collector x
  | Module_declaration x -> d.module_declaration collector x
  | Module_substitution x -> d.module_substitution collector x
  | Module_type_declaration x -> d.module_type_declaration collector x
  | Open_declaration x -> d.open_declaration collector x
  | Open_description x -> d.open_description collector x
  | Include_declaration x -> d.include_declaration collector x
  | Include_description x -> d.include_description collector x
  | Value_description x -> d.value_description collector x
  | Type_declaration x -> d.type_declaration collector x
  | Type_kind x -> d.type_kind collector x
  | Type_extension x -> d.type_extension collector x
  | Type_exception x -> d.type_exception collector x
  | Extension_constructor x -> d.extension_constructor collector x
  | Label_declaration x -> d.label_declaration collector x
  | Constructor_declaration x -> d.constructor_declaration collector x
  | Row_field x -> d.row_field collector x
  | Object_field x -> d.object_field collector x
  | Package_type x -> d.package_type collector x
  | With_constraint x -> d.with_constraint collector x
  | Class_declaration x -> d.class_declaration collector x
  | Class_description x -> d.class_description collector x
  | Class_type_declaration x -> d.class_type_declaration collector x
  | Class_expr x -> d.class_expr collector x
  | Class_structure x -> d.class_structure collector x
  | Class_field x -> d.class_field collector x
  | Class_type x -> d.class_type collector x
  | Class_signature x -> d.class_signature collector x
  | Class_type_field x -> d.class_type_field collector x

let fold_node f node acc =
  children := [];
  dispatch node;
  (* Children were pushed in reverse source order. *)
  let nodes = List.rev !children in
  children := [];
  List.fold_left nodes ~init:acc ~f:(fun acc node -> f node acc)

(** {1 Navigation} *)

include (
  Mbrowse_generic.Make (struct
    type t = node

    let fold = fold_node
    let real_loc = node_real_loc
    let merlin_loc = node_merlin_loc
    let is_hidden = has_attr ~name:"merlin.hide"
    let is_focus = has_attr ~name:"merlin.focus"
    let to_string = string_of_node
  end) :
    Mbrowse_generic.S with type node := node)

let node_loc = loc

module Tie_breaker = struct
  type t = disambiguate

  let prefer_expression node1 node2 : Mbrowse_generic.tie_break option =
    match (node1, node2) with
    | Expression _, Expression _ -> None
    | Expression _, _ -> Some Prefer_first
    | _, Expression _ -> Some Prefer_second
    | _ -> None
end

let of_structure str = [ Structure str ]
let of_signature sg = [ Signature sg ]

let of_parsetree = function
  | `Implementation str -> of_structure str
  | `Interface sg -> of_signature sg

let print_node () node = string_of_node node
