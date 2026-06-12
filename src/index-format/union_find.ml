module Uid = Shape.Uid
module Uid_map = Granular_map.Make (Uid)

type 'a elt_handle = Uid.t

type 'a content = Root of { value : 'a; rank : int } | Link of 'a elt_handle

type 'a store = 'a content Uid_map.t

let empty () = Uid_map.empty ()

let new_root store uid value =
  (Uid_map.add uid (Root { value; rank = 0 }) store, uid)

let rec find_and_compress store uid =
  match Uid_map.find uid store with
  | Root _ -> (store, uid)
  | Link parent ->
    let store, root = find_and_compress store parent in
    let store =
      (* Path compression: point [uid] to the root. *)
      if Uid.equal parent root then store else Uid_map.add uid (Link root) store
    in
    (store, root)

let rec find store uid =
  match Uid_map.find uid store with
  | Root _ -> uid
  | Link parent -> find store parent

let get store uid =
  let root = find store uid in
  match Uid_map.find root store with
  | Root { value; _ } -> value
  | Link _ -> assert false

let union ~f store x y =
  let store, x = find_and_compress store x in
  let store, y = find_and_compress store y in
  if Uid.equal x y then (store, x)
  else
    match (Uid_map.find x store, Uid_map.find y store) with
    | ( Root { value = value_x; rank = rank_x },
        Root { value = value_y; rank = rank_y } ) ->
      let value = f value_x value_y in
      if rank_x < rank_y then
        let store =
          let s = Uid_map.add x (Link y) store in
          if value <> value_y then
            Uid_map.add y (Root { value; rank = rank_y }) s
          else s
        in
        (store, y)
      else if rank_x > rank_y then
        let store =
          let s = Uid_map.add y (Link x) store in
          if value <> value_x then
            Uid_map.add x (Root { value; rank = rank_x }) s
          else s
        in
        (store, x)
      else
        let store =
          Uid_map.add y (Link x) store
          |> Uid_map.add x (Root { value; rank = rank_x + 1 })
        in
        (store, x)
    | Link _, Root _ | Root _, Link _ | Link _, Link _ -> assert false

let merge ~f (s1 : 'a store) (s2 : 'a store) =
  Uid_map.union
    (fun _ c1 c2 ->
      let r1 =
        match c1 with
        | Root _ -> c1
        | Link l -> Uid_map.find (find s1 l) s1
      in
      let r2 =
        match c2 with
        | Root _ -> c2
        | Link l -> Uid_map.find (find s2 l) s2
      in
      match (r1, r2) with
      | Root { value = v1; rank = r1 }, Root { value = v2; rank = r2 } ->
        Some (Root { value = f v1 v2; rank = (if r1 > r2 then r1 else r2) })
      | _ -> assert false)
    s1 s2
