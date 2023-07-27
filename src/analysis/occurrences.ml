open Std
module LidSet = Index_file_format.LidSet

let {Logger. log} = Logger.for_section "occurrences"

let index_tree ~(local_defs : Mtyper.typedtree) () =
  let shape_index : (Cmt_format.index_item * Longident.t Location.loc) list ref
    = ref [] in
  match local_defs with
  | `Interface _ -> failwith "not implemented"
  | `Implementation str ->
    let iter = Cmt_format.index_decl ~shape_index in
    iter.structure iter str;
    !shape_index

let index_buffer ~env ~local_defs () =
  let defs = Hashtbl.create 64 in
  let index = index_tree ~(local_defs : Mtyper.typedtree) () in
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
  List.iter index ~f:(fun (item, lid) ->
    match item with
    | Cmt_format.Resolved uid ->
        Index_file_format.(add defs uid (LidSet.singleton lid))
    | Unresolved shape ->
      match Shape_reduce.weak_reduce env shape with
        | { Shape.desc = Leaf | Struct _; uid = Some uid } ->
            Index_file_format.add defs uid (LidSet.singleton lid)
        | _ -> ());
  defs

let load_external_index ~index_file =
  let uideps = Index_file_format.read ~file:index_file in
  uideps

let merge_tbl ~into tbl = Hashtbl.iter (Index_file_format.add into) tbl

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

let locs_of ~config ~scope ~env ~local_defs ~pos ~node:_ path =
  log ~title:"occurrences" "Looking for occurences of %s (pos: %s)"
    path
    (Lexing.print_position () pos);
  let locate_result =
    Locate.from_string
    ~config
    ~traverse_aliases:false
    ~env ~local_defs ~pos `ML path
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
    | `Found (Some uid, _, loc) ->
        log ~title:"locs_of" "Found definition uid using locate: %a "
          Logger.fmt (fun fmt -> Shape.Uid.print fmt uid);
        Some (uid, loc)
    | _ ->
      log ~title:"locs_of" "Locate failed to find a definition.";
      None
  in
  match def with
  | Some (uid, loc) ->
    log ~title:"locs_of" "Definition has uid %a (%a)"
      Logger.fmt (fun fmt -> Shape.Uid.print fmt uid)
      Logger.fmt (fun fmt -> Location.print_loc fmt loc);
    (* Todo: use magic number instead and don't use the lib *)
    let index_file = Mconfig.index_file config in
    log ~title:"locs_of" "Indexing current buffer";
    let index = index_buffer ~env ~local_defs () in
    if scope = `Project then begin
      match index_file with
      | None -> log ~title:"locs_of" "No external index specified"
      | Some index_file ->
        log ~title:"locs_of" "Using external index: %S" index_file;
        let external_uideps = load_external_index ~index_file in
        merge_tbl ~into:index external_uideps.defs
    end;
    (* TODO ignore externally indexed locs from the current buffer *)
    let locs = match Hashtbl.find_opt index uid with
      | Some locs ->
        LidSet.elements locs
        |> List.filter_map ~f:(fun lid ->
          let loc = last_loc lid.Location.loc lid.txt in
          let fname = loc.Location.loc_start.Lexing.pos_fname in
          if Filename.is_relative fname then begin
            match Locate.find_source ~config loc fname with
            | `Found (Some file, _) -> Some { loc with loc_start =
                { loc.loc_start with pos_fname = file}}
            | `Found (None, _) -> Some { loc with loc_start =
                { loc.loc_start with pos_fname = ""}}
            | `File_not_found msg ->
              log ~title:"occurrences" "%s" msg;
              None
            | _ -> None
          end else Some loc)
      | None -> log ~title:"locs_of" "No locs found in index."; []
    in
    (* We only prepend the location of the definition if it's int he scope of
       the query *)
    let loc_in_unit (loc : Location.t) =
      let by = Env.get_unit_name () |> String.lowercase_ascii in
      String.is_prefixed ~by (loc.loc_start.pos_fname |> String.lowercase_ascii)
    in
    if scope = `Project || loc_in_unit loc then Ok (loc::locs)
    else Ok locs
  | None -> Error "nouid"
