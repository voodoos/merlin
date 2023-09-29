type t = [
  | `Vals
  | `Type
  | `Constr
  | `Mod
  | `Modtype
  | `Functor
  | `Labels
  | `Unknown
  | `Apply
]

val to_string : t -> string

