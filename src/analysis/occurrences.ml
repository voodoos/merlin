open Std
module LidSet = Index_format.LidSet

let {Logger. log} = Logger.for_section "occurrences"

let decl_of_path_or_lid env namespace path lid =
  match (namespace : Shape.Sig_component_kind.t) with
  | Constructor ->
    begin match Env.find_constructor_by_name lid env with
    | exception Not_found -> None
    | {cstr_uid; cstr_loc; _ } ->
      Some { Env_lookup.uid = cstr_uid; loc = cstr_loc; namespace }
    end
  | Label ->
    begin match Env.find_label_by_name lid env with
    | exception Not_found -> None
    | {lbl_uid; lbl_loc; _ } ->
      Some { Env_lookup.uid = lbl_uid; loc = lbl_loc; namespace }
    end
  | _ -> Env_lookup.loc path namespace env

let index_buffer ~local_defs () =
  let {Logger. log} = Logger.for_section "index" in
  let defs = Hashtbl.create 64 in
  let module Shape_reduce =
    Shape.Make_reduce (struct
      type env = Env.t

      let fuel = 10

      let read_unit_shape ~unit_name =
          log ~title:"read_unit_shape" "inspecting %s" unit_name;
          let cmt = Format.sprintf "%s.cmt" unit_name in
          match Cmt_format.read (Load_path.find_uncap cmt) with
          | _, Some cmt_infos ->
            log ~title:"read_unit_shape" "shapes loaded for %s" unit_name;
            cmt_infos.cmt_impl_shape
          | exception _ | _ ->
            log ~title:"read_unit_shape" "failed to find %s" unit_name;
            None

      let find_shape env id = Env.shape_of_path
        ~namespace:Shape.Sig_component_kind.Module env (Pident id)
    end)
  in
  let f ~namespace env path lid  =
    let not_ghost { Location.loc = { loc_ghost; _ }; _ } = not loc_ghost in
    if not_ghost lid then
      match Env.shape_of_path ~namespace env path with
      | exception Not_found -> ()
      | path_shape ->
        begin match Shape_reduce.reduce_for_uid env path_shape with
        | Shape.Approximated _ | Missing_uid -> ()
        | Resolved uid ->
          Index_format.(add defs uid (LidSet.singleton lid))
        | Unresolved s ->
          log ~title:"index_buffer" "Could not resolve shape %a"
            Logger.fmt (Fun.flip Shape.print s);
          begin match decl_of_path_or_lid env namespace path lid.txt with
          | exception _ |  None -> log ~title:"index_buffer" "Declaration not found"
          | Some decl ->
            log ~title:"index_buffer" "Found the declaration: %a"
              Logger.fmt (Fun.flip Location.print_loc decl.loc);
            Index_format.(add defs decl.uid (LidSet.singleton lid))
          end
        end
  in
  Ast_iterators.iter_on_usages ~f local_defs;
  defs

let merge_tbl ~into tbl = Hashtbl.iter (Index_format.add into) tbl

(* A longident can have the form: A.B.x Right now we are only interested in
   values, but we will eventually want to index all occurrences of modules in
   such longidents. However there is an issue with that: we only have the
   location of the complete longident which might span multiple lines. This is
   enough to get the last component since it will always be on the last line,
   but will prevent us to find the location of previous components. *)
let last_loc (loc : Location.t) lid =
  if lid = Longident.Lident "*unknown*" then loc
  else
    let last_size = Longident.last lid |> String.length in
    { loc with
      loc_start = { loc.loc_end with
        pos_cnum = loc.loc_end.pos_cnum - last_size;
      }
    }

let uid_and_loc_of_node env node =
  let open Browse_raw in
  log ~title:"occurrences" "Looking for uid of node %s"
    @@ string_of_node node;
  match node with
  | Module_binding_name { mb_id = Some ident; mb_name; _ } ->
    let md = Env.find_module (Pident ident) env in
    Some (md.md_uid, mb_name.loc)
  | Pattern { pat_desc =
      Tpat_var (_, name, uid) | Tpat_alias (_, _, name, uid); _ } ->
      Some (uid, name.loc)
  | Type_declaration { typ_type; typ_name; _ } ->
      Some (typ_type.type_uid, typ_name.loc)
  | Label_declaration { ld_uid; ld_loc ; _ } ->
      Some (ld_uid, ld_loc)
  | Constructor_declaration { cd_uid; cd_loc ; _ } ->
      Some (cd_uid, cd_loc)
  | Value_description { val_val; val_name; _ } ->
      Some (val_val.val_uid, val_name.loc)
  | _ -> None

