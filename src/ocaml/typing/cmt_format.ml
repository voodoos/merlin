(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                   Fabrice Le Fessant, INRIA Saclay                     *)
(*                                                                        *)
(*   Copyright 2012 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** cmt and cmti files format. *)
open Std
open Cmi_format

(* Note that in Typerex, there is an awful hack to save a cmt file
   together with the interface file that was generated by ocaml (this
   is because the installed version of ocaml might differ from the one
   integrated in Typerex).
*)

(** The layout of a cmt file is as follows:
      <cmt> := \{<cmi>\} <cmt magic> \{cmt infos\} \{<source info>\}
    where <cmi> is the cmi file format:
      <cmi> := <cmi magic> <cmi info>.
    More precisely, the optional <cmi> part must be present if and only if
    the file is:
    - a cmti, or
    - a cmt, for a ml file which has no corresponding mli (hence no
    corresponding cmti).

    Thus, we provide a common reading function for cmi and cmt(i)
    files which returns an option for each of the three parts: cmi
    info, cmt info, source info. *)

open Typedtree


let read_magic_number ic =
  let len_magic_number = String.length Config.cmt_magic_number in
  really_input_string ic len_magic_number

type binary_annots =
  | Packed of Types.signature * string list
  | Implementation of structure
  | Interface of signature
  | Partial_implementation of binary_part array
  | Partial_interface of binary_part array

and binary_part =
  | Partial_structure of structure
  | Partial_structure_item of structure_item
  | Partial_expression of expression
  | Partial_pattern : 'k pattern_category * 'k general_pattern -> binary_part
  | Partial_class_expr of class_expr
  | Partial_signature of signature
  | Partial_signature_item of signature_item
  | Partial_module_type of module_type

type dependency_kind =  Definition_to_declaration | Declaration_to_declaration
type cmt_infos = {
  cmt_modname : string;
  cmt_annots : binary_annots;
  cmt_declaration_dependencies : (dependency_kind * Uid.t * Uid.t) list;
  cmt_comments : (string * Location.t) list;
  cmt_args : string array;
  cmt_sourcefile : string option;
  cmt_builddir : string;
  cmt_loadpath : Load_path.paths;
  cmt_source_digest : Digest.t option;
  cmt_initial_env : Env.t;
  cmt_imports : (string * Digest.t option) list;
  cmt_interface_digest : Digest.t option;
  cmt_use_summaries : bool;
  cmt_uid_to_decl : item_declaration Shape.Uid.Tbl.t;
  cmt_impl_shape : Shape.t option; (* None for mli *)
  cmt_ident_occurrences :
    (Longident.t Location.loc * Shape_reduce.result) list
}

type error =
    Not_a_typedtree of string

let iter_on_parts (it : Tast_iterator.iterator) = function
  | Partial_structure s -> it.structure it s
  | Partial_structure_item s -> it.structure_item it s
  | Partial_expression e -> it.expr it e
  | Partial_pattern (_category, p) -> it.pat it p
  | Partial_class_expr ce -> it.class_expr it ce
  | Partial_signature s -> it.signature it s
  | Partial_signature_item s -> it.signature_item it s
  | Partial_module_type s -> it.module_type it s

let iter_on_annots (it : Tast_iterator.iterator) = function
  | Implementation s -> it.structure it s
  | Interface s -> it.signature it s
  | Packed _ -> ()
  | Partial_implementation array -> Array.iter (iter_on_parts it) array
  | Partial_interface array -> Array.iter (iter_on_parts it) array

let iter_on_declaration f decl =
  match decl with
  | Value vd -> f vd.val_val.val_uid decl;
  | Value_binding vb ->
      let bound_idents = let_bound_idents_full [vb] in
      List.iter ~f:(fun (_, _, _, uid) -> f uid decl) bound_idents
  | Type td ->
      if not (Btype.is_row_name (Ident.name td.typ_id)) then
        f td.typ_type.type_uid (Type td)
  | Constructor cd -> f cd.cd_uid decl
  | Extension_constructor ec -> f ec.ext_type.ext_uid decl;
  | Label ld -> f ld.ld_uid decl
  | Module md -> f md.md_uid decl
  | Module_type mtd -> f mtd.mtd_uid decl
  | Module_substitution ms -> f ms.ms_uid decl
  | Module_binding mb -> f mb.mb_uid decl
  | Class cd -> f cd.ci_decl.cty_uid decl
  | Class_type ct -> f ct.ci_decl.cty_uid decl

