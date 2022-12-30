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

let last_location = ref Location.none

let {Logger. log} = Logger.for_section "locate"
module File : sig
  type t = private
    | ML   of string
    | MLL  of string
    | MLI  of string
    | CMT  of string
    | CMTI of string

  val ml : string -> t
  val mli : string -> t
  val cmt : string -> t
  val cmti : string -> t

  val of_filename : string -> t option

  val alternate : t -> t

  val name : t -> string

  val with_ext : ?src_suffix_pair:(string * string) -> t -> string

  val explain_not_found :
    ?doc_from:string -> string -> t -> [> `File_not_found of string ]
end = struct
  type t =
    | ML   of string
    | MLL  of string
    | MLI  of string
    | CMT  of string
    | CMTI of string

  let file_path_to_mod_name f =
    Misc.unitname (Filename.basename f)

  let ml   s = ML   (file_path_to_mod_name s)
  let mll  s = MLL  (file_path_to_mod_name s)
  let mli  s = MLI  (file_path_to_mod_name s)
  let cmt  s = CMT  (file_path_to_mod_name s)
  let cmti s = CMTI (file_path_to_mod_name s)

  let of_filename fn =
    match Misc.rev_string_split ~on:'.' fn with
    | []
    | [ _ ] -> None
    | ext :: _ ->
      let ext = String.lowercase_ascii ext in
      Some (
        match ext with
        | "cmti" -> cmti fn
        | "cmt"  -> cmt fn
        | "mll"  -> mll fn
        | _ -> if Filename.check_suffix ext "i" then mli fn else ml fn
      )

  let alternate = function
    | ML  s
    | MLL s -> MLI s
    | MLI s -> ML s
    | CMT s  -> CMTI s
    | CMTI s -> CMT s

  let name = function
    | ML name
    | MLL name
    | MLI name
    | CMT name
    | CMTI name -> name

  let ext src_suffix_pair = function
    | ML _  -> fst src_suffix_pair
    | MLI _  -> snd src_suffix_pair
    | MLL _ -> ".mll"
    | CMT _ -> ".cmt"
    | CMTI _ -> ".cmti"

  let with_ext ?(src_suffix_pair=(".ml",".mli")) t =
    name t ^ ext src_suffix_pair t

  let explain_not_found ?(doc_from="") str_ident path =
    let msg =
      match path with
      | ML file ->
        sprintf "'%s' seems to originate from '%s' whose ML file could not be \
                 found" str_ident file
      | MLL file ->
        sprintf "'%s' seems to originate from '%s' whose MLL file could not be \
                 found" str_ident file
      | MLI file ->
        sprintf "'%s' seems to originate from '%s' whose MLI file could not be \
                 found" str_ident file
      | CMT file ->
        sprintf "Needed cmt file of module '%s' to locate '%s' but it is not \
                 present" file str_ident
      | CMTI file when file <> doc_from ->
        sprintf "Needed cmti file of module '%s' to locate '%s' but it is not \
                 present" file str_ident
      | CMTI _ ->
        sprintf "The documentation for '%s' originates in the current file, \
                 but no cmt is available" str_ident
    in
    `File_not_found msg
end

module Preferences : sig
  val set : [ `ML | `MLI ] -> unit

  val src : string -> File.t
  val build : string -> File.t

  val is_preferred : string -> bool
end = struct
  let prioritize_impl = ref true

  let set choice =
    prioritize_impl :=
      match choice with
      | `ML -> true
      | _ -> false

  let src   file = if !prioritize_impl then File.ml  file else File.mli  file
  let build file = if !prioritize_impl then File.cmt file else File.cmti file

  let is_preferred fn =
    match File.of_filename fn with
    | Some ML _ -> !prioritize_impl
    | Some MLI _ -> not !prioritize_impl
    | _ -> false
end

module File_switching : sig
  val reset : unit -> unit

  val move_to : digest:Digest.t -> string -> unit

  val where_am_i : unit -> string option

  val source_digest : unit -> Digest.t option
end = struct
  type t = {
    last_file_visited : string;
    digest : Digest.t;
  }

  let last_file_visited t = t.last_file_visited
  let digest t = t.digest

  let state = ref None

  let reset () = state := None

  let move_to ~digest file =
    log ~title:"File_switching.move_to" "%s" file;
    state := Some { last_file_visited = file ; digest }

  let where_am_i () = Option.map !state ~f:last_file_visited

  let source_digest () = Option.map !state ~f:digest
end


module Utils = struct
  let is_builtin_path = function
    | Path.Pident id -> Ident.is_predef id
    | _ -> false

  (* Reuse the code of [Misc.find_in_path_uncap] but returns all the files
     matching, instead of the first one. This is only used when looking for ml
     files, not cmts. Indeed for cmts we know that the load path will only ever
     contain files with uniq names; this in not the case for the "source path"
     however. We therefore get all matching files and use an heuristic at the
     call site to choose the appropriate file.

     Note: We do not refine the load path for module path as we used too. *)
  let find_all_in_path_uncap ?src_suffix_pair ~with_fallback path file =
    let name = File.with_ext ?src_suffix_pair file in
    let uname = String.uncapitalize_ascii name in
    log ~title:"find_all_in_path_uncap"
      "Attempt to find file %S in path [%a]"
      uname
      Logger.fmt (fun fmt -> Format.pp_print_list Format.pp_print_string fmt path);

    let fallback, ufallback =
      let alt = File.alternate file in
      let fallback = File.with_ext ?src_suffix_pair alt in
      fallback, String.uncapitalize fallback
    in
    let try_file dirname basename acc =
      if Misc.exact_file_exists ~dirname ~basename
      then Misc.canonicalize_filename (Filename.concat dirname basename) :: acc
      else acc
    in
    let try_dir acc dirname =
      let acc = try_file dirname uname acc in
      let acc = try_file dirname name acc in
      let acc =
        if with_fallback then
          let acc = try_file dirname ufallback acc in
          let acc = try_file dirname fallback acc in
          acc
        else
          acc
      in
      acc
    in
    List.fold_left ~f:try_dir ~init:[] path

  let find_all_matches ~config ?(with_fallback=false) file =
    let files =
      List.concat_map ~f:(fun synonym_pair ->
        find_all_in_path_uncap ~src_suffix_pair:synonym_pair ~with_fallback
          (Mconfig.source_path config) file
      ) Mconfig.(config.merlin.suffixes)
    in
    List.dedup_adjacent files ~cmp:String.compare

  let find_file_with_path ~config ?(with_fallback=false) file path =
    if File.name file = Misc.unitname Mconfig.(config.query.filename) then
      Some Mconfig.(config.query.filename)
    else
      let attempt_search src_suffix_pair =
        let fallback =
          if with_fallback then
            Some (File.with_ext ~src_suffix_pair (File.alternate file))
          else
            None
        in
        let fname = File.with_ext ~src_suffix_pair file in
        try Some (Misc.find_in_path_uncap ?fallback path fname)
        with Not_found -> None
      in
      try
        Some (List.find_map Mconfig.(config.merlin.suffixes) ~f:attempt_search)
      with Not_found ->
        None

  let find_file ~config ?with_fallback (file : File.t) =
    find_file_with_path ~config ?with_fallback file @@
        match file with
        | ML  _ | MLI _  | MLL _ -> Mconfig.source_path config
        | CMT _ | CMTI _         -> Mconfig.build_path config
end

let move_to filename cmt_infos =
  let digest =
    (* [None] only for packs, and we wouldn't have a trie if the cmt was for a
       pack. *)
    let sourcefile_in_builddir =
      Filename.concat
        (cmt_infos.Cmt_format.cmt_builddir)
        (Option.get cmt_infos.cmt_sourcefile)
    in
    match sourcefile_in_builddir |> String.split_on_char ~sep:'.' |> List.rev with
    | ext :: "pp" :: rev_path ->
      (* If the source file was a post-processed file (.pp.mli?), use the
         regular .mli? file for locate. *)
      let sourcefile_in_builddir =
        (ext :: rev_path) |> List.rev |> String.concat ~sep:"."
      in
      (match
         Misc.exact_file_exists
           ~dirname:(Filename.dirname sourcefile_in_builddir)
           ~basename:(Filename.basename sourcefile_in_builddir)
       with
       | true -> Digest.file sourcefile_in_builddir
       | false -> Option.get cmt_infos.cmt_source_digest)
    | _ -> Option.get cmt_infos.cmt_source_digest
  in
  log ~title:"move_to" "Moving to %S" filename;
  File_switching.move_to ~digest filename


let load_cmt ~config comp_unit ml_or_mli =
  Preferences.set ml_or_mli;
  let file =
    Preferences.build comp_unit
  in
  match Utils.find_file ~config ~with_fallback:true file with
  | Some path ->
      let cmt_infos = (Cmt_cache.read path).cmt_infos in
      let source_file = cmt_infos.cmt_sourcefile in
      let source_file = Option.value ~default:"*pack*" source_file in
      move_to path cmt_infos;
      Ok (source_file, cmt_infos)
  | None -> Error ()

let uid_of_path ~config ~env ~ml_or_mli ~decl_uid path ns =
  let module Shape_reduce =
    Shape.Make_reduce (struct
      type env = Env.t

      let fuel = 10

      let read_unit_shape ~unit_name =
          log ~title:"read_unit_shape" "inspecting %s" unit_name;
          match load_cmt ~config unit_name `ML with
          | Ok (filename, cmt_infos) ->
            log ~title:"read_unit_shape" "shapes loaded for %s" unit_name;
            cmt_infos.cmt_impl_shape
          | Error () ->
            log ~title:"read_unit_shape" "failed to find %s" unit_name;
            None

      let find_shape env id = Env.shape_of_path
        ~namespace:Shape.Sig_component_kind.Module env (Pident id)
    end)
  in
  match ml_or_mli with
  | `MLI -> Some decl_uid
  | `ML ->
    log ~title:"shape_of_path" "path: %a"
      Logger.fmt (fun fmt -> Path.print fmt path);
    let shape = Env.shape_of_path ~namespace:ns env path in
    log ~title:"shape_of_path" "initial: %a"
      Logger.fmt (fun fmt -> Shape.print fmt shape);
    let r = Shape_reduce.weak_reduce env shape in
    log ~title:"shape_of_path" "reduced: %a"
      Logger.fmt (fun fmt -> Shape.print fmt r);
    r.uid

