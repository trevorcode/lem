(in-package :lem-base)

(export '(first-line-p
          last-line-p
          start-line-p
          end-line-p
          start-buffer-p
          end-buffer-p
          same-line-p
          line-start
          line-end
          buffer-start
          buffer-end
          move-point
          line-offset
          character-offset
          character-at
          insert-character
          insert-string
          delete-character
          erase-buffer
          region-beginning
          region-end
          apply-region-lines
          map-region
          points-to-string
          count-characters
          delete-between-points
          count-lines
          line-number-at-point
          text-property-at
          put-text-property
          remove-text-property
          next-single-property-change
          previous-single-property-change
          line-string
          point-column
          move-to-column
          bolp
          eolp
          bobp
          eobp
          beginning-of-buffer
          end-of-buffer
          beginning-of-line
          end-of-line
          forward-line
          shift-position
          check-marked
          set-current-mark
          following-char
          preceding-char
          char-after
          char-before
          blank-line-p
          skip-chars-forward
          skip-chars-backward
          current-column
          position-at-point
          move-to-position
          move-to-line))

(annot:enable-annot-syntax)

(defun first-line-p (point)
  @lang(:jp "`point`が最初の行ならT、それ以外ならNILを返します。")
  (null (line-prev (point-line point))))

(defun last-line-p (point)
  @lang(:jp "`point`が最後の行ならT、それ以外ならNILを返します。")
  (null (line-next (point-line point))))

(defun start-line-p (point)
  @lang(:jp "`point`が行頭ならT、それ以外ならNILを返します。")
  (zerop (point-charpos point)))

(defun end-line-p (point)
  @lang(:jp "`point`が行末ならT、それ以外ならNILを返します。")
  (= (point-charpos point)
     (line-length (point-line point))))

(defun start-buffer-p (point)
  @lang(:jp "`point`がバッファの最初の位置ならT、それ以外ならNILを返します。")
  (and (first-line-p point)
       (start-line-p point)))

(defun end-buffer-p (point)
  @lang(:jp "`point`がバッファの最後の位置ならT、それ以外ならNILを返します。")
  (and (last-line-p point)
       (end-line-p point)))

(defun same-line-p (point1 point2)
  @lang(:jp "`point1`と`point2`が同じ位置ならT、それ以外ならNILを返します。")
  (assert (eq (point-buffer point1)
              (point-buffer point2)))
  (eq (point-line point1) (point-line point2)))

(defun line-string (point)
  @lang(:jp "`point`の行の文字列を返します。")
  (line-str (point-line point)))

(defun %move-to-position (point line charpos)
  (assert (line-alive-p line))
  (assert (eq (point-buffer point) (line-buffer line)))
  (assert (<= 0 charpos))
  (without-interrupts
    (point-change-line point line)
    (setf (point-charpos point) (min (line-length line) charpos)))
  point)

(defun move-point (point new-point)
  @lang(:jp "`point`を`new-point`の位置に移動します。")
  (%move-to-position point
                     (point-line new-point)
                     (point-charpos new-point)))

(defun line-start (point)
  @lang(:jp "`point`を行頭に移動します。")
  (setf (point-charpos point) 0)
  point)

(defun line-end (point)
  @lang(:jp "`point`を行末に移動します。")
  (setf (point-charpos point)
        (line-length (point-line point)))
  point)

(defun buffer-start (point)
  @lang(:jp "`point`をバッファの最初の位置に移動します。")
  (move-point point (buffers-start (point-buffer point))))

(defun buffer-end (point)
  @lang(:jp "`point`をバッファの最後の位置に移動します。")
  (move-point point (buffers-end (point-buffer point))))

