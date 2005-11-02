;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; cffi-ecl.lisp --- ECL backend for CFFI.
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

;;;# Administrivia

(defpackage #:cffi-sys
  (:use #:common-lisp #:cffi-utils)
  (:export
   #:pointerp
   #:pointer-eq
   #:%foreign-alloc
   #:foreign-free
   #:with-foreign-ptr
   #:null-ptr
   #:null-ptr-p
   #:inc-ptr
   #:%mem-ref
   #:%foreign-funcall
   #:%foreign-type-alignment
   #:%foreign-type-size
   #:%load-foreign-library
   #:make-shareable-byte-vector
   #:with-pointer-to-vector-data
   #:%defcallback
   #:foreign-symbol-ptr))

(in-package #:cffi-sys)

;;;# Allocation

(defun %foreign-alloc (size)
  "Allocate SIZE bytes of foreign-addressable memory."
  (si:allocate-foreign-data :void size))

(defun foreign-free (ptr)
  "Free a pointer PTR allocated by FOREIGN-ALLOC."
  (si:free-foreign-data ptr))

(defmacro with-foreign-ptr ((var size &optional size-var) &body body)
  "Bind VAR to SIZE bytes of foreign memory during BODY.  The
pointer in VAR is invalid beyond the dynamic extent of BODY, and
may be stack-allocated if supported by the implementation.  If
SIZE-VAR is supplied, it will be bound to SIZE during BODY."
  (unless size-var
    (setf size-var (gensym "SIZE")))
  `(let* ((,size-var ,size)
          (,var (%foreign-alloc ,size-var)))
     (unwind-protect
          (progn ,@body)
       (foreign-free ,var))))

;;;# Misc. Pointer Operations

(defun null-ptr ()
  "Construct and return a null pointer."
  (si:allocate-foreign-data :void 0))

(defun null-ptr-p (ptr)
  "Return true if PTR is a null pointer."
  (si:null-pointer-p ptr))

(defun inc-ptr (ptr offset)
  "Return a pointer OFFSET bytes past PTR."
  (ffi:make-pointer (+ (ffi:pointer-address ptr) offset) :void))

(defun pointerp (ptr)
  "Return true if PTR is a foreign pointer."
  (typep ptr 'si:foreign-data))

(defun pointer-eq (ptr1 ptr2)
  "Return true if PTR1 and PTR2 point to the same address."
  (= (ffi:pointer-address ptr1) (ffi:pointer-address ptr2)))

;;;# Dereferencing

(defun %mem-ref (ptr type &optional (offset 0))
  "Dereference an object of TYPE at OFFSET bytes from PTR."
  (let* ((type (convert-foreign-type type))
	 (type-size (ffi:size-of-foreign-type type)))
    (si:foreign-data-ref-elt
     (si:foreign-data-recast ptr (+ offset type-size) :void) offset type)))

(defun (setf %mem-ref) (value ptr type &optional (offset 0))
  "Set an object of TYPE at OFFSET bytes from PTR."
  (let* ((type (convert-foreign-type type))
	 (type-size (ffi:size-of-foreign-type type)))
    (si:foreign-data-set-elt
     (si:foreign-data-recast ptr (+ offset type-size) :void)
     offset type value)))

;;;# Type Operations

(defun convert-foreign-type (type-keyword)
  "Convert a CFFI type keyword to an ECL type keyword."
  (ecase type-keyword
    (:char            :byte)
    (:unsigned-char   :unsigned-byte)
    (:short           :short)
    (:unsigned-short  :unsigned-short)
    (:int             :int)
    (:unsigned-int    :unsigned-int)
    (:long            :long)
    (:unsigned-long   :unsigned-long)
    (:float           :float)
    (:double          :double)
    (:pointer         :pointer-void)
    (:void            :void)))

(defun %foreign-type-size (type-keyword)
  "Return the size in bytes of a foreign type."
  (nth-value 0 (ffi:size-of-foreign-type
                (convert-foreign-type type-keyword))))

(defun %foreign-type-alignment (type-keyword)
  "Return the alignment in bytes of a foreign type."
  (nth-value 1 (ffi:size-of-foreign-type
                (convert-foreign-type type-keyword))))

;;;# Calling Foreign Functions

(defun produce-function-call (c-name nargs)
  (format nil "~a(~a)" c-name
	  (subseq "#0,#1,#2,#3,#4,#5,#6,#7,#8,#9,#a,#b,#c,#d,#e,#f,#g,#h,#i,#j,#k,#l,#m,#n,#o,#p,#q,#r,#s,#t,#u,#v,#w,#x,#y,#z"
		  0 (max 0 (1- (* nargs 3))))))

(defun foreign-function-inline-form (name arg-types arg-values return-type)
  "Generate a C-INLINE form for a foreign function call."
  `(ffi:c-inline
    ,arg-values ,arg-types ,return-type
    ,(produce-function-call name (length arg-values))
    :one-liner t :side-effects t))

#+dffi
(defun foreign-function-dynamic-form (name arg-types arg-values return-type)
  "Generate a dynamic FFI form for a foreign function call."
  `(si:call-cfun (si:find-foreign-symbol ,name :default :pointer-void 0)
                 ,return-type (list ,@arg-types) (list ,@arg-values)))

(defun foreign-funcall-parse-args (args)
  "Return three values, lists of arg types, values, and result type."
  (let ((return-type :void))
    (loop for (type arg) on args by #'cddr
          if arg collect (convert-foreign-type type) into types
             and collect arg into values
          else do (setf return-type (convert-foreign-type type))
          finally (return (values types values return-type)))))

(defmacro %foreign-funcall (name &rest args)
  "Call a foreign function."
  (multiple-value-bind (types values return-type)
      (foreign-funcall-parse-args args)
    #-dffi (foreign-function-inline-form name types values return-type)
    #+dffi (foreign-function-dynamic-form name types values return-type)))

;;;# Foreign Libraries

(defun %load-foreign-library (name)
  "Load a foreign library from NAME."
  (ffi:load-foreign-library name))

;;;# Callbacks

(defmacro %defcallback (name rettype arg-names arg-types &body body)
  (with-unique-names (cb-sym)
    `(progn
       (ffi:defcallback (,cb-sym :cdecl)
			,(convert-foreign-type rettype)
			,(mapcar #'list arg-names
                                 (mapcar #'convert-foreign-type arg-types))
			,@body)
       (setf (get ',name 'callback-ptr)
	     (ffi:callback ',cb-sym)))))

;;;# Foreign Globals

(defun foreign-symbol-ptr (name kind)
  "Returns a pointer to a foreign symbol NAME. KIND is one of
:CODE or :DATA, and is ignored on some platforms."
  (declare (ignore kind))
  (si:find-foreign-symbol name :default :pointer-void 0))
