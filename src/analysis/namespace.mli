type t = [ `Type | `Mod | `Modtype | `Vals | `Constr | `Labels ]

type inferred =
  [ t
  | `This_label of Types.label_description
  | `This_cstr of Types.constructor_description ]

val from_context : Context.t -> inferred list
