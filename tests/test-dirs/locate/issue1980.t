  $ cat >test.ml <<'EOF'
  > module rec M : sig
  >   val f : unit -> unit
  > end = struct
  >   let f () = ()
  > end
  > 
  > and N : sig
  >   val foo : unit -> unit
  > end = struct
  >   let foo () = M.f ()
  > end
  > 
  > let foo () = M.f ()
  > EOF

FIXME: should jump to the definition of line 4 not the declaration
  $ $MERLIN single locate -position 10:18 -look-for implementation -filename test.ml <test.ml | jq .value
  {
    "file": "$TESTCASE_ROOT/test.ml",
    "pos": {
      "line": 2,
      "col": 6
    }
  }

  $ $MERLIN single locate -position 13:16 -look-for implementation -filename test.ml <test.ml | jq .value
  {
    "file": "$TESTCASE_ROOT/test.ml",
    "pos": {
      "line": 4,
      "col": 6
    }
  }
