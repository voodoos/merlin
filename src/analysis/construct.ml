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

  (* Todo the following functions certainly need optimisation.
      (note the these optimisations must preserver
      the ordering of the results) *)

  (* Given a list [l] of n elements which are lists of choices,
    [combination l] is a list of all possible combinations of
    these choces. For example:

    let l = [["a";"b"];["1";"2"]; ["x"]];;
    combinations l;;
    - : string list list =
    [["a"; "1"; "x"]; ["b"; "1"; "x"];
     ["a"; "2"; "x"]; ["b"; "2"; "x"]]

    If the input is the empty lsit, the result is
    the empty list singleton list.
    *)
  let combinations =
    List.fold_left  ~init:[[]] ~f:(
      fun acc_l choices_arg_i ->
      List.fold_left choices_arg_i ~init:[] ~f:(
        fun acc choice_arg_i ->
          let choices = List.map acc_l
             ~f:(fun l -> l @ [choice_arg_i])
          in
          acc @ choices
        )
      )

  let panache2 l1 l2 =
    let rec aux acc l1 l2 =
      match l1, l2 with
      | [], [] -> List.rev acc
      | tl, [] | [], tl -> List.rev_append acc tl
      | a::tl1, b::tl2 -> aux (a::b::acc) tl1 tl2
  in aux [] l1 l2

  (* Given a list [l] of n lists, [panache l] flattens the list
    by starting with the first element of it, then the second one etc. *)
  let panache l =
    List.fold_left ~init:[] ~f:panache2 l
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

  (* [make_record] builds the PAST repr of a record with holes *)
  let make_record env path labels =
    let labels = List.map labels ~f:(fun label ->
      let lid = Location.mknoloc (Util.prefix env path label.lbl_name) in
      lid, Ast_helper.Exp.hole ()
    ) in
    Ast_helper.Exp.record labels None

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
      | [], labels -> record env typ path labels
      | _ -> []
      end
    | (*todo*) _ -> [] in
    List.append matching_values constructed_from_type |> List.rev

  and constr env typ path constrs =
    log ~title:"constructors" "[%s]"
      (String.concat ~sep:"; "
        (List.map constrs ~f:(fun c -> c.Types.cstr_name)));
    List.map constrs ~f:(make_constr env path)

  and record env typ path labels =
  log ~title:"record labels" "[%s]"
    (String.concat ~sep:"; "
      (List.map labels ~f:(fun l -> l.Types.lbl_name)));
  [make_record env path labels]
end

let node ~parents ~pos (env, node) =
  match node with
  | Browse_raw.Expression { exp_type = typ; exp_env = env ; _ } ->
    Gen.expression env typ |> List.map ~f:Pprintast.string_of_expression
  | _ -> []
