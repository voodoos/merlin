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

let uid_of_node env =
  let open Browse_raw in
  function
  | Module_binding_name { mb_id = Some ident; _ } ->
    let md = Env.find_module (Pident ident) env in
    Some md.md_uid
  | Pattern { pat_desc = Tpat_var (_, _, uid); _ } -> Some uid
  | Type_declaration { typ_type; _ } -> Some typ_type.type_uid
  | Value_description { val_val; _ } -> Some val_val.val_uid
  | _ -> None

let locs_of ~config ~scope ~env ~local_defs ~pos ~node path =
  log ~title:"occurrences" "Looking for occurences of %s (pos: %s)"
    path
    (Lexing.print_position () pos);
  let locate_result =
    Locate.from_string
    ~config
    ~traverse_aliases:false
    ~env ~local_defs ~pos `ML path
  in
  let uid =
    match locate_result with
    | `At_origin ->
      log ~title:"locs_of" "Cursor is on definition / declaration";
      (* We are on  a definition / declaration so we look for the node's uid  *)
      uid_of_node env node
    | `Found (uid, _, _) ->
        log ~title:"locs_of" "Found definition uid using locate: %a"
          Logger.fmt (fun fmt ->
            Format.pp_print_option (Shape.Uid.print) fmt uid);
        uid
    | _ ->
      log ~title:"locs_of" "Locate failed to find a definition.";
      None
  in
  match uid with
  | Some uid ->
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
    let locs = (match Hashtbl.find_opt index uid with
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
      | None -> Format.eprintf "None\n%!"; [])
    in
    Ok locs
  | None -> Error "nouid"
