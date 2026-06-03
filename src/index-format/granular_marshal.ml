module Cache = Hashtbl.Make (Int)

type store = { filename : string; id : int; cache : cache }

and cache = any_link Cache.t

and any_link = Link : 'a link * 'a link Type.Id.t -> any_link

and parent_link = PLink : 'a link -> parent_link

and any_value = Value : 'a * 'a link Type.Id.t -> any_value
and small_value = Small_value of (any_value * small_value array)

and cached = Cached : 'a link * int * store * 'a schema -> cached

and 'a link = 'a repr ref

(** Links descriptions. *)
and 'a repr =
  | Small of int
  | Small_child of
      { parent : parent_link; pos : int; type_id : 'a link Type.Id.t }
  | Serialized of { loc : int }
  | Serialized_reused of { loc : int }
  | On_disk of { store : store; loc : int; schema : 'a schema }
  | On_disk_ptr of { filename : string; loc : int; id : int; pos : int option }
  | On_disk_small_ptr of
      { store : store; loc : int; small_pos : int; small_schema : 'a schema }
  | In_memory of 'a
  | In_cache of 'a * cached Dbllist.cell * any_value array
  | In_memory_reused of 'a
  | Duplicate of 'a link

and 'a schema = iter -> 'a -> unit

and iter = { yield : 'a. 'a link -> 'a link Type.Id.t -> 'a schema -> unit }

let string_of_link : type a. a link -> string =
 fun link ->
  match !link with
  | Small _ -> Printf.sprintf "Small"
  | Small_child { pos; _ } -> Printf.sprintf "Small_child(pos=%d)" pos
  | Serialized { loc } -> Printf.sprintf "Serialized(loc=%d)" loc
  | Serialized_reused { loc } -> Printf.sprintf "Serialized_reused(loc=%d)" loc
  | On_disk { loc; _ } -> Printf.sprintf "On_disk(loc=%d)" loc
  | On_disk_ptr { loc; pos; _ } ->
    Printf.sprintf "On_disk_ptr(loc=%d%s)" loc
      (match pos with
      | Some pos -> Printf.sprintf ", pos=%d" pos
      | None -> "")
  | On_disk_small_ptr { loc; small_pos; _ } ->
    Printf.sprintf "On_disk(loc=%d;small_pos=%d)" loc small_pos
  | In_memory _ -> "In_memory"
  | In_cache _ -> "In_cache"
  | In_memory_reused _ -> "In_memory_reused"
  | Duplicate _ -> "Duplicate"

exception
  Outdated_store of
    { filename : string; reason : [ `Missing_file | `Index_ids_do_not_match ] }

let lru_dbllist : cached Dbllist.t option ref = ref None
let lru_size = ref 1_000_000
let set_lru_size i = lru_size := i

let get_lru () =
  match !lru_dbllist with
  | Some lru -> lru
  | None ->
    let lru = Dbllist.create !lru_size in
    lru_dbllist := Some lru;
    lru

let schema_no_sublinks : _ schema = fun _ _ -> ()

let link v = ref (In_memory v)

let is_on_disk lnk =
  match !lnk with
  | On_disk _ | On_disk_ptr _ | In_cache _ -> true
  | _ -> false

let rec normalize lnk =
  match !lnk with
  | Duplicate lnk -> normalize lnk
  | _ -> lnk

module Cache_cache = File_cache.Make (struct
  type t = cache
  let read _filename = Cache.create 0

  let cache_name = "Cache_cache"
end)

let ptr_size = 8

let binstring_of_int v =
  String.init ptr_size (fun i -> Char.chr ((v lsr i lsl 3) land 255))

let int_of_binstring s =
  Array.fold_right
    (fun v acc -> (acc lsl 8) + v)
    (Array.init ptr_size (fun i -> Char.code s.[i]))
    0

let last_open_store = ref None

let force_open_store store =
  try
    let fd = open_in_bin store.filename in
    seek_in fd (String.length Config.index_magic_number);
    let required_id = int_of_binstring (really_input_string fd ptr_size) in
    if required_id = store.id then (
      last_open_store := Some (store, fd);
      fd)
    else
      raise
        (Outdated_store
           { filename = store.filename; reason = `Index_ids_do_not_match })
  with Sys_error _ ->
    raise (Outdated_store { filename = store.filename; reason = `Missing_file })

let open_store store =
  match !last_open_store with
  | Some (store', fd)
    when Int.equal store.id store'.id
         && String.equal store.filename store'.filename -> fd
  | Some (_, fd) ->
    close_in fd;
    force_open_store store
  | None -> force_open_store store

let read_loc store fd loc schema parent_link =
  seek_in fd loc;
  let v, small_children = Marshal.from_channel fd in
  Format.eprintf "Smalls size=%i\n%!" (Array.length small_children);
  let size_read = pos_in fd - loc in
  (* let child_pos = ref 0 in
  let child_smalls = ref [] in *)
  let rec iter smalls =
    { yield =
        (fun (type a)
          (lnk : a link)
          (type_id : a link Type.Id.t)
          (schema : a schema)
        ->
          match !lnk with
          | Small pos -> (
            Format.eprintf "Lookup Small %i size=%i\n%!" pos
              (Array.length smalls);
            let (Small_value (Value (type b) ((v, type_id') : b * _), v_smalls))
                =
              smalls.(pos)
            in
            match Type.Id.provably_equal type_id type_id' with
            | None ->
              invalid_arg "Granular_marshal.read_loc: small has wrong type"
            | Some (Equal : (a link, b link) Type.eq) ->
              schema (iter v_smalls) v;
              lnk := Small_child { parent = parent_link; pos; type_id })
          | Serialized { loc } -> lnk := On_disk { store; loc; schema }
          | Serialized_reused { loc } -> (
            match Cache.find_opt store.cache loc with
            | Some (Link (type b) ((lnk', type_id') : b link * _)) -> (
              match Type.Id.provably_equal type_id type_id' with
              | Some (Equal : (a link, b link) Type.eq) ->
                lnk := Duplicate (normalize lnk')
              | None ->
                invalid_arg
                  "Granular_marshal.read_loc: reuse of a different type")
            | None ->
              lnk := On_disk { store; loc; schema };
              Cache.add store.cache loc (Link (lnk, type_id)))
          | In_memory _
          | In_cache _
          | In_memory_reused _
          | On_disk_small_ptr _
          | On_disk _
          | Small_child _
          | Duplicate _ -> (* TODO when does this happen ? *) ()
          | On_disk_ptr { filename; loc; id; pos = None } ->
            let store = { filename; id; cache = Cache_cache.read filename } in
            lnk := On_disk { store; loc; schema }
          | On_disk_ptr { filename; loc; id; pos = Some small_pos } ->
            let store = { filename; id; cache = Cache_cache.read filename } in
            lnk :=
              On_disk_small_ptr { store; loc; small_schema = schema; small_pos })
    }
  in
  schema (iter small_children) v;
  (v, size_read, small_children)

let fetch_loc store loc schema parent_link =
  let fd = open_store store in
  let v, size, small_poses = read_loc store fd loc schema parent_link in
  (v, size, small_poses)

let rec fetch : type a. a link -> a =
 fun lnk ->
  match !lnk with
  | In_cache (v, cell, _) ->
    Dbllist.promote (get_lru ()) cell;
    v
  | In_memory v | In_memory_reused v -> v
  | Serialized _ | Serialized_reused _ | Small _ | On_disk_ptr _ ->
    invalid_arg ("Granular_marshal.fetch: " ^ string_of_link lnk)
  | Duplicate original_lnk -> fetch original_lnk
  | Small_child { parent; pos; type_id } -> (
    let (PLink parent) = parent in
    ignore (fetch parent);
    match !parent with
    | In_cache (_, _, small_poses) -> (
      let (Value (type b) ((v, type_id') : b * _)) = small_poses.(pos) in
      match Type.Id.provably_equal type_id type_id' with
      | Some (Equal : (a link, b link) Type.eq) -> v
      | None -> invalid_arg "Granular_marshal.read_loc: small has wrong type")
    | _ -> assert false)
  | On_disk_small_ptr (*{ store; loc; small_schema = schema; small_pos }*) _ ->
    assert false
  | On_disk { store; loc; schema } ->
    let v, size, small_poses = fetch_loc store loc schema (PLink lnk) in
    let discarded = Dbllist.discard_size (get_lru ()) size in
    let cell =
      Dbllist.add_front (get_lru ()) (Cached (lnk, loc, store, schema), size)
    in
    List.iter
      (fun (Cached (link, loc, store, schema)) ->
        link := On_disk { store; loc; schema })
      discarded;
    lnk := In_cache (v, cell, small_poses);
    v

(* TODO The compression is not so easy to do and has a minor impact. *)
(* Or we could just do it "in memory" *)
let rec reuse original_lnk =
  match !original_lnk with
  | In_memory v -> original_lnk := In_memory_reused v
  | In_memory_reused _ -> ()
  | On_disk _ -> ()
  | Duplicate link -> reuse link
  | _ ->
    invalid_arg
    @@ Printf.sprintf "Granular_marshal.reuse: not in memory, got %s"
         (string_of_link original_lnk)

let cache (type a) (module Key : Hashtbl.HashedType with type t = a) =
  let module H = Hashtbl.Make (Key) in
  let cache = H.create 16 in
  fun (lnk : a link) ->
    let key = fetch lnk in
    match H.find cache key with
    | original_lnk ->
      assert (original_lnk != lnk);
      reuse original_lnk;
      lnk := Duplicate original_lnk
    | exception Not_found -> H.add cache key lnk

let write ?(flags = []) fd ~id root_schema root_value =
  let output v (small_children : small_value array) =
    Marshal.to_channel fd (v, small_children) flags
  in
  let id = binstring_of_int id in
  output_string fd id;
  let pt_root = pos_out fd in
  output_string fd (String.make ptr_size '\000');
  let rec iter size ~small_children ~small_children_count =
    { yield =
        (fun (type a) (lnk : a link) type_id (schema : a schema) : unit ->
          match !lnk with
          | Serialized _
          | Serialized_reused _
          | Small _
          | On_disk_ptr _
          | On_disk_small_ptr _ -> ()
          | In_memory_reused v ->
            write_child_reused lnk schema v ~small_children
              ~small_children_count
          | Duplicate original_lnk -> (
            match !original_lnk with
            | Serialized_reused _ | On_disk_ptr _ -> lnk := !original_lnk
            | In_memory_reused v ->
              write_child_reused original_lnk schema v ~small_children
                ~small_children_count;
              lnk := !original_lnk
            | On_disk { store = { filename; id; _ }; loc; _ } ->
              lnk := On_disk_ptr { filename; id; loc; pos = None }
            | _ ->
              failwith
                (Format.sprintf
                   "Granular_marshal.write: duplicate not reused got %s"
                   (string_of_link original_lnk)))
          | In_memory v ->
            write_child lnk schema v type_id size ~small_children
              ~small_children_count
          | Small_child { parent = PLink parent; pos; _ } ->
            (* This only happens if this small child has no parent anymore.
               If it had it would have been processed along its parent. *)
            let filename, id, loc =
              match !parent with
              | In_cache
                  ( _,
                    { content = Cached (_, loc, { filename; id; _ }, _); _ },
                    _ )
              | On_disk { store = { filename; id; _ }; loc; _ }
              | On_disk_ptr { filename; id; loc; _ } -> (filename, id, loc)
              | _ -> failwith "todo explain"
            in
            lnk := On_disk_ptr { filename; id; loc; pos = Some pos }
          | In_cache (_v, t, _children) ->
            let (Cached (_, loc, { filename; id; _ }, _)) = t.content in
            lnk := On_disk_ptr { filename; id; loc; pos = None }
          | On_disk { store = { filename; id; _ }; loc; _ } ->
            (* TODO we could have all the possible filenames wrote once
               somewhere in the file. *)
            lnk := On_disk_ptr { filename; id; loc; pos = None })
    }
  and write_child : type a. a link -> a schema -> a -> a link Type.Id.t -> _ =
   fun lnk schema v type_id size ~small_children ~small_children_count ->
    let v_size, v_smalls = write_children schema v in
    let v_smalls = Array.of_list (List.rev v_smalls) in
    if v_size > 1024 then (
      lnk := Serialized { loc = pos_out fd };
      output v v_smalls)
    else (
      size := !size + v_size;
      small_children :=
        Small_value (Value (v, type_id), v_smalls) :: !small_children;
      lnk := Small !small_children_count;
      incr small_children_count)
  and write_children : type a. a schema -> a -> int * small_value list =
   fun schema v ->
    let children_size = ref 0 in
    let small_children = ref [] in
    let small_children_count = ref 0 in
    schema (iter children_size ~small_children ~small_children_count) v;
    let v_size = Obj.(reachable_words (repr v)) in
    (!children_size + v_size, !small_children)
  and write_child_reused : type a. a link -> a schema -> a -> _ =
   fun lnk schema v ~small_children ~small_children_count ->
    let () = assert false in
    let children_size = ref 0 in
    schema (iter children_size ~small_children ~small_children_count) v;
    lnk := Serialized_reused { loc = pos_out fd };
    let smalls = Array.of_list (List.rev !small_children) in
    output v smalls
  in
  let _, root_value_smalls = write_children root_schema root_value in
  let root_loc = pos_out fd in
  let root_value_smalls = Array.of_list (List.rev root_value_smalls) in
  output root_value root_value_smalls;
  seek_out fd pt_root;
  output_string fd (binstring_of_int root_loc)

let read filename fd root_schema =
  let id = int_of_binstring (really_input_string fd 8) in
  let store = { filename; id; cache = Cache_cache.read filename } in
  let root_loc = int_of_binstring (really_input_string fd 8) in
  let parent_link =
    ref (On_disk { loc = root_loc; store; schema = root_schema })
  in
  let root_value, _, _ =
    read_loc store fd root_loc root_schema (PLink parent_link)
  in
  root_value

let () =
  at_exit (fun () ->
      match !last_open_store with
      | None -> ()
      | Some (_, fd) -> close_in fd)

let () =
  at_exit (fun () ->
      (* debug fetch_count; *)
      match !lru_dbllist with
      | None -> ()
      | Some lru -> Dbllist.pp_stats lru)
