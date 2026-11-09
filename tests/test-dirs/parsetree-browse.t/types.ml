type t = A of int | B of { x : int }
type v = [ `A | `B of int ]
type o = < m : int; n : string >
class c = object
  val v = 1
  method m = v
end
