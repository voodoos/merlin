  $ cat >main.ml <<'EOF'
  > module Id(X : sig end) = X
  > module F (X :sig end ) : 
  > sig module M : sig end end = 
  > struct module M = X end
  > module N = struct end
  > module Z = F(Id(N))
  > 
  > include Z.M
  > EOF

  $ $MERLIN single locate -look-for ml -position 8:11 \
  > -filename main.ml <main.ml
  {
    "class": "return",
    "value": {
      "file": "$TESTCASE_ROOT/main.ml",
      "pos": {
        "line": 5,
        "col": 7
      }
    },
    "notifications": []
  }

  $ cat >main.ml <<'EOF'
  > module M = struct end
  > module N = M
  > module O = N
  > EOF

  $ $MERLIN single locate -look-for ml -position 3:11 \
  > -filename main.ml <main.ml
  {
    "class": "return",
    "value": {
      "file": "$TESTCASE_ROOT/main.ml",
      "pos": {
        "line": 1,
        "col": 7
      }
    },
    "notifications": []
  }
