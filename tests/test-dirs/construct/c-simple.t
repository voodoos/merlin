###############
## SUM TYPES ##
###############

Test 1.1 :

  $ cat >c1.ml <<EOF
  > let nice_candidate = Some 3
  > let nice_candidate_with_arg x = Some x
  > let nice_candidate_with_labeled_arg ~x = Some x
  > let y = 4
  > let x : int option = _
  > EOF

  $ $MERLIN single construct -position 5:22 -filename c1.ml <c1.ml |
  >  jq ".value"
  [
    {
      "start": {
        "line": 5,
        "col": 21
      },
      "end": {
        "line": 5,
        "col": 22
      }
    },
    [
      "Some _",
      "None"
    ]
  ]

With depth 2:

  $ $MERLIN single construct -max-depth 2 -position 5:22 -filename c1.ml <c1.ml |
  >  jq ".value"
  [
    {
      "start": {
        "line": 5,
        "col": 21
      },
      "end": {
        "line": 5,
        "col": 22
      }
    },
    [
      "Some _",
      "None",
      "Some 0"
    ]
  ]

With values:

  $ $MERLIN single construct -with-values local -position 5:22 -filename c1.ml <c1.ml |
  >  jq ".value"
  [
    {
      "start": {
        "line": 5,
        "col": 21
      },
      "end": {
        "line": 5,
        "col": 22
      }
    },
    [
      "Some _",
      "None",
      "nice_candidate_with_arg _",
      "nice_candidate_with_labeled_arg ~x:_",
      "nice_candidate "
    ]
  ]

With depth 2 and values:

  $ $MERLIN single construct -max-depth 2 -with-values local -position 5:22 -filename c1.ml <c1.ml |
  >  jq ".value"
  [
    {
      "start": {
        "line": 5,
        "col": 21
      },
      "end": {
        "line": 5,
        "col": 22
      }
    },
    [
      "Some _",
      "None",
      "Some 0",
      "Some (y )",
      "nice_candidate_with_arg _",
      "nice_candidate_with_labeled_arg ~x:_",
      "nice_candidate "
    ]
  ]

Test 1.2

  $ cat >c2.ml <<EOF
  > let x : int list = _
  > EOF

  $ $MERLIN single construct -position 1:20 -filename c2.ml <c2.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 1,
          "col": 19
        },
        "end": {
          "line": 1,
          "col": 20
        }
      },
      [
        "_ :: _",
        "[]"
      ]
    ],
    "notifications": []
  }

Test 1.3

  $ cat >c3.ml <<EOF
  > let x : 'a list = _
  > EOF

  $ $MERLIN single construct -position 1:19 -filename c3.ml <c3.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 1,
          "col": 18
        },
        "end": {
          "line": 1,
          "col": 19
        }
      },
      [
        "_ :: _",
        "[]"
      ]
    ],
    "notifications": []
  }


Test lazy

  $ cat >lazy.ml <<EOF
  > let x : int lazy = _
  > EOF

  $ $MERLIN single construct -position 1:20 -filename lazy.ml <lazy.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 1,
          "col": 19
        },
        "end": {
          "line": 1,
          "col": 20
        }
      },
      [
        "lazy _"
      ]
    ],
    "notifications": []
  }

#############
## RECORDS ##
#############

Test 2.1

  $ cat >c2.ml <<EOF
  > type r = { a : string; b : int option }
  > let nice_candidate = {a = "a"; b = None }
  > let x : r = _
  > EOF

  $ $MERLIN single construct -position 3:13 -filename c2.ml <c2.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 3,
          "col": 12
        },
        "end": {
          "line": 3,
          "col": 13
        }
      },
      [
        "{ a = _; b = _ }"
      ]
    ],
    "notifications": []
  }

#################
## ARROW TYPES ##
#################

Test 3.1

  $ cat >c31.ml <<EOF
  > let nice_candidate s = int_of_string s
  > let x : string -> int = _
  > EOF

  $ $MERLIN single construct -position 2:25 -filename c31.ml <c31.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 2,
          "col": 24
        },
        "end": {
          "line": 2,
          "col": 25
        }
      },
      [
        "fun _ -> _"
      ]
    ],
    "notifications": []
  }

Test 3.2

  $ cat >c32.ml <<EOF
  > let nice_candidate s = int_of_string s
  > let nicer_candidate ~v:s = int_of_string s
  > let x : v:string -> int = _
  > EOF

  $ $MERLIN single construct -position 3:25 -filename c32.ml <c32.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 3,
          "col": 26
        },
        "end": {
          "line": 3,
          "col": 27
        }
      },
      [
        "fun ~v -> _"
      ]
    ],
    "notifications": []
  }

############
## TUPLES ##
############

Test 4.1

  $ cat >c41.ml <<EOF
  > type tup = int * float * (string option)
  > let some_float = 4.2
  > let x : tup = _
  > EOF

  $ $MERLIN single construct -position 3:14 -filename c41.ml <c41.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 3,
          "col": 14
        },
        "end": {
          "line": 3,
          "col": 15
        }
      },
      [
        "(_, _, _)"
      ]
    ],
    "notifications": []
  }

####################
## POLY. VARIANTS ##
####################

TODO we need more tests here

Test 5.1

  $ cat >c51.ml <<EOF
  > type v = [ \`A | \`B of string ]
  > let some_v = \`B "totoro"
  > let x : v = _
  > EOF

  $ $MERLIN single construct -position 3:13 -filename c51.ml <c51.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 3,
          "col": 12
        },
        "end": {
          "line": 3,
          "col": 13
        }
      },
      [
        "`B _",
        "`A"
      ]
    ],
    "notifications": []
  }

###################
## MISCELLANEOUS ##
###################

Test M.1 : Type vars

  $ cat >cM1.ml <<EOF
  > type 'a t = A of 'a
  > let x = A _
  > EOF

  $ $MERLIN single construct -position 2:11 -filename cM1.ml <cM1.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 2,
          "col": 10
        },
        "end": {
          "line": 2,
          "col": 11
        }
      },
      []
    ],
    "notifications": []
  }

Test M.2 : FIXME wrong position

  $ cat >M2.ml <<EOF
  > let x : type a . a list = _
  > EOF

  $ $MERLIN single construct -position 1:26 -filename M2.ml <M2.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 1,
          "col": 4
        },
        "end": {
          "line": 1,
          "col": 27
        }
      },
      [
        "_ :: _",
        "[]"
      ]
    ],
    "notifications": []
  }

Test M.3 : Basic types

  $ cat >M3.ml <<EOF
  > let x : int = _
  > EOF

  $ $MERLIN single construct -position 1:14 -filename M3.ml <M3.ml
  {
    "class": "return",
    "value": [
      {
        "start": {
          "line": 1,
          "col": 14
        },
        "end": {
          "line": 1,
          "col": 15
        }
      },
      [
        "0"
      ]
    ],
    "notifications": []
  }
