;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; misc.lisp --- Miscellaneous tests.
;;;
;;; Copyright (C) 2006, Luis Oliveira  <loliveira@common-lisp.net>
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

;;; From CLRFI-1
(defun featurep (feature-expression)
  (etypecase feature-expression
    (symbol (not (null (member feature-expression *features*))))
    (cons                ; Not LIST, as we've already eliminated NIL.
     (ecase (first feature-expression)
       (:and (every #'featurep (rest feature-expression)))
       (:or  (some #'featurep (rest feature-expression)))
       (:not (not (featurep (cadr feature-expression))))))))

;;;# Test relations between OS features.

(deftest features.os.1
    (if (featurep 'cffi-features:windows)
        (not (or (featurep 'cffi-features:unix)
                 (featurep 'cffi-features:darwin)))
        t)
  t)

(deftest features.os.2
    (if (featurep 'cffi-features:darwin)
        (and (not (featurep 'cffi-features:windows))
             (featurep 'cffi-features:unix))
        t)
  t)

(deftest features.os.3
    (if (featurep 'cffi-features:unix)
        (not (featurep 'cffi-features:windows))
        t)
  t)

;;;# Test mutual exclusiveness of CPU features.

(defparameter *cpu-features*
  '(cffi-features:x86
    cffi-features:x86-64
    cffi-features:ppc32
    cffi-features:sparc
    cffi-features:sparc64
    cffi-features:hppa
    cffi-features:hppa64
    ))

(deftest features.cpu.1
    (loop for feature in *cpu-features*
          when (featurep feature)
          sum 1)
  1)

;;;# foreign-symbol-pointer tests

;;; This might be useful for some libraries that compare function
;;; pointers. http://thread.gmane.org/gmane.lisp.cffi.devel/694
(defcfun "compare_against_abs" :boolean (p :pointer))

(deftest foreign-symbol-pointer.1
    (compare-against-abs (foreign-symbol-pointer "abs"))
  t)

(defcfun "compare_against_xpto_fun" :boolean (p :pointer))

(deftest foreign-symbol-pointer.2
    (compare-against-xpto-fun (foreign-symbol-pointer "xpto_fun"))
  t)

;;;# Library tests
;;;
;;; Need to figure out a way to test this.  CLISP, for instance, will
;;; automatically reopen the foreign-library when we call a foreign
;;; function so we can't test CLOSE-FOREIGN-LIBRARY this way.
;;;
;;; IIRC, GCC has some extensions to have code run when a library is
;;; loaded and stuff like that.  That could work.

#||
#-(and :ecl (not :dffi))
(deftest library.close.2
    (unwind-protect
         (progn
           (close-foreign-library 'libtest)
           (ignore-errors (my-sqrtf 16.0)))
      (load-test-libraries))
  nil)

#-(or (and :ecl (not :dffi))
      cffi-features:flat-namespace
      cffi-features:no-foreign-funcall)
(deftest library.close.2
    (unwind-protect
         (values
          (foreign-funcall ("ns_function" :library libtest) :boolean)
          (close-foreign-library 'libtest)
          (foreign-funcall "ns_function" :boolean)
          (close-foreign-library 'libtest2)
          (close-foreign-library 'libtest2)
          (ignore-errors (foreign-funcall "ns_function" :boolean)))
      (load-test-libraries))
  t t nil t nil nil)
||#

(deftest library.error.1
    (handler-case (load-foreign-library "libdoesnotexistimsure")
      (load-foreign-library-error () 'error))
  error)
