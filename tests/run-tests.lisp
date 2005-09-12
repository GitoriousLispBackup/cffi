;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; run-tests.lisp --- Simple script to run the unit tests.
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

(format t "~&-------- Running tests in ~A --------~%"
        (lisp-implementation-type))

(setf *load-verbose* nil *compile-verbose* nil *compile-print* nil)
#+cmu (setf ext:*gc-verbose* nil)

#+(and (not asdf) (or sbcl openmcl))
(require "asdf")

(asdf:operate 'asdf:load-op 'cffi-tests :verbose nil)
(in-package #:cffi-tests)
(do-tests)

(defparameter *repeat* 0)
(format t "~2&How many times shall we repeat the tests? [~D]: " *repeat*)
(force-output *standard-output*)
(let ((ntimes (or (ignore-errors (parse-integer (read-line))) *repeat*)))
  (unless (eql ntimes 0)
    (loop repeat ntimes do (do-tests))
    (format t "~&Finished running tests ~D times." ntimes)))

(in-package #:cl-user)
(terpri)
(force-output)

#-allegro (quit)
#+allegro (exit)
