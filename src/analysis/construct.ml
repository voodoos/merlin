open Std
open Typedtree

let {Logger. log} = Logger.for_section "construct"

module Util = struct
  open Types

  let prefix _env _path name =
    (*todo*)
    Longident.Lident name

  (** [find_values_for_type env typ] searches the environment [env] for values
  with return type compatible with [typ] *)
  let find_values_for_type env typ =
    Printtyp.type_expr (Format.str_formatter) typ;
    Printf.eprintf "Looking for %S\n%!" (Format.flush_str_formatter ());
    let aux name path descr acc =
      let rec check_type type_expr =
        (* TODO is this test general enough ? *)
        try
          Ctype.unify env type_expr typ; true
        with Ctype.Unify _ -> begin match type_expr.desc with
          | Tarrow (_, _, te, _) -> check_type te
          | _ -> false
      end
      in
      (* TODO we should probably sort the result better *)
      (* And filter out results like "snd" *)
      if check_type descr.val_type then
        (name, path, descr) :: acc
      else acc
    in
    Env.fold_values aux None env []
end

module Gen = struct
  open Types

  let make_constr env path constr =
    let lid = Location.mknoloc (Util.prefix env path constr.cstr_name) in
    let exps = match constr.cstr_args with
    | [] -> None
    | [_] ->  Some (Ast_helper.Exp.hole ())
    | l -> Some (Ast_helper.Exp.tuple (
      List.map l ~f:(fun _ -> Ast_helper.Exp.hole ())
    ))
    in
    Ast_helper.Exp.construct lid exps

  let rec expression env typ =
    let typ = Btype.repr typ in
    let values = Util.find_values_for_type env typ in
    log ~title:"values" "[%s]"
      (String.concat ~sep:"; "
        (List.map values ~f:(fun (n, p, _) ->
          Path.print (Format.str_formatter) p;
          Printf.sprintf "%s (%s)" n
            (Format.flush_str_formatter ())

        )));
    match typ.desc with
    | Tconstr (path, params, _) ->
      let def = Env.find_type_descrs path env in
      begin match def with
      | constrs, [] -> constr env typ path constrs
      | _ -> []
      end
    | _ -> []

  and constr env typ path constrs =
    log ~title:"constructors" "[%s]"
      (String.concat ~sep:"; "
        (List.map constrs ~f:(fun c -> c.Types.cstr_name)));
    let past = List.map constrs ~f:(make_constr env path) in
    List.iter past ~f:(fun p ->
      Pprintast.expression (Format.str_formatter) p;
      Format.flush_str_formatter () |> Printf.eprintf "%s\n%!"
      );
    past
end

let node ~parents ~pos (env, node) =
  match node with
  | Browse_raw.Expression { exp_type = typ; exp_env = env ; _ } ->
    Gen.expression env typ |> List.map ~f:Pprintast.string_of_expression
  | _ -> []