let iter_on_declarations ~(f: Shape.Uid.t -> item_declaration -> unit) = {
  Tast_iterator.default_iterator with
  item_declaration = (fun _sub decl -> iter_on_declaration f decl);
}

let need_to_clear_env =
  try ignore (Sys.getenv "OCAML_BINANNOT_WITHENV"); false
  with Not_found -> true

let keep_only_summary = Env.keep_only_summary

let cenv =
  {Tast_mapper.default with env = fun _sub env -> keep_only_summary env}

let clear_part = function
  | Partial_structure s -> Partial_structure (cenv.structure cenv s)
  | Partial_structure_item s ->
      Partial_structure_item (cenv.structure_item cenv s)
  | Partial_expression e -> Partial_expression (cenv.expr cenv e)
  | Partial_pattern (category, p) -> Partial_pattern (category, cenv.pat cenv p)
  | Partial_class_expr ce -> Partial_class_expr (cenv.class_expr cenv ce)
  | Partial_signature s -> Partial_signature (cenv.signature cenv s)
  | Partial_signature_item s ->
      Partial_signature_item (cenv.signature_item cenv s)
  | Partial_module_type s -> Partial_module_type (cenv.module_type cenv s)

let clear_env binary_annots =
  if need_to_clear_env then
    match binary_annots with
    | Implementation s -> Implementation (cenv.structure cenv s)
    | Interface s -> Interface (cenv.signature cenv s)
    | Packed _ -> binary_annots
    | Partial_implementation array ->
        Partial_implementation (Array.map clear_part array)
    | Partial_interface array ->
        Partial_interface (Array.map clear_part array)

  else binary_annots

(* Every typedtree node with a located longident corresponding to user-facing
   syntax should be indexed. *)
