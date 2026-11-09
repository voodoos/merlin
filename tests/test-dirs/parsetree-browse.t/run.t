The `parsetree-browse` dump exposes the tree built by `Mbrowse_parsetree`, the
counterpart of `Mbrowse` for the untyped AST. The JSON has the same shape as
`dump -what browse`; the jq scripts below render it as an indented outline.

Nested expressions. Note that `let f x y = ...` is a single, ghost, function
expression with two parameters (unlike the typed tree, where each parameter
gives a nested function); the `open` item of `M.(...)` has no location in the
parsetree and is approximated from its children; the payload of `[%ext ...]`
appears as a structure child of the extension node; case nodes have no
location either and get the union of their children.

  $ $MERLIN single dump -what parsetree-browse -filename nested.ml < nested.ml \
  > | jq -r -f tree.jq
  structure 1:0-4:24
    structure_item 1:0-4:24
      value_binding 1:0-4:24
        pattern 1:4-1:5
        expression 1:6-4:24 (ghost)
          pattern 1:6-1:7
          pattern 1:8-1:9
          expression 2:2-4:24
            expression 2:8-2:9
            case 3:4-3:34
              pattern 3:4-3:10
                pattern 3:9-3:10
              expression 3:16-3:21 [merlin.loc]
                expression 3:16-3:17
                expression 3:18-3:19
                expression 3:20-3:21
              expression 3:25-3:34 [merlin.loc]
                structure_item 3:25-3:26
                  open_declaration 3:25-3:26
                    module_expr 3:25-3:26
                expression 3:28-3:33
                  expression 3:28-3:29
                  expression 3:30-3:31
                  expression 3:32-3:33
            case 4:4-4:24
              pattern 4:4-4:8
              expression 4:12-4:24 [merlin.loc]
                structure 4:18-4:23
                  structure_item 4:18-4:23
                    expression 4:18-4:23
                      expression 4:18-4:19
                      expression 4:20-4:21
                      expression 4:22-4:23

With a position, the dump prints the `enclosing` and `deepest_before` paths
(leaf first). Inside `1` in `z + 1`:

  $ $MERLIN single dump -what parsetree-browse -position 3:32 -filename nested.ml \
  > < nested.ml | jq -r -f path.jq
  enclosing
    expression 3:32-3:33
    expression 3:28-3:33
    expression 3:25-3:34
    case 3:4-3:34
    expression 2:2-4:24
    expression 1:6-4:24 (ghost)
    value_binding 1:0-4:24
    structure_item 1:0-4:24
    structure 1:0-4:24
  deepest_before
    expression 3:32-3:33
    expression 3:28-3:33
    expression 3:25-3:34
    case 3:4-3:34
    expression 2:2-4:24
    expression 1:6-4:24 (ghost)
    value_binding 1:0-4:24
    structure_item 1:0-4:24
    structure 1:0-4:24

Right after the guard `z > y`, on the space before `->`: `enclosing` stops at
the case, `deepest_before` selects `y`, the node just before the cursor.

  $ $MERLIN single dump -what parsetree-browse -position 3:22 -filename nested.ml \
  > < nested.ml | jq -r -f path.jq
  enclosing
    case 3:4-3:34
    expression 2:2-4:24
    expression 1:6-4:24 (ghost)
    value_binding 1:0-4:24
    structure_item 1:0-4:24
    structure 1:0-4:24
  deepest_before
    expression 3:20-3:21
    expression 3:16-3:21
    case 3:4-3:34
    expression 2:2-4:24
    expression 1:6-4:24 (ghost)
    value_binding 1:0-4:24
    structure_item 1:0-4:24
    structure 1:0-4:24

Let-punning: the pattern and the expression of `let+ x in` share the same
location under the binding operator (children are sorted by the dump). With
a position, the dump resolves such ties with the `prefer_expression`
tie-breaker:

  $ $MERLIN single dump -what parsetree-browse -filename punning.ml < punning.ml \
  > | jq -r -f tree.jq
  structure 1:0-4:3
    structure_item 1:0-1:22
      value_binding 1:0-1:22
        pattern 1:4-1:12
        expression 1:13-1:22 (ghost)
          pattern 1:13-1:14
          pattern 1:15-1:16
          expression 1:19-1:22
            expression 1:19-1:20
            expression 1:21-1:22
    structure_item 2:0-4:3
      value_binding 2:0-4:3
        pattern 2:4-2:5
        expression 2:6-4:3 (ghost)
          pattern 2:6-2:7
          expression 3:2-4:3
            binding_op 3:2-4:3
              expression 3:7-3:8
              pattern 3:7-3:8
            expression 4:2-4:3

  $ $MERLIN single dump -what parsetree-browse -position 3:8 -filename punning.ml \
  > < punning.ml | jq -r -f path.jq
  enclosing
    expression 3:7-3:8
    binding_op 3:2-4:3
    expression 3:2-4:3
    expression 2:6-4:3 (ghost)
    value_binding 2:0-4:3
    structure_item 2:0-4:3
    structure 1:0-4:3
  deepest_before
    expression 3:7-3:8
    binding_op 3:2-4:3
    expression 3:2-4:3
    expression 2:6-4:3 (ghost)
    value_binding 2:0-4:3
    structure_item 2:0-4:3
    structure 1:0-4:3

