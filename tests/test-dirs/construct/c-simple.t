###############
## SUM TYPES ##
###############

Test 1.1 :

  $ cat >c1.ml <<EOF
  > let nice_candidate = Some 3
  > let x : int option = _
  > EOF

$ $MERLIN single construct -position 2:2 -filename c1.ml <c1.ml

  $ $MERLIN single construct -position 2:22 -filename c1.ml -log-file - <c1.ml

Test 1.2

$ cat >c2.ml <<EOF
> let x : int option =
> EOF

$ $MERLIN single construct -position 1:22 -filename c2.ml <c2.ml