let iter_on_occurrences
  ~(f : namespace:Shape.Sig_component_kind.t ->
        Env.t -> Path.t -> Longident.t Location.loc ->
        unit) =
  let path_in_type typ name =
    match Types.get_desc typ with
    | Tconstr (type_path, _, _) ->
      Some (Path.Pextra_ty(type_path, Pcstr_ty name))
    | _ -> None
  in
  let add_constructor_description env lid =
    function
    | { Data_types.cstr_tag = Cstr_extension (path, _); _ } ->
        f ~namespace:Extension_constructor env path lid
    | { Data_types.cstr_uid = Predef name; _} ->
        let id = List.assoc name Predef.builtin_idents in
        f ~namespace:Constructor env (Pident id) lid
    | { Data_types.cstr_res; cstr_name; _ } ->
        let path = path_in_type cstr_res cstr_name in
        Option.iter ~f:(fun path -> f ~namespace:Constructor env path lid) path
  in
  let add_label env lid { Data_types.lbl_name; lbl_res; _ } =
    let path = path_in_type lbl_res lbl_name in
    Option.iter ~f:(fun path -> f ~namespace:Label env path lid) path
  in
  let with_constraint ~env (_path, _lid, with_constraint) =
    match with_constraint with
    | Twith_module (path', lid') | Twith_modsubst (path', lid') ->
        f ~namespace:Module env path' lid'
    | _ -> ()
  in
  Tast_iterator.{ default_iterator with

  expr = (fun sub ({ exp_desc; exp_env; _ } as e) ->
      (match exp_desc with
      | Texp_ident (path, lid, _) ->
          f ~namespace:Value exp_env path lid
      | Texp_construct (lid, constr_desc, _) ->
          add_constructor_description exp_env lid constr_desc
      | Texp_field (_, lid, label_desc)
      | Texp_setfield (_, lid, label_desc, _) ->
          add_label exp_env lid label_desc
      | Texp_new (path, lid, _) ->
          f ~namespace:Class exp_env path lid
      | Texp_record { fields; _ } ->
        Array.iter (fun (label_descr, record_label_definition) ->
          match record_label_definition with
          | Overridden (
              { Location.txt; loc},
              {exp_loc; _})
              when not exp_loc.loc_ghost
                && loc.loc_start = exp_loc.loc_start
                && loc.loc_end = exp_loc.loc_end ->
            (* In the presence of punning we want to index the label
                even if it is ghosted *)
            let lid = { Location.txt; loc = {loc with loc_ghost = false} } in
            add_label exp_env lid label_descr
          | Overridden (lid, _) -> add_label exp_env lid label_descr
          | Kept _ -> ()) fields
      | Texp_instvar  (_self_path, path, name) ->
          let lid = { name with txt = Longident.Lident name.txt } in
          f ~namespace:Value exp_env path lid
      | Texp_setinstvar  (_self_path, path, name, _) ->
          let lid = { name with txt = Longident.Lident name.txt } in
          f ~namespace:Value exp_env path lid
      | Texp_override (_self_path, modifs) ->
          List.iter ~f:(fun (id, (name : string Location.loc), _exp) ->
            let lid = { name with txt = Longident.Lident name.txt } in
            f ~namespace:Value exp_env (Path.Pident id) lid)
            modifs
      | Texp_extension_constructor (lid, path) ->
          f ~namespace:Extension_constructor exp_env path lid
      | Texp_constant _ | Texp_let _ | Texp_function _ | Texp_apply _
      | Texp_match _ | Texp_try _ | Texp_tuple _ | Texp_variant _ | Texp_array _
      | Texp_ifthenelse _ | Texp_sequence _ | Texp_while _ | Texp_for _
      | Texp_send _
      | Texp_letmodule _ | Texp_letexception _ | Texp_assert _ | Texp_lazy _
      | Texp_object _ | Texp_pack _ | Texp_letop _ | Texp_unreachable
      | Texp_open _ | Texp_typed_hole -> ());
      default_iterator.expr sub e);

  (* Remark: some types get iterated over twice due to how constraints are
      encoded in the typedtree. For example, in [let x : t = 42], [t] is
      present in both a [Tpat_constraint] and a [Texp_constraint] node) *)
  typ =
    (fun sub ({ ctyp_desc; ctyp_env; _ } as ct) ->
      (match ctyp_desc with
      | Ttyp_constr (path, lid, _ctyps) ->
          f ~namespace:Type ctyp_env path lid
      | Ttyp_package {pack_path; pack_txt} ->
          f ~namespace:Module_type ctyp_env pack_path pack_txt
      | Ttyp_class (path, lid, _typs) ->
          (* Deprecated syntax to extend a polymorphic variant *)
          f ~namespace:Type ctyp_env path lid
      |  Ttyp_open (path, lid, _ct) ->
          f ~namespace:Module ctyp_env path lid
      | Ttyp_any | Ttyp_var _ | Ttyp_arrow _ | Ttyp_tuple _ | Ttyp_object _
      | Ttyp_alias _ | Ttyp_variant _ | Ttyp_poly _ -> ());
      default_iterator.typ sub ct);

  pat =
    (fun (type a) sub
      ({ pat_desc; pat_extra; pat_env; _ } as pat : a general_pattern) ->
      (match pat_desc with
      | Tpat_construct (lid, constr_desc, _, _) ->
          add_constructor_description pat_env lid constr_desc
      | Tpat_record (fields, _) ->
        List.iter ~f:(fun (lid, label_descr, pat) ->
          let lid =
            let open Location in
            (* In the presence of punning we want to index the label
               even if it is ghosted *)
            if (not pat.pat_loc.loc_ghost
              && lid.loc.loc_start = pat.pat_loc.loc_start
              && lid.loc.loc_end = pat.pat_loc.loc_end)
            then {lid with loc = {lid.loc with loc_ghost = false}}
            else lid
          in
          add_label pat_env lid label_descr)
        fields
      | Tpat_any | Tpat_var _ | Tpat_alias _ | Tpat_constant _ | Tpat_tuple _
      | Tpat_variant _ | Tpat_array _ | Tpat_lazy _ | Tpat_value _
      | Tpat_exception _ | Tpat_or _ -> ());
      List.iter ~f:(fun (pat_extra, _, _) ->
        match pat_extra with
        | Tpat_open (path, lid, _) ->
            f ~namespace:Module pat_env path lid
        | Tpat_type (path, lid) ->
            f ~namespace:Type pat_env path lid
        | Tpat_constraint _ | Tpat_unpack -> ())
        pat_extra;
      default_iterator.pat sub pat);

  binding_op = (fun sub ({bop_op_path; bop_op_name; bop_exp; _} as bop) ->
    let lid = { bop_op_name with txt = Longident.Lident bop_op_name.txt } in
    f ~namespace:Value bop_exp.exp_env bop_op_path lid;
    default_iterator.binding_op sub bop);

  module_expr =
    (fun sub ({ mod_desc; mod_env; _ } as me) ->
      (match mod_desc with
      | Tmod_ident (path, lid) -> f ~namespace:Module mod_env path lid
      | Tmod_structure _ | Tmod_functor _ | Tmod_apply _ | Tmod_apply_unit _
      | Tmod_constraint _ | Tmod_unpack _ | Tmod_typed_hole -> ());
      default_iterator.module_expr sub me);

  open_description =
    (fun sub ({ open_expr = (path, lid); open_env; _ } as od)  ->
      f ~namespace:Module open_env path lid;
      default_iterator.open_description sub od);

  module_type =
    (fun sub ({ mty_desc; mty_env; _ } as mty)  ->
      (match mty_desc with
      | Tmty_ident (path, lid) ->
          f ~namespace:Module_type mty_env path lid
      | Tmty_with (_mty, l) ->
          List.iter ~f:(with_constraint ~env:mty_env) l
      | Tmty_alias (path, lid) ->
          f ~namespace:Module mty_env path lid
      | Tmty_signature _ | Tmty_functor _ | Tmty_typeof _ -> ());
      default_iterator.module_type sub mty);

  class_expr =
    (fun sub ({ cl_desc; cl_env; _} as ce) ->
      (match cl_desc with
      | Tcl_ident (path, lid, _) -> f ~namespace:Class cl_env path lid
      | Tcl_structure _ | Tcl_fun _ | Tcl_apply _ | Tcl_let _
      | Tcl_constraint _ | Tcl_open _ -> ());
      default_iterator.class_expr sub ce);

  class_type =
    (fun sub ({ cltyp_desc; cltyp_env; _} as ct) ->
      (match cltyp_desc with
      | Tcty_constr (path, lid, _) -> f ~namespace:Class_type cltyp_env path lid
      | Tcty_signature _ | Tcty_arrow _ | Tcty_open _ -> ());
      default_iterator.class_type sub ct);

  signature_item =
    (fun sub ({ sig_desc; sig_env; _ } as sig_item) ->
      (match sig_desc with
      | Tsig_exception {
          tyexn_constructor = { ext_kind = Text_rebind (path, lid)}} ->
          f ~namespace:Extension_constructor sig_env path lid
      | Tsig_modsubst { ms_manifest; ms_txt } ->
          f ~namespace:Module sig_env ms_manifest ms_txt
      | Tsig_typext { tyext_path; tyext_txt } ->
          f ~namespace:Type sig_env tyext_path tyext_txt
      | Tsig_value _ | Tsig_type _ | Tsig_typesubst _ | Tsig_exception _
      | Tsig_module _ | Tsig_recmodule _ | Tsig_modtype _ | Tsig_modtypesubst _
      | Tsig_open _ | Tsig_include _ | Tsig_class _ | Tsig_class_type _
      | Tsig_attribute _ -> ());
      default_iterator.signature_item sub sig_item);

  structure_item =
    (fun sub ({ str_desc; str_env; _ } as str_item) ->
      (match str_desc with
      | Tstr_exception {
          tyexn_constructor = { ext_kind = Text_rebind (path, lid)}} ->
          f ~namespace:Extension_constructor str_env path lid
      | Tstr_typext { tyext_path; tyext_txt } ->
          f ~namespace:Type str_env tyext_path tyext_txt
      | Tstr_eval _ | Tstr_value _ | Tstr_primitive _ | Tstr_type _
      | Tstr_exception _ | Tstr_module _ | Tstr_recmodule _
      | Tstr_modtype _ | Tstr_open _ | Tstr_class _ | Tstr_class_type _
      | Tstr_include _ | Tstr_attribute _ -> ());
      default_iterator.structure_item sub str_item)
}

