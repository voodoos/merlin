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
    let aux name path descr acc =
      (* [check_type| checks return type compatibility and lists parameters *)
      let rec check_type type_expr params =
        let type_expr = Btype.repr type_expr in
        (* TODO is this test general enough ? *)
        try
          Ctype.unify env type_expr typ; Some params
        with Ctype.Unify _ -> begin match type_expr.desc with
          | Tarrow (arg_label, _, te, _) -> check_type te (arg_label::params)
          | _ -> None
      end
      in
      (* TODO we should probably sort the result better *)
      (* And filter out results like "snd" *)
      match check_type descr.val_type [] with
      | Some num_params -> (name, path, descr, num_params) :: acc
      | None -> acc
    in
    Env.fold_values aux None env []
end

module Gen = struct
  open Types

  (* [make_constr] builds the PAST repr of a type constructor applied to holes *)
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

  (* [make_value] builds the PAST repr of a value applied to holes *)
  let make_value env (name, path, value_description, params) =
    let lid = Location.mknoloc (Util.prefix env path name) in
    (* Todo handle labeled params *)
    let params = List.map params
      ~f:(fun label -> label, Ast_helper.Exp.hole ())
    in
    Ast_helper.Exp.(apply (ident lid) params)

  (* Given a typed hole, there is two relevant forms of constructions:
    - Use the type's definition to propose the correct type constructors,
    - Look for values in the environnement with this correct return type. *)
  let rec expression env typ =
    let typ = Btype.repr typ in
    let matching_values = List.map
      (Util.find_values_for_type env typ)
      ~f:(make_value env)
    in
    let constructed_from_type = match typ.desc with
    | Tconstr (path, params, _) ->
      let def = Env.find_type_descrs path env in
      begin match def with
      | constrs, [] -> constr env typ path constrs
      | _ -> []
      end
    | _ -> [] in
    List.append matching_values constructed_from_type |> List.rev

  and constr env typ path constrs =
    log ~title:"constructors" "[%s]"
      (String.concat ~sep:"; "
        (List.map constrs ~f:(fun c -> c.Types.cstr_name)));
    List.map constrs ~f:(make_constr env path)
end

let node ~parents ~pos (env, node) =
  match node with
  | Browse_raw.Expression { exp_type = typ; exp_env = env ; _ } ->
    Gen.expression env typ |> List.map ~f:Pprintast.string_of_expression
  | _ -> []
