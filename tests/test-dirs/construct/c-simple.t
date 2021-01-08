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

  $ $MERLIN single construct -position 5:22 -filename c1.ml <c1.ml
  {
    "class": "return",
    "value": [
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
        "nice_candidate_with_arg _",
        "Some _",
        "nice_candidate_with_labeled_arg ~x:_",
        "None",
        "nice_candidate ",
        "Some (y )"
      ]
    ],
    "notifications": []
  }

Test 1.2

$ cat >c2.ml <<EOF
> let x : int option =
> EOF

$ $MERLIN single construct -position 1:22 -filename c2.ml <c2.ml

Test lazy : FIXME

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
      []
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
        "nice_candidate ",
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
        "nice_candidate ",
        "fun _ -> _",
        "fun _ -> nice_candidate _"
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
        "nicer_candidate ",
        "fun ~v -> _",
        "fun ~v -> nicer_candidate ~v:_",
        "fun ~v -> nice_candidate _"
      ]
    ],
    "notifications": []
  }
