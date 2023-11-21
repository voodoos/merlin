  $ cat >dune-workspace <<'EOF'
  > (lang dune 3.11)
  > (workspace_indexation enabled)
  > EOF

  $ cat >dune-project <<'EOF'
  > (lang dune 3.11)
  > EOF
 
  $ mkdir lib

  $ cat >lib/wrapped_module.ml <<'EOF'
  > let x = 42
  > let f () = x
  > EOF

  $ cat >lib/dune <<'EOF'
  > (library 
  >  (name lib))
  > EOF

  $ cat >main.ml <<'EOF'
  > open Lib
  > let () = print_int Wrapped_module.x
  > EOF

  $ cat >dune <<'EOF'
  > (executable
  >  (name main)
  >  (libraries lib))
  > EOF

  $ dune build @uideps @all

  $ ocaml-index dump _build/default/project.ocaml-index
  6 uids:
  {uid: Lib__Wrapped_module; locs:
     "Lib__Wrapped_module": File "$TESTCASE_ROOT/lib/lib.ml-gen", line 4, characters 24-43
   uid: Stdlib.313; locs:
     "print_int": File "$TESTCASE_ROOT/main.ml", line 2, characters 9-18
   uid: Lib.0; locs:
     "Wrapped_module": File "$TESTCASE_ROOT/lib/lib.ml-gen", line 4, characters 7-21
   uid: Lib__Wrapped_module.0; locs:
     "x": File "$TESTCASE_ROOT/lib/wrapped_module.ml", line 1, characters 4-5;
     "x": File "$TESTCASE_ROOT/lib/wrapped_module.ml", line 2, characters 11-12;
     "Wrapped_module.x": File "$TESTCASE_ROOT/main.ml", line 2, characters 19-35
   uid: Lib; locs:
     "Lib": File "$TESTCASE_ROOT/main.ml", line 1, characters 5-8
   uid: Lib__Wrapped_module.1; locs:
     "f": File "$TESTCASE_ROOT/lib/wrapped_module.ml", line 2, characters 4-5
   }, 0 approx shapes: {}, and shapes for CUS .

  $ $MERLIN single occurrences -scope project -identifier-at 2:34 \
  > -filename main.ml <main.ml | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib/wrapped_module.ml",
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
      "file": "$TESTCASE_ROOT/lib/wrapped_module.ml",
      "start": {
        "line": 2,
        "col": 11
      },
      "end": {
        "line": 2,
        "col": 12
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 2,
        "col": 34
      },
      "end": {
        "line": 2,
        "col": 35
      }
    }
  ]

FIXME: These are only the local occurrences. This is due to Merlin identifing
the uid as part of `Wrapped_module` instead of `Lib__wrapped_module`.
  $ $MERLIN single occurrences -scope project -identifier-at 2:11 \
  > -filename lib/wrapped_module.ml <lib/wrapped_module.ml | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib/wrapped_module.ml",
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
      "file": "$TESTCASE_ROOT/lib/wrapped_module.ml",
      "start": {
        "line": 2,
        "col": 11
      },
      "end": {
        "line": 2,
        "col": 12
      }
    }
  ]
