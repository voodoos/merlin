(enabled_if (and (< %{ocaml_version} 4.08.0) (>= %{ocaml_version} 4.06.0)))

Get type of a shadowing let binding:

  $ $MERLIN single type-enclosing -position 4:4 -verbosity 0 \
  > -log-file log -log-section type-enclosing -filename ./let.ml < ./let.ml | jq ".value[0:2]"
  [
    {
      "start": {
        "line": 4,
        "col": 4
      },
      "end": {
        "line": 4,
        "col": 7
      },
      "type": "int",
      "tail": "no"
    },
    {
      "start": {
        "line": 4,
        "col": 4
      },
      "end": {
        "line": 4,
        "col": 34
      },
      "type": "float",
      "tail": "no"
    }
  ]

  $ cat log
  # 0.01 type-enclosing - from_nodes
  unhandled node under cursor: value_binding
  # 0.01 type-enclosing - from_nodes
  unhandled node under cursor: structure_item
  # 0.01 type-enclosing - from_nodes
  unhandled node under cursor: structure
  # 0.01 type-enclosing - reconstruct identifier
  [
    {
      "start": { "line": 4, "col": 4 },
      "end": { "line": 4, "col": 7 },
      "identifier": "def"
    }
  ]
  # 0.01 type-enclosing - node_at
  mbrowse = [ core_type; core_type; pattern (let.ml[4,14+4]..let.ml[4,14+7])
    Tpat_constraint
    core_type (let.ml[4,14+4]..let.ml[4,14+34]) ghost
      Ttyp_poly
      core_type (let.ml[4,14+10]..let.ml[4,14+15])
        Ttyp_constr "float/4"
        []
    pattern (let.ml[4,14+4]..let.ml[4,14+7])
      Tpat_var "def/1003"
  ; value_binding; structure_item; structure ]
  # 0.01 type-enclosing - leaf_node
  node = core_type
  # 0.01 type-enclosing - from_reconstructed
  node = core_type
  # 0.01 type-enclosing - from_reconstructed
  typed def
  # 0.01 type-enclosing - small enclosing
  result = [ File "let.ml", line 4, characters 4-7 ]
