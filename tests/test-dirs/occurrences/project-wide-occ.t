  $ echo "(lang dune 2.0)" >dune-project

  $ cat >main.ml <<EOF
  > let x = 3 + Foo.f 3
  > let y = x
  > let r = { Foo.label_rouge = 4 }
  > let () = print_int r.label_rouge
  > module M = Map.Make(Foo.Bar)
  > type r2 = Foo.r
  > EOF

  $ cat>dune <<EOF
  > (executable (name main) (libraries foo))
  > EOF

  $ mkdir lib

  $ cat >lib/foo.ml <<EOF
  > let f x = x
  > let y = f 3
  > type r = { label_rouge : int }
  > module Bar = String
  > module Bartender = Bar
  > EOF

  $ cat>lib/dune <<EOF
  > (library (name foo))
  > EOF

  $ dune build @uideps 
$ ocamlc -c -bin-annot foo.mli foo.ml main.ml
$ ocaml-uideps process-cmt main.cmt foo.cmt foo.cmti -o project.uideps
$ ocaml-uideps dump project.uideps 

> main.ml
> let x = 3 + Foo.|f 3
  $ $MERLIN single occurrences -identifier-at 1:16 \
  > -filename main.ml <main.ml | jq '.value'
  Found uid: Foo.0 (Foo!.f)
  BUILD DIR: $TESTCASE_ROOT/_build/default
  Loading uideps from "$TESTCASE_ROOT/_build/default/project" 
  Found locs:
  pos_fname: lib/foo.ml; cmpunit: Main; unitname: Lib/foo;
   dir: $TESTCASE_ROOT
  canonical pos_fname: $TESTCASE_ROOT/lib/foo.ml
  pos_fname: main.ml; cmpunit: Main; unitname: Main;
   dir: $TESTCASE_ROOT
  canonical pos_fname: $TESTCASE_ROOT/main.ml
  pos_fname: lib/foo.ml; cmpunit: Main; unitname: Lib/foo;
   dir: $TESTCASE_ROOT
  canonical pos_fname: $TESTCASE_ROOT/lib/foo.ml
  pos_fname: main.ml; cmpunit: Main; unitname: Main;
   dir: $TESTCASE_ROOT
  canonical pos_fname: $TESTCASE_ROOT/main.ml
  [
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 5
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 12
      },
      "end": {
        "line": 1,
        "col": 17
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 2,
        "col": 8
      },
      "end": {
        "line": 2,
        "col": 9
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 12
      },
      "end": {
        "line": 1,
        "col": 17
      }
    }
  ]

> let |f x = x
  $ $MERLIN single occurrences -identifier-at 1:4 \
  > -filename lib/foo.ml <lib/foo.ml  | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 1,
        "col": 4
      },
      "end": {
        "line": 1,
        "col": 5
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 2,
        "col": 8
      },
      "end": {
        "line": 2,
        "col": 9
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 1,
        "col": 12
      },
      "end": {
        "line": 1,
        "col": 17
      }
    }
  ]

> let f |x = x
  $ $MERLIN single occurrences -identifier-at 1:6 \
  > -filename lib/foo.ml <lib/foo.ml | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/foo.ml",
      "start": {
        "line": 1,
        "col": 6
      },
      "end": {
        "line": 1,
        "col": 7
      }
    },
    {
      "file": "$TESTCASE_ROOT/foo.ml",
      "start": {
        "line": 1,
        "col": 10
      },
      "end": {
        "line": 1,
        "col": 11
      }
    }
  ]
  $ $MERLIN single occurrences -identifier-at 4:15 \
  > -filename main.ml <main.ml | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 4,
        "col": 9
      },
      "end": {
        "line": 4,
        "col": 18
      }
    }
  ]

> let () = print_int r.labe|l_rouge
FIXME this is not locating occurrences ot the label
> -log-file - -log-section locate \
  $ $MERLIN single occurrences -identifier-at 4:25 \
  > -filename main.ml <main.ml | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 3,
        "col": 0
      },
      "end": {
        "line": 3,
        "col": 30
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 6,
        "col": 10
      },
      "end": {
        "line": 6,
        "col": 15
      }
    }
  ]

> type |r = { label_rouge : int }
  $ $MERLIN single occurrences -identifier-at 3:5 \
  > -filename lib/foo.ml <lib/foo.ml| jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 3,
        "col": 0
      },
      "end": {
        "line": 3,
        "col": 30
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 6,
        "col": 10
      },
      "end": {
        "line": 6,
        "col": 15
      }
    }
  ]


