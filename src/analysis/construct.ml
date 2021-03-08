open Std
open Typedtree

let {Logger. log} = Logger.for_section "construct"

type values_scope = Null | Local

exception Not_allowed of string

module Util = struct
  open Types

  let prefix env ~env_check path name =
    Destruct.Path_utils.to_shortest_lid ~env ~env_check ~name path

  let type_to_string t =
    Printtyp.type_expr (Format.str_formatter) t;
    Format.flush_str_formatter ()

  (** [find_values_for_type env typ] searches the environment [env] for values
  with return type compatible with [typ] *)
  let find_values_for_type env typ =
    let lid = None (* Some (Longident.parse ".") *) in
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
      (* Also the Path filter is too restrictive. *)
      match path, check_type descr.val_type [] with
      | Path.Pident _, Some params ->
        (name, path, descr, params) :: acc
      | _, _ -> acc
    in
    Env.fold_values aux lid env []

  (* Todo the following functions might need optimisation. (note that these
    optimisations must preserver the ordering of the results). They are used
    to present more varied results firts when asking for values. *)

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
    by starting with the first element of each, then the second one etc. *)
  let panache l =
    List.fold_left ~init:[] ~f:panache2 l
end

module Gen = struct
  open Types

  let hole =
    (* Todo: we could, as it is done in the original PR,
      try some last minute replacement for base types.val_type
      (for example if the hole is of type int, use 0. *)
    Ast_helper.Exp.hole ()

  (* [make_record] builds the PAST repr of a record with holes *)
  let make_record env path labels =
    let labels = List.map labels ~f:(fun label ->
      let lid = Location.mknoloc (
          Util.prefix env ~env_check:Env.find_label_by_name path label.lbl_name
        )
      in
      lid, hole
    ) in
    Ast_helper.Exp.record labels None

  (* [make_value] builds the PAST repr of a value applied to holes *)
  let make_value env (name, path, value_description, params) =
    let lid = Location.mknoloc (
        Util.prefix env ~env_check:Env.find_value_by_name path name
      )
    in
    let params = List.map params
      ~f:(fun label -> label, Ast_helper.Exp.hole ())
    in
    Ast_helper.Exp.(apply (ident lid) params)

  (* [make_arg] tries to provide a nice default name for function args *)
  let make_arg label ty =
    let open Asttypes in
    match label with
    | Labelled s | Optional s ->
        (* Pun for labelled arguments *)
        Ast_helper.Pat.var ( Location.mknoloc s), s
    | Nolabel ->
      (* Type-derived name for other arguments *)
      (* todo *) (* todo check they are not in use *)
      Ast_helper.Pat.any (), "todo"

  (* Given a typed hole, there is two relevant forms of constructions:
    - Use the type's definition to propose the correct type constructors,
    - Look for values in the environnement with compatible return type. *)
  let expression = fun vscope -> let rec at_depth ~depth =
    let rec exp env typ =
      log ~title:"construct expr" "Looking for expressions of type %s"
        (Util.type_to_string typ);
      let no_values = ref (vscope = Null) in
      let rtyp = Ctype.full_expand env typ |> Btype.repr in
      let constructed_from_type = match rtyp.desc with
      | Tlink _ | Tsubst _ ->
        (* todo can these happen after expand/repr ? *)
        assert false
      | Tpoly (texp, _)  ->
        no_values := true;
        exp env texp
      | Tunivar _ | Tvar _ ->
        no_values := true;
        [ ]
      | Tconstr (path, [texp], _) when path = Predef.path_lazy_t ->
        (* Special case for lazy *)
        let exps = exp_or_hole env texp in
        List.map exps ~f:Ast_helper.Exp.lazy_
      | Tconstr (path, params, _) ->
        let def = Env.find_type_descrs path env in
        begin match def with
        | constrs, [] -> constr env rtyp path constrs
        | [], labels -> record env rtyp path labels
        | _ -> [] end
      | Tarrow (label, tyleft, tyright, _) ->
        let argument, name = make_arg label tyleft in
        (* todo does not work *)
        let value_description = {
            val_type = tyleft;
            val_kind = Val_reg;
            val_loc = Location.none;
            val_attributes = [];
            val_uid = Uid.mk ~current_unit:(Env.get_unit_name ());
          }
        in
        let env = Env.add_value (Ident.create_local name) value_description env in
        let exps = exp_or_hole env tyright in
        (* todo use names for args *)
        List.map exps ~f:(Ast_helper.Exp.fun_ label None argument)
      | Ttuple types ->
        let choices = List.map types ~f:(exp_or_hole env)
          |> Util.combinations
        in
        List.map choices  ~f:Ast_helper.Exp.tuple
      | Tvariant row_desc -> variant env rtyp row_desc
      | Tpackage (path, lids, tys) -> failwith "Not implemented"
      | Tobject _ ->  failwith "Not implemented"
      | Tfield _ ->  failwith "Not implemented"
      | Tnil -> failwith "Not implemented"
      in
      let matching_values =
        if !no_values then [] else
        List.map (Util.find_values_for_type env typ)
          ~f:(make_value env) |> List.rev
      in
      List.append constructed_from_type matching_values

    and exp_or_hole env typ =
      (* If max_depth has not been reached we resurse, else we return a hole *)
      if depth > 1 then
        Ast_helper.Exp.hole () :: (at_depth ~depth:(depth - 1) env typ)
      else [ Ast_helper.Exp.hole () ]

    and constr env typ path constrs =
      log ~title:"constructors" "[%s]"
        (String.concat ~sep:"; "
          (List.map constrs ~f:(fun c -> c.Types.cstr_name)));
      (* todo for gadt not all constr will be good *)
      (* [make_constr] builds the PAST repr of a type constructor applied to holes *)
      let make_constr env path typ constr =
        Ctype.unify env constr.cstr_res typ; (* todo handle errors *)
        (* Printf.eprintf "C: %s (%s) [%s]\n%!"
          constr.cstr_name (Util.type_to_string constr.cstr_res)
          (List.map ~f:Util.type_to_string constr.cstr_args |> String.concat ~sep:"; "); *)
        let lid = Location.mknoloc (
            Util.prefix env ~env_check:Env.find_constructor_by_name path constr.cstr_name
          )
        in
        let args = List.map constr.cstr_args ~f:(exp_or_hole env) in
        let combinations = Util.combinations args in
        let exps =
          List.map combinations ~f:(function
        | [] -> None
        | [e] ->Some (e)
        | l -> Some (Ast_helper.Exp.tuple l)
          ) in
        List.map ~f:(Ast_helper.Exp.construct lid) exps
      in
      List.map constrs ~f:(make_constr env path typ)
      |> Util.panache

      and variant env typ row_desc =
        let fields =
          List.filter
            ~f:(fun (lbl, row_field) -> match row_field with
              | Rpresent _
              | Reither (true, [], _, _)
              | Reither (false, [_], _, _) -> true
              | _ -> false)
            row_desc.row_fields
        in
        match fields with
        | [] -> raise (Not_allowed "empty variant type")
        | row_descrs ->
          List.map row_descrs ~f:(fun (lbl, row_field) ->
            (match row_field with
              | Reither (false, [ty], _, _) | Rpresent (Some ty) ->
                List.map ~f:(fun s -> Some s) (exp_or_hole env ty)
              | _ -> [None])
              |> List.map ~f:(fun e ->
                Ast_helper.Exp.variant lbl e)
              )
          |> List.flatten

    and record env typ path labels =
    log ~title:"record labels" "[%s]"
      (String.concat ~sep:"; "
        (List.map labels ~f:(fun l -> l.Types.lbl_name)));
    [make_record env path labels]
  in exp in at_depth

end

let node ?(max_depth = 1) ~vscope ~parents ~pos (env, node) =
  match node with
  | Browse_raw.Expression { exp_type = typ; exp_env = env ; exp_desc = Texp_hole; _ } ->
    Gen.expression vscope ~depth:max_depth env typ |> List.map ~f:Pprintast.string_of_expression
  | _ -> []
