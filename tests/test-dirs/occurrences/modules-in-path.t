  $ cat >main.ml <<'EOF'
  > module N = struct module M = struct let x = 42 end end
  > let () = print_int N.M.x
  > EOF

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
      }
    ],
    "notifications": []
  }