> module |Bar = String
FIXME : missing main occurrences since the alias is traversed
  $ $MERLIN single occurrences -identifier-at 4:8 \
  > -log-file - -log-section locate \
  > -filename lib/foo.ml <lib/foo.ml| jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 4,
        "col": 0
      },
      "end": {
        "line": 4,
        "col": 19
      }
    },
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 5,
        "col": 19
      },
      "end": {
        "line": 5,
        "col": 22
      }
    }
  ]

  $ $MERLIN single occurrences -identifier-at 5:20 \
  > -log-file - -log-section locate \
  > -filename lib/foo.ml <lib/foo.ml| jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/foo.ml",
      "start": {
        "line": 4,
        "col": 13
      },
      "end": {
        "line": 4,
        "col": 19
      }
    },
    {
      "file": "$TESTCASE_ROOT/foo.ml",
      "start": {
        "line": 5,
        "col": 19
      },
      "end": {
        "line": 5,
        "col": 22
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 5,
        "col": 20
      },
      "end": {
        "line": 5,
        "col": 27
      }
    }
  ]


  $ $MERLIN single occurrences -identifier-at 5:24 \
  > -log-file - -log-section locate \
  > -filename main.ml <main.ml | jq '.value'
  [
    {
      "file": "$TESTCASE_ROOT/lib/foo.ml",
      "start": {
        "line": 4,
        "col": 13
      },
      "end": {
        "line": 4,
        "col": 19
      }
    },
    {
      "file": "$TESTCASE_ROOT/main.ml",
      "start": {
        "line": 5,
        "col": 20
      },
      "end": {
        "line": 5,
        "col": 27
      }
    }
  ]




  $ $MERLIN single dump -what typedtree \
  > -filename lib/foo.ml <lib/foo.ml
  {
    "class": "return",
    "value": "[
    structure_item (foo.ml[1,0+0]..foo.ml[1,0+11])
      Tstr_value Nonrec
      [
        <def>
          pattern (foo.ml[1,0+4]..foo.ml[1,0+5])
            Tpat_var \"f/273\"
          expression (foo.ml[1,0+6]..foo.ml[1,0+11]) ghost
            Texp_function
            Nolabel
            [
              <case>
                pattern (foo.ml[1,0+6]..foo.ml[1,0+7])
                  Tpat_var \"x/275\"
                expression (foo.ml[1,0+10]..foo.ml[1,0+11])
                  Texp_ident \"x/275\"
            ]
      ]
    structure_item (foo.ml[2,12+0]..foo.ml[2,12+11])
      Tstr_value Nonrec
      [
        <def>
          pattern (foo.ml[2,12+4]..foo.ml[2,12+5])
            Tpat_var \"y/276\"
          expression (foo.ml[2,12+8]..foo.ml[2,12+11])
            Texp_apply
            expression (foo.ml[2,12+8]..foo.ml[2,12+9])
              Texp_ident \"f/273\"
            [
              <arg>
                Nolabel
                expression (foo.ml[2,12+10]..foo.ml[2,12+11])
                  Texp_constant Const_int 3
            ]
      ]
    structure_item (foo.ml[3,24+0]..foo.ml[3,24+30])
      Tstr_type Rec
      [
        type_declaration r/277 (foo.ml[3,24+0]..foo.ml[3,24+30])
          ptype_params =
            []
          ptype_cstrs =
            []
          ptype_kind =
            Ttype_record
              [
                (foo.ml[3,24+11]..foo.ml[3,24+28])
                  Immutable
                  label_rouge/278                core_type (foo.ml[3,24+25]..foo.ml[3,24+28])
                    Ttyp_poly
                    core_type (foo.ml[3,24+25]..foo.ml[3,24+28])
                      Ttyp_constr \"int/1!\"
                      []
              ]
          ptype_private = Public
          ptype_manifest =
            None
      ]
    structure_item (foo.ml[4,55+0]..foo.ml[4,55+19])
      Tstr_module
      Bar/279
        module_expr (foo.ml[4,55+13]..foo.ml[4,55+19])
          Tmod_ident \"Stdlib!.String\"
    structure_item (foo.ml[5,75+0]..foo.ml[5,75+22])
      Tstr_module
      Bartender/280
        module_expr (foo.ml[5,75+19]..foo.ml[5,75+22])
          Tmod_ident \"Bar/279\"
  ]
  
  
  ",
    "notifications": []
  }
