[@@@warning "-32"]
let x = 1 [@@attr 2 + 2]
[%%ext let y = 3]
let z = M.(x)
