  $ cat >main.ml <<'EOF'
  > let _ = Bytes.create 0
  > let _ = Bytes.create 0
  > EOF

We shouldn't return the definition when it's not in the current workspace
  $ $MERLIN single occurrences -scope project -identifier-at 2:17 \
  > -filename main.ml <main.ml
  {
    "class": "return",
    "value": [
      {
        "file": "$TESTCASE_ROOT/main.ml",
        "start": {
          "line": 1,
          "col": 14
        },
        "end": {
          "line": 1,
          "col": 20
        }
      },
      {
        "file": "$TESTCASE_ROOT/main.ml",
        "start": {
          "line": 2,
          "col": 14
        },
        "end": {
          "line": 2,
          "col": 20
        }
      }
    ],
    "notifications": []
  }
