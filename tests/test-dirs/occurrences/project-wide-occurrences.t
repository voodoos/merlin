  $ cat >dune-workspace <<EOF
  > (lang dune 3.5)
  > (workspace_indexation enabled)
  > EOF

  $ cat >dune-project <<EOF
  > (lang dune 3.5)
  > EOF

  $ cat >main.ml <<EOF
  > let x = 3 + Foo.f 3
  > let _y = x
  > let r = { Foo.label_rouge = 4 }
  > let () = print_int r.label_rouge
  > module M = Map.Make(Foo.Bar)
  > type _r2 = Foo.r
  > EOF

  $ cat>dune <<EOF
  > (executable (name main) (libraries foo))
  > EOF

  $ mkdir lib

  $ cat >lib/foo.ml <<EOF
  > let f x = x
  > let _y = f 3
  > type r = { label_rouge : int }
  > module Bar = String
  > module Bartender = Bar
  > EOF

  $ cat>lib/dune <<EOF
  > (library (name foo))
  > EOF

  $ dune build @uideps 
$ ocamlc -c -bin-annot foo.mli foo.ml main.ml
$ ocaml-uideps process-cmt main.cmt foo.cmt foo.cmti -o project.uideps
  $ ocaml-uideps dump _build/default/project.uideps 
  15 uids:
  {uid: Foo.4; locs:
     "label_rouge": File "$TESTCASE_ROOT/lib/foo.ml", line 3, characters 11-22;
     "Foo.label_rouge": File "main.ml", line 3, characters 10-25;
     "label_rouge": File "main.ml", line 4, characters 21-32
   uid: Foo.2; locs:
     "_y": File "$TESTCASE_ROOT/lib/foo.ml", line 2, characters 4-6
   uid: Foo.3; locs:
     "r": File "$TESTCASE_ROOT/lib/foo.ml", line 3, characters 5-6;
     "Foo.r": File "main.ml", line 6, characters 11-16
   uid: <predef:int>; locs: "int": File "lib/foo.ml", line 3, characters 25-28
   uid: Foo.6; locs:
     "Bartender": File "$TESTCASE_ROOT/lib/foo.ml", line 5, characters 7-16
   uid: Dune__exe__Main.0; locs:
     "x": File "$TESTCASE_ROOT/main.ml", line 1, characters 4-5;
     "x": File "main.ml", line 2, characters 9-10
   uid: Stdlib.53; locs: "+": File "main.ml", line 1, characters 10-11
   uid: Dune__exe__Main.2; locs:
     "r": File "$TESTCASE_ROOT/main.ml", line 3, characters 4-5;
     "r": File "main.ml", line 4, characters 19-20
   uid: Foo.0; locs:
     "f": File "$TESTCASE_ROOT/lib/foo.ml", line 1, characters 4-5;
     "f": File "lib/foo.ml", line 2, characters 9-10;
     "Foo.f": File "main.ml", line 1, characters 12-17
   uid: Foo.5; locs:
     "Bar": File "$TESTCASE_ROOT/lib/foo.ml", line 4, characters 7-10
   uid: Foo.1; locs: "x": File "lib/foo.ml", line 1, characters 10-11
   uid: Stdlib.316; locs: "print_int": File "main.ml", line 4, characters 9-18
   uid: Dune__exe__Main.3; locs:
     "M": File "$TESTCASE_ROOT/main.ml", line 5, characters 7-8
   uid: Dune__exe__Main.1; locs:
     "_y": File "$TESTCASE_ROOT/main.ml", line 2, characters 4-6
   uid: Dune__exe__Main.4; locs:
     "_r2": File "$TESTCASE_ROOT/main.ml", line 6, characters 5-8
   }, 4 partial shapes:
  {shape: Alias(<Foo.5>
                CU Stdlib . "String"[module type]) ; locs:
     "Bar": File "lib/foo.ml", line 5, characters 19-22
   shape: CU Stdlib . "String"[module type] ; locs:
     "String": File "lib/foo.ml", line 4, characters 13-19
   shape: CU Stdlib . "Map"[module type] . "Make"[module type] ; locs:
     "Map.Make": File "main.ml", line 5, characters 11-19
   shape: CU Foo . "Bar"[module type] ; locs:
     "Foo.Bar": File "main.ml", line 5, characters 20-27
   }, 0 unreduced shapes: {} and shapes for CUS .

> main.ml
> let x = 3 + Foo.|f 3
  $ $MERLIN single occurrences -scope project -identifier-at 1:16 \
  > -filename main.ml <main.ml | jq '.value'
  [
    {
      "file": "lib/foo.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 5
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 5
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 2,
        "col": 9
      },
      "end": {
        "line": 2,
        "col": 10
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 16
      },
      "end": {
        "line": 1,
        "col": 17
      }
    }
  ]
 

