;;; cui-tests-block.el --- test  -*- lexical-binding: t -*-

;; Copyright (C) 2025 github.com/Anoncheg1,codeberg.org/Anoncheg
;; Author: <github.com/Anoncheg1,codeberg.org/Anoncheg>
;; SPDX-License-Identifier: AGPL-3.0-or-later

;;; License

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Affero General Public License for more details.

;; You should have received a copy of the GNU Affero General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; Licensed under the GNU Affero General Public License, version 3 (AGPLv3)
;; <https://www.gnu.org/licenses/agpl-3.0.en.html>

;;; Commentary:

;; ## To run these tests:
;; 1. Save the code to an .el file (e.g., `cui-params-test.el`).
;; 2. Open Emacs and load the file: `M-x load-file RET cui-tests2.el RET`.
;; 3. Run all tests: `M-x ert RET t RET`.
;;    Or run specific tests: `M-x ert RET cui-block--let-params-macro-all-from-info RET`.
;; OR
;; to run: emacs -Q --batch -l ert.el -l cui-debug.el -l cui-block.el -l ./tests/cui-tests-block.el -f ert-run-tests-batch-and-exit
;; OR
;; M-x ert RET t RET
;; OR
;; (eval-buffer)
;; (ert t)

;;; Code:

(require 'cui-block)
(require 'ert)             ; Testing framework
(defvar ert-enabled nil)
;; -=-= Helper function to set up a temporary Org buffer for testing.

(defun cui-tests-block-insert-block ()
  ;; (mark-whole-buffer) ; output Mark set
  (kill-region (point-min) (point-max))
  ;; (call-interactively #'kill-region)
  (insert "#+begin_ai\n")
  (let ((p1 (point)))
    (insert "test\n#+end_ai")
    (goto-char p1)))

;; It inserts content and optional Org properties, then returns the
;; parsed Cui block element and its parameters alist.
;; (defun cui-test-setup-buffer (block-content &optional properties-alist)
;;   "Create a temporary Org buffer with BLOCK-CONTENT and optional PROPERTIES-ALIST.
;; PROPERTIES-ALIST should be an alist like '((property-name . \"value\")).
;; Returns a list (ELEMENT INFO-ALIST), where ELEMENT is the parsed Cui block
;; and INFO-ALIST is the parameters from its header."
;;   (let ((buf (generate-new-buffer "*cui-test-temp*")))
;;     (with-current-buffer buf
;;       (org-mode)
;;       (setq-local org-export-with-properties t) ; Ensure properties are considered
;;       (when properties-alist
;;         (dolist (prop properties-alist)
;;           (insert (format "#+PROPERTY: %s %s\n" (car prop) (cdr prop)))))
;;       (insert block-content)
;;       (goto-char (point-min))
;;       ;; Move point to the start of the cui block to ensure `org-element-at-point` works
;;       ;; and `org-entry-get-with-inheritance` can find properties.
;;       (search-forward "#+begin_ai")
;;       (let* ((element (org-element-at-point))
;;              ;; org-element-property :parameters returns a plist, which alist-get works on.
;;              (info-alist (org-element-property :parameters element)))
;;         element))))

(defun cui-test-setup-buffer (block-content &optional buf properties-alist)
  "Create cui block-CONTENT and optional PROPERTIES-ALIST.
In current buffer or in BUF.
PROPERTIES-ALIST should be an alist like ((property-name . \"value\")).
Set cursor at begining of buffer.
Returns a list (ELEMENT INFO-ALIST), where ELEMENT is the parsed Cui block
and INFO-ALIST is the parameters from its header."
  (with-current-buffer (or buf (current-buffer))
    (setq-local org-export-with-properties t) ; Ensure properties are considered
    (when properties-alist
      (dolist (prop properties-alist)
        (insert (format "#+PROPERTY: %s %s\n" (car prop) (cdr prop)))))
    (insert block-content)
    (goto-char (point-min))
    ;; Check if #+begin_ai exists to avoid search failure
    (unless (string-match-p "#\\+begin_ai" block-content)
      (error "Test setup failed: block-content does not contain '#+begin_ai'"))
    ;; Move point to the start of the cui block
    (unless (search-forward "#+begin_ai" nil t)
      (error "Failed to find '#+begin_ai' in buffer"))
    (beginning-of-line) ; Ensure point is at the start of the block
    (when (derived-mode-p 'org-mode)
      (let* ((element (org-element-at-point)))
        (unless (eq (org-element-type element) 'special-block)
          (error "No valid Cui block found at point"))
        element)))) ; return

;; (cui-test-setup-buffer "#+begin_ai\nTest content\n#+end_ai")


;; -=-= test for test

(ert-deftest cui-tests-block--setup-buffer-basic-test ()
  "Test that `cui-test-setup-buffer' sets up a buffer correctly."
  (with-temp-buffer
    (org-mode)
    (let* ((block-content "#+begin_ai\nTest content\n#+end_ai")
           (element (cui-test-setup-buffer block-content)))
      (should (eq (org-element-type element) 'special-block))
      (should (equal (org-element-property :type element) "ai")))))

;; -=-= Test for `cui-block--let-params-macro'
(ert-deftest cui-tests-block--let-params-all-from-info-test1 ()
  "Test when all parameters are provided in the block header (info alist)."
  (with-temp-buffer
    (org-mode)
    (let* ((test-block "#+begin_ai :stream t :stream1 t :sys \"A helpful LLM.\" :stream2 :max-tokens 50 :max-tokens2 :model \"gpt-3.5-turbo\" :model1 :model2 t :model3 :temperature 0.7\n#+end_ai\n")
           (element (cui-test-setup-buffer test-block))
           (info (progn (goto-char (org-element-property :begin element)) (cui-block-get-info))))
      ;; (unwind-protect
      ;; Position point inside the block for correct context, though not strictly needed for info directly.
      (let ((stream (cui-block--get-val info :stream "STREAM" nil 'string))
            (stream1 (cui-block--get-val info :stream1 "STREAM1" t 'bool))
            (stream2 (cui-block--get-val info :stream2 "STREAM2" 0 'number))
            (stream3 (cui-block--get-val info :stream3 "STREAM3" 1 'number))
            (sys (cui-block--get-val info :sys "SYS" nil 'string))
            (max-tokens (cui-block--get-val info :max-tokens "MAX-TOKENS" nil 'integer))
            (max-tokens2 (cui-block--get-val info :max-tokens2 "MAX-TOKENS2" 10 'integer))
            (model (cui-block--get-val info :model "MODEL" nil 'string))
            (model1 (cui-block--get-val info :model1 "MODEL1" nil 'string))
            (model2 (cui-block--get-val info :model2 "MODEL2" 10 'number))
            (model4 (cui-block--get-val info :model4 "MODEL4" nil 'number))
            (model3 (cui-block--get-val info :model3 "MODEL3" nil 'string))
            (temperature (cui-block--get-val info :temperature "TEMPERATURE" nil 'float))
            (unknown (cui-block--get-val info :unknown nil "s" )))
                                         ;; (print (list "model3" (type-of model3) model3 )))))
                                   ;; (print (list "stream2" (type-of stream2) stream2 ))
                                   ;; (print (list "stream3" (type-of stream3) stream3 ))
                                   ;; (print (list "max-tokens" (type-of max-tokens) max-tokens ))
                                   ;; (print (list "max-tokens2" (type-of max-tokens2) max-tokens2 ))
                                   ;; (print (list "stream1" stream1))
                                   (should (eq stream1 t))
                                   (should (= stream3 1))
                                   (should (eq stream2 nil))
                                   (should (eq max-tokens2 t))
                                   (should (string-equal stream "t"))
                                   (should (= max-tokens 50))
                                   (should (string-equal sys "A helpful LLM."))
                                   (should (string-equal model "gpt-3.5-turbo"))
                                   (should (= temperature 0.7))
                                   (should (string-equal unknown "s"))
                                   (should (string-equal model1 nil))
                                   (should (= model2 0))
                                   (should (string-equal model4 nil))
                                   (should (string-equal model3 nil))))))

(ert-deftest cui-tests-block--let-params-all-from-info-strings ()
  "Test when all parameters are provided in the block header (info alist)."
  (with-temp-buffer
    (org-mode)
    (let* ((test-block "#+begin_ai :sys nil :sys1 \n#+end_ai\n")
           (element (cui-test-setup-buffer test-block))
           (default "ss")
           (info (progn (goto-char (org-element-property :begin element)) (cui-block-get-info))))
      ;; (unwind-protect
      ;; Position point inside the block for correct context, though not strictly needed for info directly.
      (let ((sys (cui-block--get-val info		:sys "SYS" default 'string))
            (sys1 (cui-block--get-val info		:sys1 "SYS1" default 'string))
            (sys2 (cui-block--get-val info		:sys2 "SYS2" default 'string)))
        (should-not sys)
        (should-not sys1)
        (should (string-equal sys2 default))))))


(ert-deftest cui-tests-block--let-params-all-from-info-test2 ()
  (cl-letf (((symbol-function 'org-entry-get-with-inheritance) ; used in cui-block--get-val
             (lambda (_) nil)))
    (let ((info '((:model)
                  (:model1 . "nil")
                  (:stream1 . "nil")
                  (:stream2 . t)
                  ;; (:stream3)
                  (:stream4)
                  )))
      (let ((model   (cui-block--get-val info :model   nil   nil 'string))
            (model1  (cui-block--get-val info :model1  nil  nil 'string))
            (model2  (cui-block--get-val info :model2  nil  nil 'string))
            (stream  (cui-block--get-val info :stream  nil  nil 'bool))
            (stream1 (cui-block--get-val info :stream1 nil nil 'bool))
            (stream2 (cui-block--get-val info :stream2 nil nil 'bool))
            (stream3 (cui-block--get-val info :stream3 nil t   'bool))
            (stream4 (cui-block--get-val info :stream4 nil nil 'bool)))
        (should (string-equal model nil))
        (should (equal model1 nil))
        (should (equal model2 nil))
        (should (equal stream nil))
        (should (string-equal stream1 nil))
        (should (equal stream2 t))
        (should (equal stream3 t))
        (should (equal stream4 t))
        ))))

;; (defun cui-block--cui-restapi-request-prepare (req-type content element sys-prompt sys-prompt-for-all-messages model max-tokens top-p temperature frequency-penalty presence-penalty service stream)
;;   )
;; -=-= Test for `cui-block--pipeline-macro'
(ert-deftest cui-tests-block--pipeline-macro-test ()
  (let ((foo 10)
        (bar 3)
        (func1 nil)
        (funcs
         (list (lambda (plist) (plist-put plist :foo (+ (plist-get plist :foo) 1)))
               (lambda (plist) (plist-put plist :bar (* (plist-get plist :bar) 2)))))
        res)

    (setq res (cui-block--pipeline-macro (foo bar) funcs))
    (should (equal res '(11 6)))

    (setq res (cui-block--pipeline-macro (foo nil)
                               (list (lambda (plist) (plist-put plist :foo (+ (plist-get plist :foo) 1))))))
    (should (equal res '(11 nil)))
    (setq res (cui-block--pipeline-macro (nil bar)
                                         (list (lambda (plist) (plist-put plist :bar (* (plist-get plist :bar) 2))))))
    (should (equal res '(nil 6)))

    ;; func is nil
    (should (equal (cui-block--pipeline-macro (foo bar) func1)
                   '(10 3)))
    (should (equal (cui-block--pipeline-macro (foo bar) nil)
                   '(10 3)))))

;; -=-= cui-agent-call
;; (ert-deftest cui-tests-block--cui-agent-call-test ()

;;   (let* ((test-block "#+begin_ai :stream t :sys \"A helpful LLM.\" :max-tokens 50 :model \"gpt-3.5-turbo\" :temperature 0.7\n\n#+end_ai\n")
;;          (cui-agent-call #'cui-block--cui-restapi-request-prepare)
;;          ;; - setup test buffer
;;          (element (cui-test-setup-buffer test-block))
;;          (info)
;;          (marker (copy-marker (org-element-property :contents-end element)))
;;          (buffer (org-element-property :buffer element))
;;          evaluated-result)
;;     ;; (unwind-protect
;;         (with-current-buffer buffer
;;           ;; - set cursor
;;           (goto-char (org-element-property :begin element))
;;           ;; (print (list "element" (org-element-property :contents-begin element)))

;;           (let ((cui-agent-call (lambda (req-type element sys-prompt sys-prompt-for-all-messages model max-tokens top-p temperature frequency-penalty presence-penalty service stream)
;;                                      ;; (print (list 'req-type (type-of req-type) req-type))
;;                                      ;; (print (list 'element (type-of element) element))
;;                                      ;; (print (list 'sys-prompt (type-of sys-prompt) sys-prompt))
;;                                      ;; (print (list 'sys-prompt-for-all-messages (type-of sys-prompt-for-all-messages) sys-prompt-for-all-messages))
;;                                      ;; (print (list 'model (type-of model) model))
;;                                      ;; (print (list 'max-tokens (type-of max-tokens) max-tokens))
;;                                      ;; (print (list 'top-p (type-of top-p) top-p))
;;                                      ;; (print (list 'temperature (type-of temperature) temperature))
;;                                      ;; (print (list 'frequency-penalty (type-of frequency-penalty) frequency-penalty))
;;                                      ;; (print (list 'presence-penalty (type-of presence-penalty) presence-penalty))
;;                                      ;; ;; (print (list 'service (type-of service) service))
;;                                      ;; (print (list 'stream (type-of stream) stream))
;;                                      ;; (should (and (eql req-type 'chat) (eql (type-of req-type) 'symbol) ))
;;                                      ;; (should (org-element-type element 'special-block))
;;                                      ;; (should (eql (type-of element) 'cons))
;;                                      ;; (should (eql (type-of sys-prompt) 'string))
;;                                      ;; (should (string= sys-prompt "A helpful LLM."))
;;                                      ;; (should (and (eql (type-of sys-prompt-for-all-messages) 'symbol) (null sys-prompt-for-all-messages)))
;;                                      ;; (should (and (eql (type-of model) 'string) (string= model "gpt-3.5-turbo")))
;;                                      ;; (should (and (eql (type-of max-tokens) 'integer) (= max-tokens 50)))
;;                                      ;; (should (and (eql (type-of top-p) 'symbol) (null top-p)))
;;                                      ;; (should (and (eql (type-of temperature) 'float) (= temperature 0.7)))
;;                                      ;; (should (and (eql (type-of frequency-penalty) 'symbol) (null frequency-penalty)))
;;                                      ;; (should (and (eql (type-of presence-penalty) 'symbol) (null presence-penalty)))
;;                                      ;; ;; (should (and (eql (type-of service) 'symbol)
;;                                      ;; ;;              (= service 'openai)))
;;                                      ;; (should (and (eql (type-of stream) 'symbol) (eql stream t)))
;;                                                   ;; (string-equal stream "t"))
;;                                      ;; (print (list req-type content element sys-prompt sys-prompt-for-all-messages model max-tokens top-p temperature frequency-penalty presence-penalty service stream))
;;                                      )))
;;             (cui-ctrl-c-ctrl-c)
;;             )
;;           ;; (cui-interface-step1)

;;       (kill-buffer buffer)
;;       )
;;       ;; )
;;     )
;;   (should t)
;;   )


;; (ert-deftest cui-tests-block--let-params-inherited-properties ()
;;   "Test when parameters are sourced from inherited Org properties."
;;   (let* ((test-block "#+begin_ai\n#+end_ai\n") ; No parameters in block header
;;          (setup-result (cui-test-setup-buffer test-block
;;                                                  '((model . "text-davinci-003")
;;                                                    (max-tokens . "100")
;;                                                    (temperature . "0.5")
;;                                                    (sys . "Inherited system prompt"))))
;;          (element (car setup-result))
;;          (info (cadr setup-result)) ; Empty info from block header
;;          evaluated-result)
;;     (unwind-protect
;;         (with-current-buffer (marker-buffer (org-element-property :begin element))
;;           ;; Position point inside the block for `org-entry-get-with-inheritance`
;;           (goto-char (org-element-property :begin element))
;;           (setq evaluated-result
;;                 (cui-test-eval-macro
;;                  '(cui-block--let-params-macro info
;;                                             ((stream nil) ; default `nil`
;;                                              (sys nil)    ; no default, inherited from property
;;                                              (max-tokens nil :type number)
;;                                              (model nil)
;;                                              (temperature nil :type number))
;;                                             (list stream sys max-tokens model temperature))
;;                  element info)))
;;       (kill-buffer (marker-buffer (org-element-property :begin element))))
;;     (should (equal (car evaluated-result) nil)) ; No stream property or default
;;     (should (equal (cadr evaluated-result) "Inherited system prompt")) ; From inherited property
;;     (should (equal (caddr evaluated-result) 100)) ; From inherited property, converted to number
;;     (should (equal (nth 3 evaluated-result) "text-davinci-003")) ; From inherited property, no conversion (model is special)
;;     (should (equal (nth 4 evaluated-result) 0.5))) ; From inherited property, converted to number
;;   )

;; (ert-deftest cui-tests-block--let-params-default-form ()
;;   "Test when parameters fall back to default forms."
;;   (let* ((test-block "#+begin_ai\n#+end_ai\n") ; No block params, no inherited props
;;          (setup-result (cui-test-setup-buffer test-block))
;;          (element (car setup-result))
;;          (info (cadr setup-result)) ; Empty info
;;          evaluated-result)

;;     (unwind-protect
;;         (with-current-buffer (marker-buffer (org-element-property :begin element))
;;           (goto-char (org-element-property :begin element))
;;           (setq evaluated-result
;;                 (cui-test-eval-macro
;;                  '(cui-block--let-params-macro info
;;                     ((stream t) ; Default true
;;                      (sys "Default system prompt")
;;                      (max-tokens 200 :type number)
;;                      (model "default-model-name")
;; (temperature 0.8 :type number)
;;                      (non-existent-param "fallback-value")) ; Test a parameter not in definitions
;;                     (list stream sys max-tokens model temperature non-existent-param))
;;                  element info)))
;;       (kill-buffer (marker-buffer (org-element-property :begin element))))
;;     (should (equal (car evaluated-result) t))
;;     (should (equal (cadr evaluated-result) "Default system prompt"))
;;     (should (equal (caddr evaluated-result) 200))
;;     (should (equal (nth 3 evaluated-result) "default-model-name"))
;;     (should (equal (nth 4 evaluated-result) 0.8))
;;     ;; Note: `non-existent-param` is not in definitions, so it won't be bound by `let-params`.
;;     ;; This `list` will cause an error because `non-existent-param` is not defined.
;;     ;; The macro itself only binds variables listed in `definitions`.
;;     ;; Removing `non-existent-param` from the test list.
;;     ))

;; -=-= Test: `cui-block-fill-region-as-paragraph'
(ert-deftest cui-tests-block--cui-block-fill-region-as-paragraph ()
  (should (with-temp-buffer
            (progn
              (org-mode)
              (setq fill-column 10)
              (insert "Some.\n")
              (insert "Some text here asdasdasdasd asda asd asd asd asd asd asd as d\n")
              (insert "Some.\n")
              (goto-char 1)
              (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max) nil)
              (let ((strings (string-split (buffer-substring-no-properties (point-min) (point-max)) "\n")))
                (< (length (nth 1 strings)) 10))))))
;; -=-=  Test Markdown header regex cui-block--markdown-header-re
(ert-deftest cui-tests-block--markdown-header-re ()
  (equal
   (with-temp-buffer
     (let ((str "## Core Concepts"))
       (with-temp-buffer
         (insert str)
         (goto-char (point-min))
         (when (re-search-forward cui-block--markdown-header-re nil t)
           (list (match-string 1) (match-string 2) (match-string 3) (match-beginning 2))))))
   (list "##" nil "Core Concepts" nil))

  (equal
   (with-temp-buffer
     (let ((str "## 1. Core Concepts"))
       (with-temp-buffer
         (insert str)
         (goto-char (point-min))
         (when (re-search-forward cui-block--markdown-header-re nil t)
           (list (match-string 1) (match-string 2) (match-string 3))))))
   (list "##" "1." "Core Concepts"))

  (equal
   (with-temp-buffer
     (let ((str "## a)"))
       (with-temp-buffer
         (insert str)
         (goto-char (point-min))
         (when (re-search-forward cui-block--markdown-header-re nil t)
           (list (match-string 1) (match-string 2) (match-string 3))))))
   (list "##" "a)" "")))
;; ;; ;; returns: ("##" "a)" "")

;; -=-= Test: `cui-block--find-region-with-position'
(ert-deftest cui-tests-block--find-region-with-position ()
  ;;  Basic inside region
  (should (equal (cui-block--find-region-with-position '(10 20 30) 15) '((10 . 20) . 0))) ; => (10 . 20)

  (should (equal (cui-block--find-region-with-position '(10 20) 20) '((10 . 20) . 0)))

  (should (equal (cui-block--find-region-with-position '(10 20 30) 5) nil))
  ;; (should (equal (cui-block--find-region-with-position '(10 20 30 40) 30) nil))
                                        ;
  ;;  Exact boundary at start
  (should (equal (cui-block--find-region-with-position '(10 20 30) 10) '((10 . 20) . 0))) ; => (10 . 20)

  ;;  Exact boundary at end
  (should (equal (cui-block--find-region-with-position '(10 20 30) 20) '((20 . 30) . 1))) ; => (20 . 30)

  ;;  Before first region
  (should (equal (cui-block--find-region-with-position '(10 20 30) 5) nil)) ; => nil

  ;;  After last region
  (should (equal (cui-block--find-region-with-position '(10 20 30) 40) nil)) ; => nil

  ;;  Single region (should return nil, lacking 'end')
  (should (equal (cui-block--find-region-with-position '(10) 10) nil)) ; => nil

  ;;  Multiple regions, gaps between, check middle gap
  (should (equal (cui-block--find-region-with-position '(10 20 40 60) 45) '((40 . 60) . 2))) ; => (40 . 60)
  )
;; -=-= Test: `cui-block--insert-stream-response'

(ert-deftest cui-tests-block--insert-stream-response ()
  (with-temp-buffer

    (let* ((role-payload "assistant")
           (rl (intern role-payload))
           (role-prefix (car (rassoc rl cui-block-roles-prefixes)))
           res)

    (cui-block--insert-stream-response (copy-marker (point))
                                         (list (make-cui-block--response :type 'role :payload role-payload)))
    ;; (print (concat "\n[" role-prefix  "]: \n"))
    (setq res (buffer-substring-no-properties (point-min) (point-max)))
    ;; (my/diff-strings res (concat "\n[" role-prefix  "]: \n"))))
    ;; (print role-prefix)))
    (string-equal res (concat "\n[" role-prefix  "]: \n")))))

;; -=-= Test: `cui-block-tags--in-markdown-quotes-at-line-p'
(defun cui-tests-block--test--with-temp-buffer-at-pos (text pos func)
  (with-temp-buffer
    (insert text)
    (goto-char (point-min))
    (forward-char pos)
    (funcall func (point))))

;; 1. No backquotes
;; Help function:
(defun cui-block--markdown-quotes-single-p (pos)
  "Return t if POS is inside a markdown single backquote (`...`).
On current line or at quote itself."
  (cui-block--markdown-quotes-at-line-p pos "`"))


;; 4. Position exactly on first backquote
(ert-deftest cui-tests-block--in-markdown-quotes-at-line-p-on-first-backquote ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "`code`" 0 #'cui-block--markdown-quotes-single-p)))

;; 5. Multiple regions – inside second
(ert-deftest cui-tests-block--in-markdown-quotes-at-line-p-multiple-second-region ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "`foo` and `bar`" 12 #'cui-block--markdown-quotes-single-p)))


;; 1. None present: Should NOT be inside for any
(ert-deftest cui-block--markdown-quotes-single-p-no-quotes ()
  (should-not (cui-tests-block--test--with-temp-buffer-at-pos "foobar" 2 #'cui-block--markdown-quotes-single-p)))

;; help function:
(defun cui-block--markdown-triple-quotes-p (pos)
  "Return t if POS is inside a markdown triple backquote (```...```).
On current line or at quote itself."
  (cui-block--markdown-quotes-at-line-p pos "```"))


(ert-deftest cui-block--markdown-triple-quotes-p-no-quotes ()
  (should-not (cui-tests-block--test--with-temp-buffer-at-pos "foobar" 2 #'cui-block--markdown-triple-quotes-p)))
(ert-deftest cui-block--markdown-quotes-p-no-quotes ()
  (should-not (cui-tests-block--test--with-temp-buffer-at-pos "foobar" 2 #'cui-block--markdown-quotes-p)))
;; 2. Only one backquote
(ert-deftest cui-block--markdown-quotes-single-p-one-backquote ()
  (should-not (cui-tests-block--test--with-temp-buffer-at-pos "`foobar" 2 #'cui-block--markdown-quotes-single-p)))
(ert-deftest cui-block--markdown-triple-quotes-p-one-triple-backquote ()
  (should-not (cui-tests-block--test--with-temp-buffer-at-pos "```foobar" 4 #'cui-block--markdown-triple-quotes-p)))
(ert-deftest cui-block--markdown-quotes-p-one-backquote ()
  (should-not (cui-tests-block--test--with-temp-buffer-at-pos "`foobar" 2 #'cui-block--markdown-quotes-p)))
(ert-deftest cui-block--markdown-quotes-p-one-triple-backquote ()
  (should-not (cui-tests-block--test--with-temp-buffer-at-pos "```foobar" 4 #'cui-block--markdown-quotes-p)))
;; 3. Strictly inside single and triple region
(ert-deftest cui-block--markdown-quotes-single-p-inside ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "`code`" 2 #'cui-block--markdown-quotes-single-p)))
(ert-deftest cui-block--markdown-triple-quotes-p-inside ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "```code```" 5 #'cui-block--markdown-triple-quotes-p)))
(ert-deftest cui-block--markdown-quotes-p-inside-single ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "`code`" 2 #'cui-block--markdown-quotes-p)))
(ert-deftest cui-block--markdown-quotes-p-inside-triple ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "```code```" 5 #'cui-block--markdown-quotes-p)))
;; 4. On first quote of region
(ert-deftest cui-block--markdown-quotes-single-p-on-first-backquote ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "`code`" 0 #'cui-block--markdown-quotes-single-p)))
(ert-deftest cui-block--markdown-triple-quotes-p-on-first-backquote ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "```code```" 0 #'cui-block--markdown-triple-quotes-p)))
(ert-deftest cui-block--markdown-quotes-p-on-first-single-backquote ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "`code`" 0 #'cui-block--markdown-quotes-p)))
(ert-deftest cui-block--markdown-quotes-p-on-first-triple-backquote ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "```code```" 0 #'cui-block--markdown-quotes-p)))

;; ## E. Multiple regions, inside second
(ert-deftest cui-block--markdown-quotes-single-p-multiple-second-region ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "`foo` and `bar`" 12 #'cui-block--markdown-quotes-single-p)))

;; Triple quotes: strictly inside second region
(ert-deftest cui-block--markdown-triple-quotes-p-multiple-second-region ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "```foo``` and ```bar```" 18 #'cui-block--markdown-triple-quotes-p)))

;; Any quotes: strictly inside second region, single quotes
(ert-deftest cui-block--markdown-quotes-p-multiple-second-region-single ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "`foo` and `bar`" 12 #'cui-block--markdown-quotes-p)))

;; Any quotes: strictly inside second region, triple quotes
(ert-deftest cui-block--markdown-quotes-p-multiple-second-region-triple ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "```foo``` and ```bar```" 18 #'cui-block--markdown-quotes-p)))

;; ## G. Empty region (strictly between two quotes)
(ert-deftest cui-block--markdown-quotes-single-p-empty-region ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "``" 1 #'cui-block--markdown-quotes-single-p)))

;; Triple quotes: empty region
(ert-deftest cui-block--markdown-triple-quotes-p-empty-region ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "``````" 3 #'cui-block--markdown-triple-quotes-p)))

;; Any quotes: empty region single
(ert-deftest cui-block--markdown-quotes-p-empty-region-single ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "``" 1 #'cui-block--markdown-quotes-p)))

;; Any quotes: empty region triple
(ert-deftest cui-block--markdown-quotes-p-empty-region-triple ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "``````" 3 #'cui-block--markdown-quotes-p)))

;; ## H. At first quote of empty region
;; Single quotes: on first backquote
(ert-deftest cui-block--markdown-quotes-single-p-empty-region-at-first ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "``" 0 #'cui-block--markdown-quotes-single-p)))

;; Triple quotes: on first triple backquote
(ert-deftest cui-block--markdown-triple-quotes-p-empty-region-at-first ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "``````" 0 #'cui-block--markdown-triple-quotes-p)))

;; Any quotes: on first of single
(ert-deftest cui-block--markdown-quotes-p-empty-region-at-first-single ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "``" 0 #'cui-block--markdown-quotes-p)))

;; Any quotes: on first of triple
(ert-deftest cui-block--markdown-quotes-p-empty-region-at-first-triple ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "``````" 0 #'cui-block--markdown-quotes-p)))

;; ## I. Mixed region: both types present - t
;; Cursor inside single-quote region, both present
(ert-deftest cui-block--markdown-quotes-p-mixed-single-inside ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "`foo` and ```bar```" 2 #'cui-block--markdown-quotes-p)))

;; Cursor inside triple-quote region, both present
(ert-deftest cui-block--markdown-quotes-p-mixed-triple-inside ()
  (should (cui-tests-block--test--with-temp-buffer-at-pos "`foo` and ```bar```" 10 #'cui-block--markdown-quotes-p)))

;; Cursor in plain in-between (should not match)
(ert-deftest cui-block--markdown-quotes-p-mixed-outside ()
  (should-not (cui-tests-block--test--with-temp-buffer-at-pos "`foo` and ```bar```" 7 #'cui-block--markdown-quotes-p)))

;; Cursor in plain in-between (should not match)
(ert-deftest cui-block--markdown-quotes-p-mixed-outside2 ()
  (should-not (cui-tests-block--test--with-temp-buffer-at-pos "ss`foo` and ```bar```" 0 #'cui-block--markdown-quotes-p)))


;; -=-= Test: `cui-block-mark-at-point'
(ert-deftest cui-tests-block--mark-at-point ()
    (with-temp-buffer
      ;; (setq ert-enabled nil)
      (org-mode)
      (transient-mark-mode)
      (let (p1 p2
            (cui-restapi-con-token '(:openai "test-token-openai"))
            res)
        (insert "#+begin_ai :max-tokens 100 :stream nil :sys \"Be helpful\"  :service github :model \"openai\"\n")
        (setq p1 (point))
        (insert "```elisp\n")
        (insert "as\n")
        (setq p2 (point))
        (insert "```\n#+end_ai")
        (goto-char p1)
        (call-interactively #'cui-block-mark-at-point)
        (setq res (list (region-beginning) (region-end)))
        (should (equal res '(100 102)))
        (deactivate-mark)
        (goto-char p2)
        (call-interactively #'cui-block-mark-at-point)
        (setq res (list (region-beginning) (region-end)))
        (should (equal res '(100 102)))
        (call-interactively #'cui-block-mark-at-point)
        (setq res (list (region-beginning) (region-end)))
        (should (equal res '(91 106)))
        (call-interactively #'cui-block-mark-at-point)
        (setq res (list (region-beginning) (region-end)))
        (should (equal (list (region-beginning) (region-end)) '(1 115)))
        (call-interactively #'cui-block-mark-at-point)
        (setq res (list (region-beginning) (region-end)))
        (should (equal (list (region-beginning) (region-end)) '(1 115)))
        )))
;; -=-= Test: `cui-block--insert-single-response'


;; (defun my/diff-strings (str1 str2)
;;   "Return and print verbose diff between STR1 and STR2 as a list."
;;   (let* ((len1 (length str1))
;;         (len2 (length str2))
;;         (maxlen (max len1 len2))
;;         (diffs '()))
;;     (dotimes (i maxlen)
;;       (let ((c1 (if (< i len1) (aref str1 i) nil))
;;             (c2 (if (< i len2) (aref str2 i) nil)))
;;         (unless (equal c1 c2)
;;           (let ((d (list i
;;                          (if c1 (format "%S" (string c1)) "<none>")
;;                          (if c2 (format "%S" (string c2)) "<none>"))))
;;             (push d diffs)
;;             (message "Difference at index %d: %s vs %s"
;;                      i (nth 1 d) (nth 2 d))))))
;;     (unless diffs (message "No differences found"))
;;     (nreverse diffs)))

;; (my/diff-strings "hello" "hxlpo")


(ert-deftest cui-tests-block--insert-single-response ()
  (with-temp-buffer
    ;; (setq ert-enabled nil)
    (org-mode)
    ;; (cui-mode)
    (transient-mark-mode)
    (let ((fill-called nil)
          res)
      (let ( ;cui-block-fill-function
            (cui-block-fill-function (lambda(pos stream)
                                       (setq fill-called t)
                                       ))
            (fill-column 3)
            p1)
        ;; - Test 1
        (cui-tests-block-insert-block) ; output "Mark set"
        (cui-block--insert-single-response
         (cui-block--get-content-end-marker (cui-block-p))
         "asd asd asd asd"
         t nil)
        (setq res (buffer-substring-no-properties (point-min)
                                                  (point-max)))

        ;; (my/diff-strings res "#+begin_ai\ntest\n\n[ai]: asd asd asd asd\n\n[ME]: \n#+end_ai")

        (should (string-equal res "#+begin_ai\ntest\n\n[ai]: asd asd asd asd\n\n[ME]: \n#+end_ai"))
        (should (eq 47 (point)))
        (should fill-called)
        ;; - Test 2
        (setq fill-called nil)
        (cui-tests-block-insert-block)
        (cui-block--insert-single-response
         (cui-block--get-content-end-marker (cui-block-p))
         "asd asd asd asd"
         t t)
        (setq res (buffer-substring-no-properties (point-min)
                                                  (point-max)))
        (should (string-equal res "#+begin_ai\ntest\n\n[ai]: asd asd asd asd\n\n[ME]: \n#+end_ai"))
        (should (eq 47 (point)))
        (should-not fill-called)

        ;; - Test 3
        (setq fill-called nil)
        (cui-tests-block-insert-block)
        (cui-block--insert-single-response
         (cui-block--get-content-end-marker (cui-block-p))
         "asd asd asd asd"
         nil t)
        (setq res (buffer-substring-no-properties (point-min)
                                                  (point-max)))
        (should (string-equal res "#+begin_ai\ntest\n\n[ai]: asd asd asd asd\n#+end_ai"))
        (should (eq 40 (point)))
        (should-not fill-called)

        ;; - Test 4
        (setq fill-called nil)
        (cui-tests-block-insert-block)
        (cui-block--insert-single-response
         (cui-block--get-content-end-marker (cui-block-p))
         "asd asd asd asd"
         nil nil)
        (setq res (buffer-substring-no-properties (point-min)
                                                  (point-max)))
        (should (string-equal res "#+begin_ai\ntest\n\n[ai]: asd asd asd asd\n#+end_ai"))
        (should (eq 40 (point)))
        (should fill-called)

        ;; - Test 5 - nil
        (setq fill-called nil)
        (cui-tests-block-insert-block)
        (cui-block--insert-single-response
         (cui-block--get-content-end-marker (cui-block-p))
         nil
         nil nil)
        (setq res (buffer-substring-no-properties (point-min)
                                                  (point-max)))
        (should (string-equal res "#+begin_ai\ntest\n#+end_ai"))
        ;; (print (point)))))
        (should (eq 12 (point)))
        (should-not fill-called)

        ;; - Test 5 - ""
        (setq fill-called nil)
        (cui-tests-block-insert-block)
        (cui-block--insert-single-response
         (cui-block--get-content-end-marker (cui-block-p))
         nil
         nil nil)
        (setq res (buffer-substring-no-properties (point-min)
                                                  (point-max)))
        (should (string-equal res "#+begin_ai\ntest\n#+end_ai"))
        ;; (print (point)))))
        (should (eq 12 (point)))
        (should-not fill-called)))))
;; -=-= Test: `cui-block--chat-role-regions'
(ert-deftest cui-tests-block--chat-role-regions-in-org ()
  (with-temp-buffer
    ;; (setq ert-enabled nil)
    (org-mode)
    ;; (cui-mode)
    (transient-mark-mode)
    (cui-tests-block-insert-block)
    (insert "Test\n[AI]: bla\n[ME]: aaa\nvvv")
    (should (equal (cui-block--chat-role-regions) '(12 17 27 45))))

  (with-temp-buffer
    ;; (setq ert-enabled nil)
    (org-mode)
    ;; (cui-mode)
    (transient-mark-mode)
    (cui-tests-block-insert-block)
    (insert "[ME]: Test\n[AI]: bla\n[ME]: aaa\nvvv")
    (let (res)
      (setq res (cui-block--chat-role-regions))
    (should (equal res '(12 23 33 51))))))

(ert-deftest cui-tests-block--chat-role-regions-in-fundamental ()
  (with-temp-buffer
    (insert "Test\n[AI]: bla\n[ME]: aaa\nvvv")
    (let (res)
      (setq res (cui-block--chat-role-regions))
    (should (equal res '(1 6 16 29)))))
  (with-temp-buffer
    (insert "[ME]: Test\n[AI]: bla\n[ME]: aaa\nvvv")
    (let (res)
      (setq res (cui-block--chat-role-regions))
    (should (equal res '(1 12 22 35))))))

;; -=-= Test: `cui-block--markdown-block-p1'
(ert-deftest cui-tests-block--pos-in-markdown-block-p-org ()
  (with-temp-buffer
    ;; (setq ert-enabled nil)
    (org-mode)
    ;; (cui-mode)
    (transient-mark-mode)
    (cui-tests-block-insert-block)
    (let (p1 p2 p3 p4 p5 p6 res)
      (insert "Test")
      (setq p1 (point))
      (insert "\n[AI]: \n```elisp\n")
      (setq p2 (point))
      (insert "asd1\n```\n")
      (setq p3 (point))
      (insert "[ME]: aaa\n```\na")
      (setq p4 (point))
      (insert "sd1\n```\n")
      (setq p5 (point))
      (insert "vvv\n")
      (setq p6 (point))
      (insert "sd1\n```\nvvv")
      (goto-char (point-min))
      (should (equal (cui-block--markdown-block-p) nil))
      (goto-char p1)
      (setq res (cui-block--markdown-block-p))
      (should (equal res nil))
      (goto-char p2)
      (setq res (cui-block--markdown-block-p))
      (should (equal res '(24 . 38)))
      (goto-char p3)
      (setq res (cui-block--markdown-block-p))
      (should (equal res nil))
      (goto-char p4)
      (setq res (cui-block--markdown-block-p))
      (should (equal res '(52 . 61)))
      (goto-char p5)
      (setq res (cui-block--markdown-block-p))
      (should (equal res nil))
      (goto-char (point-max))
      (setq res (cui-block--markdown-block-p))
      (should (equal res nil)))))

(ert-deftest cui-tests-block--pos-in-markdown-block-p-not-org ()
  (with-temp-buffer
    ;; (setq ert-enabled nil)
    ;; (cui-mode)
    (fundamental-mode)
    ;; (transient-mark-mode)
    ;; (cui-tests-block-insert-block)
    (let (p1 p2 p3 p4 p5 res)
      (insert "Test")
      (setq p1 (point))
      (insert "\n[AI]: \n```elisp\n")
      (setq p2 (point))
      (insert "asd1\n```\n")
      (setq p3 (point))
      (insert "[ME]: aaa\n```elisp\na")
      (setq p4 (point))
      (insert "sd1\n```\nvvv\n")
      (setq p5 (point))
      (insert "sd1\n```\nvvv")
      (goto-char (point-min))
      (should (equal (cui-block--markdown-block-p) nil))
      (goto-char p1)
      (setq res (cui-block--markdown-block-p))
      (should (equal res nil))
      (goto-char p2)
      (setq res (cui-block--markdown-block-p))
      (should (equal res '(13 . 27)))
      (goto-char p3)
      (setq res (cui-block--markdown-block-p))
      (should (equal res nil))
      (goto-char p4)
      (setq res (cui-block--markdown-block-p))
      (should (equal res '(41 . 55)))
      (goto-char p5)
      (setq res (cui-block--markdown-block-p))
      (should (equal res nil))
      (goto-char (point-max))
      (setq res (cui-block--markdown-block-p))
      (should (equal res nil)))))

(ert-deftest cui-tests-block--pos-in-markdown-block-p3 ()
  (let (kill-buffer-query-functions
        org-execute-file-search-functions
        points
        res)

    (with-temp-buffer
      (org-mode)
      (add-hook 'org-execute-file-search-functions (intern "org-links-additional-formats"))
      (insert "#+begin_ai :max-tokens 100 :stream nil :sys \"Be helpful\"  :service github :model \"openai\"\n#+end_ai")
      (goto-char (point-min))
      (setq res (cui-block--markdown-block-p (point-min) (point-max)))
      ;; (cui-block-tags--markdown-mark-fenced-code-body))))
      (should-not res))

    (with-temp-buffer
      (let (p1 p2 p3 p4 p5 p6)
        (goto-char (point-min))
        (insert "#+begin_ai :max-tokens 100 :stream nil :sys \"Be helpful\"  :service github :model \"openai\"")
        (setq p1 (point))
        (insert "\n")
        (setq p2 (point))
        (insert "```elisp")
        (setq p3 (point))
        (insert "\n\n\n")
        ;; (print (point))
        (setq p4 (point))
        (insert "```")
        (setq p5 (point))
        (insert "\n")
        (setq p6 (point))
        (insert "#+end_ai")
        (insert "\n")
        (goto-char p1)
        (setq res (cui-block--markdown-block-p (point-min) (point-max)))
        (should-not res)
        (goto-char p2)
        (setq res (cui-block--markdown-block-p (point-min) (point-max)))
        ;; (should-not res
        (should (equal res '(91 . 102)))
        (goto-char p3)
        (setq res (cui-block--markdown-block-p (point-min) (point-max)))
        (should (equal res '(91 . 102)))
        (goto-char p4)
        (setq res (cui-block--markdown-block-p (point-min) (point-max)))
        (should (equal res '(91 . 102)))
        (goto-char p5)
        (setq res (cui-block--markdown-block-p (point-min) (point-max)))
        (should (equal res '(91 . 102)))
        (goto-char p6)
        (setq res (cui-block--markdown-block-p (point-min) (point-max)))
        (should-not res)))))


;; -=-= Test: `cui-block--markdown-block-p2'
(ert-deftest cui-tests--cui-block--markdown-block-p2-range1 ()
  "Test fenced code detection."
  (let ((payload "text before
```elisp
code block
line2
```
text after"))
    (with-temp-buffer
      (insert payload)
      ;; Move point to inside the code block
      (goto-char (point-min))
      (re-search-forward "code block")
      (beginning-of-line)
      (forward-line -1)
      (let ((limit-begin (point-min))
            (limit-end (point-max))
            range)
        (setq range (cui-block--markdown-block-p
                     limit-begin limit-end))
        (should (equal range (cons 13 39)))))))

(ert-deftest cui-tests--cui-block--markdown-block-p2-range2 ()
  "Test fenced code detection."
(let ((payload "text before
```elisp
```
code block
line2
```
text after"))
    (with-temp-buffer
      (insert payload)
      ;; Move point to inside the code block
      (goto-char (point-min))
      (re-search-forward "code block")
      (let* ((limit-begin (point-min))
             (limit-end (point-max))
             range)
        (setq range (cui-block--markdown-block-p
                     limit-begin limit-end))
        (should
        (equal range nil))))))

;; (ert-deftest cui-tests--cui-block--markdown-block-p2-range3 ()
;;   (should (equal '(39 41)
;;                  (with-temp-buffer
;;                    (org-mode)
;;                    (insert "#+NAME: asd\n#+begin_src text\n```elisp")
;;                    (let ((p (point)))
;;                      (insert "\naa\n```\n#+end_src\n")
;;                      (goto-char p)
;;                      (cui-block--markdown-block-p)))
;;                  )))



;; -=-= Test: `cui-block--apply-noweb'
(ert-deftest cui-tests-block--apply-noweb ()
  (let (kill-buffer-query-functions
        org-execute-file-search-functions
        points
        res)
    (with-temp-buffer
      (org-mode)
      (insert "#+NAME: ina
#+begin_ai
test
#+end_ai


#+begin_ai
<<ina()>>
#+end_ai")
      (setq res (cui-block--apply-noweb "<<ina()>> aa <<ina()>> bb"))
      (should (equal res #("test
 aa test
 bb" 0 5 (face region) 9 14 (face region)))
      ))))

;; -=-= Test: `cui-block--markdown-block-regions'
(ert-deftest cui-tests-block--markdown-subblocks-regions1 ()
  (should
   (equal
    '(2 26 30 39)
    (with-temp-buffer
      (insert "
  ```elisp
```text
test
```
```elisp
```\n")
      (cui-block--markdown-block-regions (point-min) (point-max))))))

(ert-deftest cui-tests-block--markdown-subblocks-regions2 ()
  (should
   (equal
    (with-temp-buffer
      (insert "```elisp
```text
test
```
as
```")
      (let ((reg (cui-block--markdown-block-regions (point-min) (point-max))))
        (buffer-substring (car reg) (cadr reg))))
    "```elisp
```text
test
")))

(ert-deftest cui-tests-block--markdown-subblocks-regions3 ()
  (should
   (equal
    '(2 26 30 44)
    (with-temp-buffer
      (insert "
  ```elisp
```text
test
```
```elisp
sasd\n")
      (cui-block--markdown-block-regions (point-min) (point-max))))))

(ert-deftest cui-tests-block--markdown-subblocks-regions4 ()
  (should
   (equal
    '(2 26)
    (with-temp-buffer
      (insert "
  ```elisp
```text
test
```
```
sasd\n")
      (cui-block--markdown-block-regions (point-min) (point-max))))))

;; -=-= Test: `cui-block-fill-insert'
(defvar cui-tests-block--fill-insert-insert-text "Give ASCII tree representing the evolution of Homo sapiens.


[ai]:
Homo sapiens do not evolve in a tree structure in the way one might think—evolution is a branching process, and \"ASCII tree\" representations are typically used for data structures or phylogenies. However, if we interpret your request as asking for an **ASCII representation of the phylogenetic tree** showing the evolutionary lineage of *Homo sapiens*, then here's a simplified, accurate, and visually clear ASCII tree—without rectangles:
```
         |                           |
     Paranthropus                 Homo habilis
```
**Note**: This is a simplified and educational ASCII tree showing key hominin ancestors leading to *Homo sapiens*. The actual evolutionary path involves many species, migrations, and overlapping lineages. Modern *Homo sapiens* evolved in Africa around 300,000 years ago and spread globally. This is a simplified and educational ASCII tree showing key hominin ancestors leading to *Homo sapiens*. The actual evolutionary path involves many species, migrations, and overlapping lineages. Modern *Homo sapiens* evolved in Africa around 300,000 years ago and spread globally.

```elisp
         |                           |
     Paranthropus                 Homo habilis
```
This version avoids rectangles and uses only text-based branches and nodes. This version avoids rectangles and uses only text-based branches and nodes.
")

(ert-deftest cui-tests-block--fill-insert ()
  ;; (with-current-buffer (generate-new-buffer "test")
  (with-temp-buffer
    (org-mode)
    ;; insert text and fill region
    (cui-tests-block-insert-block)
    (forward-line)
    (insert cui-tests-block--fill-insert-insert-text)
    (let ((fill-column 30)
          (m-range '(507 597 1174 1269))
          ;; (cui-block-tags--markdown-block-regions
          ;;  cui-tests-block--fill-insert-insert-text)
          (m-sub1 (substring cui-tests-block--fill-insert-insert-text
                             507 597))
          (m-sub2 (substring cui-tests-block--fill-insert-insert-text
                             1174 1269))
          )
      ;; m-sub1))
      (cui-block-fill-insert 84)

      ;; check that everthing is correct.
      ;; 1) check that first line not modified.
      (goto-char (point-min))
      (should (= 76 (re-search-forward "Give ASCII tree representing the evolution of Homo sapiens." nil t)))
      ;; 2) check if both markdown is not touched.
      (goto-char (point-min))
      (let* ((range (cui-block--markdown-block-regions (point-min) (point-max)))
             (bs (buffer-substring-no-properties (point-min) (point-max)))
             (mb-sub1 (substring bs (1- (nth 0 range)) (1- (nth 1 range))))
             (mb-sub2 (substring bs (1- (nth 2 range)) (1- (nth 3 range)))))
        (should (string-equal m-sub1 mb-sub1))
        (should (string-equal m-sub2 mb-sub2)))
      ;; 3) check that middle line is not as it was
      (goto-char (point-min))
      (should (not (re-search-forward "ote**: This is a simplified and educational ASCII tree showing key hominin ancestors leading to *Homo sapiens*. The actual evolutionary path involves many species, migrations, and overlapping lineages. Modern *Homo sapiens* evolved in Africa around 300,000 years ago and spread globally. This is a simplified and educational ASCII tree showing key hominin ancestors leading to *Homo sapiens*. The actual evolutionary path involves many species, migrations, and overlapping lineages. Modern *Homo sapiens* evolved in Africa ar" nil t)
                   ))
      ;; 4) check that first and end line is not as they was
      (goto-char (point-min))
      (should (not (re-search-forward "Homo sapiens do not evolve in a tree structure in the way one might think—evolution is a branching process" nil t)))
      (goto-char (point-min))
      (should (not (re-search-forward "This version avoids rectangles and uses only text-based branches and nodes. This version avoids rectangles and uses" nil t)))
      )))
;; -=-= Test: `cui-block--find-next-prev-region'
(ert-deftest cui-tests-block--find-next-prev-region ()
  ;; cui-block--find-next-prev-region-forward ()
  ;; move forward 1 region from point=15
  (should (equal (cui-block--find-next-prev-region 1 15 '(10 20 30 40)) 20))

  ;; move forward 2 regions
  (should (equal (cui-block--find-next-prev-region 2 15 '(10 20 30 40)) 30))

  ;; move forward beyond available regions
  (should (equal (cui-block--find-next-prev-region 4 15 '(10 20 30 40)) nil))

  ;; cui-block--find-next-prev-region-backward ()
  ;; move backward 1 region from point=35
  (should (equal (cui-block--find-next-prev-region -1 35 '(10 20 30 40)) 30))

  ;; move backward 2 regions
  (should (equal (cui-block--find-next-prev-region -2 35 '(10 20 30 40)) 20))

  ;; move backward beyond available regions
  (should (equal (cui-block--find-next-prev-region -4 35 '(10 20 30 40)) nil))

  ;; cui-block--find-next-prev-region-edge-boundaries ()
  ;; at the exact first boundary, forward should skip to the next
  (should (equal (cui-block--find-next-prev-region 1 10 '(10 20 30 40)) 20))

  ;; at the exact last boundary, backward should skip to the previous
  (should (equal (cui-block--find-next-prev-region -1 40 '(10 20 30 40)) 30))

  ;; cui-block--find-next-prev-region-empty-or-single-region ()
  ;; regions empty list
  ;; (should (equal (cui-block--find-next-prev-region 1 15 '()) nil))
  ;; regions single element, forward and backward should be nil
  (should (equal (cui-block--find-next-prev-region 1 5 '(10)) 10))
  (should (equal (cui-block--find-next-prev-region -1 15 '(10)) 10))
  (should (equal (cui-block--find-next-prev-region 1 15 '(10)) nil))
  (should (equal (cui-block--find-next-prev-region -1 5 '(10)) nil))

;; (ert-deftest cui-block--find-next-prev-region-nil-arguments ()
  ;; ;; direction and current-point nil; regions list given (assume point = 0)
  ;; (should (equal (cui-block--find-next-prev-region nil nil '(10 20 30)) 10))
  ;; ;; regions nil, should fallback to default, but here returns nil
  ;; (should (equal (cui-block--find-next-prev-region 1 15 nil) nil)))
)
;; -=-= Test: `cui-block--compose-m-block'
(ert-deftest cui-tests-block-tags--compose-m-block ()
  (should
   (string-equal (cui-block--compose-m-block "aaa" :lang "bbb" :header "ccc") "\nccc\n```bbb\naaa\n```"))
  ;; Header are ignored for cui block
  (should
   (string-equal (cui-block--compose-m-block "asda\n[me:] asdas" :lang "ai" :header "some header") "asda\n[me:] asdas"))
  (should
   (string-equal (cui-block--compose-m-block "[me:] asda\n[ai:] asdas" :lang "ai" :header "some header") "[me:] asda\n[ai:] asdas"))
  (should
   (string-equal (cui-block--compose-m-block "Text\nasdas" :lang "ai" :header "Header:")
                 "Text\nasdas"))
  (should
   (string-equal (cui-block--compose-m-block "Text\nasdas" :lang "ai" :header "Header:" :inner t)
                 "\nHeader:\n```ai\nText\nasdas\n```"))
  (should (equal (cui-block--compose-m-block nil :lang "ai" :inner t) nil))
  (should (equal (cui-block--compose-m-block nil :lang "ai" :inner nil) nil))
  (should (equal (cui-block--compose-m-block nil :lang nil :inner t) nil)))

;; -=-= Test: `cui-block--indentation-dedent-string'
(ert-deftest cui-block--indentation-dedent-string-tests ()
  (should (equal (cui-block--indentation-dedent-string "\t a\n\t  b") "\t a\n\t  b"))
  (should (equal (cui-block--indentation-dedent-string "  a\n\t  b") "  a\n\t  b"))
  (should (equal (cui-block--indentation-dedent-string "   a\n   \tb") "a\n\tb"))
  (should (equal (cui-block--indentation-dedent-string "  a\n   b") "a\n b"))
  (should (equal (cui-block--indentation-dedent-string "   a\n b") "  a\nb"))
  (should (equal (cui-block--indentation-dedent-string "   a\n\n b") "  a\n\nb"))
  (should (equal (cui-block--indentation-dedent-string "   a\n \n b") "  a\n\nb"))
  (should (equal (cui-block--indentation-dedent-string "   a\n \t\n b") "  a\n\t\nb"))
  (should (equal (cui-block--indentation-dedent-string "  a\nb ") "  a\nb "))
)

(ert-deftest cui-block--indentation-dedent-string/crlf-input- ()
  ""
  (should (equal (cui-block--indentation-dedent-string "  a\r\n  b\r\n") "a\r\nb\r\n")))

(ert-deftest cui-block--indentation-dedent-string/tab-indent-is-not-stripped ()
  "A line indented with a tab computes indent 0 and blocks dedent."
  (should (equal (cui-block--indentation-dedent-string "    a\n\tb") "    a\n\tb")))

(ert-deftest cui-block--indentation-dedent-string/single-line-with-trailing-newline ()
  "One indented line plus trailing newline round-trips cleanly."
  (should (equal (cui-block--indentation-dedent-string "    x\n") "x\n")))

(ert-deftest cui-block--indentation-dedent-string/spaces-only-single-line-is-noop ()
  "A whitespace-only string is returned verbatim (no min to compute)."
  (should (equal (cui-block--indentation-dedent-string "    ") "    ")))

(ert-deftest cui-block--indentation-dedent-string/dedent-then-reindent-roundtrip ()
  "Dedenting then re-adding the original min indent restores the input,
for non-blank lines."
  (let* ((in  "    a\n      b\n    c")
         (out (cui-block--indentation-dedent-string in)))
    (should (equal (mapconcat (lambda (l) (concat "    " l))
                              (split-string out "\n") "\n")
                   in))))


;; -=-= For `cui-block--indentation-dedent-lines'
(defun cui-block--dedent-in-buffer (s)
  "Run `cui-optional-my-dedent-spaces' on string S via a temp buffer."
  (with-temp-buffer
    (insert s)
    (cui-block--indentation-dedent-lines 1 (line-number-at-pos (point-max)))
    (buffer-string)))

(ert-deftest cui-block--indentation-dedent-lines-tests ()
  (should (equal (cui-block--dedent-in-buffer "\t a\n\t  b") "\t a\n\t  b"))
  (should (equal (cui-block--dedent-in-buffer "  a\n\t  b") "  a\n\t  b"))
  (should (equal (cui-block--dedent-in-buffer "   a\n   \tb") "a\n\tb"))
  (should (equal (cui-block--dedent-in-buffer "  a\n   b") "a\n b"))
  (should (equal (cui-block--dedent-in-buffer "   a\n b") "  a\nb"))
  (should (equal (cui-block--dedent-in-buffer "   a\n\n b") "  a\n\nb"))
  (should (equal (cui-block--dedent-in-buffer "   a\n \n b") "  a\n\nb"))
  (should (equal (cui-block--dedent-in-buffer "   a\n \t\n b") "  a\n\t\nb"))
  (should (equal (cui-block--dedent-in-buffer "  a\nb ") "  a\nb ")))

(ert-deftest cui-block--indentation-dedent-lines/crlf-input- ()
  ""
  (should (equal (cui-block--dedent-in-buffer "  a\r\n  b\r\n") "a\r\nb\r\n")))

(ert-deftest cui-block--indentation-dedent-lines/tab-indent-is-not-stripped ()
  "A line indented with a tab computes indent 0 and blocks dedent."
  (should (equal (cui-block--dedent-in-buffer "    a\n\tb") "    a\n\tb")))

(ert-deftest cui-block--indentation-dedent-lines/single-line-with-trailing-newline ()
  "One indented line plus trailing newline round-trips cleanly."
  (should (equal (cui-block--dedent-in-buffer "    x\n") "x\n")))

(ert-deftest cui-block--indentation-dedent-lines/spaces-only-single-line-is-noop ()
  "A whitespace-only string is returned verbatim (no min to compute)."
  (should (equal (cui-block--dedent-in-buffer "    ") "    ")))

(ert-deftest cui-block--indentation-dedent-lines/dedent-then-reindent-roundtrip ()
  "Dedenting then re-adding the original min indent restores the input,
for non-blank lines."
  (let* ((in  "    a\n      b\n    c")
         (out (cui-block--dedent-in-buffer in)))
    (should (equal (mapconcat (lambda (l) (concat "    " l))
                              (split-string out "\n") "\n")
                   in))))


;; -=-= Test: fill paragraph

(defmacro cui-block-test-with-fill-env (input expected &rest body)
  "Helper macro to isolate temporary buffer setup for filling tests."
  `(with-temp-buffer
     (setq fill-column 20
           fill-prefix "")
     (insert ,input)
     ,@body
     (should (string= (buffer-string) ,expected))))

;; ======================================================================
;; Profile 1: Inline Asterisks Protection Rules
;; ======================================================================

(ert-deftest cui-block-fill-inline-double-asterisks ()
  "Ensure matching double asterisks block line breaking."
  (cui-block-test-with-fill-env
   "Line with **1unbreakabletext** here."
   "Line with\n**1unbreakabletext**\nhere."
   (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max))))

(ert-deftest cui-block-fill-inline-single-asterisks ()
  "Ensure matching single asterisks block line breaking."
  (cui-block-test-with-fill-env
   "Line with *2unbreakabletext* here."
   "Line with\n*2unbreakabletext*\nhere."
   (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max))))

(ert-deftest cui-block-fill-mismatched-asterisks ()
  "Ensure mismatched asterisks are allowed to break naturally."
  (cui-block-test-with-fill-env
   "Line with **3breakabletext* here."
   "Line with\n**3breakabletext*\nhere."
   (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max))))

(ert-deftest cui-block-fill-asterisks-with-punctuation ()
  "Ensure trailing punctuation doesn't break asterisk detection."
  (cui-block-test-with-fill-env
   "Line with **4unbreakabletext**, okay?"
   "Line with\n**4unbreakabletext**,\nokay?"
   (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max))))

(ert-deftest cui-block-fill-asterisks-with-internal-spaces ()
  "Ensure asterisks containing multiple internal words are preserved."
  (cui-block-test-with-fill-env
   "Line with **4unbre akab letext**, okay?"
   "Line with\n**4unbre akab letext**,\nokay?"
   (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max))))

(ert-deftest cui-block-fill-multiple-asterisks-sequences ()
  "Ensure multiple highlighted sequences on a single stretch handle correctly."
  (cui-block-test-with-fill-env
   "**with** **4unbre akab letext**, okay?"
   "**with**\n  **4unbre akab letext**,\n  okay?"
   (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max))))

;; ======================================================================
;; Profile 2: Layout Block Structural Exclusions
;; ======================================================================

(ert-deftest cui-block-fill-blockquote-exclusion ()
  "Ensure email/markdown blockquotes remain entirely un-filled."
  (cui-block-test-with-fill-env
   "> This is a very long blockquote line that exceeds twenty characters."
   "> This is a very long blockquote line that exceeds twenty characters."
   (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max))))

(ert-deftest cui-block-fill-table-pipe-exclusion ()
  "Ensure pipe-separated structural tables are ignored."
  (cui-block-test-with-fill-env
   "| Feature | Status | Long Description Here |"
   "| Feature | Status | Long Description Here |"
   (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max))))

(ert-deftest cui-block-fill-table-grid-exclusion ()
  "Ensure multi-line grid-border markdown/org tables are ignored."
  (cui-block-test-with-fill-env
   "+-+---+---\n| A | B | C |\n+-+---+---+"
   "+-+---+---\n| A | B | C |\n+-+---+---+"
   (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max))))

;; ======================================================================
;; Profile 3: Baseline Normalization
;; ======================================================================

(ert-deftest cui-block-fill-plain-text-fallback ()
  "Ensure normal paragraph sentences fill normally when no rules match."
  (cui-block-test-with-fill-env
   "Line with a verylongbreakablesequence here."
   "Line with a\nverylongbreakablesequence\nhere."
   (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max))))

;; OLD original:
;; (defun my-test-asterisk-filling-robust ()
;;   (interactive)
;;   (with-temp-buffer
;;     (let ((passed t)
;;           (fill-column 20)
;;           (fill-prefix "")
;;           (cases '(;; 1. Standard wrapping behavior
;;                    ("Line with **1unbreakabletext** here." . "Line with\n**1unbreakabletext**\nhere.")
;;                    ("Line with *2unbreakabletext* here."   . "Line with\n*2unbreakabletext*\nhere.")
;;                    ;; 2. Mismatched delimiters SHOULD break if necessary
;;                    ("Line with **3breakabletext* here."    . "Line with\n**3breakabletext*\nhere.")
;;                    ;; 3. Trailing punctuation should not break the logic
;;                    ("Line with **4unbreakabletext**, okay?" . "Line with\n**4unbreakabletext**,\nokay?")
;;                    ("Line with **4unbre akab letext**, okay?" . "Line with\n**4unbre akab letext**,\nokay?")
;;                    ("**with** **4unbre akab letext**, okay?" . "**with**\n  **4unbre akab letext**,\n  okay?")

;;                    ("> This is a very long blockquote line that exceeds twenty characters."
;;                     . "> This is a very long blockquote line that exceeds twenty characters.")

;;                    ;; 3. Tables (Should remain entirely untouched)
;;                    ("| Feature | Status | Long Description Here |"
;;                     . "| Feature | Status | Long Description Here |")
;;                    ("+-+---+---+\n| A | B | C |\n+-+---+---+"
;;                     . "+-+---+---+\n| A | B | C |\n+-+---+---+")
;;                    ;; 5. Plain text without asterisks should break normally
;;                    ("Line with a verylongbreakablesequence here." . "Line with a\nverylongbreakablesequence\nhere."))))
;;       (dolist (c cases)
;;         (erase-buffer)
;;         (insert (car c))
;;         ;; (cui-block-fill-region-as-paragraph (point-min) (point-max))
;;         ;; (let ((fill-nobreak-predicate (cons #'cui-block-fill-predicate-to-nobreak-lines
;;         ;;                                     fill-nobreak-predicate)))
;;           (cui-block--apply-to-region-lines #'fill-region-as-paragraph (point-min) (point-max))
;;         (unless (string= (buffer-string) (cdr c))
;;           (setq passed nil)
;;           (message "FAIL: %S\nGot:  %S\nExp:  %S\n" (car c) (buffer-string) (cdr c))))
;;       (message (if passed "--- ALL ROBUST TESTS PASSED ---" "--- COMPREHENSIVE TESTS FAILED ---")))))

;; (my-test-asterisk-filling-robust)


;; -=-= provide
(provide 'cui-tests-block)

;;; cui-tests-block.el ends here
