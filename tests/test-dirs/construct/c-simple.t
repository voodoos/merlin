###############
## SUM TYPES ##
###############

Test 1.1 :

  $ cat >c1.ml <<EOF
  > let x : int option = _

  $ $MERLIN single construct -position 1:22 -filename c1.ml <c1.ml
