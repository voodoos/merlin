  $ cat >oui_ml.ml <<'EOF'
  > type t = int
  > EOF

  $ cat >no_ml.mli <<'EOF'
  > include module type of Oui_ml
  > EOF

  $ cat >main.ml <<'EOF'
  > let (x : No_ml.t) = 42
  > open No_ml
  > let (y : t) = 43
  > EOF

  $ $OCAMLC -bin-annot -bin-annot-occurrences -c oui_ml.ml no_ml.mli main.ml
  $ ocaml-index aggregate oui_ml.cmt no_ml.cmti main.cmt -o project.index

  $ cat >.merlin <<'EOF'
  > INDEX_FILE project.index
  > EOF

  $ $MERLIN single occurrences -scope project -identifier-at 1:15 \
  > -filename main.ml <main.ml | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 15
      },
      "end": {
        "line": 1,
        "col": 16
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 3,
        "col": 9
      },
      "end": {
        "line": 3,
        "col": 10
      }
    }
  ]



  $ $MERLIN single locate -look-for ml -position 1:15 \
  > -filename main.ml <main.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/oui_ml.ml",
    "pos": {
      "line": 1,
      "col": 5
    }
  }