let index_declarations binary_annots =
  let index : item_declaration Types.Uid.Tbl.t = Types.Uid.Tbl.create 16 in
  let f uid fragment = Types.Uid.Tbl.add index uid fragment in
  iter_on_annots (iter_on_declarations ~f) binary_annots;
  index

let index_occurrences binary_annots =
  let index : (Longident.t Location.loc * Shape_reduce.result) list ref =
    ref []
  in
  let f ~namespace env path lid =
    let not_ghost { Location.loc = { loc_ghost; _ }; _ } = not loc_ghost in
    let reduce_and_store ~namespace lid path = if not_ghost lid then
      match Env.shape_of_path ~namespace env path with
      | exception Not_found -> ()
      | { uid = Some (Predef _); _ } -> ()
      | path_shape ->
        let result = Shape_reduce.local_reduce_for_uid env path_shape in
        index := (lid, result) :: !index
    in
    (* Shape reduction can be expensive, but the persistent memoization tables
       should make these successive reductions fast. *)
    let rec index_components namespace lid path  =
      let module_ = Shape.Sig_component_kind.Module in
      match (lid.Location.txt : Longident.t), (path : Path.t) with
      | Ldot (lid', _), Pdot (path', _)
      | Ldot (lid', _), Pextra_ty (Pdot(path', _), Pcstr_ty _) ->
        reduce_and_store ~namespace lid path;
        index_components module_ lid' path'
      | Lapply (lid', lid''), Papply (path', path'')
      | Lapply (lid', lid''), Pextra_ty (Papply (path', path''), Pcstr_ty _) ->
        index_components module_ lid'' path'';
        index_components module_ lid' path'
      | Lident _, _ ->
        reduce_and_store ~namespace lid path;
      | _, _ -> ()
    in
    index_components namespace lid path
  in
  iter_on_annots (iter_on_occurrences ~f) binary_annots;
  !index

