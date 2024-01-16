  $ cat >main.ml <<'EOF'
  > module M : sig
  >   module F (X : sig end) : sig end
  > end = struct
  >   module F (X : sig end) = X
  > end
  > module X = struct end
  > module N = M.F (X)
  > 
  > include N
  > EOF

  $ $MERLIN single locate -look-for ml -position 9:8 \
  > -filename ./main.ml < ./main.ml | jq '.value'
  {
    "file": "$TESTCASE_ROOT/main.ml",
    "pos": {
      "line": 7,
      "col": 7
    }
  }

  $ $MERLIN single occurrences -identifier-at 9:8 \
  > -filename ./main.ml < ./main.ml | jq '.value' | grep line | uniq
        "line": 7,
        "line": 9,
