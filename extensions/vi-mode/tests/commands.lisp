(defpackage :lem-vi-mode/tests/commands
  (:use :cl
        :lem
        :rove
        :lem-vi-mode/tests/utils)
  (:import-from :lem-fake-interface
                :with-fake-interface)
  (:import-from :named-readtables
                :in-readtable))
(in-package :lem-vi-mode/tests/commands)

(in-readtable :interpol-syntax)

(deftest vi-undo
  (with-fake-interface ()
    (with-vi-buffer (#?"[1]\n2\n3\n")
      (cmd "a: Hello!<Esc>")
      (ok (buf= #?"1: Hello[!]\n2\n3\n"))
      (ok (state= :normal))
      (cmd "u")
      (ok (buf= #?"[1]\n2\n3\n"))
      (cmd "<C-r>")
      (ok (buf= #?"1: Hello[!]\n2\n3\n"))
      (cmd "o4: World!<Esc>a<Esc>")
      (ok (buf= #?"1: Hello!\n4: World[!]\n2\n3\n"))
      (cmd "2u")
      (ok (buf= #?"[1]\n2\n3\n")))
    (with-vi-buffer (#?"[1]\n2\n3\n")
      (cmd "a: Hello!<Esc>")
      (ok (buf= #?"1: Hello[!]\n2\n3\n"))
      (cmd "ja: World!<Esc>")
      (ok (buf= #?"1: Hello!\n2: World[!]\n3\n"))
      (cmd "u")
      (ok (buf= #?"1: Hello!\n[2]\n3\n")))))

(deftest vi-repeat
  (with-fake-interface ()
    (with-vi-buffer (#?"[1]:abc\n2:def\n3:ghi\n4:jkl\n5:mno\n6:opq\n7:rst\n8:uvw")
      (cmd "dd")
      (ok (buf= #?"[2]:def\n3:ghi\n4:jkl\n5:mno\n6:opq\n7:rst\n8:uvw"))
      (cmd ".")
      (ok (buf= #?"[3]:ghi\n4:jkl\n5:mno\n6:opq\n7:rst\n8:uvw"))
      (cmd "2.")
      (ok (buf= #?"[5]:mno\n6:opq\n7:rst\n8:uvw")))
    (with-vi-buffer (#?"[1]:abc\n2:def\n3:ghi\n4:jkl\n5:mno\n6:opq\n7:rst\n8:uvw")
      (cmd "2d2d")
      (ok (buf= #?"[5]:mno\n6:opq\n7:rst\n8:uvw"))
      (cmd "2.")
      (ok (buf= #?"[7]:rst\n8:uvw")))
    (with-vi-buffer (#?"[f]oo\nbar\nbaz\n")
      (cmd "A-fighters<Esc>")
      (ok (buf= #?"foo-fighter[s]\nbar\nbaz\n"))
      (cmd "j^.")
      (ok (buf= #?"foo-fighters\nbar-fighter[s]\nbaz\n")))))

(deftest vi-paste-after-and-before
  (with-fake-interface ()
    (testing "paste char"
      (with-vi-buffer (#?"a[b]cd\nefgh\n")
        (cmd "yl")
        (cmd "p")
        (ok (buf= #?"ab[b]cd\nefgh\n"))
        (cmd "jP")
        (ok (buf= #?"abbcd\nef[b]gh\n"))))
    (testing "paste line"
      (with-vi-buffer (#?"a[b]cd\nefgh\n")
        (cmd "yy")
        (cmd "jp")
        (ok (buf= #?"abcd\nefgh\n[a]bcd\n"))
        (cmd "P")
        (ok (buf= #?"abcd\nefgh\n[a]bcd\nabcd\n"))))
    (testing "paste block"
      (with-vi-buffer (#?"a[b]cd\nefgh\n")
        (cmd "<C-v>jly")
        (cmd "p")
        (ok (buf= #?"ab[b]ccd\neffggh\n"))
        (cmd "u^")
        (cmd "P")
        (ok (buf= #?"[b]cabcd\nfgefgh\n"))))
    (testing "paste block (add spaces)"
      (with-vi-buffer (#?"a[b]cd\nefgh\n\nijk\n")
        (cmd "<C-v>jly")
        (cmd "j$2h")
        (cmd "p")
        (ok (buf= #?"abcd\nef[b]cgh\n  fg\nijk\n"))
        (cmd "u$2hP")
        (ok (buf= #?"abcd\ne[b]cfgh\n fg\nijk\n"))))))
