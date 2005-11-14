;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; cffi-openmcl.lisp --- CFFI-SYS implementation for OpenMCL.
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
  (:use #:common-lisp #:ccl #:cffi-utils)
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
   #:%foreign-funcall-ptr
   #:%foreign-type-alignment
   #:%foreign-type-size
   #:%load-foreign-library
   #:make-shareable-byte-vector
   #:with-pointer-to-vector-data
   #:foreign-symbol-ptr
   #:%defcallback))
 
(in-package #:cffi-sys)

;;;# Features

(eval-when (:compile-toplevel :load-toplevel :execute)
  #+darwinppc-target (pushnew :darwin *features*)
  #+ppc32-target     (pushnew :ppc32 *features*))

;;;# Allocation
;;;
;;; Functions and macros for allocating foreign memory on the stack
;;; and on the heap.  The main CFFI package defines macros that wrap
;;; FOREIGN-ALLOC and FOREIGN-FREE in UNWIND-PROTECT for the common
;;; usage when the memory has dynamic extent.

(defun pointer-eq (ptr1 ptr2)
  "Return true if PTR1 and PTR2 point to the same address."
  (%ptr-eql ptr1 ptr2))

(defun %foreign-alloc (size)
  "Allocate SIZE bytes on the heap and return a pointer."
  (ccl::malloc size))

(defun foreign-free (ptr)
  "Free a PTR allocated by FOREIGN-ALLOC."
  ;; TODO: Should we make this a dead macptr?
  (ccl::free ptr))

(defmacro with-foreign-ptr ((var size &optional size-var) &body body)
  "Bind VAR to SIZE bytes of foreign memory during BODY.  The
pointer in VAR is invalid beyond the dynamic extent of BODY, and
may be stack-allocated if supported by the implementation.  If
SIZE-VAR is supplied, it will be bound to SIZE during BODY."
  (unless size-var
    (setf size-var (gensym "SIZE")))
  `(let ((,size-var ,size))
     (%stack-block ((,var ,size-var))
       ,@body)))

;;;# Misc. Pointer Operations

(defun null-ptr ()
  "Construct and return a null pointer."
  (%null-ptr))

(defun null-ptr-p (ptr)
  "Return true if PTR is a null pointer."
  (%null-ptr-p ptr))

(defun inc-ptr (ptr offset)
  "Return a pointer OFFSET bytes past PTR."
  (ccl:%inc-ptr ptr offset))

;;;# Shareable Vectors
;;;
;;; This interface is very experimental.  WITH-POINTER-TO-VECTOR-DATA
;;; should be defined to perform a copy-in/copy-out if the Lisp
;;; implementation can't do this.

(defun make-shareable-byte-vector (size)
  "Create a Lisp vector of SIZE bytes that can passed to
WITH-POINTER-TO-VECTOR-DATA."
  (make-array size :element-type '(unsigned-byte 8)))

(defmacro with-pointer-to-vector-data ((ptr-var vector) &body body)
  "Bind PTR-VAR to a foreign pointer to the data in VECTOR."
  `(ccl:with-pointer-to-ivector (,ptr-var ,vector)
     ,@body))

;;;# Dereferencing

;; This shouldn't cons when the result is an immediate.
(defun %mem-ref (ptr type &optional (offset 0))
  "Dereference an object of TYPE at OFFSET bytes from PTR."
  (ecase type
    (:char (%get-signed-byte ptr offset))
    (:unsigned-char (%get-unsigned-byte ptr offset))
    (:short (%get-signed-word ptr offset))
    (:unsigned-short (%get-unsigned-word ptr offset))
    (:int (%get-signed-long ptr offset))
    (:unsigned-int (%get-unsigned-long ptr offset))
    (:long #+ppc32-target (%get-signed-long ptr offset)
           #+ppc64-target (ccl::%%get-signed-longlong ptr offset))
    (:unsigned-long #+ppc32-target (%get-unsigned-long ptr offset)
                    #+ppc64-target (ccl::%%get-unsigned-longlong ptr offset))
    (:long-long (ccl::%get-signed-long-long ptr offset))
    (:unsigned-long-long (ccl::%get-unsigned-long-long ptr offset))
    (:float (%get-single-float ptr offset))
    (:double (%get-double-float ptr offset))
    (:pointer (%get-ptr ptr offset))))

(define-compiler-macro %mem-ref (&whole form ptr type &optional (offset 0))
  "Compiler macro to open-code when TYPE is constant."
  (if (constantp type)
      (progn
        #-(and) (format t "~&;; Open-coding %MEM-REF form: ~S~%" form)
        (ecase (eval type)
          (:char `(%get-signed-byte ,ptr ,offset))
          (:unsigned-char `(%get-unsigned-byte ,ptr ,offset))
          (:short `(%get-signed-word ,ptr ,offset))
          (:unsigned-short `(%get-unsigned-word ,ptr ,offset))
          (:int `(%get-signed-long ,ptr ,offset))
          (:unsigned-int `(%get-unsigned-long ,ptr ,offset))
          (:long
           #+ppc32-target `(%get-signed-long ,ptr ,offset)
           #+ppc64-target `(ccl::%%get-signed-longlong  ,ptr ,offset))
          (:unsigned-long
           #+ppc32-target `(%get-unsigned-long ,ptr ,offset)
           #+ppc64-target `(ccl::%%get-unsigned-longlong ,ptr ,offset))
          (:long-long `(ccl::%get-signed-long-long ,ptr ,offset))
          (:unsigned-long-long `(ccl::%get-unsigned-long-long ,ptr ,offset))
          (:float `(%get-single-float ,ptr ,offset))
          (:double `(%get-double-float ,ptr ,offset))
          (:pointer `(%get-ptr ,ptr ,offset))))
      form))

(define-setf-expander %mem-ref (ptr type &optional (offset 0) &environment env)
  "SETF expander for %MEM-REF that doesn't rebind TYPE.
This is necessary for the compiler macro on %MEM-SET to be able
to open-code (SETF %MEM-REF) forms."
  (multiple-value-bind (dummies vals newval setter getter)
      (get-setf-expansion ptr env)
    (declare (ignore setter newval))
    (with-unique-names (store type-tmp offset-tmp)
      (values
       (append (unless (constantp type)   (list type-tmp))
               (unless (constantp offset) (list offset-tmp))
               dummies)
       (append (unless (constantp type)   (list type))
               (unless (constantp offset) (list offset))
               vals)
       (list store)
       `(progn
          (%mem-set ,store ,getter
                   ,@(if (constantp type)   (list type)   (list type-tmp))
                   ,@(if (constantp offset) (list offset) (list offset-tmp)))
          ,store)
       `(%mem-ref ,getter
                 ,@(if (constantp type)   (list type)   (list type-tmp))
                 ,@(if (constantp offset) (list offset) (list offset-tmp)))))))

(defun %mem-set (value ptr type &optional (offset 0))
  "Set an object of TYPE at OFFSET bytes from PTR."
  (ecase type
    (:char (setf (%get-signed-byte ptr offset) value))
    (:unsigned-char (setf (%get-unsigned-byte ptr offset) value))
    (:short (setf (%get-signed-word ptr offset) value))
    (:unsigned-short (setf (%get-unsigned-word ptr offset) value))
    (:int (setf (%get-signed-long ptr offset) value))
    (:unsigned-int (setf (%get-unsigned-long ptr offset) value))
    (:long (setf
            #+ppc32-target (%get-signed-long ptr offset)
            #+ppc64-target (ccl::%%get-signed-longlong ptr offset)
            value))
    (:unsigned-long (setf
                     #+ppc32-target (%get-unsigned-long ptr offset)
                     #+ppc64-target (ccl::%%get-unsigned-longlong ptr offset)
                     value))
    (:long-long (setf (ccl::%get-signed-long-long ptr offset) value))
    (:unsigned-long-long (setf (ccl::%get-unsigned-long-long ptr offset) value))
    (:float (setf (%get-single-float ptr offset) value))
    (:double (setf (%get-double-float ptr offset) value))
    (:pointer (setf (%get-ptr ptr offset) value))))

(define-compiler-macro %mem-set (&whole form value ptr type &optional (offset 0))
  "Compiler macro to open-code when TYPE is constant."
  (if (constantp type)
      (progn
        #-(and) (format t "~&;; Open-coding (SETF %MEM-REF) form: ~S~%" form)
        (ecase (eval type)
          (:char `(setf (%get-signed-byte ,ptr ,offset) ,value))
          (:unsigned-char `(setf (%get-unsigned-byte ,ptr ,offset) ,value))
          (:short `(setf (%get-signed-word ,ptr ,offset) ,value))
          (:unsigned-short `(setf (%get-unsigned-word ,ptr ,offset) ,value))
          (:int `(setf (%get-signed-long ,ptr ,offset) ,value))
          (:unsigned-int `(setf (%get-unsigned-long ,ptr ,offset) ,value))
          (:long
           #+ppc32-target `(setf (%get-signed-long ,ptr ,offset) ,value)
           #+ppc64-target `(setf (ccl::%%get-signed-longlong ,ptr ,offset)
                            ,value))
          (:unsigned-long
           #+ppc32-target `(setf (%get-unsigned-long ,ptr ,offset) ,value)
           #+ppc64-target `(setf (ccl::%%get-unsigned-longlong ,ptr ,offset)
                            ,value))
          (:long-long `(setf (ccl::%get-signed-long-long ,ptr ,offset) ,value))
          (:unsigned-long-long
           `(setf (ccl::%get-unsigned-long-long ,ptr ,offset) ,value))
          (:float `(setf (%get-single-float ,ptr ,offset) ,value))
          (:double `(setf (%get-double-float ,ptr ,offset) ,value))
          (:pointer `(setf (%get-ptr ,ptr ,offset) ,value))))
      form))

;;;# Calling Foreign Functions

(defun convert-foreign-type (type-keyword)
  "Convert a CFFI type keyword to an OpenMCL type."
  (ecase type-keyword
    (:char                :signed-byte)
    (:unsigned-char       :unsigned-byte)
    (:short               :signed-short)
    (:unsigned-short      :unsigned-short)
    (:int                 :signed-int)
    (:unsigned-int        :unsigned-int)
    (:long                :signed-long)
    (:unsigned-long       :unsigned-long)
    (:long-long           :signed-doubleword)
    (:unsigned-long-long  :unsigned-doubleword)
    (:float               :single-float)
    (:double              :double-float)
    (:pointer             :address)
    (:void                :void)))

(defun %foreign-type-size (type-keyword)
  "Return the size in bytes of a foreign type."
  (/ (ccl::foreign-type-bits
      (ccl::parse-foreign-type
       (convert-foreign-type type-keyword))) 8))

;; There be dragons here.  See the following thread for details:
;; http://clozure.com/pipermail/openmcl-devel/2005-June/002777.html
(defun %foreign-type-alignment (type-keyword)
  "Return the alignment in bytes of a foreign type."
  (/ (ccl::foreign-type-alignment
      (ccl::parse-foreign-type
       (convert-foreign-type type-keyword))) 8))

(defun convert-foreign-funcall-types (args)
  "Convert foreign types for a call to FOREIGN-FUNCALL."
  (loop for (type arg) on args by #'cddr
        collect (convert-foreign-type type)
        if arg collect arg))

(defun convert-external-name (name)
  "Add an underscore to NAME if necessary for the ABI."
  #+darwinppc-target (concatenate 'string "_" name)
  #-darwinppc-target name)

(defmacro %foreign-funcall (function-name &rest args)
  "Perform a foreign function call, document it more later."
  `(external-call
    ,(convert-external-name function-name)
    ,@(convert-foreign-funcall-types args)))

(defmacro %foreign-funcall-ptr (ptr &rest args)
  `(ff-call ,ptr ,@(convert-foreign-funcall-types args)))

;;;# Callbacks

(defmacro %defcallback (name rettype arg-names arg-types &body body)
  (with-unique-names (cb-sym)
    `(progn
       (defcallback ,cb-sym (,@(mapcan (lambda (sym type)
                                         (list (convert-foreign-type type) sym))
                                       arg-names arg-types)
                               ,(convert-foreign-type rettype))
           ,@body)
       (setf (get ',name 'callback-ptr) (symbol-value ',cb-sym)))))

;;;# Loading Foreign Libraries

(defun %load-foreign-library (name)
  "Load the foreign library NAME."
  (open-shared-library name))

;;;# Foreign Globals

(defun foreign-symbol-ptr (name kind)
  "Returns a pointer to a foreign symbol NAME. KIND is one of
:CODE or :DATA, and is ignored on some platforms."
  (declare (ignore kind))
  (foreign-symbol-address (convert-external-name name)))