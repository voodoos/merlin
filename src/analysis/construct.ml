open Std
open Typedtree

let {Logger. log} = Logger.for_section "construct"

module Util = struct
  open Types

  let prefix _env _path name =
    (*todo*)
    Longident.Lident name

  let type_to_string t =
    Printtyp.type_expr (Format.str_formatter) t;
    Format.flush_str_formatter ()

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
    - Look for values in the environnement with compatible return type. *)
  let rec expression ?(depth = 1) env typ =
    log ~title:"construct expr" "Looking for expressions of type %s"
      (Printtyp.type_expr Format.str_formatter typ; Format.flush_str_formatter ());
    let typ = Btype.repr typ in
    let matching_values = List.map
      (Util.find_values_for_type env typ)
      ~f:(make_value env) |> List.rev
    in
    let constructed_from_type = match typ.desc with
    | Tconstr (path, params, _) ->
      let def = Env.find_type_descrs path env in
      begin match def with
      | constrs, [] -> constr ~depth env typ path constrs
      | [], labels -> record ~depth env typ path labels
      | _ -> []
      end
    | (*todo*) _ -> [] in
    Util.panache2 (constructed_from_type) matching_values

  and exp_or_hole ~depth env typ =
    if depth > 0 then
      Ast_helper.Exp.hole () ::(expression ~depth:(depth - 1) env typ)
    else [ Ast_helper.Exp.hole () ]

  and constr ~depth env typ path constrs =
    log ~title:"constructors" "[%s]"
      (String.concat ~sep:"; "
        (List.map constrs ~f:(fun c -> c.Types.cstr_name)));
    (* todo for gadt not all constr will be good *)
    List.map constrs ~f:(make_constr ~depth env path typ)
    |> Util.panache

    (* [make_constr] builds the PAST repr of a type constructor applied to holes *)
  and make_constr ~depth env path typ constr =
    Ctype.unify env constr.cstr_res typ; (* todo handle errors *)
    Printf.eprintf "C: %s (%s) [%s]\n%!"
      constr.cstr_name (Util.type_to_string constr.cstr_res)
      (List.map ~f:Util.type_to_string constr.cstr_args |> String.concat ~sep:"; ");
    let lid = Location.mknoloc (Util.prefix env path constr.cstr_name) in
    let args = List.map constr.cstr_args ~f:(exp_or_hole ~depth env) in
    let combinations = Util.combinations args in
    let exps =
      List.map combinations ~f:(function
    | [] -> None
    | [e] ->Some (e)
    | l -> Some (Ast_helper.Exp.tuple l)
      ) in
    List.map ~f:(Ast_helper.Exp.construct lid) exps

  and record ~depth env typ path labels =
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