(defun line-offset (point n &optional (charpos 0))
  @lang(:jp "`point`を`n`が正の数なら下に、負の数なら上に行を移動し、移動後の`point`を返します。
`n`行先に行が無ければ`point`の位置はそのままでNILを返します。
`charpos`は移動後の行頭からのオフセットです。
")
  (cond
    ((plusp n)
     (do ((n n (1- n))
          (line (point-line point) (line-next line)))
         ((null line) nil)
       (when (zerop n)
         (%move-to-position point line charpos)
         (return point))))
    ((minusp n)
     (do ((n n (1+ n))
          (line (point-line point) (line-prev line)))
         ((null line) nil)
       (when (zerop n)
         (%move-to-position point line charpos)
         (return point))))
    (t
     (setf (point-charpos point)
           (if (< charpos 0)
               0
               (min charpos
                    (line-length (point-line point)))))
     point)))

(declaim (inline %character-offset))
(defun %character-offset (point n fn zero-fn)
  (cond ((zerop n) (when zero-fn (funcall zero-fn)))
        ((plusp n)
         (do ((line (point-line point) (line-next line))
              (charpos (point-charpos point) 0))
             ((null line) nil)
           (let ((w (- (line-length line) charpos)))
             (when (<= n w)
               (return (funcall fn line (+ charpos n))))
             (decf n (1+ w)))))
        (t
         (setf n (- n))
         (do* ((line (point-line point) (line-prev line))
               (charpos (point-charpos point) (and line (line-length line))))
             ((null line) nil)
           (when (<= n charpos)
             (return (funcall fn line (- charpos n))))
           (decf n (1+ charpos))))))

(defun character-offset (point n)
  @lang(:jp "`point`を`n`が正の数なら後に、負の数なら前に移動し、移動後の`point`を返します。
`n`文字先がバッファの範囲外なら`point`の位置はそのままでNILを返します。")
  (%character-offset point n
                     (lambda (line charpos)
                       (%move-to-position point line charpos)
                       point)
                     (lambda ()
                       point)))

(defun character-at (point &optional (offset 0))
  @lang(:jp "`point`から`offset`ずらした位置の文字を返します。
バッファの範囲外ならNILを返します。")
  (%character-offset point offset
                     (lambda (line charpos)
                       (line-char line charpos))
                     (lambda ()
                       (line-char (point-line point)
                                  (point-charpos point)))))

(defun text-property-at (point prop &optional (offset 0))
  @lang(:jp "`point`から`offset`ずらした位置の`prop`のプロパティを返します。")
  (%character-offset point offset
                     (lambda (line charpos)
                       (line-search-property line prop charpos))
                     (lambda ()
                       (line-search-property (point-line point)
                                             prop
                                             (point-charpos point)))))

(defun put-text-property (start-point end-point prop value)
  @lang(:jp "`start-point`から`end-point`の間のテキストプロパティ`prop`を`value`にします。")
  (assert (eq (point-buffer start-point)
              (point-buffer end-point)))
  (%map-region start-point end-point
               (lambda (line start end)
                 (line-add-property line
                                    start
                                    (if (null end)
                                        (line-length line)
                                        end)
                                    prop
                                    value
                                    (null end)))))

(defun remove-text-property (start-point end-point prop)
  @lang(:jp "`start-point`から`end-point`までのテキストプロパティ`prop`を削除します。")
  (assert (eq (point-buffer start-point)
              (point-buffer end-point)))
  (%map-region start-point end-point
               (lambda (line start end)
                 (line-remove-property line
                                       start
                                       (if (null end)
                                           (line-length line)
                                           end)
                                       prop))))

;; 下の二つの関数next-single-property-change, previous-single-property-changeは
;; 効率がとても悪いので時が来たら書き直す

(defun next-single-property-change (point prop &optional limit-point)
  @lang(:jp "`point`からテキストプロパティ`prop`の値が異なる位置まで後の方向に移動し、
移動後の`point`を返します。  
バッファの最後まで走査が止まらないか、`limit-point`を越えると走査を中断しNILを返します。")
  (let ((first-value (text-property-at point prop)))
    (with-point ((curr point))
      (loop
        (unless (character-offset curr 1)
          (return nil))
        (unless (eq first-value (text-property-at curr prop))
          (return (move-point point curr)))
        (when (and limit-point (point<= limit-point curr))
          (return nil))))))

(defun previous-single-property-change (point prop &optional limit-point)
  @lang(:jp "`point`からテキストプロパティ`prop`の値が異なる位置まで前の方向に移動し、
移動後の`point`を返します。  
バッファの最初の位置まで走査が止まらないか、`limit-point`を越えると走査を中断しNILを返します。")
  (let ((first-value (text-property-at point prop -1)))
    (with-point ((curr point))
      (loop
        (unless (eq first-value (text-property-at curr prop -1))
          (return (move-point point curr)))
        (unless (character-offset curr -1)
          (return nil))
        (when (and limit-point (point>= limit-point curr))
          (return nil))))))

(defun insert-character (point char &optional (n 1))
  @lang(:jp "`point`に文字`char`を`n`回挿入します。")
  (loop :repeat n :do (insert-char/point point char))
  t)

(defun insert-string (point string &rest plist)
  @lang(:jp "`point`に文字列`string`を挿入します。  
`plist`を指定すると`string`を挿入した範囲にテキストプロパティを設定します。")
  (if (null plist)
      (insert-string/point point string)
      (with-point ((start-point point))
        (insert-string/point point string)
        (let ((end-point (character-offset (copy-point start-point :temporary)
                                           (length string))))
          (loop :for (k v) :on plist :by #'cddr
                :do (put-text-property start-point end-point k v)))))
  t)

(defun delete-character (point &optional (n 1))
  @lang(:jp "`point`から`n`個文字を削除し、削除した文字列を返します。 
`n`個の文字を削除する前にバッファの末尾に達した場合はNILを返します。")
  (when (minusp n)
    (unless (character-offset point n)
      (return-from delete-character nil))
    (setf n (- n)))
  (unless (end-buffer-p point)
    (let ((string (delete-char/point point n)))
      string)))

(defun erase-buffer (&optional (buffer (current-buffer)))
  @lang(:jp "`buffer`のテキストをすべて削除します。")
  (buffer-start (buffer-point buffer))
  (delete-char/point (buffer-point buffer)
                     (count-characters (buffers-start buffer)
                                       (buffers-end buffer))))

(defun region-beginning (&optional (buffer (current-buffer)))
  @lang(:jp "`buffer`内のリージョンの始まりの位置の`point`を返します。")
  (let ((start (buffer-point buffer))
        (end (buffer-mark buffer)))
    (if (point< start end)
        start
        end)))

(defun region-end (&optional (buffer (current-buffer)))
  @lang(:jp "`buffer`内のリージョンの終わりの位置の`point`を返します。")
  (let ((start (buffer-point buffer))
        (end (buffer-mark buffer)))
    (if (point< start end)
        end
        start)))

(defun apply-region-lines (start end function)
  (with-point ((start start :right-inserting)
	       (end end :right-inserting))
    (move-point (current-point) start)
    (loop :while (point< (current-point) end) :do
       (with-point ((prev (line-start (current-point)) :left-inserting))
	 (funcall function)
	 (when (same-line-p (current-point) prev)
	   (unless (line-offset (current-point) 1)
	     (return)))))))

(defun %map-region (start end function)
  (when (point< end start)
    (rotatef start end))
  (let ((start-line (point-line start))
        (end-line (point-line end)))
    (loop :for line := start-line :then (line-next line)
          :for firstp := (eq line start-line)
          :for lastp := (eq line end-line)
          :do (funcall function
                       line
                       (if firstp
                           (point-charpos start)
                           0)
                       (if lastp
                           (point-charpos end)
                           nil))
          :until lastp))
  (values))

(defun map-region (start end function)
  (%map-region start end
               (lambda (line start end)
                 (funcall function
                          (subseq (line-str line) start end)
                          (not (null end))))))

(defun points-to-string (start-point end-point)
  @lang(:jp "`start-point`から`end-point`までの範囲の文字列を返します。")
  (assert (eq (point-buffer start-point)
              (point-buffer end-point)))
  (with-output-to-string (out)
    (map-region start-point end-point
                (lambda (string lastp)
                  (write-string string out)
                  (unless lastp
                    (write-char #\newline out))))))

(defun count-characters (start-point end-point)
  @lang(:jp "`start-point`から`end-point`までの文字列の長さを返します。")
  (let ((count 0))
    (map-region start-point
                end-point
                (lambda (string lastp)
                  (incf count (length string))
                  (unless lastp
                    (incf count))))
    count))

(defun delete-between-points (start-point end-point)
  @lang(:jp "`start-point`から`end-point`までの範囲を削除し、削除した文字列を返します。")
  (assert (eq (point-buffer start-point)
              (point-buffer end-point)))
  (unless (point< start-point end-point)
    (rotatef start-point end-point))
  (delete-char/point start-point
		     (count-characters start-point end-point)))

(defun count-lines (start-point end-point)
  @lang(:jp "`start-point`から`end-point`までの行数を返します。")
  (assert (eq (point-buffer start-point)
              (point-buffer end-point)))
  (when (point< end-point start-point)
    (rotatef start-point end-point))
  (do ((line (point-line start-point) (line-next line))
       (goal (point-line end-point))
       (count 0 (1+ count)))
      ((eq line goal)
       count)))

(defun line-number-at-point (point)
  @lang(:jp "`point`の行番号を返します。")
  (let* ((buffer (point-buffer point))
         (end-point (buffer-end-point buffer))
         (n (line-ord (point-line point)))
         (n2 (line-ord (point-line end-point))))
    (if (< n (- n2 n))
        (1+ (count-lines (buffer-start-point buffer) point))
        (- (buffer-nlines buffer) (count-lines point end-point)))))

(defun point-column (point)
  @lang(:jp "`point`の行頭からの列幅を返します。")
  (string-width (line-string point)
                0
                (point-charpos point)))

(defun move-to-column (point column &optional force)
  @lang(:jp "`point`を行頭から列幅`column`まで移動し、移動後の`point`を返します。
`force`が非NILの場合は、行の長さが`column`より少なければ空白を挿入して移動し、
`force`がNILの場合は、行末まで移動し、移動後の`point`を返します。")
  (line-end point)
  (let ((cur-column (point-column point)))
    (cond ((< column cur-column)
           (setf (point-charpos point)
                 (wide-index (line-string point) column))
           point)
          (force
           (insert-character point #\space (- column cur-column))
           (line-end point))
          (t
           (line-end point)))))

(defun position-at-point (point)
  @lang(:jp "`point`のバッファの先頭からの1始まりのオフセットを返します。")
  (let ((offset (point-charpos point)))
    (do ((line (line-prev (point-line point)) (line-prev line)))
        ((null line) (1+ offset))
      (incf offset (1+ (line-length line))))))

(defun move-to-position (point position)
  @lang(:jp "`point`をバッファの先頭からの1始まりのオフセット`position`に移動してその位置を返します。
`position`がバッファの範囲外なら`point`は移動せず、NILを返します。")
  (character-offset (buffer-start point) (1- position)))

(defun move-to-line (point line-number)
  @lang(:jp "`point`を行番号`line-number`に移動し、移動後の位置を返します。
`line-number`がバッファの範囲外なら`point`は移動せず、NILを返します。")
  (let ((n (- (buffer-nlines (point-buffer point))
              line-number)))
  (if (< line-number n)
      (line-offset (buffer-start point) (1- line-number))
      (line-offset (buffer-end point) (- n)))))


(defun bolp ()
  (start-line-p (current-point)))

(defun eolp ()
  (end-line-p (current-point)))

(defun bobp ()
  (start-buffer-p (current-point)))

(defun eobp ()
  (end-buffer-p (current-point)))

(defun beginning-of-buffer ()
  (buffer-start (current-point)))

(defun end-of-buffer ()
  (buffer-end (current-point)))

(defun beginning-of-line ()
  (line-start (current-point))
  t)

(defun end-of-line ()
  (line-end (current-point))
  t)

(defun forward-line (&optional (n 1))
  (line-offset (current-point) n))

(defun shift-position (n)
  (character-offset (current-point) n))

(defun check-marked ()
  (unless (buffer-mark (current-buffer))
    (editor-error "Not mark in this buffer")))

(defun set-current-mark (point)
  @lang(:jp "`point`を現在のマークに設定します。")
  (let ((buffer (point-buffer point)))
    (setf (buffer-mark-p buffer) t)
    (cond ((buffer-mark buffer)
           (move-point (buffer-mark buffer) point))
          (t
           (setf (buffer-mark buffer)
                 (copy-point point :right-inserting)))))
  point)

(defun following-char ()
  (character-at (current-point)))

(defun preceding-char ()
  (character-at (current-point) -1))

(defun char-after (&optional (point (current-point)))
  (character-at point 0))

(defun char-before (&optional (point (current-point)))
  (character-at point -1))

(defun blank-line-p (point)
  (let ((string (line-string point))
        (eof-p (last-line-p point))
        (count 0))
    (loop :for c :across string :do
       (unless (or (char= c #\space)
		   (char= c #\tab))
	 (return-from blank-line-p nil))
       (incf count))
    (if eof-p
        count
        (1+ count))))

(defun skip-chars-internal (point test dir)
  (loop :for count :from 0
        :for c := (character-at point (if dir 0 -1))
        :do
        (unless (if (consp test)
                    (member c test)
                    (funcall test c))
          (return count))
        (unless (character-offset point (if dir 1 -1))
          (return count))))

(defun skip-chars-forward (point test)
  @lang(:jp "`point`からその位置の文字を`test`で評価して非NILの間、後の方向に移動します。  
`test`が文字のリストならその位置の文字が`test`のリスト内に含まれるか  
`test`が関数ならその位置の文字を引数として一つ取り、返り値が非NILであるか
")
  (skip-chars-internal point test t))

(defun skip-chars-backward (point test)
  @lang(:jp "`point`からその位置の前の文字を`test`で評価して非NILの間、前の方向に移動します。  
`test`が文字のリストならその位置の前の文字が`test`のリスト内に含まれるか  
`test`が関数ならその位置の前の文字を引数として一つ取り、返り値が非NILであるか
")
  (skip-chars-internal point test nil))

(defun current-column ()
  (point-column (current-point)))

(defun invoke-save-excursion (function)
  (let ((point (copy-point (current-point) :right-inserting))
        (mark (when (buffer-mark-p (current-buffer))
                (copy-point (buffer-mark (current-buffer))
                            :right-inserting))))
    (unwind-protect (funcall function)
      (setf (current-buffer) (point-buffer point))
      (move-point (current-point) point)
      (delete-point point)
      (when mark
        (set-current-mark mark)
        (delete-point mark)))))
