;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; cffi-corman.lisp --- CFFI-SYS implementation for Corman Lisp.
;;;
;;; Copyright (C) 2005, Luis Oliveira  <loliveira(@)common-lisp.net>
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
  (:use #:common-lisp #:c-types #:cffi-utils)
  (:export
   #:pointerp
   #:null-ptr
   #:null-ptr-p
   #:inc-ptr
   #:%foreign-alloc
   #:foreign-free
   #:with-foreign-ptr
   #:%foreign-funcall
   #:%foreign-type-alignment
   #:%foreign-type-size
   #:%load-foreign-library
   #:%mem-ref
   ;#:make-shareable-byte-vector
   ;#:with-pointer-to-vector-data
   #:foreign-var-ptr
   #:defcfun-helper-forms
   #:make-callback))

(in-package #:cffi-sys)

;;;# Mis-*features*
(eval-when (:compile-toplevel :load-toplevel :execute)
  (pushnew :cffi/no-foreign-funcall *features*))

;;;# Basic Pointer Operations

(defun pointerp (ptr)
  "Return true if PTR is a foreign pointer."
  (cpointerp ptr))

(defun null-ptr ()
  "Return a null pointer."
  (create-foreign-ptr))

(defun null-ptr-p (ptr)
  "Return true if PTR is a null pointer."
  (cpointer-null ptr))

(defun inc-ptr (ptr offset)
  "Return a pointer pointing OFFSET bytes past PTR."
  (let ((new-ptr (create-foreign-ptr)))
    (setf (cpointer-value new-ptr)
          (+ (cpointer-value ptr) offset))
    new-ptr))

;;;# Allocation
;;;
;;; Functions and macros for allocating foreign memory on the stack
;;; and on the heap.  The main CFFI package defines macros that wrap
;;; FOREIGN-ALLOC and FOREIGN-FREE in UNWIND-PROTECT for the common usage
;;; when the memory has dynamic extent.

(defun %foreign-alloc (size)
  "Allocate SIZE bytes on the heap and return a pointer."
  (malloc size))

(defun foreign-free (ptr)
  "Free a PTR allocated by FOREIGN-ALLOC."
  (free ptr))

(defmacro with-foreign-ptr ((var size &optional size-var) &body body)
  "Bind VAR to SIZE bytes of foreign memory during BODY.  The
pointer in VAR is invalid beyond the dynamic extent of BODY, and
may be stack-allocated if supported by the implementation.  If
SIZE-VAR is supplied, it will be bound to SIZE during BODY."
  (unless size-var
    (setf size-var (gensym "SIZE")))
  `(let* ((,size-var ,size)
          (,var (malloc ,size-var)))
     (unwind-protect
          (progn ,@body)
       (free ,var))))
     
;;;# Shareable Vectors
;;;
;;; This interface is very experimental.  WITH-POINTER-TO-VECTOR-DATA
;;; should be defined to perform a copy-in/copy-out if the Lisp
;;; implementation can't do this.

;(defun make-shareable-byte-vector (size)
;  "Create a Lisp vector of SIZE bytes can passed to
;WITH-POINTER-TO-VECTOR-DATA."
;  (make-array size :element-type '(unsigned-byte 8)))
;
;(defmacro with-pointer-to-vector-data ((ptr-var vector) &body body)
;  "Bind PTR-VAR to a foreign pointer to the data in VECTOR."
;  `(sb-sys:without-gcing
;     (let ((,ptr-var (sb-sys:vector-sap ,vector)))
;       ,@body)))

;;;# Dereferencing

;; According to the docs, Corman's C Function Definition Parser
;; converts int to long, so we'll assume that.
(defun convert-foreign-type (type-keyword)
  "Convert a CFFI type keyword to a CormanCL type."
  (ecase type-keyword
    (:char             :char)
    (:unsigned-char    :unsigned-char)
    (:short            :short)
    (:unsigned-short   :unsigned-short)
    (:int              :long)
    (:unsigned-int     :unsigned-long)
    (:long             :long)
    (:unsigned-long    :unsigned-long)
    (:float            :single-float)
    (:double           :double-float)
    (:pointer          :handle)
    (:void             :void)))

(defun %mem-ref (ptr type &optional (offset 0))
  "Dereference an object of TYPE at OFFSET bytes from PTR."
  (ecase type
    (:char             (cref (:char *) ptr offset))
    (:unsigned-char    (cref (:unsigned-char *) ptr offset))
    (:short            (cref (:short *) ptr offset))
    (:unsigned-short   (cref (:unsigned-short *) ptr offset))
    (:int              (cref (:long *) ptr offset))
    (:unsigned-int     (cref (:unsigned-long *) ptr offset))
    (:long             (cref (:long *) ptr offset))
    (:unsigned-long    (cref (:unsigned-long *) ptr offset))
    (:float            (cref (:single-float *) ptr offset))
    (:double           (cref (:double-float *) ptr offset))
    (:pointer          (cref (:handle *) ptr offset))))

;(define-compiler-macro %mem-ref (&whole form ptr type &optional (offset 0))
;  (if (constantp type)
;      `(cref (,(convert-foreign-type type) *) ,ptr ,offset)
;      form))

(defun (setf %mem-ref) (value ptr type &optional (offset 0))
  "Set the object of TYPE at OFFSET bytes from PTR."
  (ecase type
    (:char             (setf (cref (:char *) ptr offset) value))
    (:unsigned-char    (setf (cref (:unsigned-char *) ptr offset) value))
    (:short            (setf (cref (:short *) ptr offset) value))
    (:unsigned-short   (setf (cref (:unsigned-short *) ptr offset) value))
    (:int              (setf (cref (:long *) ptr offset) value))
    (:unsigned-int     (setf (cref (:unsigned-long *) ptr offset) value))
    (:long             (setf (cref (:long *) ptr offset) value))
    (:unsigned-long    (setf (cref (:unsigned-long *) ptr offset) value))
    (:float            (setf (cref (:single-float *) ptr offset) value))
    (:double           (setf (cref (:double-float *) ptr offset) value))
    (:pointer          (setf (cref (:handle *) ptr offset) value))))

;;;# Calling Foreign Functions

(defun %foreign-type-size (type-keyword)
  "Return the size in bytes of a foreign type."
  (sizeof (convert-foreign-type type-keyword)))

;; Couldn't find anything in sys/ffi.lisp and the C declaration parser
;; doesn't seem to care about alignment so we'll assume that it's the
;; same as its size.
(defun %foreign-type-alignment (type-keyword)
  (sizeof (convert-foreign-type type-keyword)))

(defun find-dll-containing-function (name)
  "Searches for NAME in the loaded DLLs. If found, returns
the DLL's name (a string), else returns NIL."
  (dolist (dll ct::*dlls-loaded*)
    (when (ignore-errors
            (ct::get-dll-proc-address name (ct::dll-record-handle dll)))
      (return (ct::dll-record-name dll)))))

;; This won't work at all...
;(defmacro %foreign-funcall (name &rest args)
;  (let ((sym (gensym)))
;    `(let (,sym)
;       (ct::install-dll-function ,(find-dll-containing-function name)
;                                 ,name ,sym)
;       (funcall ,sym ,@(loop for (type arg) on args by #'cddr
;                             if arg collect arg)))))

;; It *might* be possible to implement by copying
;; most of the code from Corman's DEFUN-DLL.
(defmacro %foreign-funcall (name &rest args)
  "Call a foreign function NAME passing arguments ARGS."
  `(format t "~&;; Calling ~A with args ~S.~%" ,name ',args))

(defun defcfun-helper-forms (name lisp-name rettype args types)
  "Return 2 values for DEFCFUN. A prelude form and a caller form."
  (let ((ff-name (intern (format nil "%cffi-foreign-function/~A" lisp-name)))
        ;; XXX This will only work if the dll is already loaded, fix this.
        (dll (find-dll-containing-function name)))
    (values
     `(defun-dll ,ff-name
          ,(mapcar (lambda (type)
                     (list (gensym) (convert-foreign-type type)))
                   types)
        :return-type ,(convert-foreign-type rettype)
        :library-name ,dll
        :entry-name ,name
        ;; we want also :pascal linkage type to access
        ;; the win32 api for instance..
        :linkage-type :c)
     `(,ff-name ,@args))))

;;;# Callbacks

;; defun-c-callback vs. defun-direct-c-callback?
(defmacro make-callback (name rettype arg-names arg-types body-form)
  (declare (ignore rettype))
  (let ((cb-sym (callback-symbol-name name)))
    `(progn
       (defun-c-callback ,cb-sym
           ,(mapcar (lambda (sym type) (list sym (convert-foreign-type type)))
                            arg-names arg-types)
         ,body-form)
       (get-callback-procinst ',cb-sym))))

;;;# Loading Foreign Libraries

(defun %load-foreign-library (name)
  "Load the foreign library NAME."
  (ct::get-dll-record name))

;;;# Foreign Globals

;; FFI to GetProcAddress from the Win32 API.
;; "The  GetProcAddress function retrieves the address of an exported
;; function or variable from the specified dynamic-link library (DLL)."
(defun-dll get-proc-address
    ((module HMODULE)
     (name LPCSTR))
  :return-type FARPROC
  :library-name "Kernel32.dll"
  :entry-name "GetProcAddress"
  :linkage-type :pascal)

(defmacro foreign-var-ptr (name)
  "Return a pointer pointing to the foreign variable NAME."
  `(let ((str (lisp-string-to-c-string ,name)))
     (unwind-protect
          (dolist (dll ct::*dlls-loaded*)
            (let ((ptr (get-proc-address
                        (int-to-foreign-ptr (ct::dll-record-handle dll))
                        str)))
              (when (not (cpointer-null ptr))
                (return ptr))))
       (free str))))