module Cache = Hashtbl.Make (Int)

type store = { filename : string; id : int; cache : cache }

and cache = any_link Cache.t

and any_link = Link : 'a link * 'a link Type.Id.t -> any_link

and parent_link = PLink : 'a link -> parent_link

and any_value = Value : 'a -> any_value

and cached = Cached : 'a link * int * store * 'a schema -> cached

and 'a link = 'a repr ref

and 'a repr =
  | Small of 'a
      (** A serialized small value. Used for optimisation to avoid a pointer
          indirection. *)
  | Small_child of { parent : parent_link; pos : int }
      (** A small read value identified as a children of the given parent link.
          [loc] is the index of the link value in the parent childrens array. *)
  | Serialized of { loc : int }
      (** An already serialized value. [loc] is its offset in the index file. *)
  | Serialized_reused of { loc : int }
      (** An already serialized link stored in a store cache. [loc] is its
          offset in the index file. *)
  | On_disk of { store : store; loc : int; schema : 'a schema }
      (** A link pointing to a value stored in the given store at index [loc].
      *)
  | On_disk_ptr of { filename : string; loc : int; id : int }
      (** A link pointing to a value stored in another index file. [id] is the
          identifier of the store where the value has been stored during its
          serialisation (useful to avoid loading outdated store). *)
  | In_memory of 'a  (** A link pointing to a value stored in memory. *)
  | In_memory_reused of 'a
      (** A link pointing to a value used more than once stored in memory
          (contained in a store cache). *)
  | In_cache of 'a * cached Dbllist.cell * any_value array
      (** [In_cache (v, cache_cell, childrens)] represents value stored in a
          cell of the LRU cache. [childrens] are an array of its small child
          links. *)
  | In_cache_reused of 'a * cached Dbllist.cell * any_value array
      (** Same as [In_cache] but points to a value used more than once (stored
          in a store cache). *)
  | Duplicate of 'a link
      (** A duplicate value. Useful to perform compression and to avoid writing
          multiple times the same value. *)
  | Placeholder
      (** A intermediate state used for granulary writing small values. *)

and 'a schema = iter -> 'a -> unit

and iter = { yield : 'a. 'a link -> 'a link Type.Id.t -> 'a schema -> unit }

let string_of_link link =
  match !link with
  | Small _ -> "Small\n"
  | Small_child _ -> "Small_child\n"
  | Serialized _ -> "Serialized\n"
  | Serialized_reused _ -> "Serialized_reused\n"
  | On_disk _ -> "On_disk\n"
  | On_disk_ptr _ -> "On_disk_ptr\n"
  | In_memory _ -> "In_memory\n"
  | In_cache (_, _, _) -> "In_cache\n"
  | In_memory_reused _ -> "In_memory_reused\n"
  | In_cache_reused (_, _, _) -> "In_cache_reused\n"
  | Duplicate _ -> "Duplicate\n"
  | Placeholder -> "Placeholder\n"

exception
  Outdated_store of
    { filename : string; reason : [ `Missing_file | `Index_ids_do_not_match ] }

let lru_size = ref 1_000_000
let set_lru_size size = lru_size := size
let lru_dbllist = lazy (Dbllist.create 1_000_000)
let get_lru () = Lazy.force lru_dbllist

(* let fetch_count = Hashtbl.create 16

let debug h =
  let r = Hashtbl.create 16 in
  Hashtbl.iter (fun _k v ->
    let count = try Hashtbl.find r v with Not_found -> 0 in
    Hashtbl.replace r v (count + 1);
  ) h;
  let acc = ref 0 in
  Hashtbl.iter (fun k v ->
    acc := !acc + v;
    Format.eprintf "fetché %d fois -> %d valeurs\n%!" k v
  ) r;
  Format.eprintf "en tout : %d valeurs\n%!" !acc *)

(* let create_lru cap = lru_dbllist := Some (Dbllist.create cap) *)

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

(** A cache of store cache (yes) used to avoid creating separate caches for a
    given store when recovering [On_disk_ptr] links. *)
module Cache_cache = File_cache.Make (struct
  type t = cache
  let read _filename = Cache.create 0

  let cache_name = "Cache_cache"
end)

(* Serialization and deserialization functions for offset index. *)

let ptr_size = 8

let binstring_of_int v =
  String.init ptr_size (fun i -> Char.chr ((v lsr i lsl 3) land 255))

let int_of_binstring s =
  Array.fold_right
    (fun v acc -> (acc lsl 8) + v)
    (Array.init ptr_size (fun i -> Char.code s.[i]))
    0

(* Manage store opening to always have at most one file descriptor opened. *)

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
  let v = Marshal.from_channel fd in
  let size_read = pos_in fd - loc in
  let child_pos = ref 0 in
  let child_smalls = ref [] in
  let rec iter =
    { yield =
        (fun (type a) (lnk : a link) type_id schema ->
          match !lnk with
          | Small v ->
            schema iter v;
            child_smalls := Value v :: !child_smalls;
            lnk := Small_child { parent = parent_link; pos = !child_pos };
            child_pos := !child_pos + 1
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
          | In_cache_reused _
          | On_disk _
          | Small_child _
          | Duplicate _ -> (* TODO when does this happen ? *) ()
          | On_disk_ptr { filename; loc; id } ->
            (* Recovering the correct store cache and transform it to a concrete link. *)
            let store = { filename; id; cache = Cache_cache.read filename } in
            lnk := On_disk { store; loc; schema }
          | Placeholder -> invalid_arg "Granular_marshal.read_loc: Placeholder")
    }
  in
  schema iter v;
  let small_poses = Array.of_list (List.rev !child_smalls) in
  (v, size_read, small_poses)

let fetch_loc store loc schema parent_link =
  let fd = open_store store in
  let v, size, small_poses = read_loc store fd loc schema parent_link in
  (v, size, small_poses)

(* Follow a link to get the pointed value. *)
let rec fetch : type a. a link -> a =
 fun lnk ->
  match !lnk with
  | In_cache (v, cell, _) | In_cache_reused (v, cell, _) ->
    let (Cached (_, _loc, _, _)) = Dbllist.get cell in
    Dbllist.promote (get_lru ()) cell;
    v
  | In_memory v | In_memory_reused v -> v
  | Serialized _ | Serialized_reused _ | Small _ | On_disk_ptr _ ->
    (* It makes no sense to fetch a serialized value. *)
    invalid_arg "Granular_marshal.fetch: serialized"
  | Placeholder -> invalid_arg "Granular_marshal.fetch: during a write"
  | Duplicate original_lnk -> fetch original_lnk
  | Small_child { parent; pos } -> (
    (* Fetching the parent link in order to access its child array. *)
    let (PLink parent) = parent in
    ignore (fetch parent);
    match !parent with
    | In_cache (_, _, small_poses) | In_cache_reused (_, _, small_poses) ->
      let (Value v) = small_poses.(pos) in
      Obj.magic v
    | _ -> assert false)
  | On_disk { store; loc; schema } ->
    (* let count = try Hashtbl.find fetch_count (loc, store.filename) with Not_found -> 0 in
       Hashtbl.replace fetch_count (loc, store.filename) (count + 1); *)
    (* Add the value stored on disk to the LRU cache. *)
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

let rec reuse original_lnk =
  match !original_lnk with
  | In_memory v -> original_lnk := In_memory_reused v
  | In_cache (v, cell, smalls) ->
    original_lnk := In_cache_reused (v, cell, smalls)
  | In_memory_reused _ | In_cache_reused _ -> ()
  | On_disk _ -> ()
  | Duplicate link -> reuse link
  | _ ->
    invalid_arg
    @@ Printf.sprintf "Granular_marshal.reuse: not in memory, got %s"
         (string_of_link original_lnk)

(* A generic cache used to identify duplicate link and compress them. *)
let cache (type a) (module Key : Hashtbl.HashedType with type t = a) =
  let module H = Hashtbl.Make (Key) in
  let cache = H.create 16 in
  fun (lnk : a link) ->
    let key = fetch lnk in
    match H.find cache key with
    | original_lnk ->
      assert (original_lnk != lnk);
      (* Mark the link as reused, since it's already contained in the cache. *)
      reuse original_lnk;
      lnk := Duplicate original_lnk
    | exception Not_found -> H.add cache key lnk

let write ?(flags = []) fd ~id root_schema root_value =
  let id = binstring_of_int id in
  output_string fd id;
  let pt_root = pos_out fd in
  output_string fd (String.make ptr_size '\000');
  let rec iter size ~placeholders ~restore =
    { yield =
        (fun (type a) (lnk : a link) _type_id (schema : a schema) : unit ->
          match !lnk with
          | Serialized _ | Serialized_reused _ | Small _ | On_disk_ptr _ ->
            (* Already serialized *)
            ()
          | Placeholder -> failwith "big nono"
          | In_memory_reused v -> write_child_reused lnk schema v
          | Duplicate original_lnk -> (
            match !original_lnk with
            | Serialized_reused _ | On_disk_ptr _ -> lnk := !original_lnk
            | In_memory_reused v ->
              write_child_reused original_lnk schema v;
              lnk := !original_lnk
            | In_cache_reused (_v, t, _) ->
              let (Cached (_, loc, { filename; id; _ }, _)) = t.content in
              lnk := On_disk_ptr { filename; id; loc }
            | On_disk { store = { filename; id; _ }; loc; _ } ->
              lnk := On_disk_ptr { filename; id; loc }
            | _ ->
              failwith
                (Format.sprintf
                   "Granular_marshal.write: duplicate not reused got %s"
                   (string_of_link original_lnk)))
          | In_memory v -> write_child lnk schema v size ~placeholders ~restore
          | Small_child _ ->
            let v = fetch lnk in
            write_child lnk schema v size ~placeholders ~restore
          | In_cache (_v, t, _children) | In_cache_reused (_v, t, _children) ->
            let (Cached (_, loc, { filename; id; _ }, _)) = t.content in
            lnk := On_disk_ptr { filename; id; loc }
          | On_disk { store = { filename; id; _ }; loc; _ } ->
            lnk := On_disk_ptr { filename; id; loc })
    }
  and write_child : type a. a link -> a schema -> a -> _ =
   fun lnk schema v size ~placeholders ~restore ->
    let v_size = write_children schema v in
    if v_size > 1024 then (
      lnk := Serialized { loc = pos_out fd };
      let rec iter =
        { yield =
            (fun (type b) (lnk : b link) _type_id schema ->
              match !lnk with
              | Small v -> schema iter v
              | On_disk { store = { filename; id; _ }; loc; _ } ->
                lnk := On_disk_ptr { filename; id; loc }
              | _ -> ())
        }
      in
      schema iter v;
      Marshal.to_channel fd v flags)
    else (
      (* The value is considered small. *)
      size := !size + v_size;
      placeholders := (fun () -> lnk := Placeholder) :: !placeholders;
      restore := (fun () -> lnk := Small v) :: !restore)
  and write_children : type a. a schema -> a -> int =
   fun schema v ->
    let children_size = ref 0 in
    let placeholders = ref [] in
    let restore = ref [] in
    schema (iter children_size ~placeholders ~restore) v;
    List.iter (fun placehold -> placehold ()) !placeholders;
    let v_size = Obj.(reachable_words (repr v)) in
    List.iter (fun restore -> restore ()) !restore;
    !children_size + v_size
  and write_child_reused : type a. a link -> a schema -> a -> _ =
   fun lnk schema v ->
    let children_size = ref 0 in
    let placeholders = ref [] in
    let restore = ref [] in
    schema (iter children_size ~placeholders ~restore) v;
    lnk := Serialized_reused { loc = pos_out fd };
    Marshal.to_channel fd v flags
  in
  let _ : int = write_children root_schema root_value in
  let root_loc = pos_out fd in
  let rec iter =
    { yield =
        (fun (type b) (lnk : b link) _type_id schema ->
          match !lnk with
          | Small v -> schema iter v
          | On_disk { store = { filename; id; _ }; loc; _ } ->
            lnk := On_disk_ptr { filename; id; loc }
          | _ -> ())
    }
  in
  root_schema iter root_value;
  Marshal.to_channel fd root_value flags;
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
      Dbllist.pp_stats (get_lru ()))
