open! Std

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

let to_string = function
  | `Mod -> "(module) "
  | `Functor -> "(functor)"
  | `Labels -> "(label) "
  | `Constr -> "(constructor) "
  | `Type -> "(type) "
  | `Vals -> "(value) "
  | `Modtype -> "(module type) "
  | `Unknown -> "(unknown)"
  | `Apply -> "(functor application)"