Type declarations, polymorphic variants, object types and classes. Nodes
without a location and without children (the abstract `type_kind` of a type
with a manifest) get an empty location:

  $ $MERLIN single dump -what parsetree-browse -filename types.ml < types.ml \
  > | jq -r -f tree.jq
  structure 1:0-7:3
    structure_item 1:0-1:36
      type_declaration 1:0-1:36
        type_kind 1:9-1:36
          constructor_declaration 1:9-1:17
            core_type 1:14-1:17
          constructor_declaration 1:18-1:36
            label_declaration 1:27-1:34
              core_type 1:31-1:34
    structure_item 2:0-2:27
      type_declaration 2:0-2:27
        type_kind 0:-1-0:-1 (ghost)
        core_type 2:9-2:27
          row_field 2:11-2:13
          row_field 2:16-2:25
            core_type 2:22-2:25
    structure_item 3:0-3:32
      type_declaration 3:0-3:32
        type_kind 0:-1-0:-1 (ghost)
        core_type 3:9-3:32
          object_field 3:11-3:19
            core_type 3:15-3:18
          object_field 3:20-3:30
            core_type 3:24-3:30
    structure_item 4:0-7:3
      class_declaration 4:0-7:3
        class_expr 4:10-7:3
          class_structure 4:16-6:14
            pattern 4:16-4:16 (ghost)
            class_field 5:2-5:11
              expression 5:10-5:11
            class_field 6:2-6:14
              expression 6:13-6:14 (ghost)
                expression 6:13-6:14

Interfaces:

  $ $MERLIN single dump -what parsetree-browse -filename iface.mli < iface.mli \
  > | jq -r -f tree.jq
  signature 1:0-7:23
    signature_item 1:0-1:18
      value_description 1:0-1:18
        core_type 1:8-1:18
          core_type 1:8-1:11
          core_type 1:15-1:18
    signature_item 2:0-2:21
      type_declaration 2:0-2:21
        type_kind 2:9-2:21
          constructor_declaration 2:9-2:17
            core_type 2:14-2:17
          constructor_declaration 2:18-2:21
    signature_item 3:0-5:3
      module_declaration 3:0-5:3
        module_type 3:11-5:3
          signature 4:2-4:8
            signature_item 4:2-4:8
              type_declaration 4:2-4:8
                type_kind 0:-1-0:-1 (ghost)
    signature_item 6:0-6:8
      open_description 6:0-6:8
    signature_item 7:0-7:23
      module_type_declaration 7:0-7:23
        module_type 7:16-7:23
          signature 0:-1-0:-1 (ghost)

Attributes are never traversed, extension payloads are:

  $ $MERLIN single dump -what parsetree-browse -filename attrs.ml < attrs.ml \
  > | jq -r -f tree.jq
  structure 1:0-4:13
    structure_item 1:0-1:18 [warning _]
    structure_item 2:0-2:24
      value_binding 2:0-2:24 [attr _]
        pattern 2:4-2:5
        expression 2:8-2:9
    structure_item 3:0-3:17
      structure 3:7-3:16
        structure_item 3:7-3:16
          value_binding 3:7-3:16
            pattern 3:11-3:12
            expression 3:15-3:16
    structure_item 4:0-4:13
      value_binding 4:0-4:13
        pattern 4:4-4:5
        expression 4:8-4:13
          structure_item 4:8-4:9
            open_declaration 4:8-4:9
              module_expr 4:8-4:9
          expression 4:11-4:12

The tree is available even when the file does not parse, thanks to the
parser's recovery:

  $ $MERLIN single dump -what parsetree-browse -filename broken.ml < broken.ml \
  > | jq -r -f tree.jq
  structure 1:0-3:3
    structure_item 1:0-3:3
      value_binding 1:0-3:3
        pattern 1:4-1:5
        expression 1:6-3:3 (ghost)
          pattern 1:6-1:7
          expression 2:2-3:3
            value_binding 2:2-3:3
              pattern 2:6-2:7
              expression 2:10-3:3
                expression 2:10-2:11
                expression 2:12-2:13
                expression 3:2-3:3
            expression 3:3-3:3 (ghost) [merlin.loc]
              structure 0:-1-0:-1 (ghost)