> let |f x = x
  $ $MERLIN single occurrences -scope project -identifier-at 1:4 \
  > -log-file - \
  > -filename lib/foo.ml <lib/foo.ml  | jq '.value'
  # 0.01 Mconfig_dot - get_config
  Starting dune configuration provider from dir $TESTCASE_ROOT.
  # 0.01 Mconfig_dot - get_config
  Querying dune (inital cwd: $TESTCASE_ROOT) for file: lib/foo.ml.
  Workdir: $TESTCASE_ROOT/lib
  # 0.01 Mconfig - normalize
  {
    "ocaml": {
      "include_dirs": [],
      "no_std_include": false,
      "unsafe": false,
      "classic": false,
      "principal": false,
      "real_paths": false,
      "recursive_types": false,
      "strict_sequence": true,
      "applicative_functors": true,
      "nopervasives": false,
      "strict_formats": true,
      "open_modules": [],
      "ppx": [],
      "pp": null,
      "warnings": {
        "actives": [
          1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
          21, 22, 23, 24, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38,
          39, 43, 46, 47, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 61, 62,
          63, 64, 65, 67, 69, 71, 72, 73
        ],
        "warn_error": [
          1, 2, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
          22, 23, 24, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
          43, 46, 47, 49, 50, 51, 52, 53, 54, 55, 56, 57, 61, 62, 67, 69
        ],
        "alerts": {
          "alerts": [ "unstable", "unsynchronized_access" ],
          "complement": true
        },
        "alerts_error": { "alerts": [ "deprecated" ], "complement": false }
      }
    },
    "merlin": {
      "build_path": [
        "$TESTCASE_ROOT/_build/default/lib/.foo.objs/byte"
      ],
      "source_path": [
        "$TESTCASE_ROOT/lib"
      ],
      "cmi_path": [],
      "cmt_path": [],
      "flags_applied": [
        {
          "workdir": "$TESTCASE_ROOT/lib",
          "workval": [
            "-w", "@1..3@5..28@30..39@43@46..47@49..57@61..62@67@69-40",
            "-strict-sequence", "-strict-formats", "-short-paths",
            "-keep-locs", "-g"
          ]
        }
      ],
      "extensions": [],
      "suffixes": [
        { "impl": ".ml", "intf": ".mli" }, { "impl": ".re", "intf": ".rei" }
      ],
      "stdlib": "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml",
      "index_file": "$TESTCASE_ROOT/_build/default/project.uideps",
      "reader": [],
      "protocol": "json",
      "log_file": "-",
      "log_sections": [],
      "flags_to_apply": [],
      "failures": [],
      "assoc_suffixes": [
        { "extension": ".re", "reader": "reason" },
        { "extension": ".rei", "reader": "reason" }
      ]
    },
    "query": {
      "filename": "foo.ml",
      "directory": "$TESTCASE_ROOT/lib",
      "printer_width": 0,
      "verbosity": "lvl 0"
    }
  }
  # 0.01 Mconfig - normalize
  {
    "ocaml": {
      "include_dirs": [],
      "no_std_include": false,
      "unsafe": false,
      "classic": false,
      "principal": false,
      "real_paths": false,
      "recursive_types": false,
      "strict_sequence": true,
      "applicative_functors": true,
      "nopervasives": false,
      "strict_formats": true,
      "open_modules": [],
      "ppx": [],
      "pp": null,
      "warnings": {
        "actives": [
          1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
          21, 22, 23, 24, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38,
          39, 43, 46, 47, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 61, 62,
          63, 64, 65, 67, 69, 71, 72, 73
        ],
        "warn_error": [
          1, 2, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
          22, 23, 24, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
          43, 46, 47, 49, 50, 51, 52, 53, 54, 55, 56, 57, 61, 62, 67, 69
        ],
        "alerts": {
          "alerts": [ "unstable", "unsynchronized_access" ],
          "complement": true
        },
        "alerts_error": { "alerts": [ "deprecated" ], "complement": false }
      }
    },
    "merlin": {
      "build_path": [
        "$TESTCASE_ROOT/_build/default/lib/.foo.objs/byte"
      ],
      "source_path": [
        "$TESTCASE_ROOT/lib"
      ],
      "cmi_path": [],
      "cmt_path": [],
      "flags_applied": [
        {
          "workdir": "$TESTCASE_ROOT/lib",
          "workval": [
            "-w", "@1..3@5..28@30..39@43@46..47@49..57@61..62@67@69-40",
            "-strict-sequence", "-strict-formats", "-short-paths",
            "-keep-locs", "-g"
          ]
        }
      ],
      "extensions": [],
      "suffixes": [
        { "impl": ".ml", "intf": ".mli" }, { "impl": ".re", "intf": ".rei" }
      ],
      "stdlib": "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml",
      "index_file": "$TESTCASE_ROOT/_build/default/project.uideps",
      "reader": [],
      "protocol": "json",
      "log_file": "-",
      "log_sections": [],
      "flags_to_apply": [],
      "failures": [],
      "assoc_suffixes": [
        { "extension": ".re", "reader": "reason" },
        { "extension": ".rei", "reader": "reason" }
      ]
    },
    "query": {
      "filename": "foo.ml",
      "directory": "$TESTCASE_ROOT/lib",
      "printer_width": 0,
      "verbosity": "lvl 0"
    }
  }
  # 0.01 Pipeline - pop_cache
  nothing cached for this configuration
  # 0.01 New_commands - run(query)
  {
    "command": "occurrences",
    "kind": "identifiers",
    "position": { "line": 1, "column": 4 },
    "scope": "project"
  }
  # 0.01 Mconfig - normalize
  {
    "ocaml": {
      "include_dirs": [],
      "no_std_include": false,
      "unsafe": false,
      "classic": false,
      "principal": false,
      "real_paths": false,
      "recursive_types": false,
      "strict_sequence": true,
      "applicative_functors": true,
      "nopervasives": false,
      "strict_formats": true,
      "open_modules": [],
      "ppx": [],
      "pp": null,
      "warnings": {
        "actives": [
          1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
          21, 22, 23, 24, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38,
          39, 43, 46, 47, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 61, 62,
          63, 64, 65, 67, 69, 71, 72, 73
        ],
        "warn_error": [
          1, 2, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
          22, 23, 24, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
          43, 46, 47, 49, 50, 51, 52, 53, 54, 55, 56, 57, 61, 62, 67, 69
        ],
        "alerts": {
          "alerts": [ "unstable", "unsynchronized_access" ],
          "complement": true
        },
        "alerts_error": { "alerts": [ "deprecated" ], "complement": false }
      }
    },
    "merlin": {
      "build_path": [
        "$TESTCASE_ROOT/_build/default/lib/.foo.objs/byte"
      ],
      "source_path": [
        "$TESTCASE_ROOT/lib"
      ],
      "cmi_path": [],
      "cmt_path": [],
      "flags_applied": [
        {
          "workdir": "$TESTCASE_ROOT/lib",
          "workval": [
            "-w", "@1..3@5..28@30..39@43@46..47@49..57@61..62@67@69-40",
            "-strict-sequence", "-strict-formats", "-short-paths",
            "-keep-locs", "-g"
          ]
        }
      ],
      "extensions": [],
      "suffixes": [
        { "impl": ".ml", "intf": ".mli" }, { "impl": ".re", "intf": ".rei" }
      ],
      "stdlib": "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml",
      "index_file": "$TESTCASE_ROOT/_build/default/project.uideps",
      "reader": [],
      "protocol": "json",
      "log_file": "-",
      "log_sections": [],
      "flags_to_apply": [],
      "failures": [],
      "assoc_suffixes": [
        { "extension": ".re", "reader": "reason" },
        { "extension": ".rei", "reader": "reason" }
      ]
    },
    "query": {
      "filename": "foo.ml",
      "directory": "$TESTCASE_ROOT/lib",
      "printer_width": 0,
      "verbosity": "lvl 0"
    }
  }
  # 0.01 Phase cache - Reader phase
  Cache is disabled: configuration
  # 0.01 Mreader - run
  extension("foo.ml") = ".ml"
  # 0.01 Phase cache - PPX phase
  Cache is disabled: configuration
  # 0.01 Mconfig - build_path
  2 items in path, 2 after deduplication
  # 0.01 Mconfig - build_path
  2 items in path, 2 after deduplication
  # 0.01 File_cache(Directory_content_cache) - read
  reading "$TESTCASE_ROOT/_build/default/lib/.foo.objs/byte" from disk
  # 0.01 File_cache(Directory_content_cache) - read
  reading "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml" from disk
  # 0.01 File_cache(Cmi_cache) - read
  reading "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml/stdlib.cmi" from disk
  # 0.01 Mtyper - node_at
  Node: [ structure ]
  # 0.01 Mtyper - node_at
  Deepest before [ pattern (foo.ml[1,0+4]..foo.ml[1,0+5])
    Tpat_var "f/275"
  ; value_binding; structure_item; structure ]
  # 0.01 type-enclosing - reconstruct-identifier
  paths: [f]
  # 0.01 locate - reconstructed identifier
  f
  # 0.01 occurrences - occurrences
  Looking for occurences of f (pos: 1:4)
  # 0.01 context - inspect_context
  current node is: [[ structure ]]
  # 0.01 context - inspect_context
  current enclosing node is: pattern (foo.ml[1,0+4]..foo.ml[1,0+5])
    Tpat_var "f/275"
  # 0.01 context - inspect_context
  current pattern is: pattern (foo.ml[1,0+4]..foo.ml[1,0+5])
    Tpat_var "f/275"
  # 0.01 locate - from_string
  already at origin, doing nothing
  # 0.01 occurrences - locs_of
  Cursor is on definition / declaration
  # 0.01 occurrences - occurrences
  Looking for uid of node pattern (foo.ml[1,0+4]..foo.ml[1,0+5])
    Tpat_var "f/275"
  # 0.01 occurrences - locs_of
  Definition has uid Foo.0 (File "foo.ml", line 1, characters 4-5)
  # 0.01 occurrences - locs_of
  Indexing current buffer
  # 0.01 occurrences - read_unit_shape
  inspecting Stdlib
  # 0.01 occurrences - read_unit_shape
  shapes loaded for Stdlib
  # 0.01 occurrences - read_unit_shape
  inspecting Stdlib__String
  # 0.01 occurrences - read_unit_shape
  shapes loaded for Stdlib__String
  # 0.01 occurrences - locs_of
  Using external index: "$TESTCASE_ROOT/_build/default/project.uideps"
  # 0.01 locate - find_source
  attempt to find "foo.ml"
  # 0.01 File_cache(Exists_in_directory) - read
  reading "$TESTCASE_ROOT/lib" from disk
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reading "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml" from disk
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml"
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml"
  # 0.01 locate - find_source
  attempt to find "lib/foo.ml"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml"
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml"
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml"
  # 0.01 locate - find_source
  attempt to find "main.ml"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml"
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml"
  # 0.01 stat_cache - reuse cache
  /Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml"
  # 0.01 locate - find_source
  failed to find "Main" in source path (fallback = false)
  # 0.01 locate - find_source
  looking for "Main" in "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 locate - find_in_path_uncap
  Failed to load $TESTCASE_ROOT/lib/Main.ml
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 locate - find_in_path_uncap
  Failed to load $TESTCASE_ROOT/lib/Main.re
  # 0.01 locate - find_source
  Trying to find "main.ml" in "$TESTCASE_ROOT/lib" directly
  # 0.01 stat_cache - reuse cache
  $TESTCASE_ROOT/lib
  # 0.01 File_cache(Exists_in_directory) - read
  reusing "$TESTCASE_ROOT/lib"
  # 0.01 occurrences - occurrences
  'main.ml' seems to originate from 'Main' whose ML file could not be found
  # 0.02 New_merlin - run(result)
  {
    "class": "return",
    "value": [
      {
        "file": "foo.ml",
        "start": { "line": 1, "col": 4 },
        "end": { "line": 1, "col": 5 }
      },
      {
        "file": "$TESTCASE_ROOT/lib/foo.ml",
        "start": { "line": 1, "col": 4 },
        "end": { "line": 1, "col": 5 }
      },
      {
        "file": "$TESTCASE_ROOT/lib/foo.ml",
        "start": { "line": 2, "col": 9 },
        "end": { "line": 2, "col": 10 }
      },
      {
        "file": "$TESTCASE_ROOT/lib/foo.ml",
        "start": { "line": 2, "col": 9 },
        "end": { "line": 2, "col": 10 }
      }
    ],
    "notifications": [],
    "timing": {
      "clock": 26,
      "cpu": 8,
      "query": 5,
      "pp": 0,
      "reader": 1,
      "ppx": 0,
      "typer": 2,
      "error": 0
    }
  }
  [
    {
      "file": "foo.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 5
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 5
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 2,
        "col": 9
      },
      "end": {
        "line": 2,
        "col": 10
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 2,
        "col": 9
      },
      "end": {
        "line": 2,
        "col": 10
      }
    }
  ]

$ ocaml-uideps dump _build/default/project.uideps
$ ocamlmerlin single dump-configuration  -filename lib/foo.ml <lib/foo.ml | jq


  $ FILE=main.ml
  $ printf "(4:File%d:%s)" ${#FILE} $FILE | dune ocaml-merlin
  ((10:INDEX_FILE151:$TESTCASE_ROOT/_build/default/project.uideps)(6:STDLIB45:/Users/ulysse/tmp/0ccurrences/_opam/lib/ocaml)(17:EXCLUDE_QUERY_DIR)(1:B153:$TESTCASE_ROOT/_build/default/.main.eobjs/byte)(1:B155:$TESTCASE_ROOT/_build/default/lib/.foo.objs/byte)(1:S121:$TESTCASE_ROOT)(1:S125:$TESTCASE_ROOT/lib)(3:FLG(2:-w51:@1..3@5..28@30..39@43@46..47@49..57@61..62@67@69-4016:-strict-sequence15:-strict-formats12:-short-paths10:-keep-locs2:-g)))
