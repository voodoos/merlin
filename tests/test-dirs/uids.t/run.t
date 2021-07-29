  $ $MERLIN single dump -what typedtree -filename ex1.ml < ex1.ml |
  > grep '==>'
  
  Paired: val x : int ==>{ Ex1.5 }<==
     with val x : int ==>{ Ex1.0 }<==
  
  Paired: type t ==>{ Ex1.8 }<==
     with type t ==>{ Ex1.2 }<==
  Paired: val y : float ==>{ Ex1.9 }<==
     with val y : float ==>{ Ex1.3 }<==
  Paired: val x : int ==>{ Ex1.0 }<==
     with val x : int ==>{ Ex1.0 }<==
  
  Paired: val x : int ==>{ Ex1.0 }<==
     with val x : int ==>{ Ex1.0 }<==
  
  Paired: type t ==>{ Ex1.12 }<==
     with type t ==>{ Ex1.2 }<==
  Paired: val y : float ==>{ Ex1.13 }<==
     with val y : float ==>{ Ex1.3 }<==
              value_description x/81 (ex1.ml[2,28+2]..ex1.ml[2,28+21]) ==>{ Ex1.0 }<==
                  Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
                type_declaration t/83 ==>{ Ex1.2 }<== (ex1.ml[6,102+2]..ex1.ml[6,102+8])
              value_description y/84 (ex1.ml[7,119+2]..ex1.ml[7,119+22]) ==>{ Ex1.3 }<==
                  Ttyp_constr \"float/4!\" ==>{ <predef:float> }<==
      M/87 ==>{ Ex1.6 }<==
                      Tpat_var \"x/86\" ==>{ Ex1.5 }<==
      F/95 ==>{ Ex1.10 }<==
                    type_declaration t/89 ==>{ Ex1.8 }<== (ex1.ml[28,420+4]..ex1.ml[28,420+10])
                    Tmod_ident \"X/88\" ==>{ Ex1.7 }<==
                        Tpat_var \"y/91\" ==>{ Ex1.9 }<==
      A/99 ==>{ Ex1.11 }<==
            Tmod_ident \"F/95\" ==>{ Ex1.10 }<==
            Tmod_ident \"M/87\" ==>{ Ex1.6 }<==
      B/102 ==>{ Ex1.14 }<==
                  type_declaration t/100 ==>{ Ex1.12 }<== (ex1.ml[56,879+2]..ex1.ml[56,879+8])
                      Tpat_var \"y/101\" ==>{ Ex1.13 }<==
            Tpat_var \"y/103\" ==>{ Ex1.15 }<==
            Texp_ident \"A/99.x\" ==>{ Ex1.0 }<==
            Tpat_var \"z/104\" ==>{ Ex1.16 }<==
            Texp_ident \"A/99.y\" ==>{ Ex1.3 }<==

  $ $MERLIN single dump -what typedtree -filename ex_pair.ml < ex_pair.ml |
  > grep '==>'
  
  Paired: type t = int ==>{ Ex_pair.10 }<==
     with type t ==>{ Ex_pair.0 }<==
  Paired: val to_string : int -> string ==>{ Ex_pair.11 }<==
     with val to_string : t -> string ==>{ Ex_pair.1 }<==
  
  Paired: type t = string ==>{ Ex_pair.14 }<==
     with type t ==>{ Ex_pair.0 }<==
  Paired: val to_string : 'a -> 'a ==>{ Ex_pair.15 }<==
     with val to_string : t -> string ==>{ Ex_pair.1 }<==
  
  Paired: type t = Int.t ==>{ Ex_pair.0 }<==
     with type t ==>{ Ex_pair.0 }<==
  Paired: val to_string : t -> string ==>{ Ex_pair.1 }<==
     with val to_string : t -> string ==>{ Ex_pair.1 }<==
  
  Paired: type t = String.t * Int.t ==>{ Ex_pair.5 }<==
     with type t ==>{ Ex_pair.0 }<==
  Paired: val to_string : String.t * Int.t -> string ==>{ Ex_pair.6 }<==
     with val to_string : t -> string ==>{ Ex_pair.1 }<==
  
  Paired: type t = Int.t ==>{ Ex_pair.0 }<==
     with type t ==>{ Ex_pair.0 }<==
  Paired: val to_string : t -> string ==>{ Ex_pair.1 }<==
     with val to_string : t -> string ==>{ Ex_pair.1 }<==
                type_declaration t/81 ==>{ Ex_pair.0 }<== (ex_pair.ml[2,35+2]..ex_pair.ml[2,35+8])
              value_description to_string/82 (ex_pair.ml[4,51+2]..ex_pair.ml[4,51+35]) ==>{ Ex_pair.1 }<==
                    Ttyp_constr \"t/81\" ==>{ Ex_pair.0 }<==
                    Ttyp_constr \"string/15!\" ==>{ <predef:string> }<==
      Pair/92 ==>{ Ex_pair.9 }<==
                    type_declaration t/86 ==>{ Ex_pair.5 }<== (ex_pair.ml[10,181+2]..ex_pair.ml[10,181+32])
                                Ttyp_constr \"X/84.t\" ==>{ Ex_pair.0 }<==
                                Ttyp_constr \"Y/85.t\" ==>{ Ex_pair.0 }<==
                        Tpat_var \"to_string/87\" ==>{ Ex_pair.6 }<==
                                Texp_ident \"Stdlib!.^\" ==>{ Stdlib.112 }<==
                                      Texp_ident \"X/84.to_string\" ==>{ Ex_pair.1 }<==
                                          Texp_ident \"x/89\" ==>{ Ex_pair.7 }<==
                                      Texp_ident \"Stdlib!.^\" ==>{ Stdlib.112 }<==
                                            Texp_ident \"Y/85.to_string\" ==>{ Ex_pair.1 }<==
                                                Texp_ident \"y/90\" ==>{ Ex_pair.8 }<==
      Int/97 ==>{ Ex_pair.13 }<==
                  type_declaration t/93 ==>{ Ex_pair.10 }<== (ex_pair.ml[29,573+2]..ex_pair.ml[29,573+21])
                          Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
                      Tpat_var \"to_string/94\" ==>{ Ex_pair.11 }<==
                              Texp_ident \"Stdlib!.string_of_int\" ==>{ Stdlib.119 }<==
                                  Texp_ident \"i/96\" ==>{ Ex_pair.12 }<==
      String/102 ==>{ Ex_pair.17 }<==
                type_declaration t/98 ==>{ Ex_pair.14 }<== (ex_pair.ml[45,816+2]..ex_pair.ml[45,816+24])
                        Ttyp_constr \"string/15!\" ==>{ <predef:string> }<==
                    Tpat_var \"to_string/99\" ==>{ Ex_pair.15 }<==
                          Texp_ident \"s/101\" ==>{ Ex_pair.16 }<==
      P/113 ==>{ Ex_pair.18 }<==
              Tmod_ident \"Pair/92\" ==>{ Ex_pair.9 }<==
              Tmod_ident \"Int/97\" ==>{ Ex_pair.13 }<==
                  Tmod_ident \"Pair/92\" ==>{ Ex_pair.9 }<==
                  Tmod_ident \"String/102\" ==>{ Ex_pair.17 }<==
                Tmod_ident \"Int/97\" ==>{ Ex_pair.13 }<==
            Texp_ident \"P/113.to_string\" ==>{ Ex_pair.6 }<==

  $ $MERLIN single dump -what typedtree \
  > -filename ex_compressed.ml < ex_compressed.ml |
  > grep '==>'
  
  Paired: val x : int ==>{ Ex_compressed.0 }<==
     with val x : int ==>{ Ex_compressed.1 }<==
  
  Paired: module N : sig val x : int end ==>{ Ex_compressed.2 }<==
     with module N : sig val x : int end ==>{ Ex_compressed.4 }<==
  
  Paired: val x : int ==>{ Ex_compressed.1 }<==
     with val x : int ==>{ Ex_compressed.3 }<==
      M/86 ==>{ Ex_compressed.5 }<==
                N/83 ==>{ Ex_compressed.2 }<==
                                Tpat_var \"x/81\" ==>{ Ex_compressed.0 }<==
                          value_description x/82 (ex_compressed.ml[7,115+4]..ex_compressed.ml[7,115+23]) ==>{ Ex_compressed.1 }<==
                              Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
                Tsig_module \"N/85\" ==>{ Ex_compressed.4 }<==
                      value_description x/84 (ex_compressed.ml[3,48+4]..ex_compressed.ml[3,48+23]) ==>{ Ex_compressed.3 }<==
                          Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
            Texp_ident \"M/86.N.x\" ==>{ Ex_compressed.3 }<==

  $ $OCAMLC -bin-annot an_external_module.ml 
  $ $MERLIN single dump -what typedtree \
  > -filename ex_compressed_with_hole.ml < ex_compressed_with_hole.ml |
  > grep '==>'
  
  Paired: val x : int ==>{ An_external_module.0 }<==
     with val x : int ==>{ Ex_compressed_with_hole.0 }<==
  
  Paired: module N : sig val x : int end ==>{ Ex_compressed_with_hole.1 }<==
     with module N : sig val x : int end ==>{ Ex_compressed_with_hole.3 }<==
  
  Paired: val x : int ==>{ Ex_compressed_with_hole.0 }<==
     with val x : int ==>{ Ex_compressed_with_hole.2 }<==
      M/87 ==>{ Ex_compressed_with_hole.4 }<==
                N/84 ==>{ Ex_compressed_with_hole.1 }<==
                            Tmod_ident \"An_external_module!\" ==>{ An_external_module }<==
                          value_description x/83 (ex_compressed_with_hole.ml[7,115+4]..ex_compressed_with_hole.ml[7,115+23]) ==>{ Ex_compressed_with_hole.0 }<==
                              Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
                Tsig_module \"N/86\" ==>{ Ex_compressed_with_hole.3 }<==
                      value_description x/85 (ex_compressed_with_hole.ml[3,48+4]..ex_compressed_with_hole.ml[3,48+23]) ==>{ Ex_compressed_with_hole.2 }<==
                          Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
            Texp_ident \"M/87.N.x\" ==>{ Ex_compressed_with_hole.2 }<==
          Tmod_ident \"M/87.N\" ==>{ Ex_compressed_with_hole.3 }<==


  $ $MERLIN single dump -what typedtree \
  > -filename ex_functors.ml < ex_functors.ml |
  > grep '==>'
  
  Paired: type t = Int.t ==>{ Ex_functors.2 }<==
     with type t ==>{ Ex_functors.0 }<==
  
  Paired: type t = Int.t ==>{ Ex_functors.2 }<==
     with type t ==>{ Ex_functors.0 }<==
  
  Paired: type t = Int.t ==>{ Ex_functors.0 }<==
     with type t ==>{ Ex_functors.0 }<==
                type_declaration t/81 ==>{ Ex_functors.0 }<== (ex_functors.ml[2,26+6]..ex_functors.ml[2,26+12])
      Int/84 ==>{ Ex_functors.3 }<==
                type_declaration t/83 ==>{ Ex_functors.2 }<== (ex_functors.ml[5,74+9]..ex_functors.ml[5,74+15])
      Ie/86 ==>{ Ex_functors.5 }<==
            Tmod_ident \"X/85\" ==>{ Ex_functors.4 }<==
      IEI/88 ==>{ Ex_functors.6 }<==
            Tmod_ident \"Ie/86\" ==>{ Ex_functors.5 }<==
            Tmod_ident \"Int/84\" ==>{ Ex_functors.3 }<==
        type_declaration a/89 ==>{ Ex_functors.7 }<== (ex_functors.ml[12,194+0]..ex_functors.ml[12,194+14])
                Ttyp_constr \"IEI/88.t\" ==>{ Ex_functors.0 }<==
      IEIEI/92 ==>{ Ex_functors.8 }<==
            Tmod_ident \"Ie/86\" ==>{ Ex_functors.5 }<==
              Tmod_ident \"Ie/86\" ==>{ Ex_functors.5 }<==
              Tmod_ident \"Int/84\" ==>{ Ex_functors.3 }<==
        type_declaration b/93 ==>{ Ex_functors.9 }<== (ex_functors.ml[20,291+0]..ex_functors.ml[20,291+16])
                Ttyp_constr \"IEIEI/92.t\" ==>{ Ex_functors.0 }<==

  $ $MERLIN single dump -what typedtree \
  > -filename ex_abstract_type.ml < ex_abstract_type.ml |
  > grep '==>'
  
  Paired: type t = X.t ==>{ Ex_abstract_type.0 }<==
     with type t ==>{ Ex_abstract_type.0 }<==
  
  Paired: type t = int ==>{ Ex_abstract_type.2 }<==
     with type t ==>{ Ex_abstract_type.0 }<==
  
  Paired: type t = char ==>{ Ex_abstract_type.4 }<==
     with type t ==>{ Ex_abstract_type.0 }<==
                type_declaration t/81 ==>{ Ex_abstract_type.0 }<== (ex_abstract_type.ml[1,0+25]..ex_abstract_type.ml[1,0+31])
      Int/84 ==>{ Ex_abstract_type.3 }<==
                type_declaration t/83 ==>{ Ex_abstract_type.2 }<== (ex_abstract_type.ml[2,41+25]..ex_abstract_type.ml[2,41+42])
                        Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
      Char/86 ==>{ Ex_abstract_type.5 }<==
                type_declaration t/85 ==>{ Ex_abstract_type.4 }<== (ex_abstract_type.ml[3,88+26]..ex_abstract_type.ml[3,88+44])
                        Ttyp_constr \"char/2!\" ==>{ <predef:char> }<==
      Const/89 ==>{ Ex_abstract_type.8 }<==
                Tmod_ident \"X/87\" ==>{ Ex_abstract_type.6 }<==
      I2/93 ==>{ Ex_abstract_type.9 }<==
              Tmod_ident \"Const/89\" ==>{ Ex_abstract_type.8 }<==
              Tmod_ident \"Int/84\" ==>{ Ex_abstract_type.3 }<==
            Tmod_ident \"Char/86\" ==>{ Ex_abstract_type.5 }<==
        type_declaration a/94 ==>{ Ex_abstract_type.10 }<== (ex_abstract_type.ml[30,468+0]..ex_abstract_type.ml[30,468+13])
                Ttyp_constr \"I2/93.t\" ==>{ Ex_abstract_type.0 }<==

  $ $MERLIN single dump -what typedtree \
  > -filename ex_big_functor.ml < ex_big_functor.ml |
  > grep '==>'
  
  Paired: type t ==>{ Ex_big_functor.4 }<==
     with type t ==>{ Ex_big_functor.0 }<==
  Paired: val x : int ==>{ Ex_big_functor.5 }<==
     with val x : int ==>{ Ex_big_functor.2 }<==
  
  Paired: type t = X.t ==>{ Ex_big_functor.0 }<==
     with type t ==>{ Ex_big_functor.0 }<==
  Paired: module A : sig type t = Y.t val x : int end ==>{ Ex_big_functor.9 }<==
     with module A : S ==>{ Ex_big_functor.13 }<==
  Paired: module B = M ==>{ Ex_big_functor.10 }<==
     with module B = M ==>{ Ex_big_functor.14 }<==
  Paired: module C : sig type t = X.t end ==>{ Ex_big_functor.12 }<==
     with module C : sig type t end ==>{ Ex_big_functor.16 }<==
  
  Paired: type t = Y.t ==>{ Ex_big_functor.0 }<==
     with type t ==>{ Ex_big_functor.0 }<==
  
  Paired: type t = X.t ==>{ Ex_big_functor.11 }<==
     with type t ==>{ Ex_big_functor.15 }<==
  
  Paired: type t ==>{ Ex_big_functor.18 }<==
     with type t ==>{ Ex_big_functor.0 }<==
  
  Paired: type t = M.t ==>{ Ex_big_functor.0 }<==
     with type t ==>{ Ex_big_functor.0 }<==
  Paired: val x : int ==>{ Ex_big_functor.2 }<==
     with val x : int ==>{ Ex_big_functor.2 }<==
                type_declaration t/81 ==>{ Ex_big_functor.0 }<== (ex_big_functor.ml[1,0+25]..ex_big_functor.ml[1,0+31])
              value_description x/84 (ex_big_functor.ml[4,86+2]..ex_big_functor.ml[4,86+18]) ==>{ Ex_big_functor.2 }<==
                  Ttyp_constr \"int/1!\" ==>{ <predef:int> }<==
      M/88 ==>{ Ex_big_functor.6 }<==
                  type_declaration t/86 ==>{ Ex_big_functor.4 }<== (ex_big_functor.ml[8,143+2]..ex_big_functor.ml[8,143+8])
                      Tpat_var \"x/87\" ==>{ Ex_big_functor.5 }<==
      F/103 ==>{ Ex_big_functor.17 }<==
                      Tmod_ident \"X/89\" ==>{ Ex_big_functor.7 }<==
                    A/94 ==>{ Ex_big_functor.9 }<==
                              Tmod_ident \"Y/90\" ==>{ Ex_big_functor.8 }<==
                    B/95 ==>{ Ex_big_functor.10 }<==
                        Tmod_ident \"M/88\" ==>{ Ex_big_functor.6 }<==
                    C/97 ==>{ Ex_big_functor.12 }<==
                              type_declaration t/96 ==>{ Ex_big_functor.11 }<== (ex_big_functor.ml[33,537+4]..ex_big_functor.ml[33,537+23])
                                      Ttyp_constr \"X/89.t\" ==>{ Ex_big_functor.0 }<==
                    Tsig_module \"A/99\" ==>{ Ex_big_functor.13 }<==
                    Tsig_module \"B/100\" ==>{ Ex_big_functor.14 }<==
                    Tsig_module \"C/102\" ==>{ Ex_big_functor.16 }<==
                            type_declaration t/101 ==>{ Ex_big_functor.15 }<== (ex_big_functor.ml[21,381+4]..ex_big_functor.ml[21,381+10])
      FsN/116 ==>{ Ex_big_functor.19 }<==
              Tmod_ident \"F/103\" ==>{ Ex_big_functor.17 }<==
                    type_declaration t/104 ==>{ Ex_big_functor.18 }<== (ex_big_functor.ml[57,930+35]..ex_big_functor.ml[57,930+41])
            Tmod_ident \"M/88\" ==>{ Ex_big_functor.6 }<==
        type_declaration a/117 ==>{ Ex_big_functor.20 }<== (ex_big_functor.ml[71,1183+0]..ex_big_functor.ml[71,1183+14])
                Ttyp_constr \"FsN/116.t\" ==>{ Ex_big_functor.0 }<==
        type_declaration b/118 ==>{ Ex_big_functor.21 }<== (ex_big_functor.ml[76,1246+0]..ex_big_functor.ml[76,1246+16])
                Ttyp_constr \"FsN/116.A.t\" ==>{ Ex_big_functor.0 }<==
        type_declaration c/119 ==>{ Ex_big_functor.22 }<== (ex_big_functor.ml[81,1297+0]..ex_big_functor.ml[81,1297+16])
                Ttyp_constr \"FsN/116.B.t\" ==>{ Ex_big_functor.0 }<==

  $ $MERLIN single dump -what typedtree \
  > -filename ex_include_sub_module.ml < ex_include_sub_module.ml |
  > grep '==>'
  
  Paired: type t = X.M.t ==>{ Ex_include_sub_module.0 }<==
     with type t ==>{ Ex_include_sub_module.5 }<==
  
  Paired: type t = N.t ==>{ Ex_include_sub_module.7 }<==
     with type t ==>{ Ex_include_sub_module.0 }<==
  Paired: module M = N.M ==>{ Ex_include_sub_module.9 }<==
     with module M : sig type t end ==>{ Ex_include_sub_module.2 }<==
  
  Paired: type t = N.M.t ==>{ Ex_include_sub_module.8 }<==
     with type t ==>{ Ex_include_sub_module.0 }<==
                type_declaration t/81 ==>{ Ex_include_sub_module.0 }<== (ex_include_sub_module.ml[2,26+2]..ex_include_sub_module.ml[2,26+8])
              Tsig_module \"M/85\" ==>{ Ex_include_sub_module.2 }<==
      F/91 ==>{ Ex_include_sub_module.6 }<==
                    Tmod_ident \"X/87.M\" ==>{ Ex_include_sub_module.2 }<==
                    type_declaration t/90 ==>{ Ex_include_sub_module.5 }<== (ex_include_sub_module.ml[12,132+37]..ex_include_sub_module.ml[12,132+43])
      N/95 ==>{ Ex_include_sub_module.10 }<==
                type_declaration t/92 ==>{ Ex_include_sub_module.7 }<== (ex_include_sub_module.ml[27,330+2]..ex_include_sub_module.ml[27,330+8])
              M/94 ==>{ Ex_include_sub_module.9 }<==
                        type_declaration t/93 ==>{ Ex_include_sub_module.8 }<== (ex_include_sub_module.ml[29,370+4]..ex_include_sub_module.ml[29,370+10])
      FN/98 ==>{ Ex_include_sub_module.11 }<==
            Tmod_ident \"F/91\" ==>{ Ex_include_sub_module.6 }<==
            Tmod_ident \"N/95\" ==>{ Ex_include_sub_module.10 }<==
        type_declaration a/99 ==>{ Ex_include_sub_module.12 }<== (ex_include_sub_module.ml[54,601+0]..ex_include_sub_module.ml[54,601+13])
                Ttyp_constr \"FN/98.t\" ==>{ Ex_include_sub_module.5 }<==
