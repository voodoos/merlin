  $ cat >main.ml <<'EOF'
  > module N = struct module M = struct let x = 42 end end
  > let () = print_int N.M.x
  > let () = print_int N.M.(*comment*)x
  > EOF

FIXME: longident with spaces will be highlighted incorrectly

  $ $MERLIN single occurrences -identifier-at 1:25 \
  > -filename main.ml <main.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 1,
          "col": 25
        },
        "end": {
          "line": 1,
          "col": 26
        }
      },
      {
        "start": {
          "line": 2,
          "col": 21
        },
        "end": {
          "line": 2,
          "col": 22
        }
      },
      {
        "start": {
          "line": 3,
          "col": 32
        },
        "end": {
          "line": 3,
          "col": 33
        }
      }
    ],
    "notifications": []
  }

  $ $MERLIN single occurrences -identifier-at 1:7 \
  > -filename main.ml <main.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 1,
          "col": 7
        },
        "end": {
          "line": 1,
          "col": 8
        }
      },
      {
        "start": {
          "line": 2,
          "col": 19
        },
        "end": {
          "line": 2,
          "col": 20
        }
      },
      {
        "start": {
          "line": 3,
          "col": 30
        },
        "end": {
          "line": 3,
          "col": 31
        }
      }
    ],
    "notifications": []
  }


FIXME: reconstruct identifier does not handle correctly longidents with comments
between components.
  $ $MERLIN single occurrences -identifier-at 3:34 \
  > -log-file - -log-section locate \
  > -filename main.ml <main.ml
  # 0.01 locate - reconstructed identifier
  x
  # 0.01 locate - from_string
  inferred context: expression
  # 0.01 locate - from_string
  looking for the source of 'x' (prioritizing .ml files)
  {
    "class": "return",
    "value": [],
    "notifications": []
  }
