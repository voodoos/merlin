  $ cat >dune-workspace <<'EOF'
  > (lang dune 3.11)
  > (workspace_indexation enabled)
  > EOF

  $ cat >dune-project <<'EOF'
  > (lang dune 3.11)
  > EOF

  $ mkdir lib
  $ cat >lib/lib.ml <<'EOF'
  > let x = 42
  > let y = x
  > EOF

  $ cat >lib/dune <<'EOF'
  > (library
  >  (name lib))
  > EOF

  $ mkdir exe
  $ cat >exe/main.ml <<'EOF'
  > print_int Lib.x
  > EOF

  $ cat >exe/dune <<'EOF'
  > (library
  >  (name main)
  >  (libraries lib))
  > EOF

  $ dune build @all

  $ ocaml-index dump _build/default/project.ocaml-index
  3 uids:
  {uid: Lib.1; locs:
     "y": File "$TESTCASE_ROOT/lib/lib.ml", line 2, characters 4-5
   uid: Stdlib.313; locs:
     "print_int": File "$TESTCASE_ROOT/exe/main.ml", line 1, characters 0-9
   uid: Lib.0; locs:
     "x": File "$TESTCASE_ROOT/lib/lib.ml", line 1, characters 4-5;
     "x": File "$TESTCASE_ROOT/lib/lib.ml", line 2, characters 8-9;
     "Lib.x": File "$TESTCASE_ROOT/exe/main.ml", line 1, characters 10-15
   }, 0 approx shapes: {}, and shapes for CUS .

Occurrences of Lib.x
  $ $MERLIN single occurrences -scope project -identifier-at 1:15 \
  > -filename exe/main.ml <exe/main.ml
  {
    "class": "return",
    "value": [
      {
        "file": "$TESTCASE_ROOT/lib/lib.ml",
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
        "file": "$TESTCASE_ROOT/exe/main.ml",
        "start": {
          "line": 1,
          "col": 14
        },
        "end": {
          "line": 1,
          "col": 15
        }
      },
      {
        "file": "$TESTCASE_ROOT/lib/lib.ml",
        "start": {
          "line": 2,
          "col": 8
        },
        "end": {
          "line": 2,
          "col": 9
        }
      }
    ],
    "notifications": []
  }


  $ sleep 1 # Make sure that the time will change
  $ echo " (* *)" >> lib/lib.ml

  $ $MERLIN single occurrences -scope project -identifier-at 1:15 \
  > -log-file log -log-section occurrences \
  > -filename exe/main.ml <exe/main.ml
  {
    "class": "return",
    "value": [
      {
        "file": "$TESTCASE_ROOT/exe/main.ml",
        "start": {
          "line": 1,
          "col": 14
        },
        "end": {
          "line": 1,
          "col": 15
        }
      }
    ],
    "notifications": []
  }

  $ cat log | grep index
  File $TESTCASE_ROOT/lib/lib.ml has been modified since the index was built.
  External index might be out-of-sync.
