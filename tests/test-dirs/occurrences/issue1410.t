FIXME: No result is returned, we could expect the one occurrence of None.
  $ $MERLIN single occurrences -identifier-at 3:3 -filename opt.ml <<EOF | \
  > jq '.value'
  > (* test case *)
  > let f ?(x=1) () = 2 ;;
  > None
  > EOF
  []

  $ $MERLIN single occurrences -identifier-at 3:3 -filename opt.ml <<EOF | \
  > jq '.value'
  > (* test case *)
  > let f () = 2 ;;
  > None
  > EOF
  []
