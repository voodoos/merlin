open! Std
let {Logger. log} = Logger.for_section "env-lookup"

module Namespace = struct
  type t = [
    | `Vals
    | `Type
    | `Constr
    | `Mod
    | `Modtype
    | `Functor
    | `Labels
    | `Unknown
    | `Apply
  ]

  let to_string = function
    | `Vals -> "(value) "
    | `Type -> "(type) "
    | `Constr -> "(constructor) "
    | `Mod -> "(module) "
    | `Modtype -> "(module type) "
    | `Functor -> "(functor)"
    | `Labels -> "(label) "
    | `Unknown -> "(unknown)"
    | `Apply -> "(functor application)"

  type under_type = [ `Constr | `Labels ]

  type inferred_basic = (* TODO: share with [Namespace.t] *)
    [ `Type | `Mod | `Modtype | `Vals | under_type ]

  type inferred =
    [ inferred_basic
    | `This_label of Types.label_description
    | `This_cstr of Types.constructor_description ]

  let from_context : Context.t -> inferred list = function
    | Type          -> [ `Type ; `Mod ; `Modtype ; `Constr ; `Labels ; `Vals ]
    | Module_type   -> [ `Modtype ; `Mod ; `Type ; `Constr ; `Labels ; `Vals ]
    | Expr | Constant ->
      [ `Vals ; `Mod ; `Modtype ; `Constr ; `Labels ; `Type ]
    | Patt          -> [ `Mod ; `Modtype ; `Type ; `Constr ; `Labels ; `Vals ]
    | Unknown       -> [ `Vals ; `Type ; `Constr ; `Mod ; `Modtype ; `Labels ]
    | Label lbl     -> [ `This_label lbl ]
    | Module_path   -> [ `Mod ]
    | Constructor (c, _) -> [ `This_cstr c ]
end

type declaration = {
  uid: Shape.Uid.t;
  loc: Location.t;
  namespace: Shape.Sig_component_kind.t
}

let loc path (namespace : Namespace.t) env =
  try
    let loc, uid, namespace =
      match namespace with
      | `Unknown
      | `Apply
      | `Vals ->
        let vd = Env.find_value path env in
        vd.val_loc, vd.val_uid, Shape.Sig_component_kind.Value
      | `Constr
      | `Labels
      | `Type ->
        let td = Env.find_type path env in
        td.type_loc, td.type_uid, Shape.Sig_component_kind.Type
      | `Functor
      | `Mod ->
        let md = Env.find_module path env in
        md.md_loc, md.md_uid, Shape.Sig_component_kind.Module
      | `Modtype ->
        let mtd = Env.find_modtype path env in
        mtd.mtd_loc, mtd.mtd_uid, Shape.Sig_component_kind.Module_type
    in
    Some { uid; loc; namespace }
  with
    Not_found -> None

exception Found of
  (Path.t * Shape.Sig_component_kind.t * Shape.Uid.t * Location.t)

let path_and_loc_of_cstr desc _ =
  let open Types in
  match desc.cstr_tag with
  | Cstr_extension (path, _) -> path, desc.cstr_loc
  | _ ->
    match get_desc desc.cstr_res with
    | Tconstr (path, _, _) -> path, desc.cstr_loc
    | _ -> assert false

let path_and_loc_from_label desc env =
  let open Types in
  match get_desc desc.lbl_res with
  | Tconstr (path, _, _) ->
    let typ_decl = Env.find_type path env in
    path, typ_decl.Types.type_loc
  | _ -> assert false

let in_namespaces (nss : Namespace.inferred list) ident env =
  let open Shape.Sig_component_kind in
  try
    List.iter nss ~f:(fun namespace ->
      try
        match namespace with
        | `This_cstr ({ Types.cstr_tag = Cstr_extension _; _ } as cd) ->
          log ~title:"lookup"
            "got extension constructor";
          let path, loc = path_and_loc_of_cstr cd env in
          (* TODO: Use [`Constr] here instead of [`Type] *)
          raise (Found (path, Extension_constructor, cd.cstr_uid, loc))
        | `This_cstr cd ->
          log ~title:"lookup"
            "got constructor, fetching path and loc in type namespace";
          let path, loc = path_and_loc_of_cstr cd env in
          log ~title:"lookup" "found path: %a"
            Logger.fmt (fun fmt -> Path.print fmt path);
          let path = Path.Pdot (path, cd.cstr_name)
          in
          raise (Found (path, Constructor, cd.cstr_uid, loc))
        | `Constr ->
          log ~title:"lookup" "lookup in constructor namespace" ;
          let cd = Env.find_constructor_by_name ident env in
          let path, loc = path_and_loc_of_cstr cd env in
          let path = Path.Pdot (path, cd.cstr_name) in
          (* TODO: Use [`Constr] here instead of [`Type] *)
          raise (Found (path, Constructor,cd.cstr_uid, loc))
        | `Mod ->
          log ~title:"lookup" "lookup in module namespace" ;
          let path, md = Env.find_module_by_name ident env in
          raise (Found (path, Module, md.md_uid, md.Types.md_loc))
        | `Modtype ->
          let path, mtd = Env.find_modtype_by_name ident env in
          raise
            (Found (path, Module_type, mtd.mtd_uid, mtd.Types.mtd_loc))
        | `Type ->
          log ~title:"lookup" "lookup in type namespace" ;
          let path, typ_decl = Env.find_type_by_name ident env in
          raise (
            Found
              (path, Type, typ_decl.type_uid, typ_decl.Types.type_loc)
          )
        | `Vals ->
          log ~title:"lookup" "lookup in value namespace" ;
          let path, val_desc = Env.find_value_by_name ident env in
          raise (
            Found
              (path, Value, val_desc.val_uid, val_desc.Types.val_loc)
          )
        | `This_label lbl ->
          log ~title:"lookup"
            "got label, fetching path and loc in type namespace";
          let path, loc = path_and_loc_from_label lbl env in
          let path = Path.Pdot (path, lbl.lbl_name)
          in
          raise (Found (path, Label, lbl.lbl_uid, loc))
        | `Labels ->
          log ~title:"lookup" "lookup in label namespace" ;
          let lbl = Env.find_label_by_name ident env in
          let path, loc = path_and_loc_from_label lbl env in
          (* TODO: Use [`Labels] here instead of [`Type] *)
          raise (Found (path, Type, lbl.lbl_uid, loc))
      with Not_found -> ()
    ) ;
    log ~title:"lookup" "   ... not in the environment" ;
    None
  with Found (path, namespace, decl_uid, loc) ->
    log ~title:"env_lookup" "found: '%a' in namespace %s with decl_uid %a\nat loc %a"
      Logger.fmt (fun fmt -> Path.print fmt path)
      (Shape.Sig_component_kind.to_string namespace)
      Logger.fmt (fun fmt -> Shape.Uid.print fmt decl_uid)
      Logger.fmt (fun fmt -> Location.print_loc fmt loc);
    Some (path, { uid = decl_uid; loc; namespace })
