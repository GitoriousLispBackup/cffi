;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; strings.lisp --- Tests for foreign string conversion.
;;;
;;; Copyright (C) 2005, James Bielman  <jamesjb@jamesjb.com>
;;; Copyright (C) 2007, Luis Oliveira  <loliveira@common-lisp.net>
;;;
;;; Permission is hereby granted, free of charge, to any person
;;; obtaining a copy of this software and associated documentation
;;; files (the "Software"), to deal in the Software without
;;; restriction, including without limitation the rights to use, copy,
;;; modify, merge, publish, distribute, sublicense, and/or sell copies
;;; of the Software, and to permit persons to whom the Software is
;;; furnished to do so, subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be
;;; included in all copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;;; NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
;;; HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
;;; WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;;; DEALINGS IN THE SOFTWARE.
;;;

(in-package #:cffi-tests)

;;;# Foreign String Conversion Tests
;;;
;;; With the implementation of encoding support, there are a lot of
;;; things that can go wrong with foreign string conversions.  This is
;;; a start at defining tests for strings and encoding conversion, but
;;; there needs to be a lot more.

;;; *ASCII-TEST-STRING* contains the characters in the ASCII character
;;; set that we will convert to a foreign string and check against
;;; *ASCII-TEST-BYTES*.  We don't bother with control characters.
;;;
;;; FIXME: It would probably be good to move these tables into files
;;; in "tests/", especially if we ever want to get fancier and have
;;; tests for more encodings.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *ascii-test-string*
    (concatenate 'string " !\"#$%&'()*+,-./0123456789:;"
                 "<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]"
                 "^_`abcdefghijklmnopqrstuvwxyz{|}~")))

;;; *ASCII-TEST-BYTES* contains the expected ASCII encoded values
;;; for each character in *ASCII-TEST-STRING*.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *ascii-test-bytes*
    (let ((vector (make-array 95 :element-type '(unsigned-byte 8))))
      (loop for i from 0
            for code from 32 below 127
            do (setf (aref vector i) code)
            finally (return vector)))))

;;; Test basic consistency converting a string to and from Lisp using
;;; the default encoding.
(deftest string.conversion.basic
    (with-foreign-string (s *ascii-test-string*)
      (foreign-string-to-lisp s))
  #.*ascii-test-string*)

;;; Ensure that conversion of *ASCII-TEST-STRING* to a foreign buffer
;;; and back preserves ASCII encoding.
(deftest string.encoding.ascii
    (with-foreign-string (s *ascii-test-string* :encoding :ascii)
      (let ((vector (make-array 95 :element-type '(unsigned-byte 8))))
        (loop for i from 0 below (length vector)
              do (setf (aref vector i) (mem-ref s :unsigned-char i)))
        vector))
  #.*ascii-test-bytes*)

;;; Test UTF-16 conversion of a string back and forth.  Tests proper
;;; null terminator handling for wide character strings and ensures no
;;; byte order marks are added.  (Why no BOM? --luis)
#-babel::8-bit-chars
(deftest string.encoding.utf-16.basic
    (with-foreign-string (s *ascii-test-string* :encoding :utf-16)
      (foreign-string-to-lisp s :encoding :utf-16))
  #.*ascii-test-string*)

;;; Ensure that writing a long string into a short buffer does not
;;; attempt to write beyond the edge of the buffer, and that the
;;; resulting string is still null terminated.
;;;
;;; Expected failure.  Investigating whether these semantics are a
;;; good idea. [2007-06-07 LO]
(deftest string.short-write.1
    (with-foreign-pointer (buf 6)
      (setf (mem-ref buf :unsigned-char 5) 70)
      (lisp-string-to-foreign "ABCDE" buf 5 :encoding :ascii)
      (values (mem-ref buf :unsigned-char 4)
              (mem-ref buf :unsigned-char 5)))
  0 70)

#-babel::8-bit-chars
(deftest string.encoding.utf-8.basic
    (with-foreign-pointer (buf 7 size)
      (let ((string (concatenate 'string '(#\u03bb #\u00e3 #\u03bb))))
        (lisp-string-to-foreign string buf size :encoding :utf-8)
        (loop for i from 0 below size
              collect (mem-ref buf :unsigned-char i))))
  (206 187 195 163 206 187 0))

(defparameter *basic-latin-alphabet* "abcdefghijklmnopqrstuvwxyz")

(defparameter *non-latin-compatible-encodings*
  '())

(defun list-latin-compatible-encodings ()
  (remove-if (lambda (x) (member x *non-latin-compatible-encodings*))
             (babel:list-character-encodings)))

(deftest string.encodings.all.basic
    (let (failed)
      (dolist (encoding (list-latin-compatible-encodings) failed)
        ;; (format t "Testing ~S~%" encoding)
        (with-foreign-string (ptr *basic-latin-alphabet* :encoding encoding)
          (let ((string (foreign-string-to-lisp ptr :encoding encoding)))
            ;; (format t "  got ~S~%" string)
            (unless (string= *basic-latin-alphabet* string)
              (push encoding failed))))))
  nil)

;;; rt: make sure *default-foreign-enconding* binds to a keyword
(deftest string.encodings.default
    (keywordp *default-foreign-encoding*)
  t)
