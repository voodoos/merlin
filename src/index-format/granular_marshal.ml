module Cache = Hashtbl.Make (Int)

type store = { filename : string; id : int; cache : cache }

and cache = any_link Cache.t

and any_link = Link : 'a link * 'a link Type.Id.t option -> any_link

and parent_link = PLink : 'a link -> parent_link
and any_value =
  | Value : 'a * 'a link Type.Id.t -> any_value
  | Unknown : 'a -> any_value
and any_val = V : 'a -> any_val
and any_val_link = Vlink : 'a * 'a link -> any_val_link

and cached = Cached : 'a link * int * store * 'a schema option ref -> cached

and 'a link = 'a repr ref

(** Links descriptions.
  There are two different realms: on disk and in memory.
  Things such as On_disk cannot live on disk since the contain a function, schema.
  _ Type.Id.t cannot survive to marshalling either.

  TODO: reorder the list by realm.
*)
and 'a repr =
  | Small of int
  | Serialized of { loc : int }
  | Serialized_reused of { loc : int }
  | On_disk of { store : store; loc : int; schema : 'a schema }
  | On_disk_small of
      { store : store;
        loc : int;
        parent : parent_link; (* Either the parent or an On_disk_ptr *)
        small_type_id : 'a link Type.Id.t;
        small_pos : int;
        small_schema : 'a schema
      }
  | On_disk_ptr of { filename : string; loc : int; id : int; pos : int option }
  | In_memory of 'a
  | In_cache of 'a * value_status * cached Dbllist.cell * any_value array
  | In_memory_reused of 'a
  | Duplicate of 'a link

and value_status = Dirty_unknown_schema | Clean

and 'a schema = iter -> 'a -> unit

and iter = { yield : 'a. 'a link -> 'a link Type.Id.t -> 'a schema -> unit }

let string_of_link : type a. a link -> string =
 fun link ->
  match !link with
  | Small _ -> Printf.sprintf "Small"
  | Serialized { loc } -> Printf.sprintf "Serialized(loc=%d)" loc
  | Serialized_reused { loc } -> Printf.sprintf "Serialized_reused(loc=%d)" loc
  | On_disk { loc; _ } -> Printf.sprintf "On_disk(loc=%d)" loc
  | On_disk_small { small_pos; _ } ->
    Printf.sprintf "On_disk_small(small_pos=%d)" small_pos
  | On_disk_ptr { loc; pos; _ } ->
    Printf.sprintf "On_disk_ptr(loc=%d%s)" loc
      (match pos with
      | Some pos -> Printf.sprintf ", pos=%d" pos
      | None -> "")
  | In_memory _ -> "In_memory"
  | In_cache (_, status, { content = Cached (_, loc, _, _); _ }, _) ->
    let clean_dirty =
      match status with
      | Clean -> "Clean"
      | Dirty_unknown_schema -> "Dirty"
    in
    Printf.sprintf "In_cache(%s; loc=%i)" clean_dirty loc
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

(** This iterator translate links from the Disk Realm to the Memory Realm *)
let rec disk_to_memory_iter store loc parent_link =
  { yield =
      (fun (type a)
        (lnk : a link)
        (type_id : a link Type.Id.t)
        (schema : a schema)
      ->
        match !lnk with
        | Small pos ->
          lnk :=
            On_disk_small
              { store;
                loc;
                parent = parent_link;
                small_pos = pos;
                small_type_id = type_id;
                small_schema = schema
              }
        | Serialized { loc } -> lnk := On_disk { store; loc; schema }
        | Serialized_reused { loc } -> (
          match Cache.find_opt store.cache loc with
          | Some (Link (type b) ((lnk', Some type_id') : b link * _)) -> (
            match Type.Id.provably_equal type_id type_id' with
            | Some (Equal : (a link, b link) Type.eq) ->
              lnk := Duplicate (normalize lnk')
            | None ->
              invalid_arg "Granular_marshal.read_loc: reuse of a different type"
            )
          | Some _ ->
            invalid_arg "Granular_marshal.read_loc: reuse of a different type"
          | None ->
            lnk := On_disk { store; loc; schema };
            Cache.add store.cache loc (Link (lnk, Some type_id)))
        | In_memory _
        | In_cache _
        | In_memory_reused _
        | On_disk_small _
        | On_disk _
        | Duplicate _ -> (* TODO when does this happen ? *) ()
        | On_disk_ptr { filename; loc; id; pos = None } -> (
          let store = { filename; id; cache = Cache_cache.read filename } in

          match Cache.find_opt store.cache loc with
          | Some (Link (type b) ((lnk', Some type_id') : b link * _)) -> (
            match Type.Id.provably_equal type_id type_id' with
            | Some (Equal : (a link, b link) Type.eq) ->
              lnk := Duplicate (normalize lnk')
            | None ->
              invalid_arg "Granular_marshal.read_loc: reuse of a different type"
            )
          | Some (Link (lnk', None)) ->
            let lnk' = Obj.magic lnk' in
            let () =
              (* We might have reused a parent whose schema was initially unknown.
                   Let's update it. *)
              match !lnk' with
              | On_disk_ptr { loc; pos = None; _ } ->
                (* This case only happens if the previous read was an
                    [On_disc_ptr { pos = Some_; _}] with a parent of unknown
                    schema. *)
                lnk' := On_disk { store; loc; schema }
              | In_cache (v, Dirty_unknown_schema, cell, smalls) ->
                (* If we already have the value in cache we must clean it. *)
                schema (disk_to_memory_iter store loc (PLink lnk')) v;
                lnk' := In_cache (v, Clean, cell, smalls)
              | Small _
              | Serialized _
              | Serialized_reused _
              | On_disk _
              | On_disk_small _
              | On_disk_ptr _
              | In_memory _
              | In_cache (_, _, _, _)
              | In_memory_reused _ | Duplicate _ -> assert false
            in
            Cache.replace store.cache loc (Link (lnk', Some type_id));
            lnk := Duplicate (normalize lnk')
          | _ -> lnk := On_disk { store; loc; schema })
        | On_disk_ptr { filename; loc; id; pos = Some small_pos } ->
          let store = { filename; id; cache = Cache_cache.read filename } in
          let parent =
            match Cache.find_opt store.cache loc with
            | Some (Link (lnk, _)) -> PLink (normalize lnk)
            | None ->
              let lnk = ref (On_disk_ptr { filename; loc; id; pos = None }) in
              Cache.add store.cache loc (Link (lnk, None));
              PLink lnk
          in
          lnk :=
            On_disk_small
              { store;
                loc;
                parent;
                small_type_id = type_id;
                small_schema = schema;
                small_pos
              })
  }

let read_loc store fd loc schema parent_link =
  seek_in fd loc;
  let v, small_children = Marshal.from_channel fd in
  let size_read = pos_in fd - loc in
  let iter = disk_to_memory_iter store loc parent_link in
  schema iter v;
  (* Map on small children to make them Unknown *)
  let small_children = Array.map (fun (V v) -> Unknown v) small_children in
  (v, size_read, small_children)

let fetch_loc store loc schema parent_link =
  let fd = open_store store in
  read_loc store fd loc schema parent_link

let on_cache_discard (Cached (link, loc, store, schema)) =
  (* This also free the smalls that are stored in the link *)
  match !schema with
  | Some schema -> link := On_disk { store; loc; schema }
  | None ->
    link :=
      On_disk_ptr { filename = store.filename; id = store.id; loc; pos = None }

let fetch_on_disk lnk store loc schema =
  (* TODO this could have already be loaded "without a schema" we should just
     update the existing record in that case. *)
  let v, size, small_poses = fetch_loc store loc schema (PLink lnk) in
  let discarded = Dbllist.discard_size (get_lru ()) size in
  let cell =
    Dbllist.add_front (get_lru ())
      (Cached (lnk, loc, store, ref (Some schema)), size)
  in
  List.iter on_cache_discard discarded;
  lnk := In_cache (v, Clean, cell, small_poses);
  (v, small_poses)

let fetch_parent : parent_link -> any_value array =
 fun (PLink parent_link) ->
  match !parent_link with
  | In_cache (_, _, _, smalls) -> smalls
  | On_disk_ptr { filename; loc; id; pos = None } ->
    let store = { filename; id; cache = Cache_cache.read filename } in
    let fd = open_store store in
    seek_in fd loc;
    let (v, small_children) : _ * any_val array = Marshal.from_channel fd in
    let size = pos_in fd - loc in
    let small_children = Array.map (fun (V v) -> Unknown v) small_children in
    let discarded = Dbllist.discard_size (get_lru ()) size in
    let cell =
      Dbllist.add_front (get_lru ())
        (Cached (parent_link, loc, store, ref None), size)
    in
    List.iter on_cache_discard discarded;
    parent_link := In_cache (v, Dirty_unknown_schema, cell, small_children);
    small_children
  | On_disk { store; loc; schema } ->
    snd (fetch_on_disk parent_link store loc schema)
  | _ ->
    invalid_arg
      ("Granular_marshal.fetch_parent: Unexpected parent link "
     ^ string_of_link parent_link)

let rec fetch : type a. a link -> a =
 fun lnk ->
  match !lnk with
  | In_cache (v, Clean, cell, _) ->
    Dbllist.promote (get_lru ()) cell;
    v
  | In_cache (_v, Dirty_unknown_schema, _, _) ->
    invalid_arg "Granular_marshal.fetch: accessing dirty cached value"
  | In_memory v | In_memory_reused v -> v
  | Serialized _ | Serialized_reused _ | Small _ | On_disk_ptr _ ->
    invalid_arg ("Granular_marshal.fetch: " ^ string_of_link lnk)
  | Duplicate original_lnk -> fetch original_lnk
  | On_disk_small { store; loc; parent; small_pos; small_type_id; small_schema }
    -> (
    let smalls = fetch_parent parent in
    match smalls.(small_pos) with
    | Value (type b) ((v, type_id') : b * _) -> (
      match Type.Id.provably_equal small_type_id type_id' with
      | None -> invalid_arg "Granular_marshal.read_loc: small has wrong type"
      | Some (Equal : (a link, b link) Type.eq) -> v)
    | Unknown v ->
      let v = Obj.magic v in
      small_schema (disk_to_memory_iter store loc parent) v;
      smalls.(small_pos) <- Value (v, small_type_id);
      v)
  | On_disk { store; loc; schema } -> fst (fetch_on_disk lnk store loc schema)

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

let write ?(flags = []) fd ~filename ~id root_schema root_value =
  let id' = binstring_of_int id in
  output_string fd id';
  let pt_root = pos_out fd in
  output_string fd (String.make ptr_size '\000');
  let rec iter size ~small_children =
    { yield =
        (fun (type a) (lnk : a link) _type_id (schema : a schema) : unit ->
          match !lnk with
          | Serialized _ | Serialized_reused _ | Small _ | On_disk_ptr _ -> ()
          | In_memory_reused v -> write_child_reused lnk schema v
          | Duplicate original_lnk -> (
            match !original_lnk with
            | Serialized_reused _ | On_disk_ptr _ -> lnk := !original_lnk
            | In_memory_reused v ->
              write_child_reused original_lnk schema v;
              lnk := !original_lnk
            | On_disk { store = { filename; id; _ }; loc; _ }
            | In_cache
                ( _,
                  _,
                  { content = Cached (_, loc, { filename; id; _ }, _); _ },
                  _ ) -> lnk := On_disk_ptr { filename; id; loc; pos = None }
            | _ ->
              failwith
                (Format.sprintf
                   "Granular_marshal.write: duplicate not reused got %s"
                   (string_of_link original_lnk)))
          | In_memory v -> write_child lnk schema v size ~small_children
          (* | Small_child { parent = PLink parent; pos; _ } ->
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
            lnk := On_disk_ptr { filename; id; loc; pos = Some pos } *)
          | In_cache (_v, _, t, _children) ->
            let (Cached (_, loc, { filename; id; _ }, _)) = t.content in
            lnk := On_disk_ptr { filename; id; loc; pos = None }
          | On_disk { store = { filename; id; _ }; loc; _ } ->
            (* TODO we could have all the possible filenames wrote once
               somewhere in the file. *)
            lnk := On_disk_ptr { filename; id; loc; pos = None }
          | On_disk_small { store = { filename; id; _ }; loc; small_pos; _ } ->
            lnk := On_disk_ptr { filename; id; loc; pos = Some small_pos })
    }
  and output_and_mark (V v) (small_children : any_val_link list) =
    let new_smalls =
      (* Some smalls might have been already serialized by another value *)
      List.filter
        (fun (Vlink (_v, lnk)) ->
          match !lnk with
          | On_disk_ptr { pos = Some _; _ } ->
            (* This small has already been serialized by another owner *) false
          | _ -> true)
        small_children
    in
    let smalls =
      (* We iter on the smalls to set their links with the position in the array and *)
      List.mapi
        (fun i (Vlink (v, lnk)) ->
          lnk := Small i;
          V v)
        new_smalls
      |> Array.of_list
    in
    let loc = pos_out fd in
    Marshal.to_channel fd (v, smalls) flags;
    (* Now we replace the links by an indirection in case they are reused *)
    List.iteri
      (fun i (Vlink (_v, lnk)) ->
        lnk := On_disk_ptr { filename; loc; id; pos = Some i })
      new_smalls
  and write_child : type a. a link -> a schema -> a -> _ =
   fun lnk schema v size ~small_children ->
    let v_size, v_smalls = write_children schema v in
    if v_size > 1024 then (
      lnk := Serialized { loc = pos_out fd };
      output_and_mark (V v) v_smalls)
    else (
      size := !size + v_size;
      (* We don't care about the order since smalls are numbered right before
         writing to the disk. *)
      let smalls = List.rev_append v_smalls !small_children in
      small_children := Vlink (v, lnk) :: smalls)
  and write_children : type a. a schema -> a -> _ =
   fun schema v ->
    let children_size = ref 0 in
    let small_children = ref [] in
    schema (iter children_size ~small_children) v;
    let v_size = Obj.(reachable_words (repr v)) in
    (!children_size + v_size, !small_children)
  and write_child_reused : type a. a link -> a schema -> a -> unit =
   fun lnk schema v ->
    let _v_size, v_smalls = write_children schema v in
    lnk := Serialized_reused { loc = pos_out fd };
    output_and_mark (V v) v_smalls
  in
  let _, root_value_smalls = write_children root_schema root_value in
  let root_loc = pos_out fd in
  output_and_mark (V root_value) root_value_smalls;
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
