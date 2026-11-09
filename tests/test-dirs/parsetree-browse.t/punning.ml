let ( let+ ) x f = f x
let g x =
  let+ x in
  x