(** [module_aliasing] iterates on a typedtree to check if the provided uid
  corresponds to a module alias. If it does the function returns the uid of the
  aliased module. If not it returns None.
  The intended use of this function is to traverse dune-generated aliases. *)
let module_aliasing ~(bin_annots : Cmt_format.binary_annots) uid  =
  let exception Found of Path.t * Env.t in
  let iterator env = { Tast_iterator.default_iterator with
    module_binding = (fun sub mb ->
      begin match mb with
      | { mb_id = Some id; mb_expr = { mod_desc = Tmod_ident (path, _); _ }; _ }
        ->
          let md = Env.find_module (Pident id) env in
          if Shape.Uid.equal uid md.md_uid then
            raise (Found (path, env))
      | _ -> () end;
      Tast_iterator.default_iterator.module_binding sub mb)
    }
  in
  try
    begin match bin_annots with
    | Interface s ->
        let sig_final_env = Envaux.env_of_only_summary s.sig_final_env in
        let iterator = iterator sig_final_env in
        iterator.signature iterator { s with sig_final_env }
    | Implementation str ->
      let str_final_env = Envaux.env_of_only_summary str.str_final_env in
      let iterator = iterator str_final_env in
      iterator.structure iterator { str with str_final_env }
    | _ -> () end;
    None
  with Found (path, env) ->
    let namespace = Shape.Sig_component_kind.Module in
    let shape = Env.shape_of_path ~namespace env path in
    log ~title:"locate" "Uid %a corresponds to an alias of %a
      which has the shape %a and the uid %a"
      Logger.fmt (fun fmt -> Shape.Uid.print fmt uid)
      Logger.fmt (fun fmt -> Path.print fmt path)
      Logger.fmt (fun fmt -> Shape.print fmt shape)
      Logger.fmt (fun fmt ->
        Format.pp_print_option Shape.Uid.print fmt shape.uid);
    Option.map ~f:(fun uid -> uid, path) shape.uid

