module type T = sig type a end

module T : sig type b end

include T
