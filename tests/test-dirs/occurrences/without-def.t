Sometimes it's not possible to get the definition of an ident, we still want to
display local occurrences based on the declarations uid for that.

  $ cat >local.ml <<'EOF'
  > let _x : bool = Filename.is_relative "/" 
  > let _y : bool = Filename.is_relative "/" 
  > let _z : string = Filename.basename "/" 
  > EOF

FIXME: there are two occurrences of Filename.is_relative
  $ $MERLIN single occurrences -identifier-at 1:30 \
  > -filename local.ml <local.ml | jq '.value'
  []