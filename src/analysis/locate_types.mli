module Type_tree = Query_protocol.Locate_types_result.Type_tree

type raw_type = { path : Path.t; ty : Types.type_expr }

(** Convert a type into a simplified tree representation. *)
val create_type_tree : Types.type_expr -> raw_type Type_tree.t option
