;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; memory.lisp --- Tests for memory referencing.
;;;
;;; Copyright (C) 2005, James Bielman  <jamesjb@jamesjb.com>
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

(deftest deref.char
    (with-foreign-object (p :char)
      (setf (mem-ref p :char) -127)
      (mem-ref p :char))
  -127)

(deftest deref.unsigned-char
    (with-foreign-object (p :unsigned-char)
      (setf (mem-ref p :unsigned-char) 255)
      (mem-ref p :unsigned-char))
  255)

(deftest deref.short
    (with-foreign-object (p :short)
      (setf (mem-ref p :short) -32767)
      (mem-ref p :short))
  -32767)

(deftest deref.unsigned-short
    (with-foreign-object (p :unsigned-short)
      (setf (mem-ref p :unsigned-short) 65535)
      (mem-ref p :unsigned-short))
  65535)

(deftest deref.int
    (with-foreign-object (p :int)
      (setf (mem-ref p :int) -131072)
      (mem-ref p :int))
  -131072)

(deftest deref.unsigned-int
    (with-foreign-object (p :unsigned-int)
      (setf (mem-ref p :unsigned-int) 262144)
      (mem-ref p :unsigned-int))
  262144)

(deftest deref.long
    (with-foreign-object (p :long)
      (setf (mem-ref p :long) -536870911)
      (mem-ref p :long))
  -536870911)

(deftest deref.unsigned-long
    (with-foreign-object (p :unsigned-long)
      (setf (mem-ref p :unsigned-long) 536870912)
      (mem-ref p :unsigned-long))
  536870912)

#-cffi-features:no-long-long
(progn
  (deftest deref.long-long
      (with-foreign-object (p :long-long)
        (setf (mem-ref p :long-long) -9223372036854775807)
        (mem-ref p :long-long))
    -9223372036854775807)

  (deftest deref.unsigned-long-long
      (with-foreign-object (p :unsigned-long-long)
        (setf (mem-ref p :unsigned-long-long) 18446744073709551615)
        (mem-ref p :unsigned-long-long))
    18446744073709551615))

(deftest deref.float.1
    (with-foreign-object (p :float)
      (setf (mem-ref p :float) 0.0)
      (mem-ref p :float))
  0.0)

