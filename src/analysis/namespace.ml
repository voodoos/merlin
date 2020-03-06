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
  | Expr          -> [ `Vals ; `Mod ; `Modtype ; `Constr ; `Labels ; `Type ]
  | Patt          -> [ `Mod ; `Modtype ; `Type ; `Constr ; `Labels ; `Vals ]
  | Unknown       -> [ `Vals ; `Type ; `Constr ; `Mod ; `Modtype ; `Labels ]
  | Label lbl     -> [ `This_label lbl ]
  | Constructor c -> [ `This_cstr c ]
  | Module_path   -> [ `Mod ]
