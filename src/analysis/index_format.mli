exception Not_an_index of string

module Lid : Set.OrderedType with type t = Longident.t Location.loc
module LidSet : Set.S with type elt = Longident.t Location.loc

val add : ('a, LidSet.t) Hashtbl.t -> 'a -> LidSet.t -> unit

module Stats : Map.S with type key = String.t

type stat = { mtime : float; size : int; source_digest: string option }
type index = {
  defs : (Shape.Uid.t, LidSet.t) Hashtbl.t;
  approximated : (Shape.Uid.t, LidSet.t) Hashtbl.t;
  load_path : string list;
  cu_shape : (string, Shape.t) Hashtbl.t;
  stats : stat Stats.t;
}

type file_content = Cmt of Cmt_format.cmt_infos | Index of index | Unknown

val pp : Format.formatter -> index -> unit

val ext : string
val magic_number : string

val write : file:string -> index -> unit
val read : file:string -> file_content

(** [read_exn] raises [Not_an_index] if the file does not have the correct magic
  nulmber. *)
val read_exn : file:string -> index
