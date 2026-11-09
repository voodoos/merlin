let f x y =
  match x with
  | Some z when z > y -> M.(z + 1)
  | None -> [%ext 1 + 2]
