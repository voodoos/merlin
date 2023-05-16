The issue appears when `Papplying` a functor from another compilation unit.

  $ cat >fun.ml <<EOF
  > module Make (Config : sig val version : int end) = struct
  >   type t = int
  > end
  > EOF

  $  cat >main.ml <<EOF
  > let _ = int_of_string "42"
  > 
  > module C = struct let version = 1 end
  > type t = Fun.Make(C).t
  > EOF

  $ $OCAMLC -c fun.ml main.ml

  $ $MERLIN server stop-server
  $ $MERLIN server errors \
  > -log-file - -log-section DBG \
  > -filename main.ml <main.ml
  # 0.01 DBG - levels
  Current level: 0
  # 0.01 DBG - stats
  DBG Stats: persistent_env size: 53267
  
  # 0.01 DBG - levels
  Current level: 2
  {
    "class": "return",
    "value": [],
    "notifications": []
  }

  $ sed -i.bak 's/42/43/' main.ml

  $ $MERLIN server errors \
  > -log-file - -log-section DBG \
  > -filename main.ml <main.ml
  # 0.01 DBG - levels
  Current level: 2
  # 0.01 DBG - stats
  DBG Stats: persistent_env size: 53384
  
  # 0.01 DBG - levels
  Current level: 4
  {
    "class": "return",
    "value": [],
    "notifications": []
  }

  $ sed -i.bak 's/43/44/' main.ml

  $ $MERLIN server errors \
  > -log-file - -log-section DBG \
  > -filename main.ml <main.ml
  # 0.01 DBG - levels
  Current level: 4
  # 0.01 DBG - stats
  DBG Stats: persistent_env size: 53501
  
  # 0.01 DBG - levels
  Current level: 6
  {
    "class": "return",
    "value": [],
    "notifications": []
  }


  $ sed -i.bak 's/44/45/' main.ml

  $ $MERLIN server errors \
  > -log-file - -log-section DBG \
  > -filename main.ml <main.ml
  # 0.01 DBG - levels
  Current level: 6
  # 0.02 DBG - stats
  DBG Stats: persistent_env size: 53618
  
  # 0.02 DBG - levels
  Current level: 8
  {
    "class": "return",
    "value": [],
    "notifications": []
  }

  $ $MERLIN server stop-server
