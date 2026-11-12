let log_section = "short-paths"
let { Logger.log } = Logger.for_section log_section
let { Logger.log = log_dbg } = Logger.for_section (log_section ^ "-dbg")

let path_print = Format_doc.compat Path.print

module Out_type = struct
  (* This part is copied from upstream's [Out_type] *)

  (* Normalize paths *)

  type param_subst = Id | Nth of int | Map of int list

  let compose l1 = function
    | Id -> Map l1
    | Map l2 -> Map (List.map (List.nth l1) l2)
    | Nth n -> Nth (List.nth l1 n)

  let rec index l x =
    match l with
    | [] -> raise Not_found
    | a :: l -> if Types.eq_type x a then 0 else 1 + index l x

  let rec uniq = function
    | [] -> true
    | a :: l -> (not (List.memq (a : int) l)) && uniq l

  let rec normalize_type_path ?(cache = false) env p =
    let open Types in
    try
      let params (* type_params *), ty (* type_manifest *), _ =
        (* Find the manifest type associated to a type when appropriate:
           - the type should be public or should have a private row,
           - the type should have an associated manifest type. *)
        Env.find_type_expansion p env
      in
      match get_desc ty with
      | Tconstr (p1, tyl, _) ->
        log ~title:"normalize_type_path" "Found type expansion %a for %a"
          Logger.fmt (Fun.flip path_print p1) Logger.fmt (Fun.flip path_print p);
        if
          List.length params = List.length tyl
          && List.for_all2 eq_type params tyl
          && p1 <> p (* TODO if this the correct way to prevent looping ? *)
        then normalize_type_path ~cache env p1
        else if
          cache
          || List.length params <= List.length tyl
          || not (uniq (List.map get_id tyl))
        then (Env.normalize_type_path None env p, Id)
        else
          let l1 = List.map (index params) tyl in
          let p2, s2 = normalize_type_path ~cache env p1 in
          (p2, compose l1 s2)
      | _ -> (Env.normalize_type_path None env p, Nth (index params ty))
    with Not_found ->
      log ~title:"normalize_type_path"
        "Calling [Env.normalize_type_path] for %a" Logger.fmt
        (Fun.flip path_print p);
      (Env.normalize_type_path None env p, Id)

  let normalize_type_path ?cache env p =
    log ~title:"normalize_type_path" "Normalizing %a " Logger.fmt
      (Fun.flip path_print p);
    let p, subst = normalize_type_path ?cache env p in
    log ~title:"normalize_type_path" "Normalizing %a " Logger.fmt
      (Fun.flip path_print p);
    (p, subst)

  let find_double_underscore s =
    let len = String.length s in
    let rec loop i =
      if i + 1 >= len then None
      else if s.[i] = '_' && s.[i + 1] = '_' then Some i
      else loop (i + 1)
    in
    loop 0

  let penalty_size = 20

  let name_penalty s =
    if s <> "" && s.[0] = '_' then penalty_size
    else
      match find_double_underscore s with
      | None -> 2
      | Some _ -> penalty_size

  let penalty s =
    if s <> "" && s.[0] = '_' then 10
    else
      match find_double_underscore s with
      | None -> 1
      | Some _ -> 10
end

let rec longident_cost = function
  | Longident.Lident id -> Out_type.penalty id
  | Ldot (l, id) -> Out_type.penalty id.txt + longident_cost l.txt
  | Lapply (l1, l2) -> longident_cost l1.txt + longident_cost l2.txt

let compare_strings s1 s2 =
  let length_diff = String.length s1 - String.length s2 in
  if length_diff <> 0 then length_diff else String.compare s1 s2

let compare_longidents l1 l2 =
  let l1_cost = longident_cost l1 in
  let l2_cost = longident_cost l2 in
  let cost_diff = l1_cost - l2_cost in
  if cost_diff <> 0 then cost_diff
  else Discourse_types.compare_longidents ~compare_strings l1 l2

let ident_scope id =
  if Ident.is_predef id then Ident.highest_scope else Ident.scope id

(* Adapted from out_type. Same weight but we favorize predefs.

   TODO CR Ulysse there is room for adjustment here. Scope is not always a very
   good metric, proximity of the last usage might be better. *)
let path_size path =
  let name_penalty = Out_type.name_penalty in
  let rec size = function
    | Path.Pident id -> (name_penalty (Ident.name id), -ident_scope id)
    | Pdot (p, id) | Pextra_ty (p, Pcstr_ty id) ->
      let l, b = size p in
      (name_penalty id + l, b)
    | Papply (p1, p2) ->
      let l, b = size p1 in
      (l + fst (size p2), b)
    | Pextra_ty (p, Pext_ty) -> size p
  in
  size path

let compare_weight (l1, s1) (l2, s2) =
  let c = l1 - l2 in
  if c <> 0 then c else s1 - s2

let compare_paths_weight p1 p2 = compare_weight (path_size p1) (path_size p2)
type kind = Type | Module | Module_type
let kind_of_kind = function
  | Type -> Shape.Sig_component_kind.Type
  | Module -> Module
  | Module_type -> Module_type
let string_of_kind = function
  | Type -> "Type"
  | Module -> "Module"
  | Module_type -> "Module_type"

module Path_set = struct
  module T = struct
    type t = kind * Path.t * Path.t

    let compare (k1, p1, fp1) (k2, p2, fp2) =
      let c = compare_paths_weight p1 p2 in
      if c <> 0 then c
      else
        let c = compare k1 k2 in
        if c <> 0 then c
        else
          let c = Path.compare p1 p2 in
          if c <> 0 then c else Path.compare fp1 fp2
  end
  let pp_elt fmt (kind, p, full_path) =
    Format.fprintf fmt "%a [%a] (%s)" path_print p path_print full_path
      (string_of_kind kind)

  include Set.Make (T)
end

module Path_tbl = Hashtbl.Make (struct
  type t = Path.t
  let equal = Path.same
  let hash = Hashtbl.hash
end)

module Kinds = Discourse_types.Kinds
module Priority_queue = Path_set
module Path_trie = Discourse_types.Path_trie
module String_map = Discourse_types.String_map

(* To shorten paths we will build a table that maps "canonical paths" - i.e. a
   path which is not itself an alias - to a set of paths from D that are aliases
   to it. We will build this table by putting the elements of D into a priority
   queue ordered by their length. Then we "process" each element by looking up
   its canonical path and then adding it to the map. We do this using whatever
   environment we are currently trying to shorten paths with (ignoring any local
   constraints). If an element of D is not available in that environment then we
   skip it and leave it in the priority queue. *)

(* When shortenning:
   - We empty the Discourse into the priority queue.
   - We compute all possible paths substitutions and add them to the priority
     queue. TODO: there might be a better, lazier way.
   - We read the priority queue in orderto sort paths by their canonical form.
   - Once we found a valid path for the request we stop after finishing the
     current level (when the next path in the queue is longer).
   - The priority queue and canonical paths map are kept between queries. *)

let priority_queue : Priority_queue.t ref =
  Local_store.s_ref Priority_queue.empty
let not_in_env : Path_trie.t ref = Local_store.s_ref Path_trie.empty
let canon_table : Path_set.t Path_tbl.t ref =
  Local_store.s_table Path_tbl.create 256
(* TODO CR Ulysse having a table keyed by Uids would seem to be a better choice,
   but it does not always work. One example of that is test `sp-13` were a type
   from Deferred0 is redefined in Deferred, causing paths converging to this same
   type to have unmatching uids.*)

(* Rule D3 (the components of a module of U are in D) is applied on demand: the
   components of a module are all heavier than the module itself, so they are
   only materialised ("expanded") when the search reaches the module's weight.
   An expansion is a module of U (its full path) under one of its apparent
   paths. *)
module Expand_set = Set.Make (struct
  type t = Path.t * Path.t (* apparent path, full path *)

  let compare (a, f) (a', f') =
    let c = compare_paths_weight a a' in
    if c <> 0 then c
    else
      let c = Path.compare a a' in
      if c <> 0 then c else Path.compare f f'
end)

(* Expansions not done yet, lightest first *)
let pending_expand : Expand_set.t ref = Local_store.s_ref Expand_set.empty

(* Expansions done: each pair is expanded at most once *)
let expanded : Expand_set.t ref = Local_store.s_ref Expand_set.empty

(* Every path queued so far, substitutions applied: an expansion only queues
   the paths that are not already there, and a substitution discovered by an
   expansion must also be applied to them. *)
let all_paths : Path_trie.t ref = Local_store.s_ref Path_trie.empty

(* The minimum weight of a component of a module known as [apparent] *)
let min_component_weight apparent =
  let l, s = path_size apparent in
  (l + 1, s)

let note_expansion apparent full =
  if Discourse.is_expandable full then begin
    let e = (apparent, full) in
    if not (Expand_set.mem e !expanded) then
      pending_expand := Expand_set.add e !pending_expand
  end

let pp_table fmt t =
  Path_tbl.iter
    (fun p paths ->
      let paths = Path_set.to_list paths in
      Format.fprintf fmt "@;%a -> {%a}" path_print p
        (Format.pp_print_list ~pp_sep:Format.pp_print_space Path_set.pp_elt)
        paths)
    t

let normalize_type_path = Out_type.normalize_type_path ~cache:false

(* The paths obtained by applying [substs] once to [t]: every node of [t]
   whose path is a substitution target is re-rooted under the replacements.
   [apply_substitutions] is driven by the nodes of [t], so its cost does not
   depend on the number of substitutions (expansions apply them to small
   tries, many times); [apply_substitutions_by_target] is driven by the
   substitutions, for a few of them on a large trie. *)
let apply_substitutions_by_target (substs : Discourse_types.substs) t =
  Path.Map.fold
    (fun target replacements acc ->
      match Path_trie.reach t target with
      | None -> acc
      | Some (Trie (kinds, children)) ->
        Path.Set.fold
          (fun path acc ->
            Path_trie.union acc @@ Path_trie.trie_of_path ~children path kinds)
          replacements acc)
    substs Path_trie.empty

let apply_substitutions (substs : Discourse_types.substs) t =
  Path_trie.fold_nodes
    (fun path (Trie (kinds, children)) acc ->
      match Path.Map.find_opt path substs with
      | None -> acc
      | Some replacements ->
        Path.Set.fold
          (fun path acc ->
            Path_trie.union acc @@ Path_trie.trie_of_path ~children path kinds)
          replacements acc)
    t Path_trie.empty

let apply_substitutions_fixpoint t substs =
  let rec aux ~fuel acc t =
    let new_paths = apply_substitutions substs t in
    if Path_trie.is_empty new_paths then acc
    else begin
      let acc_length = Path_trie.size acc in
      let acc = Path_trie.union acc new_paths in
      if fuel = 0 || acc_length = Path_trie.size acc then acc
      else aux ~fuel:(fuel - 1) acc new_paths
    end
  in
  aux ~fuel:2 t t

let fill_queue (paths : Path_trie.t) queue =
  Path_trie.to_seq paths
  |> Seq.fold_left
       (fun acc (path, full_paths) ->
         Discourse_types.Paths.fold
           (fun (kind, full_path) acc ->
             match kind with
             | Type -> Priority_queue.add (Type, path, full_path) acc
             | Module ->
               note_expansion path full_path;
               Priority_queue.add (Module, path, full_path) acc
             | Module_type ->
               Priority_queue.add (Module_type, path, full_path) acc
             | _ -> acc)
           full_paths acc)
       queue

(* This function should be called before any attempt to [shorten] paths in an
   environment different that the one of the previous attempt.

   This is called after any function wrapped with [Printyp.wrap_printing_env].
*)
let restore_ignored_paths id =
  match id with
  | None ->
    priority_queue := fill_queue !not_in_env !priority_queue;
    not_in_env := Path_trie.empty
  | Some ident -> (
    match Path_trie.take ident !not_in_env with
    | None, _ -> ()
    | Some t, remaining ->
      priority_queue := fill_queue t !priority_queue;
      not_in_env := remaining)

let find_by_name env kind lid =
  match kind with
  | Type -> fst (Env.find_type_by_name lid env)
  | Module -> fst (Env.find_module_by_name_lazy lid env)
  | Module_type -> fst (Env.find_modtype_by_name_lazy lid env)

let find_path_by_name env kind path =
  let lid = Untypeast.lident_of_path path in
  try Some (find_by_name env kind lid) with Not_found -> None

let normalize env kind path =
  match kind with
  | Type -> fst (normalize_type_path env path)
  | Module -> Env.normalize_module_path None env path
  | Module_type -> Env.normalize_modtype_path env path

(* Candidates are apparent paths: in the presence of [open] statements they
   cannot be looked up in the environment directly, so we find them by name.

   TODO CR Ulysse if required we might use a shortcut here with "find_"
   functions but these must be treated carefully as they do allow hidden
   module to be used. (breaks l-repro2 for example) *)
let canonical_path_by_name env kind apparent_path full_path =
  (* TODO it might be worth it to memoïze this function *)
  match find_path_by_name env kind apparent_path with
  (* TODO Env.find_type_by_name can raise Assertion_failure when the case Papply
     is reached in Env.lookup_type_path_full *)
  | None | (exception Assert_failure _) ->
    log ~title:"find_path_in_env" "%s name not found: %a" (string_of_kind kind)
      Logger.fmt
      (Fun.flip path_print apparent_path);
    None
  | Some path_in_env -> (
    log ~title:"find_path_in_env" "Lid: %a [%a] Path in env: %a" Logger.fmt
      (Fun.flip path_print apparent_path)
      Logger.fmt
      (Fun.flip path_print full_path)
      Logger.fmt
      (Fun.flip path_print path_in_env);
    try
      let canonical_path = normalize env kind path_in_env in
      if Path.same full_path path_in_env then Some canonical_path
      else begin
        let path = normalize env kind full_path in
        log ~title:"find_path_in_env" "%a <>? %a" Logger.fmt
          (Fun.flip path_print path) Logger.fmt
          (Fun.flip path_print canonical_path);
        if Path.same path canonical_path then Some canonical_path else None
      end
    with Not_found -> None)

(* Check that [path] denote [canon_path] in [env]. Used to re-validate the
   entries of the table, which are kept across environments. *)
let check_path env kind ~canon_path path =
  match find_path_by_name env kind path with
  | None | (exception Assert_failure _) -> false
  | Some path_in_env -> (
    Path.same path_in_env canon_path
    ||
    match normalize env kind path_in_env with
    | path' -> Path.same path' canon_path
    | exception Not_found -> false)

let find_best_path env ~canon_path table target_kind =
  match Path_tbl.find_opt table canon_path with
  | None -> None
  | Some paths ->
    Path_set.to_seq paths
    |> Seq.find_map (fun (kind, path, _full_path) ->
        (* TODO we should probably have a kind*path map*)
        if kind <> target_kind then None
        else if check_path env kind ~canon_path path then Some path
        else None)

let improve_path env ~canon_path table kind path =
  find_best_path env ~canon_path table kind
  |> Option.fold ~none:path ~some:Option.some

type state = { queue : Priority_queue.t; not_in_env : Path_trie.t }

(* Materialises the components of the module [full], known as [apparent]: they
   are added to the queue, substitutions applied, and the substitutions of
   their alias sub-modules to [substs]. Returns the weight of the lightest
   path added, if any. *)
let expand substs state (apparent, full) =
  expanded := Expand_set.add (apparent, full) !expanded;
  match Discourse.module_components full with
  | None -> (state, None)
  | Some (components, component_substs) ->
    (* The components, under the apparent name of the module *)
    let new_paths =
      if Path.same apparent full then components
      else
        match Path_trie.reach components full with
        | None -> Path_trie.empty
        | Some (Trie (kinds, children)) ->
          Path_trie.trie_of_path ~children apparent kinds
    in
    (* D12: paths under an alias target can be written under the alias. The
       substitutions known so far were applied to the paths queued so far, the
       new ones are applied to them here. *)
    let new_substs =
      Path.Map.filter_map
        (fun target replacements ->
          let known =
            Option.value ~default:Path.Set.empty
              (Path.Map.find_opt target !substs)
          in
          let fresh = Path.Set.diff replacements known in
          if Path.Set.is_empty fresh then None else Some fresh)
        component_substs
    in
    let new_paths =
      if Path.Map.is_empty new_substs then new_paths
      else begin
        substs :=
          Path.Map.union
            (fun _ a b -> Some (Path.Set.union a b))
            !substs new_substs;
        Path_trie.union new_paths
          (apply_substitutions_by_target new_substs !all_paths)
      end
    in
    let new_paths = apply_substitutions_fixpoint new_paths !substs in
    (* Paths already in [all_paths] were queued (and possibly treated) before *)
    let fresh = Path_trie.diff new_paths !all_paths in
    log ~title:"expand"
      "Expanding %a [%a]: %a components, %d new substs, %a new paths" Logger.fmt
      (Fun.flip path_print apparent)
      Logger.fmt (Fun.flip path_print full) Logger.fmt
      (fun fmt -> Format.pp_print_int fmt (Path_trie.size components))
      (Path.Map.cardinal new_substs)
      Logger.fmt
      (fun fmt -> Format.pp_print_int fmt (Path_trie.size fresh));
    all_paths := Path_trie.union !all_paths fresh;
    let queue = fill_queue fresh state.queue in
    let lightest =
      Path_trie.to_seq fresh
      |> Seq.fold_left
           (fun acc (path, _) ->
             let w = path_size path in
             match acc with
             | Some w' when compare_weight w' w <= 0 -> acc
             | _ -> Some w)
           None
    in
    ({ state with queue }, lightest)

let process_queue env substs state ~table ~canon_path target_kind best =
  (* The items of the queue from the first one of the requested kind heavier
     than [lb], the weight of the last treated level: nothing lighter of that
     kind is left, and the weight is the primary key of the queue, so the
     level is sought directly. *)
  let candidates lb queue =
    (* Items are ordered by weight, then kind: a level that has no item of
       the requested kind is skipped in logarithmic time. *)
    let rec seek pred =
      match Priority_queue.find_first_opt pred queue with
      | None -> Seq.empty
      | Some ((kind, path, _) as item) ->
        if kind = target_kind then Priority_queue.to_seq_from item queue
        else
          let w = path_size path in
          if compare kind target_kind > 0 then
            (* [item] is the first of its level: no item of the requested
               kind there *)
            seek (fun (_, p, _) -> compare_weight (path_size p) w > 0)
          else
            seek (fun (k, p, _) ->
                let c = compare_weight (path_size p) w in
                c > 0 || (c = 0 && compare k target_kind >= 0))
    in
    match lb with
    | None -> seek (fun _ -> true)
    | Some lb -> seek (fun (_, p, _) -> compare_weight (path_size p) lb > 0)
  in
  (* Validates one candidate: in the presence of [open] statements the
     Discourse contains partial paths that cannot be looked up in the
     environment directly, so it is found by name and checked against its full
     path. It is then filed in the table under its canonical path, or kept
     aside in [not_in_env]. *)
  let treat state ((kind, path, full_path) as item) =
    log ~title:"fill_by_level" "Treating %a (%s)" Logger.fmt
      (Fun.flip path_print path) (string_of_kind kind);
    match canonical_path_by_name env kind path full_path with
    | Some canonical_path ->
      log ~title:"fill_by_level" "Updating table: %a -> { %a (%s) }" Logger.fmt
        (fun fmt -> path_print fmt canonical_path)
        Logger.fmt
        (fun fmt -> path_print fmt path)
        (string_of_kind kind);
      let () =
        let update =
          match Path_tbl.find_opt table canonical_path with
          | None -> Path_set.singleton item
          | Some set -> Path_set.add item set
        in
        Path_tbl.replace table canonical_path update
      in
      (* And remove it from the queue *)
      let queue = Priority_queue.remove item state.queue in
      { state with queue }
    | None ->
      log ~title:"fill_by_level" "Path %a invalid in the current env" Logger.fmt
        (Fun.flip path_print path);
      (* Elements not valid in the current environement are kept in a separate
         queue. This prevent uselessly re-testing them when [shorten] is
         called multiple times with the same environment. This notably happens
         when printing module signatures, and they can be quite large. *)
      let queue = Priority_queue.remove item state.queue in
      let not_in_env =
        Path_trie.add ~full_path path (kind_of_kind kind) state.not_in_env
      in
      { queue; not_in_env }
  in
  (* Treats the candidates of one level: those of the weight of [first] and
     of the requested kind. The weight is checked first so that the items of
     other kinds beyond the level are not scanned. *)
  let rec one_level ~first seq state =
    match seq () with
    | Seq.Nil -> state
    | Seq.Cons (((kind, path, _full_path) as item), next) ->
      if compare_paths_weight first path < 0 then state
      else if kind <> target_kind then one_level ~first next state
      else one_level ~first next (treat state item)
  in
  (* Levels are treated in increasing weight. Before a level, the pending
     expansions whose components may belong to it are done. The search stops
     when the best candidate found so far is lighter than anything left. *)
  let rec by_level ~lb ?candidates:cached state best =
    log ~title:"fill_by_level" "Current best: %a" Logger.fmt (fun f ->
        Format.pp_print_option path_print f best);
    (* [cached] holds the candidates of the previous iteration when an
       expansion added nothing that could come before them. *)
    let seq, first =
      match cached with
      | Some cached -> cached
      | None ->
        let seq = candidates lb state.queue in
        let first =
          match seq () with
          | Seq.Nil -> None
          | Seq.Cons ((_, path, _), _) -> Some path
        in
        (seq, first)
    in
    let first_weight = Option.map path_size first in
    (* The lightest pending expansion, if its components can belong to the
       next level *)
    let expansion =
      match Expand_set.min_elt_opt !pending_expand with
      | None -> None
      | Some ((apparent, _) as e) -> (
        let weight = min_component_weight apparent in
        match first_weight with
        | Some first_weight when compare_weight weight first_weight > 0 -> None
        | _ -> Some (e, weight))
    in
    let next_weight =
      match (expansion, first_weight) with
      | Some (_, weight), _ -> Some weight
      | None, first_weight -> first_weight
    in
    match (next_weight, best) with
    | None, _ ->
      log ~title:"fill_by_level" "Empty queue";
      (improve_path env ~canon_path table target_kind best, state)
    | Some next_weight, Some best_path
      when compare_weight (path_size best_path) next_weight < 0 ->
      log ~title:"fill_by_level"
        "Found a name shorter than the next level:\n %a" Logger.fmt
        (Fun.flip path_print best_path);
      (Some best_path, state)
    | Some _, _ -> (
      match (expansion, first) with
      | Some (e, _), _ ->
        pending_expand := Expand_set.remove e !pending_expand;
        let state, lightest = expand substs state e in
        let unchanged = Some (seq, first) in
        let lb, candidates =
          match (lightest, first_weight) with
          | None, _ -> (lb, unchanged)
          | Some w, Some first_weight when compare_weight w first_weight > 0 ->
            (lb, unchanged)
          | Some w, _ -> (
            (* A substitution can make a new path lighter than the levels
               already treated: start again from the lightest candidate. *)
            match lb with
            | Some lb when compare_weight w lb <= 0 -> (None, None)
            | _ -> (lb, None))
        in
        by_level ~lb ?candidates state best
      | None, Some first ->
        let state = one_level ~first seq state in
        let best = improve_path env ~canon_path table target_kind best in
        by_level ~lb:(Some (path_size first)) state best
      | None, None -> assert false)
  in
  by_level ~lb:None state best

(* Given a Path and a Longident that represents a suffix  of that path,
   [path_mask] returns the paths corresponding to that suffix. *)

(* This cache prevent the same ident to be given different stamps in the same query *)
(* todo: we should probably store the masking in the table instead. *)
let path_masks_cache : (Longident.t * Path.t, Path.t) Hashtbl.t ref =
  Local_store.s_table Hashtbl.create 32

(* The print function expect a path but we have longidents.

   TODO What we should really do is modify the printing function to expect a
   longident. *)
let rec path_mask (path : Path.t) (lid : Longident.t) : Path.t =
  match Hashtbl.find_opt !path_masks_cache (lid, path) with
  | Some path -> path
  | None ->
    let masked_path : Path.t =
      match (path, lid) with
      | Pident id, Lident _ -> Pident id
      | Pdot (p, s), Ldot (l, _) -> Pdot (path_mask p l.txt, s)
      | Papply (p1, p2), Lapply (l1, l2) ->
        Papply (path_mask p1 l1.txt, path_mask p2 l2.txt)
      | (Pdot _ | Papply _), Lident s ->
        let scope = Path.scope path in
        Pident (Ident.create_scoped ~scope s)
      | _ -> path
    in
    Hashtbl.add !path_masks_cache (lid, path) masked_path;
    masked_path

let rec shorten ~env ~initial ~canon_path kind =
  let discourse = Discourse.get () in
  let queue, table = (!priority_queue, !canon_table) in
  let substs = ref discourse.substs in
  log_dbg ~title:"shorten" "Current discourse: %a\n%!" Logger.fmt (fun fmt ->
      Discourse.debug_print fmt);
  log_dbg ~title:"shorten" "Current queue: %a" Logger.fmt (fun fmt ->
      Format.pp_print_seq ~pp_sep:Format.pp_print_space Path_set.pp_elt fmt
        (Priority_queue.to_seq queue));
  log_dbg ~title:"shorten" "Current notinenv: %a" Logger.fmt (fun fmt ->
      Discourse_types.Path_trie.pp_seq fmt !not_in_env);
  log_dbg ~title:"shorten" "Current table: %a" Logger.fmt (fun fmt ->
      pp_table fmt table);

  let queue =
    let paths =
      Path_trie.add initial (kind_of_kind kind) discourse.paths
      |> Path_trie.add canon_path (kind_of_kind kind)
    in
    let paths = apply_substitutions_fixpoint paths !substs in
    log_dbg ~title:"shorten" "Discourse after substitutions: %a\n%!" Logger.fmt
      (fun fmt -> Path_trie.pp_seq fmt paths);
    (* Paths queued by a previous call were treated already *)
    let fresh = Path_trie.diff paths !all_paths in
    all_paths := Path_trie.union !all_paths fresh;
    fill_queue fresh queue
  in

  log_dbg ~title:"shorten" "Current queue: %a" Logger.fmt (fun fmt ->
      Format.pp_print_seq ~pp_sep:Format.pp_print_space Path_set.pp_elt fmt
        (Priority_queue.to_seq queue));

  (* Do we already have a candidate ? *)
  let best = find_best_path env ~canon_path table kind in

  log ~title:"shorten" "Initial: %a; Canon: %a; Current best: %a" Logger.fmt
    (Fun.flip path_print initial) Logger.fmt (Fun.flip path_print canon_path)
    Logger.fmt (fun f -> Format.pp_print_option path_print f best);

  (* Is there a better one in the queue ? *)
  let best_path, { queue = queue'; not_in_env = not_in_env' } =
    let not_in_env = !not_in_env in
    process_queue env substs { queue; not_in_env } ~table ~canon_path kind best
  in

  (* Empty the discourse *)
  Discourse.reset ~substs:!substs ();

  (* Update the persistent queues and table *)
  priority_queue := queue';
  not_in_env := not_in_env';

  Option.value ~default:initial best_path |> shorten_application_args env
(* match best_path with
  | None ->
    log ~title:"shorten" "Falling-back on initial path %a" Logger.fmt
      (Fun.flip path_print initial);
    initial
  | Some (lid, path) ->
    log ~title:"shorten" "%a" Logger.fmt (fun fmt ->
        Format.fprintf fmt "Masking path %a with lid %a" path_print path
          Pprintast.longident lid);
    path_mask path lid *)

and shorten_application_args env path =
  match (path : Path.t) with
  | Pident _ -> path
  | Pdot (p, s) ->
    let p' = shorten_application_args env p in
    if p' == p then path else Pdot (p', s)
  | Pextra_ty (p, extra) ->
    let p' = shorten_application_args env p in
    if p' == p then path else Pextra_ty (p', extra)
  | Papply (p1, p2) ->
    let p1' = find_module env p1 in
    let p2' = find_module env p2 in
    if p1' == p1 && p2' == p2 then path else Papply (p1', p2')

and find_module env initial =
  let canon_path = Env.normalize_module_path None env initial in
  shorten ~env ~initial ~canon_path Module

type type_result = Short_paths.type_result =
  | Nth of int
  | Path of int list option * Path.t

type type_resolution = Short_paths.type_resolution =
  | Nth of int
  | Subst of int list
  | Id

let find_type env initial : type_result =
  match normalize_type_path env initial with
  | _, Nth i -> (* TODO, this looks like this is incorrect *) Nth i
  | canon_path, Id -> Path (None, shorten ~env ~initial ~canon_path Type)
  | canon_path, Map l -> Path (Some l, shorten ~env ~initial ~canon_path Type)

let find_type_resolution env path : type_resolution =
  match normalize_type_path env path with
  | _, Nth i -> Nth i
  | _, Id -> Id
  | _, Map l -> Subst l

let find_type_simple env initial =
  let canon_path, _subst = normalize_type_path env initial in
  let short = shorten ~env ~initial ~canon_path Type in
  short

let find_module_type env initial =
  let canon_path = Env.normalize_modtype_path env initial in
  shorten ~env ~initial ~canon_path Module_type
