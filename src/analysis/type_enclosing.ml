open Std

let from_nodes path =
    let aux (env, node, tail) =
      let open Browse_raw in
      let ret x = Some (Mbrowse.node_loc node, x, tail) in
      match[@ocaml.warning "-9"] node with
      | Expression {exp_type = t}
      | Pattern {pat_type = t}
      | Core_type {ctyp_type = t}
      | Value_description { val_desc = { ctyp_type = t } } ->
        ret (`Type (env, t))
      | Type_declaration { typ_id = id; typ_type = t} ->
        ret (`Type_decl (env, id, t))
      | Module_expr {mod_type = m}
      | Module_type {mty_type = m}
      | Module_binding {mb_expr = {mod_type = m}}
      | Module_declaration {md_type = {mty_type = m}}
      | Module_type_declaration {mtd_type = Some {mty_type = m}}
      | Module_binding_name {mb_expr = {mod_type = m}}
      | Module_declaration_name {md_type = {mty_type = m}}
      | Module_type_declaration_name {mtd_type = Some {mty_type = m}} ->
        ret (`Modtype (env, m))
      | _ -> None
    in
    List.filter_map ~f:aux path

let from_reconstructed get_context verbosity exprs env node =
      let open Browse_raw in
      let include_lident = match node with
        | Pattern _ -> false
        | _ -> true
      in
      let include_uident = match node with
        | Module_binding _
        | Module_binding_name _
        | Module_declaration _
        | Module_declaration_name _
        | Module_type_declaration _
        | Module_type_declaration_name _
          -> false
        | _ -> true
      in
      let f =
        fun {Location. txt = source; loc} ->
          match (get_context source) with
            (* Retrieve the type from the AST when it is possible *)
          | Some (Context.Constructor cd) ->
            Some (Mbrowse.node_loc node, `Type (env, cd.cstr_res), `No)
          | _ ->
            (* Else use the reconstructed identifier *)
            match source with
            | "" -> None
            | source when not include_lident && Char.is_lowercase source.[0] ->
              None
            | source when not include_uident && Char.is_uppercase source.[0] ->
              None
            | source ->
              try
                let ppf, to_string = Format.to_string () in
                if Type_utils.type_in_env ~verbosity env ppf source then
                  Some (loc, `String (to_string ()), `No)
                else
                  None
              with _ ->
                None
      in
      List.filter_map exprs ~f