let from_uid ~config ~ml_or_mli uid loc path =
  let loc_of_comp_unit comp_unit =
    match load_cmt ~config comp_unit ml_or_mli with
    | Ok (pos_fname, _cmt) ->
      let pos = Std.Lexing.make_pos ~pos_fname (1, 0) in
      let loc = { Location.loc_start=pos; loc_end=pos; loc_ghost=true } in
      Some loc
    | _ -> None
  in
  let title = "from_uid" in
  match uid with
  | Some (Shape.Uid.Item { comp_unit; _ } as uid) ->
    let locopt =
      if Env.get_unit_name () = comp_unit then begin
        log ~title "We look for %a in the current compilation unit."
          Logger.fmt (fun fmt -> Shape.Uid.print fmt uid);
        let tbl = Env.get_uid_to_loc_tbl () in
        match Shape.Uid.Tbl.find_opt tbl uid with
        | Some loc ->
          log ~title "Found location: %a"
            Logger.fmt (fun fmt -> Location.print_loc fmt loc);
          Some (uid, loc)
        | None ->
          log ~title
            "Uid not found in the local table.\
            Fallbacking to the node's location: %a"
          Logger.fmt (fun fmt -> Location.print_loc fmt loc);
          Some (uid, loc)
      end else begin
        log ~title "Loading the shapes for unit %S" comp_unit;
        match load_cmt ~config comp_unit ml_or_mli with
        | Ok (_pos_fname, cmt) ->
          log ~title "Shapes successfully loaded, looking for %a"
            Logger.fmt (fun fmt -> Shape.Uid.print fmt uid);
          begin match Shape.Uid.Tbl.find_opt cmt.cmt_uid_to_loc uid with
            | Some loc when
              String.ends_with ~suffix:"ml-gen" loc.loc_start.pos_fname ->
              log ~title "Found location in generated file: %a"
                Logger.fmt (fun fmt -> Location.print_loc fmt loc);
              (* This notably happens when using Dune. In that case we
                 try to resolve the alias immediately. *)
              begin match module_aliasing ~bin_annots:cmt.cmt_annots uid with
              | Some (Shape.Uid.Compilation_unit comp_unit as uid, _path) ->
                log ~title
                  "The alias points to another compilation unit %s" comp_unit;
                loc_of_comp_unit comp_unit
                |> Option.map ~f:(fun loc -> uid, loc)
              | _ -> Some (uid, loc)
              end
            | Some loc ->
              log ~title "Found location: %a"
                Logger.fmt (fun fmt -> Location.print_loc fmt loc);
              Some (uid, loc)
            | None ->
              log ~title "Uid not found in the cmt table. \
                Fallbacking to the node's location: %a"
                Logger.fmt (fun fmt -> Location.print_loc fmt loc);
              Some (uid, loc)
          end
        | _ ->
          log ~title "Failed to load the shapes";
          None
      end
    in
    begin match locopt with
    | Some (uid, loc) -> `Found (Some uid, loc)
    | None -> `Not_found (Path.name path, None)
    end
  | Some (Compilation_unit comp_unit as uid) ->
    begin
      log ~title "Got the uid of a compilation unit: %a"
        Logger.fmt (fun fmt -> Shape.Uid.print fmt uid);
      match loc_of_comp_unit comp_unit with
      | Some loc -> `Found (Some uid, loc)
      | _ -> log ~title "Failed to load the shapes";
        `Not_found (Path.name path, None)
    end
  | Some (Predef _ | Internal) -> assert false
  | None -> log ~title "No UID found, fallbacking to lookup location.";
      `Found (None, loc)

let locate ~config ~env ~ml_or_mli decl_uid loc path ns =
  let uid = uid_of_path ~config ~env ~ml_or_mli ~decl_uid path ns in
  from_uid ~config ~ml_or_mli uid loc path

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

type find_source_result =
  | Found of string
  | Not_found of File.t
  | Multiple_matches of string list

let find_source ~config loc =
  let fname = loc.Location.loc_start.Lexing.pos_fname in
  log ~title:"find_source" "attempt to find %S" fname;
  let with_fallback = loc.Location.loc_ghost in
  let file =
    match File.of_filename fname with
    | Some file -> file
    | None ->
      (* no extension? we have to decide. *)
      Preferences.src fname
  in
  let filename = File.name file in
  log ~title:"find_source" "filename %S" filename;

  let initial_path =
    match File_switching.where_am_i () with
    | None -> fname
    | Some s ->
      log ~title:"find_source" "i am here: %S" s;
      s
  in
  let dir = Filename.dirname initial_path in
  let dir =
    match Mconfig.(config.query.directory) with
    | "" -> dir
    | cwd -> Misc.canonicalize_filename ~cwd dir
  in
  match Utils.find_all_matches ~config ~with_fallback file with
  | [] ->
    log ~title:"find_source" "failed to find %S in source path (fallback = %b)"
       (File.with_ext file) with_fallback ;
    log ~title:"find_source" "looking for %S in %S" (File.name file) dir ;
    begin match Utils.find_file_with_path ~config ~with_fallback file [dir] with
    | Some source -> Found source
    | None ->
      log ~title:"find_source" "Trying to find %S in %S directly" fname dir;
      try Found (Misc.find_in_path [dir] fname)
      with _ -> Not_found file
    end
  | [ x ] -> Found x
  | files ->
    log ~title:(sprintf "find_source(%s)" filename)
      "multiple matches in the source path : %s"
      (String.concat ~sep:" , " files);
    try
      match File_switching.source_digest () with
      | None ->
        log ~title:"find_source"
          "... no source digest available to select the right one" ;
        raise Not_found
      | Some digest ->
        log ~title:"find_source"
          "... trying to use source digest to find the right one" ;
        log ~title:"find_source" "Source digest: %s" (Digest.to_hex digest) ;
        Found (
          List.find files ~f:(fun f ->
            let fdigest = Digest.file f in
            log ~title:"find_source" "  %s (%s)" f (Digest.to_hex fdigest) ;
            fdigest = digest
          )
        )
    with Not_found ->
      log ~title:"find_source" "... using heuristic to select the right one" ;
      log ~title:"find_source" "we are looking for a file named %s in %s" fname dir ;
      let rev = String.reverse (Misc.canonicalize_filename ~cwd:dir fname) in
      let lst =
        List.map files ~f:(fun path ->
          let path' = String.reverse path in
          let priority = (String.common_prefix_len rev path') * 2 +
                          if Preferences.is_preferred path
                          then 1
                          else 0
          in
          priority, path
        )
      in
      let lst =
        (* TODO: remove duplicates in [source_path] instead of using
          [sort_uniq] here. *)
        List.sort_uniq ~cmp:(fun ((i:int),s) ((j:int),t) ->
          let tmp = compare j i in
          if tmp <> 0 then tmp else
          match compare s t with
          | 0 -> 0
          | n ->
            (* Check if we are referring to the same files.
                Especially useful on OSX case-insensitive FS.
                FIXME: May be able handle symlinks and non-existing files,
                CHECK *)
            match File_id.get s, File_id.get t with
            | s', t' when File_id.check s' t' ->
              0
            | _ -> n
        ) lst
      in
      match lst with
      | (i1, _) :: (i2, _) :: _ when i1 = i2 ->
        Multiple_matches files
      | (_, s) :: _ -> Found s
      | _ -> assert false

(* Well, that's just another hack.
   [find_source] doesn't like the "-o" option of the compiler. This hack handles
   Jane Street specific use case where "-o" is used to prefix a unit name by the
   name of the library which contains it. *)
let find_source ~config loc path =
  let result =
    match find_source ~config loc with
    | Found _ as result -> result
    | failure ->
      let fname = loc.Location.loc_start.Lexing.pos_fname in
      match
        let i = String.first_double_underscore_end fname in
        let pos = i + 1 in
        let fname = String.sub fname ~pos ~len:(String.length fname - pos) in
        let loc =
          let lstart = { loc.Location.loc_start with Lexing.pos_fname = fname } in
          { loc with Location.loc_start = lstart }
        in
        find_source ~config loc
      with
      | Found _ as result -> result
      | _ -> failure
      | exception _ -> failure
  in
  match result with
  | Found src -> `Found (Some src, loc.Location.loc_start)
  | Not_found f -> File.explain_not_found path f
  | Multiple_matches lst ->
    let matches = String.concat lst ~sep:", " in
    `File_not_found (
      sprintf "Several source files in your path have the same name, and \
               merlin doesn't know which is the right one: %s"
        matches)

module Namespace = struct
  type under_type = [ `Constr | `Labels ]

  type t = (* TODO: share with [Namespaced_path.Namespace.t] *)
    [ `Type | `Mod | `Modtype | `Vals | under_type ]

  type inferred =
    [ t
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

module Env_lookup : sig

  val loc
    : Path.t
    -> Namespaced_path.Namespace.t
    -> Env.t
    -> (Location.t * Shape.Uid.t * Shape.Sig_component_kind.t) option

  val in_namespaces
     : Namespace.inferred list
    -> Longident.t
    -> Env.t
    -> (Path.t * Shape.Sig_component_kind.t * Shape.Uid.t * Location.t) option

end = struct

  let loc path (namespace : Namespaced_path.Namespace.t) env =
    try
      Some (
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
      )
    with
      Not_found -> None

  exception Found of
    (Path.t * Shape.Sig_component_kind.t * Shape.Uid.t * Location.t)

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
            (* TODO: Use [`Constr] here instead of [`Type] *)
            raise (Found (path, Type, cd.cstr_uid,loc))
          | `Constr ->
            log ~title:"lookup" "lookup in constructor namespace" ;
            let cd = Env.find_constructor_by_name ident env in
            let path, loc = path_and_loc_of_cstr cd env in
            (* TODO: Use [`Constr] here instead of [`Type] *)
            raise (Found (path, Type,cd.cstr_uid, loc))
          | `Mod ->
            log ~title:"lookup" "lookup in module namespace" ;
            let path, md = Env.find_module_by_name ident env in
            raise (Found (path, Module, md.md_uid, md.Types.md_loc))
          | `Modtype ->
            log ~title:"lookup" "lookup in module type namespace" ;
            let path, mtd = Env.find_modtype_by_name ident env in
            raise (Found (path, Module_type, mtd.mtd_uid, mtd.Types.mtd_loc))
          | `Type ->
            log ~title:"lookup" "lookup in type namespace" ;
            let path, typ_decl = Env.find_type_by_name ident env in
            raise (
              Found (path, Type, typ_decl.type_uid, typ_decl.Types.type_loc)
            )
          | `Vals ->
            log ~title:"lookup" "lookup in value namespace" ;
            let path, val_desc = Env.find_value_by_name ident env in
            raise (
              Found (path, Value, val_desc.val_uid, val_desc.Types.val_loc)
            )
          | `This_label lbl ->
            log ~title:"lookup"
              "got label, fetching path and loc in type namespace";
            let path, loc = path_and_loc_from_label lbl env in
            (* TODO: Use [`Labels] here instead of [`Type] *)
            raise (Found (path, Type, lbl.lbl_uid, loc))
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
    with Found ((path, namespace, decl_uid, _loc) as x) ->
      log ~title:"env_lookup" "found: '%a' in namespace %s with uid %a"
        Logger.fmt (fun fmt -> Path.print fmt path)
        (Shape.Sig_component_kind.to_string namespace)
        Logger.fmt (fun fmt -> Shape.Uid.print fmt decl_uid);
      Some x
end

let uid_from_longident ~config ~env nss ml_or_mli ident =
  let str_ident = String.concat ~sep:"." (Longident.flatten ident) in
  match Env_lookup.in_namespaces nss ident env with
  | None -> `Not_in_env str_ident
  | Some (path, namespace, decl_uid, loc) ->
    if Utils.is_builtin_path path then
      `Builtin
    else
      let uid = uid_of_path ~config ~env ~ml_or_mli ~decl_uid path namespace in
      `Uid (uid, loc, path)

let from_longident ~config ~env nss ml_or_mli ident =
  match uid_from_longident ~config ~env nss ml_or_mli ident with
  | `Uid (uid, loc, path) -> from_uid ~config ~ml_or_mli uid loc path
  | (`Builtin | `Not_in_env _) as v -> v

let from_path ~config ~env ~namespace ml_or_mli path =
  File_switching.reset ();
  if Utils.is_builtin_path path then
    `Builtin
  else
    match Env_lookup.loc path namespace env with
    | None -> `Not_in_env (Path.name path)
    | Some (loc, uid, namespace) ->
      match locate ~config ~env ~ml_or_mli uid loc path namespace with
      | `Not_found _
      | `File_not_found _ as err -> err
      | `Found (uid, loc) ->
        match find_source ~config loc (Path.name path) with
        | `Found (file, loc) -> `Found (uid, file, loc)
        | `File_not_found _ as otherwise -> otherwise

let from_string ~config ~env ~local_defs ~pos ?namespaces switch path =
  File_switching.reset ();
  let browse = Mbrowse.of_typedtree local_defs in
  let lid = Longident.parse path in
  let ident, is_label = Longident.keep_suffix lid in
  match
    match namespaces with
    | Some nss ->
      if not is_label
      then `Ok (nss :> Namespace.inferred list)
      else if List.mem `Labels ~set:nss then (
        log ~title:"from_string" "restricting namespaces to labels";
        `Ok [ `Labels ]
      ) else (
        log ~title:"from_string"
          "input is clearly a label, but the given namespaces don't cover that";
        `Error `Missing_labels_namespace
      )
    | None ->
      match Context.inspect_browse_tree ~cursor:pos lid [browse], is_label with
      | None, _ ->
        log ~title:"from_string" "already at origin, doing nothing" ;
        `Error `At_origin
      | Some (Label _ as ctxt), true
      | Some ctxt, false ->
        log ~title:"from_string"
          "inferred context: %s" (Context.to_string ctxt);
        `Ok (Namespace.from_context ctxt)
      | _, true ->
        log ~title:"from_string"
          "dropping inferred context, it is not precise enough";
        `Ok [ `Labels ]
  with
  | `Error e -> e
  | `Ok nss ->
    log ~title:"from_string"
      "looking for the source of '%s' (prioritizing %s files)"
      path (match switch with `ML -> ".ml" | `MLI -> ".mli");
    match from_longident ~config ~env nss switch ident with
    | `File_not_found _ | `Not_found _ | `Not_in_env _ as err -> err
    | `Builtin -> `Builtin path
    | `Found (uid, loc) ->
      match find_source ~config loc path with
      | `Found (file, loc) -> `Found (uid, file, loc)
      | `File_not_found _ as otherwise -> otherwise

(** When we look for docstring in external compilation unit we can perform
    a uid-based search and return the attached comment in the attributes.
    This is a more sound way to get documentation than resorting on the
    [Ocamldoc.associate_comment] heuristic *)
let doc_from_uid ~config ~comp_unit uid =
  let exception Found of Typedtree.attributes in
  let test elt_uid attributes =
    if Shape.Uid.equal uid elt_uid then raise (Found attributes)
  in
  let iterator =
    let first_item = ref true in
    let uid_is_comp_unit = match uid with
      | Shape.Uid.Compilation_unit _ -> true
      | _ -> false
    in
    fun env -> { Tast_iterator.default_iterator with

      (* Needed to return top-level module doc (when the uid is a compunit).
         The module docstring must be the first signature or structure item *)
      signature_item = (fun sub ({ sig_desc; _} as si) ->
        begin match sig_desc, !first_item, uid_is_comp_unit with
        | Tsig_attribute attr, true, true -> raise (Found [attr])
        | _, false, true -> raise Not_found
        | _, _, _ -> first_item := false end;
        Tast_iterator.default_iterator.signature_item sub si);

      structure_item = (fun sub ({ str_desc; _} as sti) ->
        begin match str_desc, !first_item, uid_is_comp_unit with
        | Tstr_attribute attr, true, true -> raise (Found [attr])
        | _, false, true -> raise Not_found
        | _, _, _ -> first_item := false end;
        Tast_iterator.default_iterator.structure_item sub sti);

      value_description = (fun sub ({ val_val; val_attributes; _ } as vd) ->
        test val_val.val_uid val_attributes;
        Tast_iterator.default_iterator.value_description sub vd);

      type_declaration = (fun sub ({ typ_type; typ_attributes; _ } as td) ->
        test typ_type.type_uid typ_attributes;
        Tast_iterator.default_iterator.type_declaration sub td);

      value_binding = (fun sub ({ vb_pat; vb_attributes; _ } as vb) ->
        begin match vb_pat.pat_desc with
        | Tpat_var (id, _) ->
            begin try
              let vd = Env.find_value (Pident id) env in
              test vd.val_uid vb_attributes
            with Not_found -> () end
        | _ -> () end;
        Tast_iterator.default_iterator.value_binding sub vb)
    }
  in
  let parse_attributes attrs =
    let open Parsetree in
    try Some (List.find_map attrs ~f:(fun attr ->
      if List.exists ["ocaml.doc"; "ocaml.text"]
        ~f:(String.equal attr.attr_name.txt)
      then Ast_helper.extract_str_payload attr.attr_payload
      else None))
    with Not_found -> None
  in
  let typedtree =
    log ~title:"doc_from_uid" "Loading the cmt for unit %S" comp_unit;
    match load_cmt ~config comp_unit `MLI with
    | Ok (_, cmt_infos) ->
      log ~title:"doc_from_uid" "Cmt loaded, itering on the typedtree";
      begin match cmt_infos.cmt_annots with
      | Interface s -> Some (`Interface { s with
          sig_final_env = Envaux.env_of_only_summary s.sig_final_env})
      | Implementation str -> Some (`Implementation { str with
          str_final_env = Envaux.env_of_only_summary str.str_final_env})
      | _ -> None
      end
    | Error _ -> None
  in
  try begin match typedtree with
    | Some (`Interface s) ->
        let iterator = iterator s.sig_final_env in
        iterator.signature iterator s;
        log ~title:"doc_from_uid" "uid not found in the signature"
    | Some (`Implementation str) ->
        let iterator = iterator str.str_final_env in
        iterator.structure iterator str;
        log ~title:"doc_from_uid" "uid not found in the implementation"
    | _ -> () end;
    `No_documentation
  with
    | Found attrs ->
       log ~title:"doc_from_uid" "Found attributes for this uid";
        begin match parse_attributes attrs with
        | Some (doc, _) -> `Found (doc |> String.trim)
        | None -> `No_documentation end
    | Not_found -> `No_documentation

let get_doc ~config ~env ~local_defs ~comments ~pos =
  File_switching.reset ();
  let from_uid ~loc uid =
    begin match uid with
    | Some (Shape.Uid.Item { comp_unit; _ } as uid)
    | Some (Shape.Uid.Compilation_unit comp_unit as uid)
        when Env.get_unit_name () <> comp_unit ->
          log ~title:"get_doc" "the doc (%a) you're looking for is in another
            compilation unit (%s)"
            Logger.fmt (fun fmt -> Shape.Uid.print fmt uid) comp_unit;
          (match doc_from_uid ~config ~comp_unit uid with
          | `Found doc -> `Found_doc doc
          | `No_documentation ->
              (* We fallback on the legacy heuristic to handle some unproper
                 doc placement. See test [unattached-comment.t] *)
              `Found loc)
    | _ ->
      (* Uid based search doesn't works in the current CU since Merlin's parser
         does not attach doc comments to the typedtree *)
      `Found loc
    end
  in
  fun path ->
  let_ref last_location Location.none @@ fun () ->
  match
    match path with
    | `Completion_entry (namespace, path, _loc) ->
      log ~title:"get_doc" "completion: looking for the doc of '%a'"
        Logger.fmt (fun fmt -> Path.print fmt path) ;
      let from_path = from_path ~config ~env ~namespace `MLI path in
      begin match from_path with
      | `Found (uid, _, pos) ->
        let loc : Location.t =
          { loc_start = pos; loc_end = pos; loc_ghost = true }
        in
        from_uid ~loc uid
      | (`Builtin |`Not_in_env _|`File_not_found _|`Not_found _)
        as otherwise -> otherwise
      end
    | `User_input path ->
      log ~title:"get_doc" "looking for the doc of '%s'" path;
      begin match from_string ~config ~env ~local_defs ~pos `MLI path with
      | `Found (uid, _, pos) ->
        let loc : Location.t =
          { loc_start = pos; loc_end = pos; loc_ghost = true }
        in
        from_uid ~loc uid
      | `At_origin | `Missing_labels_namespace -> `No_documentation
      | `Builtin _ -> `Builtin
      | (`Not_in_env _ | `Not_found _ |`File_not_found _ )
        as otherwise -> otherwise
      end
  with
  | `Found_doc doc -> `Found doc
  | `Found loc ->
    (* When the doc we look for is in the current buffer or if search by uid
      has failed we use an alternative heuristic since Merlin's pure parser
      does not poulates doc attributes in the typedtree. *)
    let comments =
      match File_switching.where_am_i () with
      | None ->
        log ~title:"get_doc" "Using reader's comment (current buffer)";
        comments
      | Some cmt_path ->
        log ~title:"get_doc" "File switching: actually in %s" cmt_path;
        let {Cmt_cache. cmt_infos; _ } = Cmt_cache.read cmt_path in
        cmt_infos.Cmt_format.cmt_comments
    in
    log ~title:"get_doc" "%a" Logger.fmt (fun fmt ->
        Format.fprintf fmt "looking around %a inside: [\n"
          Location.print_loc !last_location;
        List.iter comments ~f:(fun (c, l) ->
            Format.fprintf fmt "  (%S, %a);\n" c
              Location.print_loc l);
        Format.fprintf fmt "]\n"
      );
    let browse = Mbrowse.of_typedtree local_defs in
    let (_, deepest_before) =
      Mbrowse.(leaf_node @@ deepest_before loc.loc_start [browse])
    in
    (* based on https://v2.ocaml.org/manual/doccomments.html#ss:label-comments: *)
    let after_only = begin match deepest_before with
      | Browse_raw.Constructor_declaration _ -> true
      (* The remaining `true` cases are currently not reachable *)
      | Label_declaration _ | Record_field _ | Row_field _  -> true
      | _ -> false
    end in
    begin match
      Ocamldoc.associate_comment ~after_only comments loc !last_location
    with
    | None, _     -> `No_documentation
    | Some doc, _ -> `Found doc
    end
  | `Builtin ->
    begin match path with
    | `User_input path -> `Builtin path
    | `Completion_entry (_, path, _) -> `Builtin (Path.name path)
    end
  | `File_not_found _
  | `Not_found _
  | `No_documentation
  | `Not_in_env _ as otherwise -> otherwise

module Uideps_format = struct
  (* TODO WE SHOULD USE A MAGIC NUMBER *)
  module Loc : Set.OrderedType with type t = Location.t = struct
    type t = Location.t

    (* TODO: this does not compare pos_fname *)
    let compare = Location_aux.compare
  end

  module LocSet = Set.Make (Loc)

  type payload = {
    defs : (Shape.Uid.t, LocSet.t) Hashtbl.t;
    partial : (Location.t * Shape.t * Env.t) list;
    load_path : string list;
  }

  type file_format = V1 of payload

  let pp_payload (fmt : Format.formatter) pl =
    Format.fprintf fmt "{@[";
    Hashtbl.iter
      (fun uid locs -> Format.fprintf fmt "uid: %a; locs: @[%a@]@,"
        Shape.Uid.print uid
        (Format.pp_print_list
          ~pp_sep:(fun fmt () -> Format.fprintf fmt ";@;")
          Location.print_loc) (LocSet.elements locs))
      pl.defs;
      Format.fprintf fmt "@]}@,";
      Format.fprintf fmt "And %i partial shapes." (List.length pl.partial)

  let _pp (fmt : Format.formatter) ff =
    match ff with
    | V1 tbl ->
      Format.fprintf fmt "V1@,%a" pp_payload tbl

  let ext = "uideps"

  let _write ~file tbl =
      let oc = open_out_bin file in
      Marshal.to_channel oc (V1 tbl) [];
      close_out oc

  let read ~file =
    let file = String.concat ~sep:"." [file; ext] in
    try
      let ic = open_in_bin file in
      try
        let payload = match Marshal.from_channel ic with
          | V1 payload -> payload (* TODO is that "safe" ? *)
        in
        close_in ic;
        Ok payload
      with e -> raise e (* todo *)
    with Sys_error msg -> Error msg
end

module LocSet = Uideps_format.LocSet

let add tbl uid locs =
  try
    let locations = Hashtbl.find tbl uid in
    Hashtbl.replace tbl uid (LocSet.union locs locations)
  with Not_found -> Hashtbl.add tbl uid locs

let merge_tbl ~into tbl = Hashtbl.iter (add into) tbl

let get_local_uideps ~config ~local_defs _uid =
  let module Kind = Shape.Sig_component_kind in
  let module Shape_reduce =
    Shape.Make_reduce (struct
      type env = Env.t

      let fuel = 10

      let read_unit_shape ~unit_name =
          log ~title:"read_unit_shape" "inspecting %s" unit_name;
          match load_cmt ~config unit_name `ML with
          | Ok (_filename, cmt_infos) ->
            log ~title:"read_unit_shape" "shapes loaded for %s" unit_name;
            cmt_infos.cmt_impl_shape
          | Error () ->
            log ~title:"read_unit_shape" "failed to find %s" unit_name;
            None

      let find_shape env id = Env.shape_of_path
        ~namespace:Shape.Sig_component_kind.Module env (Pident id)
    end)
  in
  let tbl =
    (* We start with all the uids that have been registered into the typing env
       *)
    let tbl = Env.get_uid_to_loc_tbl () in
    Shape.Uid.Tbl.map tbl LocSet.singleton
    |> Shape.Uid.Tbl.to_seq
    |> Hashtbl.of_seq
   in
  let iterator =
    let add_to_tbl ~env ~loc shape =
        match (Shape_reduce.reduce env shape).uid with
        | Some uid -> add tbl uid (LocSet.singleton loc)
        | None -> ()
    in
    let pat
    : type k . Tast_iterator.iterator -> k Typedtree.general_pattern -> unit
    = fun sub ({pat_desc; _} as p) ->
      match pat_desc with
      | Tpat_var (ident, _) ->
        (try
        let uid = Ident.Tbl.find (Env.get_ident_to_uid_tbl ()) ident in
        let loc =  Shape.Uid.Tbl.find (Env.get_uid_to_loc_tbl ()) uid in
        add tbl uid @@ LocSet.singleton loc
        with _ -> ())
      | _ -> Tast_iterator.default_iterator.pat sub p
    in
    { Tast_iterator.default_iterator with

      expr =
        (fun sub ({ exp_desc; exp_loc; exp_env = env; _} as e) ->
          begin match exp_desc with
          | Texp_ident (path, _, { val_uid=_; _ }) ->
            begin try
              (* let env = Envaux.env_of_only_summary exp_env in *)
              let shape = Env.shape_of_path ~namespace:Kind.Value env path in
              add_to_tbl ~env ~loc:exp_loc shape
            with Not_found ->
              log ~title:"occurrences_iterator" "No shape for expr %a at %a"
                Logger.fmt (fun fmt -> Path.print fmt path)
                Logger.fmt (fun fmt -> Location.print_loc fmt exp_loc)
            end
          | _ -> () end;
          Tast_iterator.default_iterator.expr sub e);

      module_expr =
        (fun sub ({ mod_desc; mod_loc; mod_env = env; _} as me) ->
          begin match mod_desc with
          | Tmod_ident (path, _lid) ->
            begin try
              (* let env = Envaux.env_of_only_summary mod_env in *)
              let shape = Env.shape_of_path ~namespace:Kind.Module env path in
              add_to_tbl ~env ~loc:mod_loc shape
            with Not_found ->
              log ~title:"occurrences_iterator"
                "No shape for module %a at %a\n%!"
                Logger.fmt (fun fmt -> Path.print fmt path)
                Logger.fmt (fun fmt -> Location.print_loc fmt mod_loc)
            end
          | _ -> () end;
          Tast_iterator.default_iterator.module_expr sub me);

      pat;

      typ =
        (fun sub ({ ctyp_desc; ctyp_loc; ctyp_env = env; _} as me) ->
          begin match ctyp_desc with
          | Ttyp_constr (path, _lid, _ctyps) ->
            begin try
              (* let env = Envaux.env_of_only_summary ctyp_env in *)
              let shape = Env.shape_of_path ~namespace:Kind.Type env path in
              add_to_tbl ~env ~loc:ctyp_loc shape
            with Not_found ->
              log ~title:"occurrences_iterator" "No shape for type %a at %a"
                Logger.fmt (fun fmt -> Path.print fmt path)
                Logger.fmt (fun fmt -> Location.print_loc fmt ctyp_loc)
            end
          | _ -> () end;
          Tast_iterator.default_iterator.typ sub me);

    }
  in
  log ~title:"get_local_uideps" "Scanning for local uideps";
  begin match local_defs with
  | `Interface signature -> iterator.signature iterator signature
  | `Implementation structure -> iterator.structure iterator structure
  end;
  tbl

let get_uideps ~build_dir =
  let filename = "project" in
  let file = Filename.concat build_dir filename in
  let uideps = Uideps_format.read ~file in
  (match uideps with
  | Ok _ -> log ~title:"read_uideps" "Project uideps file loaded: %s" file
  | Error m -> log ~title:"read_uideps" "Failed to load project uideps: %s" m);
  uideps

let occurrences ~config ~scope ~env ~local_defs ~pos ~node ~path =
  log ~title:"occurrences" "Looking for occurences of %s (pos: %s)"
    path
    (Lexing.print_position () pos);
  let browse = Mbrowse.of_typedtree local_defs in
  let lid = Longident.parse path in
  let _ident, is_label = Longident.keep_suffix lid in
  let ctx = match Context.inspect_browse_tree ~cursor:pos lid [browse], is_label with
    | None, _ ->
      log ~title:"occurrences" "already at origin" ;
      `Error `At_origin
    | Some (Label _ as ctxt), true
    | Some ctxt, false ->
      log ~title:"occurrences"
        "inferred context: %s" (Context.to_string ctxt);
      `Ok (Namespace.from_context ctxt)
    | _, true ->
      log ~title:"occurrences"
        "dropping inferred context, it is not precise enough";
      `Ok [ `Labels ]
  in
  let uid = match ctx with
    | `Error `At_origin ->
      (* We are on  a definition / declaration so we look for the node's uid  *)
      let uid = Browse_raw.uid_of_node env node in
      (match uid with
      | Some uid ->
        log ~title:"occurrences" "found uid %a\n%!"
          Logger.fmt (fun fmt -> Shape.Uid.print fmt uid)
      | None ->
        log ~title:"occurrences" "no uid found for node %s, stopping\n%!"
        @@ Browse_raw.string_of_node node);
      Option.map uid ~f:(fun uid ->
        let def_loc = Shape.Uid.Tbl.find (Env.get_uid_to_loc_tbl ()) uid in
        uid, def_loc)
    | `Ok nss ->
      (* We are somewhere else: we must locate the definition to get its uid *)
      let uid = uid_from_longident ~config ~env nss `ML lid in
      match uid with
      | `Uid (Some uid, loc, path) ->
        log  ~title:"occurrences" "Found uid: %a (%a)\n%!"
          Logger.fmt (fun fmt -> Shape.Uid.print fmt uid)
          Logger.fmt (fun fmt -> Path.print fmt path);
        Some (uid, loc)
      | _ -> None
  in
  match uid with
  | Some (uid, _def_loc) ->
    (* Todo: use magic number instead and don't use the lib *)
    let build_dir = Mconfig.build_dir config in
    let uideps = get_local_uideps  ~config ~local_defs uid in
    if scope = `Project then begin
      let external_uideps = get_uideps ~build_dir in
      match external_uideps with
      | Ok external_uideps -> merge_tbl ~into:uideps external_uideps.defs
      | Error s -> failwith s
    end;
    (* TODO ignore indexed locs from the current buffer *)
    let locs = (match Hashtbl.find_opt uideps uid with
      | Some locs ->
        LocSet.elements locs
        |> List.filter_map ~f:(fun loc ->
          let fname = loc.Location.loc_start.Lexing.pos_fname in
          match find_source ~config loc fname with
          | `Found (Some file, _) -> Some { loc with loc_start =
              { loc.loc_start with pos_fname = file}}
          | `Found (None, _) -> Some { loc with loc_start =
              { loc.loc_start with pos_fname = ""}}
          | `File_not_found msg ->
            log ~title:"occurrences" "%s" msg;
            None
          | _ -> None)
      | None -> Format.eprintf "None\n%!"; [])
    in
    Ok locs
  | None -> Error "nouid"