(deftest deref.float.2
    (with-foreign-object (p :float)
      (setf (mem-ref p :float) most-positive-single-float)
      (mem-ref p :float))
  #.most-positive-single-float)

(deftest deref.float.3
    (with-foreign-object (p :float)
      (setf (mem-ref p :float) least-positive-single-float)
      (mem-ref p :float))
  #.least-positive-single-float)

(deftest deref.double.1
    (with-foreign-object (p :double)
      (setf (mem-ref p :double) 0.0d0)
      (mem-ref p :double))
  0.0d0)

(deftest deref.double.2
    (with-foreign-object (p :double)
      (setf (mem-ref p :double) most-positive-double-float)
      (mem-ref p :double))
  #.most-positive-double-float)

(deftest deref.double.3
    (with-foreign-object (p :double)
      (setf (mem-ref p :double) least-positive-double-float)
      (mem-ref p :double))
  #.least-positive-double-float)

;;; make sure the lisp doesn't convert NULL to NIL
(deftest deref.pointer.null
    (with-foreign-object (p :pointer)
      (setf (mem-ref p :pointer) (null-pointer))
      (null-pointer-p (mem-ref p :pointer)))
  t)

;;; regression test. lisp-string-to-foreign should handle empty strings
(deftest lisp-string-to-foreign.empty
    (with-foreign-pointer (str 2)
      (setf (mem-ref str :unsigned-char) 42)
      (lisp-string-to-foreign "" str 1)
      (mem-ref str :unsigned-char))
  0)

;; regression test. with-foreign-pointer shouldn't evaluate
;; the size argument twice.
(deftest with-foreign-pointer.evalx2
    (let ((count 0))
      (with-foreign-pointer (x (incf count) size-var)
        (values count size-var)))
  1 1)

(deftest mem-ref.left-to-right
    (let ((i 0))
      (with-foreign-object (p :char 3)
        (setf (mem-ref p :char 0) 66 (mem-ref p :char 1) 92)
        (setf (mem-ref p :char (incf i)) (incf i))
        (values (mem-ref p :char 0) (mem-ref p :char 1) i)))
  66 2 2)

;; regression test. mem-aref's setf expansion evaluated its type argument twice.
(deftest mem-aref.eval-type-x2
    (let ((count 0))
      (with-foreign-pointer (p 1)
        (setf (mem-aref p (progn (incf count) :char) 0) 127))
      count)
  1)

(deftest mem-aref.left-to-right
    (let ((count -1))
      (with-foreign-pointer (p 2)
        (values
         (setf (mem-aref p (progn (incf count) :char) (incf count)) (incf count))
         (setq count -1)
         (mem-aref (progn (incf count) p) :char (incf count))
         count)))
  2 -1 2 1)

;; regression tests. nested mem-ref's and mem-aref's had bogus getters
(deftest mem-ref.nested
    (with-foreign-object (p :pointer)
      (with-foreign-object (i :int)
        (setf (mem-ref p :pointer) i)
        (setf (mem-ref i :int) 42)
        (setf (mem-ref (mem-ref p :pointer) :int) 1984)
        (mem-ref i :int)))
  1984)

(deftest mem-aref.nested
    (with-foreign-object (p :pointer)
      (with-foreign-object (i :int 2)
        (setf (mem-aref p :pointer 0) i)
        (setf (mem-aref i :int 1) 42)
        (setf (mem-aref (mem-ref p :pointer 0) :int 1) 1984)
        (mem-aref i :int 1)))
  1984)

;;; regression tests. dereferencing an aggregate type. dereferencing a
;;; struct should return a pointer to the struct itself, not return the
;;; first 4 bytes (or whatever the size of :pointer is) as a pointer.
;;;
;;; This important for accessing an array of structs, which is
;;; what the deref.array-of-aggregates test does.
(defcstruct some-struct (x :int))

(deftest deref.aggregate
    (with-foreign-object (s 'some-struct)
      (pointer-eq s (mem-ref s 'some-struct)))
  t)

(deftest deref.array-of-aggregates
    (with-foreign-object (arr 'some-struct 3)
      (loop for i below 3
            do (setf (foreign-slot-value (mem-aref arr 'some-struct i)
                                         'some-struct 'x)
                     112))
      (loop for i below 3
            collect (foreign-slot-value (mem-aref arr 'some-struct i)
                                        'some-struct 'x)))
  (112 112 112))

;;; pointer operations
(deftest pointer.1
    (pointer-address (make-pointer 42))
  42)

;;; I suppose this test is not very good. --luis
(deftest pointer.2
    (pointer-address (null-pointer))
  0)

;;; Ensure that a pointer to the highest possible address can be
;;; created using MAKE-POINTER.  Regression test for CLISP/X86-64.
(deftest make-pointer.high
    (let* ((pointer-length (foreign-type-size :pointer))
           (high-address (1- (expt 2 (* pointer-length 8))))
           (pointer (make-pointer high-address)))
      (- high-address (pointer-address pointer)))
  0)

;;; Ensure that incrementing a pointer by zero bytes returns an
;;; equivalent pointer.
(deftest inc-pointer.zero
    (with-foreign-object (x :int)
      (pointer-eq x (inc-pointer x 0)))
  t)

;;; Test the INITIAL-ELEMENT keyword argument to FOREIGN-ALLOC.
(deftest foreign-alloc.1
    (let ((ptr (foreign-alloc :int :initial-element 42)))
      (unwind-protect
           (mem-ref ptr :int)
        (foreign-free ptr)))
  42)

;;; Test the INITIAL-ELEMENT and COUNT arguments to FOREIGN-ALLOC.
(deftest foreign-alloc.2
    (let ((ptr (foreign-alloc :int :count 4 :initial-element 100)))
      (unwind-protect
           (loop for i from 0 below 4
                 collect (mem-aref ptr :int i))
        (foreign-free ptr)))
  (100 100 100 100))

;;; Test the INITIAL-CONTENTS and COUNT arguments to FOREIGN-ALLOC,
;;; passing a list of initial values.
(deftest foreign-alloc.3
    (let ((ptr (foreign-alloc :int :count 4 :initial-contents '(4 3 2 1))))
      (unwind-protect
           (loop for i from 0 below 4
                 collect (mem-aref ptr :int i))
        (foreign-free ptr)))
  (4 3 2 1))

;;; Test INITIAL-CONTENTS and COUNT with FOREIGN-ALLOC passing a
;;; vector of initial values.
(deftest foreign-alloc.4
    (let ((ptr (foreign-alloc :int :count 4 :initial-contents #(10 20 30 40))))
      (unwind-protect
           (loop for i from 0 below 4
                 collect (mem-aref ptr :int i))
        (foreign-free ptr)))
  (10 20 30 40))

;;; Ensure calling FOREIGN-ALLOC with both INITIAL-ELEMENT and
;;; INITIAL-CONTENTS signals an error.
(deftest foreign-alloc.5
    (values
     (ignore-errors
       (let ((ptr (foreign-alloc :int :initial-element 1 :initial-contents '(1))))
         (foreign-free ptr))
       t))
  nil)

;;; Tests for mem-ref with a non-constant type. This is a way to test
;;; the functional interface (without compiler macros).

(deftest deref.nonconst.char
    (let ((type :char))
      (with-foreign-object (p type)
        (setf (mem-ref p type) -127)
        (mem-ref p type)))
  -127)

(deftest deref.nonconst.unsigned-char
    (let ((type :unsigned-char))
      (with-foreign-object (p type)
        (setf (mem-ref p type) 255)
        (mem-ref p type)))
  255)

(deftest deref.nonconst.short
    (let ((type :short))
      (with-foreign-object (p type)
        (setf (mem-ref p type) -32767)
        (mem-ref p type)))
  -32767)

(deftest deref.nonconst.unsigned-short
    (let ((type :unsigned-short))
      (with-foreign-object (p type)
        (setf (mem-ref p type) 65535)
        (mem-ref p type)))
  65535)

(deftest deref.nonconst.int
    (let ((type :int))
      (with-foreign-object (p type)
        (setf (mem-ref p type) -131072)
        (mem-ref p type)))
  -131072)

(deftest deref.nonconst.unsigned-int
    (let ((type :unsigned-int))
      (with-foreign-object (p type)
        (setf (mem-ref p type) 262144)
        (mem-ref p type)))
  262144)

(deftest deref.nonconst.long
    (let ((type :long))
      (with-foreign-object (p type)
        (setf (mem-ref p type) -536870911)
        (mem-ref p type)))
  -536870911)

(deftest deref.nonconst.unsigned-long
    (let ((type :unsigned-long))
      (with-foreign-object (p type)
        (setf (mem-ref p type) 536870912)
        (mem-ref p type)))
  536870912)

#-cffi-features:no-long-long
(progn
  (deftest deref.nonconst.long-long
      (let ((type :long-long))
        (with-foreign-object (p type)
          (setf (mem-ref p type) -9223372036854775807)
          (mem-ref p type)))
    -9223372036854775807)

  (deftest deref.nonconst.unsigned-long-long
      (let ((type :unsigned-long-long))
        (with-foreign-object (p type)
          (setf (mem-ref p type) 18446744073709551615)
          (mem-ref p type)))
    18446744073709551615))

(deftest deref.nonconst.float.1
    (let ((type :float))
      (with-foreign-object (p type)
        (setf (mem-ref p type) 0.0)
        (mem-ref p type)))
  0.0)

(deftest deref.nonconst.float.2
    (let ((type :float))
      (with-foreign-object (p type)
        (setf (mem-ref p type) most-positive-single-float)
        (mem-ref p type)))
  #.most-positive-single-float)

(deftest deref.nonconst.float.3
    (let ((type :float))
      (with-foreign-object (p type)
        (setf (mem-ref p type) least-positive-single-float)
        (mem-ref p type)))
  #.least-positive-single-float)

(deftest deref.nonconst.double.1
    (let ((type :double))
      (with-foreign-object (p type)
        (setf (mem-ref p type) 0.0d0)
        (mem-ref p type)))
  0.0d0)

(deftest deref.nonconst.double.2
    (let ((type :double))
      (with-foreign-object (p type)
        (setf (mem-ref p type) most-positive-double-float)
        (mem-ref p type)))
  #.most-positive-double-float)

(deftest deref.nonconst.double.3
    (let ((type :double))
      (with-foreign-object (p type)
        (setf (mem-ref p type) least-positive-double-float)
        (mem-ref p type)))
  #.least-positive-double-float)