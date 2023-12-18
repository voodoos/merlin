  $ cat >main.ml <<'EOF'
  > module Id(X : sig end) = X
  > module F (X :sig end ) : 
  > sig module M : sig end end = 
  > struct module M = X end
  > module N = struct end
  > module Z = F(struct end)
  > 
  > include Z.M
  > EOF

  $ $MERLIN single locate -look-for ml -position 8:11 \
  > -log-file - -log-section locate \
  > -filename main.ml <main.ml
  # 0.01 locate - reconstructed identifier
  Z.M
  # 0.01 locate - from_string
  inferred context: module path
  # 0.01 locate - from_string
  looking for the source of 'Z.M' (prioritizing .ml files)
  # 0.01 locate - lookup
  lookup in module namespace
  # 0.01 locate - env_lookup
  found: 'Z/281[8].M' in namespace module with uid Main.4
  # 0.01 locate - shape_of_path
  initial: Abs<Main.5>(X/275, {
                      "M"[module] -> X/275<Main.2>;
                      })({
                          })<Main.7> . "M"[module]
  # 0.01 locate - shape_of_path
  reduced: {
   }
  # 0.01 locate - shape_of_path
  No uid found; fallbacking to declaration uid
  # 0.01 locate - uid_of_path
  Unaliasing uid: Main.4 -> Main.4
  # 0.01 locate - from_uid
  We look for Main.4 in the current compilation unit.
  # 0.01 locate - from_uid
  Looking for Main.4 in the uid_to_loc table
  # 0.01 locate - from_uid
  Found location: File "main.ml", line 3, characters 4-22
  # 0.01 locate - find_source
  attempt to find "main.ml"
  # 0.01 locate - result
  found: $TESTCASE_ROOT/main.ml
  {
    "class": "return",
    "value": {
      "file": "$TESTCASE_ROOT/main.ml",
      "pos": {
        "line": 3,
        "col": 4
      }
    },
    "notifications": []
  }


  $ cat >main.ml <<'EOF'
  > module M = struct end
  > module N  : sig end  = M
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
        "col": 0
      }
    },
    "notifications": []
  }

  $ cat >main.ml <<'EOF'
  > module F (X: sig end) = struct module M = X end
  > module N = F(struct end)
  > module O = N.M
  > EOF

  $ $MERLIN single locate -look-for ml -position 3:13 \
  > -log-file - -log-section locate \
  > -filename main.ml <main.ml
  # 0.01 locate - reconstructed identifier
  N.M
  # 0.01 locate - from_string
  inferred context: module path
  # 0.01 locate - from_string
  looking for the source of 'N.M' (prioritizing .ml files)
  # 0.01 locate - lookup
  lookup in module namespace
  # 0.01 locate - env_lookup
  found: 'N/277[4].M' in namespace module with uid Main.1
  # 0.01 locate - shape_of_path
  initial: Abs<Main.2>(X/273, {
                      "M"[module] -> X/273<Main.0>;
                      })({
                          })<Main.3> . "M"[module]
  # 0.01 locate - shape_of_path
  reduced: {
   }
  # 0.01 locate - shape_of_path
  No uid found; fallbacking to declaration uid
  # 0.01 locate - uid_of_path
  Unaliasing uid: Main.1 -> Main.1
  # 0.01 locate - from_uid
  We look for Main.1 in the current compilation unit.
  # 0.01 locate - from_uid
  Looking for Main.1 in the uid_to_loc table
  # 0.01 locate - from_uid
  Found location: File "main.ml", line 1, characters 31-43
  # 0.01 locate - find_source
  attempt to find "main.ml"
  # 0.01 locate - result
  found: $TESTCASE_ROOT/main.ml
  {
    "class": "return",
    "value": {
      "file": "$TESTCASE_ROOT/main.ml",
      "pos": {
        "line": 1,
        "col": 31
      }
    },
    "notifications": []
  }
