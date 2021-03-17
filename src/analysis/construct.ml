open Std
open Typedtree

let {Logger. log} = Logger.for_section "construct"

type values_scope = Null | Local

exception Not_allowed of string

module Util = struct
  open Types

  let predef_types =
    (* Taken from old PR *)
    let tbl = Hashtbl.create 14 in
    let () =
      let mk s =
        Ast_helper.Exp.construct (Location.mknoloc (Longident.Lident s)) None
      in
      List.iter ~f:(fun (k, v) -> Hashtbl.add tbl k v) [
        Predef.path_int, mk "0" ;
        Predef.path_char, mk "'c'" ;
        Predef.path_string, mk "\"\"" ;
        Predef.path_float, mk "0.0" ;
        Predef.path_bool, mk "true" ;
        Predef.path_unit, mk "()" ;
        Predef.path_exn, mk "exn" ;
        Predef.path_array, mk "[| |]" ;
        Predef.path_nativeint, mk "0n" ;
        Predef.path_int32, mk "0l" ;
        Predef.path_int64, mk "0L" ;
        Predef.path_lazy_t, mk "(lazy)" ;
      ]
    in
    tbl

  let prefix env ~env_check path name =
    Destruct.Path_utils.to_shortest_lid ~env ~env_check ~name path

  let type_to_string t =
    Printtyp.type_expr (Format.str_formatter) t;
    Format.flush_str_formatter ()

  (** [find_values_for_type env typ] searches the environment [env] for values
  with a return type compatible with [typ] *)
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
      (* TODO we should probably sort the results better *)
      (* Also the Path filter is too restrictive. *)
      match path, check_type descr.val_type [] with
      | Path.Pident _, Some params ->
        (name, path, descr, params) :: acc
      | _, _ -> acc
    in
    Env.fold_values aux lid env []

  (* TODO the following function could be optimized. (note that these
    optimisations should preserve the ordering of the results).
    It is used to present all possible mixes of arguments when calling
    construct recursively on a pultiple holes. *)

  (* Given a list [l] of n elements which are lists of choices,
    [combination l] is a list of all possible combinations of
    these choices. For example:

    let l = [["a";"b"];["1";"2"]; ["x"]];;
    combinations l;;
    - : string list list =
    [["a"; "1"; "x"]; ["b"; "1"; "x"];
     ["a"; "2"; "x"]; ["b"; "2"; "x"]]

    If the input is the empty list, the result is
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
    Ast_helper.Exp.hole ()

  (* [value] generates the PAST repr of a value applied to holes *)
  let value env (name, path, value_description, params) =
    let env_check = Env.find_value_by_name in
    let lid = Location.mknoloc (Util.prefix env ~env_check path name) in
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

  (* [expression values_scope ~depth env ty] generates a list of PAST
    expressions that could fill a hole of type [ty] in the environment [env].
    [depth] regulates the deep construction of recursive values. If
    [values_scope] is set to [Local] the returned list will also contains
    local values to choose from *)
  let expression = fun vscope -> let rec at_depth ~depth =
    let exp_or_hole env typ =
      if depth > 1 then
        (* If max_depth has not been reached we resurse *)
        Ast_helper.Exp.hole () :: (at_depth ~depth:(depth - 1) env typ)
      else
        (* else we return a hole *)
        [ Ast_helper.Exp.hole () ]
    in

    let constructor env typ path constrs =
      log ~title:"constructors" "[%s]"
        (String.concat ~sep:"; "
          (List.map constrs ~f:(fun c -> c.Types.cstr_name)));
      (* todo for gadt not all constr will be good *)
      (* [make_constr] builds the PAST repr of a type constructor applied to holes *)
      let make_constr env path typ cstr_descr =
        let snap = Btype.snapshot () in
        let ty_args, ty_res = Ctype.instance_constructor cstr_descr in
        try
          Ctype.unify env ty_res typ;
          let lid =
            Util.prefix env ~env_check:Env.find_constructor_by_name
              path cstr_descr.cstr_name
            |> Location.mknoloc
          in
          let args = List.map ty_args ~f:(exp_or_hole env) in
          let args_combinations = Util.combinations args in
          let exps =List.map args_combinations
            ~f:(function
              | [] -> None
              | [e] ->Some e
              | l -> Some (Ast_helper.Exp.tuple l))
          in
          Btype.backtrack snap;
          List.map ~f:(Ast_helper.Exp.construct lid) exps
        with _ -> (* Unification failure *) []
      in
      List.map constrs ~f:(make_constr env path typ)
      |> Util.panache
    in

    let variant env typ row_desc =
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
    in

    let record env typ path labels =
      log ~title:"record labels" "[%s]"
        (String.concat ~sep:"; "
          (List.map labels ~f:(fun l -> l.Types.lbl_name)));

      let labels = List.map labels ~f:(fun ({ lbl_name; _ } as lbl) ->
        let snap = Btype.snapshot () in
        let _, arg, res = Ctype.instance_label true lbl in
        Ctype.unify env res typ ;
        let lid =
          Util.prefix env ~env_check:Env.find_label_by_name path lbl_name
          |> Location.mknoloc
        in
        let exprs = exp_or_hole env arg in
        Btype.backtrack snap;
        lid, exprs)
      in

      let lbl_lids, lbl_exprs = List.split labels in
      Util.combinations lbl_exprs
      |> List.map
          ~f:(fun lbl_exprs ->
            let labels = List.map2 lbl_lids lbl_exprs
              ~f:(fun lid exp -> (lid, exp))
            in
            Ast_helper.Exp.record labels None)
    in

    (* Given a typed hole, there is two possible forms of constructions:
      - Use the type's definition to propose the correct type constructors,
      - Look for values in the environnement with compatible return type. *)
    fun env typ ->
      log ~title:"construct expr" "Looking for expressions of type %s"
        (Util.type_to_string typ);
      let no_values = ref (vscope = Null) in
      let rtyp = Ctype.full_expand env typ |> Btype.repr in
      let constructed_from_type = match rtyp.desc with
        | Tlink _ | Tsubst _ ->
          assert false
        | Tpoly (texp, _)  ->
          no_values := true;
          exp_or_hole env texp
        | Tunivar _ | Tvar _ ->
          no_values := true;
          [ ]
        | Tconstr (path, [texp], _) when path = Predef.path_lazy_t ->
          (* Special case for lazy *)
          let exps = exp_or_hole env texp in
          List.map exps ~f:Ast_helper.Exp.lazy_
        | Tconstr (path, params, _) ->
          (* If this is a "basic" type we propose a default value *)
          begin try
            [ Hashtbl.find Util.predef_types path ]
          with Not_found ->
            let def = Env.find_type_descrs path env in
            match def with
            | constrs, [] -> constructor env rtyp path constrs
            | [], labels -> record env rtyp path labels
            | _ -> []
          end
        | Tarrow (label, tyleft, tyright, _) ->
          let argument, name = make_arg label tyleft in
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
        | Tobject _ -> failwith "Not implemented"
        | Tfield _ -> failwith "Not implemented"
        | Tnil -> failwith "Not implemented"
      in
      let matching_values =
        if !no_values then [] else
        List.map (Util.find_values_for_type env typ)
          ~f:(value env) |> List.rev
      in
      List.append constructed_from_type matching_values
   in
   at_depth
end

let node ?(max_depth = 1) ~vscope ~parents ~pos (env, node) =
  match node with
  | Browse_raw.Expression { exp_type; exp_env ; exp_desc = Texp_hole; _ } ->
    Gen.expression vscope ~depth:max_depth exp_env exp_type
    |> List.map ~f:Pprintast.string_of_expression
  | _ -> []
