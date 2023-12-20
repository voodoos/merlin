  $ cat >lib.ml <<'EOF'
  > let something_fun () = print_string "fun";;
  > let g = something_fun
  > EOF

  $ cat >main.ml <<'EOF'
  > let () = Lib.something_fun ()
  > EOF

  $ $OCAMLC -c -bin-annot -bin-annot-occurrences - lib.ml main.ml
  $ ocaml-index aggregate lib.cmt main.cmt -o project.index

  $ cat >.merlin <<'EOF'
  > INDEX_FILE project.index
  > B .
  > EOF

FIXME: remove duplicates
  $ $MERLIN single occurrences -scope project -identifier-at 1:16 \
  > -filename main.ml <main.ml | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 17
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 13
      },
      "end": {
        "line": 1,
        "col": 26
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib.ml",
      "start": {
        "line": 2,
        "col": 8
      },
      "end": {
        "line": 2,
        "col": 21
      }
    }
  ]

FIXME: remove duplicates
  $ $MERLIN single occurrences -scope project -identifier-at 2:15 \
  > -filename lib.ml <lib.ml | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 17
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 17
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 13
      },
      "end": {
        "line": 1,
        "col": 26
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib.ml",
      "start": {
        "line": 2,
        "col": 8
      },
      "end": {
        "line": 2,
        "col": 21
      }
    }
  ]

FIXME: remove duplicates
  $ $MERLIN single occurrences -scope project -identifier-at 1:10 \
  > -filename lib.ml <lib.ml | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 17
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 17
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 13
      },
      "end": {
        "line": 1,
        "col": 26
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib.ml",
      "start": {
        "line": 2,
        "col": 8
      },
      "end": {
        "line": 2,
        "col": 21
      }
    }
  ]
