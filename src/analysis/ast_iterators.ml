open Std
open Typedtree

let {Logger. log} = Logger.for_section "iterators"

(* The compiler contains an iterator that aims to gather definitions but
ignores local values like let-in expressions and local type definition. To
provide occurrences in the active buffer we extend the compiler's iteratir with
these cases. *)
let iter_on_defs ~uid_to_locs_tbl =
  let log = log ~title:"iter_on_defs" in
  let register_uid uid fragment =
    let loc = Misc_utils.loc_of_decl ~uid fragment in
    Option.iter loc ~f:(fun loc ->
      Types.Uid.Tbl.add uid_to_locs_tbl uid loc)
  in
  let iter_decl = Cmt_format.iter_decl ~f:register_uid in
  let register_uid uid loc =
    Types.Uid.Tbl.add uid_to_locs_tbl uid loc
  in
  { iter_decl with

    expr = (fun sub ({ exp_extra; exp_env; _ } as expr) ->
      List.iter exp_extra ~f:(fun (exp_extra, _loc, _attr) ->
        match exp_extra with
        | Texp_newtype' (typ_id, typ_name) ->
          log "Found definition %s (%a)\n%!" typ_name.txt
            Logger.fmt (fun fmt -> Location.print_loc fmt typ_name.loc);
          let decl = Env.find_type (Path.Pident typ_id) exp_env in
          register_uid decl.type_uid typ_name;
          ()
        | _ -> ());
      iter_decl.expr sub expr);

    pat = (fun (type a) sub ({pat_desc; _} as pat : a general_pattern) ->
      (match pat_desc with
      | Tpat_var (_, name, uid) | Tpat_alias (_, _, name, uid) ->
          register_uid uid name
      | _ -> ());
      iter_decl.pat sub pat);

  }