exception Error of error

let input_cmt ic = (input_value ic : cmt_infos)

let output_cmt oc cmt =
  ignore (oc, cmt)
  (*
  output_string oc Config.cmt_magic_number;
  Marshal.(to_channel oc (cmt : cmt_infos) [Compression])
  *)

let read filename =
(*  Printf.fprintf stderr "Cmt_format.read %s\n%!" filename; *)
  let ic = open_in_bin filename in
  Misc.try_finally
    ~always:(fun () -> close_in ic)
    (fun () ->
       let magic_number = read_magic_number ic in
       let cmi, cmt =
         if magic_number = Config.cmt_magic_number then
           None, Some (input_cmt ic)
         else if magic_number = Config.cmi_magic_number then
           let cmi = Cmi_format.input_cmi ic in
           let cmt = try
               let magic_number = read_magic_number ic in
               if magic_number = Config.cmt_magic_number then
                 let cmt = input_cmt ic in
                 Some cmt
               else None
             with _ -> None
           in
           Some cmi, cmt
         else
           raise Magic_numbers.Cmi.(Error(Not_an_interface filename))
       in
       cmi, cmt
    )

let read_cmt filename =
  match read filename with
      _, None -> raise (Error (Not_a_typedtree filename))
    | _, Some cmt -> cmt

let read_cmi filename =
  match read filename with
      None, _ ->
        raise Magic_numbers.Cmi.(Error (Not_an_interface filename))
    | Some cmi, _ -> cmi

let saved_types = ref []
let uids_deps : (dependency_kind * Uid.t * Uid.t) list ref = ref []

let clear () =
  saved_types := [];
  uids_deps := []

let add_saved_type b = saved_types := b :: !saved_types
let get_saved_types () = !saved_types
let set_saved_types l = saved_types := l

let get_declaration_dependencies () = !uids_deps

let record_declaration_dependency (rk, uid1, uid2) =
  if not (Uid.equal uid1 uid2) then
    uids_deps := (rk, uid1, uid2) :: !uids_deps

let save_cmt target binary_annots initial_env cmi shape =
  if !Clflags.binary_annotations && not !Clflags.print_types then begin
    Misc.output_to_file_via_temporary
       ~mode:[Open_binary] (Unit_info.Artifact.filename target)
       (fun temp_file_name oc ->
         let this_crc =
           match cmi with
           | None -> None
           | Some cmi -> Some (output_cmi temp_file_name oc cmi)
         in
         let sourcefile = Unit_info.Artifact.source_file target in
         let cmt_ident_occurrences =
          if !Clflags.store_occurrences then
            index_occurrences binary_annots
          else
            []
         in
         let cmt_annots = clear_env binary_annots in
         let cmt_uid_to_decl = index_declarations cmt_annots in
         let source_digest = Option.map ~f:Digest.file sourcefile in
         let cmt = {
           cmt_modname = Unit_info.Artifact.modname target;
           cmt_annots;
           cmt_declaration_dependencies = !uids_deps;
           cmt_comments = [];
           cmt_args = Sys.argv;
           cmt_sourcefile = sourcefile;
           cmt_builddir = Location.rewrite_absolute_path (Sys.getcwd ());
           cmt_loadpath = Load_path.get_paths ();
           cmt_source_digest = source_digest;
           cmt_initial_env = if need_to_clear_env then
               keep_only_summary initial_env else initial_env;
           cmt_imports = List.sort ~cmp:compare (Env.imports ());
           cmt_interface_digest = this_crc;
           cmt_use_summaries = need_to_clear_env;
           cmt_uid_to_decl;
           cmt_impl_shape = shape;
           cmt_ident_occurrences;
         } in
         output_cmt oc cmt)
  end;
  clear ()
