  $ dune build @check

When the definition is in one of the implicit transitive dependencies
Merlin does not find the file in the source path provided by Dune. One possible
fix would be for Dune to provide additional source path for "external" deps.
  $ $MERLIN single locate -look-for ml -position 1:15 \
  > -filename bin/main.ml <bin/main.ml
  {
    "class": "return",
    "value": {
      "file": "$TESTCASE_ROOT/src/lib2/lib2.ml",
      "pos": {
        "line": 1,
        "col": 5
      }
    },
    "notifications": []
  }