let loc_of_local_def ~local_defs uid =
  (* WIP *)
  (* todo: cache or specialize ? *)
  let uid_to_locs_tbl : string Location.loc Types.Uid.Tbl.t =
    Types.Uid.Tbl.create 64
  in
  match local_defs with
  | `Interface _ -> failwith "not implemented"
  | `Implementation str ->
    let iter = Ast_iterators.iter_on_defs ~uid_to_locs_tbl in
    iter.structure iter str;
    (* todo: optimize, the iterator could be more flexible *)
    (* we could check equality and raise with the result as soon that it arrive *)
    Shape.Uid.Tbl.find uid_to_locs_tbl uid

let comp_unit_of_uid = function
  | Shape.Uid.Compilation_unit comp_unit
  | Item { comp_unit; _ } -> Some comp_unit
  | Internal | Predef _ -> None

let locs_of ~config ~scope ~env ~local_defs ~pos ~node:_ path =
  log ~title:"occurrences" "Looking for occurences of %s (pos: %s)"
    path
    (Lexing.print_position () pos);
  let locate_result =
    Locate.from_string
    ~config:{ mconfig = config; traverse_aliases=false; ml_or_mli = `ML}
    ~env ~local_defs ~pos path
  in
  let def =
    match locate_result with
    | `At_origin ->
      log ~title:"locs_of" "Cursor is on definition / declaration";
      (* We are on  a definition / declaration so we look for the node's uid  *)
      (* todo: refactor *)
      let browse = Mbrowse.of_typedtree local_defs in
      let node = Mbrowse.enclosing pos [browse] in
      let env, node = Mbrowse.leaf_node node in
      uid_and_loc_of_node env node
    | `Found { uid; location; approximated = false; _ } ->
        log ~title:"locs_of" "Found definition uid using locate: %a "
          Logger.fmt (fun fmt -> Shape.Uid.print fmt uid);
        Some (uid, location)
    | `Found { uid; location; approximated = true; _ } ->
        log ~title:"locs_of" "Approx: %a "
          Logger.fmt (fun fmt -> Shape.Uid.print fmt uid);
        Some (uid, location)
    | `Builtin (uid, s) -> log ~title:"locs_of" "Locate found a builtin: %s" s; Some (uid, Location.none)
    | _ ->
      log ~title:"locs_of" "Locate failed to find a definition.";
      None
  in
  let current_buffer_path =
    Filename.concat config.query.directory config.query.filename
  in
  match def with
  | Some (def_uid, def_loc) ->
    log ~title:"locs_of" "Definition has uid %a (%a)"
      Logger.fmt (fun fmt -> Shape.Uid.print fmt def_uid)
      Logger.fmt (fun fmt -> Location.print_loc fmt def_loc);
    log ~title:"locs_of" "Indexing current buffer";
    let index = index_buffer ~local_defs () in
    if scope = `Project then begin
      match config.merlin.index_file with
      | None -> log ~title:"locs_of" "No external index specified"
      | Some file ->
        log ~title:"locs_of" "Using external index: %S" file;
        let external_uideps = Index_format.read_exn ~file in
        merge_tbl ~into:index external_uideps.defs
    end;
    (* TODO ignore externally indexed locs from the current buffer *)
    let locs = match Hashtbl.find_opt index def_uid with
      | Some locs ->
        log ~title:"occurrences" "Found %i locs" (LidSet.cardinal locs);
        LidSet.elements locs
        |> List.filter_map ~f:(fun {Location.txt; loc} ->
          log ~title:"occurrences" "Found occ: %s %a"
            (Longident.head txt) Logger.fmt (Fun.flip Location.print_loc loc);
          let loc = last_loc loc txt in
          let fname = loc.Location.loc_start.Lexing.pos_fname in
          if String.equal fname current_buffer_path then
            (* ignore locs coming from the external index for the buffer *)
            (* maybe filter before *)
            None
          else if Filename.is_relative fname then begin
            match Locate.find_source ~config loc fname with
            | `Found (file, _) -> Some { loc with loc_start =
                { loc.loc_start with pos_fname = file}}
            | `File_not_found msg ->
              log ~title:"occurrences" "%s" msg;
              None
            | _ -> None
          end else Some loc)
      | None -> log ~title:"locs_of" "No locs found in index."; []
    in
    (* We only prepend the loc of the definition for the current buffer *)
    let uid_in_current_unit =
      let uid_comp_unit = comp_unit_of_uid def_uid in
      Option.value_map ~default:false uid_comp_unit
        ~f:(String.equal @@ Env.get_unit_name ())
    in
    if uid_in_current_unit then
      let def_loc = {def_loc with
        loc_start = {def_loc.loc_start with pos_fname = current_buffer_path }} in
      Ok (def_loc::locs)
      else Ok locs
  | None -> Error "nouid"
