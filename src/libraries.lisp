;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; libraries.lisp --- Finding and loading foreign libraries.
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

(in-package #:cffi)

;;;# Loading Foreign Libraries
;;;
;;; For now, this interface is dirt simple.  It simply passes the
;;; library name to the underlying function in CFFI-SYS.  Once we get
;;; some user feedback about implementing a search strategy this will
;;; get fancier.

;; All %load/close-foreign-library are required to handle are strings.
(defun ensure-string (x)
  (etypecase x
    (pathname (namestring x))
    (string x)))

(defun load-foreign-library (name)
  "Load a foreign library NAME."
  (%load-foreign-library (ensure-string name)))

(defun close-foreign-library (name)
  "Closes a foreign library NAME."
  (%close-foreign-library (ensure-string name)))
   