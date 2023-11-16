module Namespace : sig
  type t =
      [ `Apply
      | `Constr
      | `Functor
      | `Labels
      | `Mod
      | `Modtype
      | `Type
      | `Unknown
      | `Vals ]

  val to_string : t -> string

  type under_type = [ `Constr | `Labels ]
  type inferred_basic =
      [ `Constr | `Labels | `Mod | `Modtype | `Type | `Vals ]
  type inferred =
      [ `Constr
      | `Labels
      | `Mod
      | `Modtype
      | `This_cstr of Types.constructor_description
      | `This_label of Types.label_description
      | `Type
      | `Vals ]

  val from_context : Context.t -> inferred list
end

type declaration = {
  uid: Shape.Uid.t;
  loc: Location.t;
  namespace: Shape.Sig_component_kind.t
}

val loc
  : Path.t
  -> Namespace.t
  -> Env.t
  -> declaration option

val in_namespaces
   : Namespace.inferred list
  -> Longident.t
  -> Env.t
  -> (Path.t * declaration) option
