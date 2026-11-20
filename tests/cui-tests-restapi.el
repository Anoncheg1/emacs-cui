;;; cui-tests-restapi.el --- Tests. -*- lexical-binding: t; -*-

;; Copyright (c) 2025 github.com/Anoncheg1,codeberg.org/Anoncheg
;; SPDX-License-Identifier: AGPL-3.0-or-later
;; Author: github.com/Anoncheg1,codeberg.org/Anoncheg

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
;;
;; $ emacs -Q --batch -l ert.el -l cui-debug.el -l cui-block-tags.el -l cui-block.el -l cui-timers.el -l cui-async1.el -l cui-restapi.el -l ./tests/cui-tests-restapi.el -f ert-run-tests-batch-and-exit
;; or

;; (eval-buffer)
;; (ert t)

;;; Code:
;; -=-= imports
(require 'ert)
(require 'cui-block-tags) ; for cui-tests-restapi--replace-images
(require 'cui-restapi)
(defvar ert-enabled nil)

;; -=-= For `cui-restapi--get-token' (old)

;; (require 'cui) ;; Assuming the function is defined in cui.el

(ert-deftest cui-tests-restapi--get-token-string ()
  "Test when cui-restapi-con-token is a non-empty string."
  (let ((cui-restapi-con-token "test-token-123"))
    (should (equal (cui-restapi--get-token 'openai) "test-token-123")))) ; ignored

(ert-deftest cui-tests-restapi--get-token-plist-valid-test ()
  "Test when cui-restapi-con-token is a plist with valid service token."
  (let ((cui-restapi-con-token '(:openai "test-token-openai" :anthropic "test-token-anthropic")))
    (should (equal (cui-restapi--get-token :openai) "test-token-openai"))))

;; (let ((cui-restapi-con-token '(:openai "test-token-openai" :anthropic "test-token-anthropic")))
;;     (cui-restapi--get-token :openai))

(ert-deftest cui-tests-restapi--get-token-plist-invalid-test ()
  "Test when cui-restapi-con-token is a plist without the service token."
  (let ((cui-restapi-con-token '(:anthropic "test-token-anthropic")))
    (let ((err (cadr
                (should-error (cui-restapi--get-token :openai) :type 'error))))
      (should (eql 0 (string-match "Token not found" err))))))

;; (let ((cui-restapi-con-token '(:anthropic "test-token-anthropic")))
;;   (cui-restapi--get-token :openai))

;; (ert-deftest cui-tests-restapi--get-token-auth-source-test ()
;;   "Test when token is retrieved from auth-source."
;;   (let ((cui-restapi-con-token "")
;;         (auth-sources '((:host "api.openai.com" :user "user" :secret "auth-token-123"))))
;;     (fset 'cui-restapi--get-token-auth-source (lambda (service) "auth-token-123"))
;;     (should (equal (cui-restapi--get-token 'openai) "auth-token-123"))
;;     (fmakunbound 'cui-restapi--get-token-auth-source)))


(ert-deftest cui-tests-restapi--get-token-auth-source-test ()
  "Test when token is retrieved from auth-source."
  (let* ((cui-restapi-con-token "")
         (auth-sources '((:host "api.openai.com" :user "user" :secret "auth-token-123")))
         (orig-fn (symbol-function 'cui-restapi--get-token-auth-source)))
    (unwind-protect
        (progn
          (fset 'cui-restapi--get-token-auth-source (lambda (service) (setq service service) "auth-token-123"))
          (should (equal (cui-restapi--get-token 'openai) "auth-token-123")))
      (fset 'cui-restapi--get-token-auth-source orig-fn))))

;; (ert-deftest cui-tests-restapi--get-token-no-valid-token-test ()
;;   "Test when no valid token is provided."
;;   (let ((cui-restapi-con-token "")
;;         (auth-sources nil))
;;     (fset 'cui-restapi--get-token-auth-source (lambda (service) nil))
;;     (let ((err (cadr
;;                 (should-error (cui-restapi--get-token :openai) :type 'error))))
;;       ;; (print err)
;;       (should (eql 0 (string-match "Please set" err))))

;;     )
;;     (fmakunbound 'cui-restapi--get-token-auth-source))

(ert-deftest cui-tests-restapi--get-token-no-valid-token-test ()
  "Test when no valid token is provided."
  (let ((cui-restapi-con-token "")
        (auth-sources nil)
        (orig-fn (symbol-function 'cui-restapi--get-token-auth-source)))
    (unwind-protect
        (progn
          (fset 'cui-restapi--get-token-auth-source (lambda (service) (setq service service) nil))

          (should-error (cui-restapi--get-token :openai) :type 'user-error)
            ;; (print err)))))

          ;; - 2)
          (setq cui-restapi-con-token '(:asd nil))
          (should-error (cui-restapi--get-token :openai) :type 'error))
      (fset 'cui-restapi--get-token-auth-source orig-fn))))
;;;
;; -=-= For `cui-restapi--get-token'
;; Dummy function for auth-source behavior
;; (defun cui-restapi--get-token-auth-source (service) nil)

(ert-deftest cui-tests-restapi--get-token/string ()
  "Single string in `cui-restapi-con-token` returns value."
  (let ((cui-restapi-con-token "tok123"))
    (should (equal (cui-restapi--get-token "foo") "tok123"))))

;; (ert-deftest cui-tests-restapi--get-token/empty-string-error ()
;;   "Empty string errors out."
;;   (let ((cui-restapi-con-token ""))
;;     (let ((err (cadr
;;                 (should-error (cui-restapi--get-token :openai) :type 'error))))
;;       ;; (print err)
;;       (should (eql 0 (string-match "Please set" err)))
;;       )))

(ert-deftest cui-tests-restapi--get-token/plist-string ()
  "Plist with symbol key, single string."
  (let ((cui-restapi-con-token '(:foo "tokfoo")))
    (should (equal (cui-restapi--get-token "foo") "tokfoo"))))

(ert-deftest cui-tests-restapi--get-token/set-to-nil ()
  "Neither string, plist nor auth-source: signals error."
  (should (not
           (let ((cui-restapi-con-token '(:local nil)))
             (cui-restapi--get-token "local")))))

(ert-deftest cui-tests-restapi--get-token/not-found-error ()
  "."
  (should-error
   (let ((cui-restapi-con-token '(:local nil)))
     (cui-restapi--get-token "local2"))
   :type 'user-error))

(ert-deftest cui-tests-restapi--get-token/wrong-token-empty ()
  "."
  (should-error
   (let ((cui-restapi-con-token '(:local "")))
     (cui-restapi--get-token "local"))
   :type 'user-error))


(ert-deftest cui-tests-restapi--get-token/plist-list-by-index ()
  "Plist with key and list of strings, access by index."
  (cl-labels ((cui-restapi--split-dash-number (s) (setq s s) (cons "foo" 1))) ;; fake service splitting
    (let ((cui-restapi-con-token '(:foo ("tok0" "tok1"))))
      (should (equal (cui-restapi--get-token "foo--1") "tok1")))))

(ert-deftest cui-tests-restapi--get-token/plist-list-car ()
  "Plist with key and list of strings, no index (get car)."
  (let ((cui-restapi-con-token '(:foo ("tok0" "tok1"))))
    (should (equal (cui-restapi--get-token "foo") "tok0"))))

(ert-deftest cui-tests-restapi--get-token/plist-error-when-key-not-found ()
  "Plist with missing key errors."
  (let ((cui-restapi-con-token '(:foo "tokfoo")))
    (let ((err (cadr
                (should-error (cui-restapi--get-token "bar") :type 'error))))
      ;; (print err)
      (should (eql 0 (string-match "Token not found" err))))))


(ert-deftest cui-tests-restapi--get-token/plist-bad-config ()
  "Plist with invalid structure signals error."
  (let ((cui-restapi-con-token '(:foo 1234)))
    (should-error (cui-restapi--get-token "foo")
                  :type 'error)))


;; (ert-deftest cui-tests-restapi--get-token/missing-errors ()
;;   "Neither string, plist nor auth-source: signals error."
;;   (let ((cui-restapi-con-token nil))
;;     (should-error (cui-restapi--get-token "foo")
;;                   :type 'user-error)))


;; -=-= For `cui-restapi--get-headers'
(ert-deftest cui-tests-restapi--get-headers()
  (let ((cui-restapi-con-token '(:local1
                                 :github ("token1" "token2" "token3")
                                 :some "vv"
                                 :local2 nil)))

    (should (equal (cui-restapi--get-values cui-restapi-con-token "local1") '(nil)))
    (should (equal (cui-restapi--get-values cui-restapi-con-token "local2") '(nil)))
    (should (equal (cui-restapi--get-values-enhanced cui-restapi-con-token "local1") '(nil)))
    (should (equal (cui-restapi--get-values-enhanced cui-restapi-con-token "local2") '(nil)))
    (should (equal (cui-restapi--get-values-enhanced cui-restapi-con-token "github--0") '("token1")))
    (should (equal (cui-restapi--get-values-enhanced cui-restapi-con-token "github--1") '("token2")))
    (should (equal (cui-restapi--get-values-enhanced cui-restapi-con-token "github--3") nil))
    (should-error (cui-restapi--get-token "github--3")
                  :type 'user-error)
    (should (string-equal (cui-restapi--get-token "github--1") "token2"))
    (should (string-equal (cui-restapi--get-token :some) "vv"))
    (should (equal (cui-restapi--get-token :local1) nil))
    (should (equal (cui-restapi--get-headers "local2") '(("Content-Type" . "application/json"))))
    (should (equal (cui-restapi--get-headers "github--1") '(("Content-Type" . "application/json") ("Authorization" . "Bearer token2"))))
    (should-error (cui-restapi--get-headers "local3")
                  :type 'user-error)
    ))
;; -=-= For `cui-restapi--get-values'
(ert-deftest cui-tests-restapi--cui-restapi--get-values ()
  ;; Example variables
  (defvar my-plist '(:foo "bar" :baz "qux" :bavv nil ))
  (defvar my-string "hello")

  ;; Using cui-restapi--get-value-or-string
  (should (equal (cui-restapi--get-values my-plist "foo") '("bar")))
  (should (equal (cui-restapi--get-values my-string "foo") '("hello")))
  (should (equal (cui-restapi--get-values my-plist "foo1")  nil))
  (should (equal (cui-restapi--get-values my-plist "bavv")  '(nil)))
)
;;         (cui-block--set-variable

;; ;;     (with-current-buffer buf
;; ;;       (org-mode)
;;   (let ((buf (generate-new-buffer "*cui-test-temp*")))
;;     ))

;; (defun cui-tests--progress-reporter-start-two-and-stop-one ()
;;   "."
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


;; -=-= For `cui-restapi--payload'
(ert-deftest cui-tests-restapi--payload ()
  (should (equal (cui-restapi--payload :messages [])
                 '((messages . []) (stream . :json-false))))
  (should (equal (cui-restapi--payload)
                 '((prompt) (stream . :json-false))))
  (should (equal (cui-restapi--payload :prompt "asd")
                 '((prompt . "asd") (stream . :json-false))))
  (should (equal
           (let ((cui-restapi-con-request-extra '(:local ((:tools (("type" . "web_search")
                                                                   ("web_search" . (("enable" . t) ("search_result" . t))))
                                                                  )))))
             (cui-restapi--payload
              :service 'local
              ))
             '((prompt) (stream . :json-false) (:tools (("type" . "web_search") ("web_search" ("enable" . t) ("search_result" . t))))))))
;; -=-= Handling non-unicode characters at input in url-buffer
;; (progn
;;   (let (
;;         (json-object-type 'plist)
;;         (json-key-type 'symbol)
;;         (json-array-type 'vector)
;;         (garbage-str (concat (string ?\x81 ?\xA0 ?\xFF)))
;;          data)
;;     (setq data (with-temp-buffer
;;       ;; (insert "{\"choices\":[{\"message\":{\"annotations\":[],\"content\":\"How can I perform a test?\\n\\n\",\"refusal\":null,\"role\":\"assistant\"}}]}")
;;       (insert (concat "{\"choices\":[{\"message\":{\"annotations\":[],\"content\":\"How can I perform a test?"
;;                       garbage-str
;;                       "\\n\\n\",\"refusal\":null,\"role\":\"assistant\"}}]}"))
;;       (goto-char (point-min))
;;       (json-read)))
;;     (setq data (aref (plist-get data 'choices) 0))
;;     (print (list "data1" data))
;;     (setq data (plist-get (plist-get data 'message) 'content))
;;     (print (list "data2" data))
;;     ;; (print (alist-get 'choices data))
;; ))


;; (let ((json-object-type 'plist)
;;       (json-key-type 'symbol)
;;       (json-array-type 'vector))
;;   (condition-case _err
;;       (json-read-from-string (concat
;;                               (string-as-unibyte (string ?\x81 ?\xA0 ?\xFF )) ; garbage-str
;;                               (string ?\x10) ; garbage
;;                               "\\n\\n\",\"refusal\":null,\"role\":\"assistant\"}}]}"))
;;   (error
;;    nil
;;    )))

;; -=-= For: `cui-restapi--normalize-response'
(ert-deftest cui-tests-restapi--normalize-response ()
  (should
   (equal
    (let ((test-val '(id "o3fA4D4-62bZhn-9617f44f6d399d91" object "chat.completion" created 1752904364 model "meta-llama/Llama-3.3-70B-Instruct-Turbo-Free" prompt [] choices [(finish_reason "stop" seed 819567834314233700 logprobs nil index 0 message (role "assistant" content "It works: `(2 3 1)` is returned." tool_calls []))] usage (prompt_tokens 131 completion_tokens 14 total_tokens 145 cached_tokens 0))))
      (cui-restapi--normalize-response test-val))
    '(#s(cui-block--response role "assistant") #s(cui-block--response text "It works: `(2 3 1)` is returned.") #s(cui-block--response stop "stop")))))


;; -=-= For: `cui-block--insert-stream-response'

(ert-deftest cui-tests-restapi--response-payload ()
  (with-temp-buffer
    (let* ((test-val '((#s(cui-block--response role "assistant") #s(cui-block--response text "It seems ") #s(cui-block--response stop "length"))))
           (test-val0 (nth 0 test-val))
           (test-val1 (nth 1 test-val))
           (m (mark-marker)))
      (set-marker m (point) (current-buffer)) ; requred
      (cui-block--insert-stream-response (mark-marker) test-val0)
      (should (string-equal (buffer-string) "\n[ai]: \nIt seems ")))))

;; -=-= For: `cui-restapi--url-request-on-change-function'
(defvar callback-n-test 0)
(defvar callback-test nil)

(defun cui-tests-restapi--callback (data)
  (when (= callback-n-test 0)
    (setq callback-n-test (1+ callback-n-test))
    (setq callback-test data)))



;; (ert-deftest cui-tests-restapi--url-request-on-change-function-not-streamed()
;;   (with-temp-buffer
;;     ;; set vars,functions used in `cui-restapi--url-request-on-change-function'
;;     (let ((cui-restapi--current-url-request-callback 'cui-tests-restapi--callback)
;;           cui-restapi--current-request-is-streamed
;;           ;; cui-debug-buffer
;;           (callback-n-test 0)
;;           (payload-str (concat "{\"choices\":[{\"message\":{\"annotations\":[],\"content\":\"How can \\tI perform a test 再次?"
;;                                (concat
;;                                 (string-as-unibyte (string ?\x81 ?\xA0 ?\xFF )) ; garbage-str
;;                                 (string ?\x05) ; garbage
;;                                 "\\n\\n\",\"refusal\":null,\"role\":\"assistant\"}}]}"))))
;;       ;; (setq payload-str (clean-unicode-text payload-str ))
;;       ;; (setq payload-str (decode-coding-string (encode-coding-string payload-str 'utf-8 't) 'utf-8))
;;       (insert payload-str)
;;       (goto-char (point-min))
;;       (setq url-http-end-of-headers (point-min)) ; should set globally, checked by `boundp'
;;       ;; (print (list (boundp 'url-http-end-of-headers) url-http-end-of-headers))
;;       ;; (funcall cui-restapi--current-url-request-callback "data")
;;       (cui-restapi--url-request-on-change-function nil nil nil)
;;       ;; (print (list "wtf" callback-test))
;;       (print (list "wtf" callback-test))))
;;       (let* ((data (aref (plist-get callback-test 'choices) 0))
;;              (data (plist-get (plist-get data 'message) 'content))
;;              (length (length data) ))
;;         (should (> length 25))
;;         ))))

(ert-deftest cui-tests-restapi--url-request-on-change-function-streamed()
  (with-temp-buffer
    ;; set vars,functions used in `cui-restapi--url-request-on-change-function'
    (let ((cui-restapi--current-url-request-callback 'cui-tests-restapi--callback)
          (cui-restapi--current-request-is-streamed t)
          (callback-test nil)
          ;; cui-debug-buffer
          (callback-n-test 0)
          (payload-str (concat "data: {\"choices\":[{\"finish_reason\":\"stop\",\"index\":0,\"delta\":{\"content\":\"Text"
                               (concat
                                (string-as-unibyte (string ?\x81 ?\xA0 ?\xFF )) ; garbage-str
                                (string ?\x05) ; garbage
                                "\"}}]}")))
          data)
      ;; (setq payload-str (clean-unicode-text payload-str ))
      ;; (setq payload-str (decode-coding-string (encode-coding-string payload-str 'utf-8 't) 'utf-8))
      (insert payload-str)
      (insert "\n\n")
      (insert "data: [DONE]")
      (insert "\n\n")
      (goto-char (point-min))
      (setq url-http-end-of-headers (point-min)) ; should set globally, checked by `boundp'
      (cui-restapi--url-request-on-change-function nil nil nil)
      ;; (print callback-test)))
      ;; (print (plist-get callback-test 'choices))))
      ;; (print (list "aa" (plist-get (plist-get (aref (plist-get callback-test 'choices) 0) 'message) 'content) "bb"))))
      ;; (print (cui-restapi--normalize-response callback-test))))
      ;; (print (cui-restapi--normalize-response callback-test))))
      (setq data (decode-coding-string (cui-block--response-payload (nth 0 (cui-restapi--normalize-response callback-test))) 'utf-8))
      ;; (print (list (length data) data))))
      ;; ;; (print (list "data2" (length data) data ))
      ;; (should (string-equal "Text ÿ"  data)
      (should (= (length data) 7))
      )))
    ;; (let ((json-object-type 'plist)
    ;;                 (json-key-type 'symbol)
    ;;                 (json-array-type 'vector))
    ;;                 (let ( ; error
    ;;                       (data (json-read-from-string
    ;;                              (buffer-substring-no-properties (point) (point-max))))
    ;;                       ;; (data (json-read))  ; problem: with codepage, becaseu url buffer not utf-8
    ;;                       )
    ;;                   (when data
    ;;                     (print data))
    ;; ))


;; -=-= For: `cui-restapi--strip-api-url'
(ert-deftest cui-tests-restapi--strip-api-url-test ()
  "Runs tests for `cui-restapi--strip-api-url` explicitly for each case,
   without using a loop or an explicit assert function."

  (should (string= (cui-restapi--strip-api-url "https://api.perplexity.ai/chat/completions") "api.perplexity.ai"))

  (should (string= (cui-restapi--strip-api-url "http://www.example.com/path/to/file") "www.example.com"))

  ;; (should (string= (cui-restapi--strip-api-url "ftp://some.server.org") "some.server.org")
  ;;   (error "Test 3 Failed: ftp://some.server.org"))

  (should (string= (cui-restapi--strip-api-url "no-protocol.com/stuff") "no-protocol.com"))

  (should (string= (cui-restapi--strip-api-url "http://www.google.com/search?q=elisp") "www.google.com"))

  (should (string= (cui-restapi--strip-api-url "localhost:8080/app") "localhost:8080"))

  (should (string= (cui-restapi--strip-api-url "example.com") "example.com"))

  (should (string= (cui-restapi--strip-api-url "https://sub.domain.co.uk") "sub.domain.co.uk"))

  (should (string= (cui-restapi--strip-api-url "domain.com/") "domain.com"))

  (should (string= (cui-restapi--strip-api-url "localhost") "localhost"))

  ;; (should (string= (cui-restapi--strip-api-url "") "")
  ;;   (error "Test 11 Failed: empty string"))

  ;; (message "All individual tests passed for cui-restapi--strip-api-url!")
  t) ; Return t for success


;; -=-= For: `cui-restapi--get-values-enhanced'

(ert-deftest cui-tests-restapi--get-values-enhanced ()
  (should (equal (cui-async1-plist-get '(:zaza :foo 1 :bar nil) :zaza) nil))
  (should (equal (cui-restapi--get-values '(:foo 1 :bar nil) :foo)	'(1)))
  (should (equal (cui-restapi--get-values '(:foo 1 :bar nil) :bar)	'(nil))) ; value is nil
  (should (equal (cui-restapi--get-values '(:foo 1 :bar nil) :baz)	nil)) ; not exist
  (should (equal (cui-restapi--get-values '(:foo 1 :bar nil) :zaza)	nil)) ; not exist
  (should (equal (cui-restapi--get-values '(:only) :only)		'(nil)))  ; no value
  (should (equal (cui-restapi--get-values "something" "vvv")		'("something")))
  (should (equal (cui-restapi--get-values '(:foo (1 2) :bar nil) :foo)	'(1 2))) ; list of values
  (should (equal (cui-restapi--get-values nil "vvv")		nil))
  (should (equal (cui-restapi--get-values '(:zaza :foo 1 :bar nil) :zaza)	'(nil))) ; value is null
  (should (equal
            (let ((cui-restapi-con-token '(:local1
                                           :github ("token1" "token2" "token3")
                                           :some "vv"
                                           :local2 nil)))
              (cui-restapi--get-values-enhanced cui-restapi-con-token "github--3")) nil))
  )
;; -=-= For: `cui-restapi--split-dash-number'

(ert-deftest cui-tests-restapi--split-dash-number-test ()
  (should-error (cui-restapi--split-dash-number nil))
  (should (equal (cui-restapi--split-dash-number "foo")
                                                 nil))
  (should (equal (cui-restapi--split-dash-number "foo--")
                                                 nil))
  (should (equal (cui-restapi--split-dash-number "foo--23")
                                                 '("foo" . 23)))
  (should (equal (cui-restapi--split-dash-number "--1")
                                                 '("" . 1)))
  (should (equal (cui-restapi--split-dash-number "a--b")
                                                 nil))
  (should (equal (cui-restapi--split-dash-number "foo--2.4")
                                                 nil)))


;; -=-= For: `cui-restapi--get-single-response-text'

(ert-deftest cui-tests-restapi--get-single-response-text1 ()
  (should
   (string-equal
    (let ((test-val
           '(id "nz7KyaB-3NKUce-9539d1912ce8b148" object "chat.completion" created 1750575101 model "meta-llama/Llama-3.3-70B-Instruct-Turbo-Free" prompt []
                choices [(finish_reason "length" seed 3309196889559996400 logprobs nil index 0
                                        message (role "assistant" content " The answer is simple: live a long time. But how do you do that? Well, itâs not as simple as it sounds." tool_calls []))] usage (prompt_tokens 5 completion_tokens 150 total_tokens 155 cached_tokens 0))))
      (cui-restapi--get-single-response-text test-val))
    " The answer is simple: live a long time. But how do you do that? Well, itâs not as simple as it sounds.")))


(ert-deftest cui-tests-restapi--get-single-response-text2 ()
  ;; z.ai
  (let ((response '(choices [(finish_reason "length" index 0 message (content "cont-text" reasoning_content "reasoning-text" role "assistant"))] created 1795076924 id "20261119162725094b03b8ae3b4d75" model "GLM-4.7-Flash" object "chat.completion" request_id "20261119162725094b03b8ae3b4d75" usage (completion_tokens 900 completion_tokens_details (reasoning_tokens 900) prompt_tokens 113 prompt_tokens_details (cached_tokens 2) total_tokens 1013))))
    (should (string-equal "reasoning-text cont-text"
                          (cui-restapi--get-single-response-text response)))))


;; -=-= For: `cui-restapi--collect-chat-messages' (old)
;; (ert-deftest cui-tests-restapi--collect-chat-messages ()
;;   ;; deal with unspecified prefix
;;   (should
;;    (equal
;;     (let ((test-string "\ntesting\n  [ME]: foo bar baz zorrk\nfoo\n[AI]: hello hello[ME]: "))
;;       (cui-restapi--collect-chat-messages test-string))
;;     '[(:role user :content "testing\nfoo bar baz zorrk\nfoo")
;;       (:role assistant :content "hello hello")]))

;;   ;; sys prompt
;;   (should
;;    (equal
;;     (let ((test-string "[SYS]: system\n[ME]: user\n[AI]: assistant"))
;;       (cui-restapi--collect-chat-messages test-string))
;;     '[(:role system :content "system")
;;       (:role user :content "user")
;;       (:role assistant :content "assistant")]))

;;   ;; sys prompt intercalated
;;   (should
;;    (equal
;;     (let ((test-string "[SYS]: system\n[ME]: user\n[AI]: assistant\n[ME]: user"))
;;       (cui-restapi--collect-chat-messages test-string nil t))
;;     '[(:role system :content "system")
;;       (:role user :content "user")
;;       (:role assistant :content "assistant")
;;       (:role system :content "system")
;;       (:role user :content "user")]))

;;   ;; merge messages with same role
;;   (should
;;    (equal
;;     (let ((test-string "[ME]: hello [ME]: world")) (cui-restapi--collect-chat-messages test-string))
;;     '[(:role user :content "hello\nworld")]))

;;   (should
;;    (equal
;;     (let ((test-string "[ME:] hello world")) (cui-restapi--collect-chat-messages test-string))
;;     '[(:role user :content "hello world")]))

;;   (should
;;    (equal
;;     (let ((test-string "[ME]: hello [ME:] world")) (cui-restapi--collect-chat-messages test-string))
;;     '[(:role user :content "hello\nworld")]))

;;   (should
;;    (equal
;;     (let ((test-string "  [ME]: hello [ME]: world")) (cui-restapi--collect-chat-messages test-string))
;;     '[(:role user :content "hello\nworld")]))

;;   )

;; -=-= For: `cui-restapi--stringify-chat-messages' (old)
;; (ert-deftest cui-tests-restapi--stringify-chat-messages ()
;;   (should
;;    (string-equal
;;     (cui-restapi--stringify-chat-messages '[(:role system :content "system")
;;                                             (:role user :content "user")
;;                                             (:role assistant :content "assistant")])
;;     "[SYS]: system\n\n[ME]: user\n\n[AI]: assistant"))

;;   (should
;;    (string-equal
;;     (cui-restapi--stringify-chat-messages '[(:role user :content "user")
;;                                             (:role assistant :content "assistant")]
;;                                           :default-system-prompt "system")
;;     "[SYS]: system\n\n[ME]: user\n\n[AI]: assistant"))

;;   (should
;;    (string-equal
;;     (cui-restapi--stringify-chat-messages '[(:role user :content "user")
;;                                             (:role assistant :content "assistant")]
;;                                           :user-prefix "You: "
;;                                           :assistant-prefix "Assistant: ")
;;     "You: user\n\nAssistant: assistant")))


;; -=-= For: `cui-restapi-prepare-content' TODO: move to `cui-block-tags-get-content-ai-messages'
;; (ert-deftest cui-tests-restapi--prepare-content1 ()
;;   (with-temp-buffer
;;     (org-mode)
;;     (let* ((element (progn (insert "#+begin_ai :stream t :sys \"A helpful LLM.\" :stream2 :max-tokens 50 :max-tokens2 :model \"gpt-3.5-turbo\" :model1 :model2 t :model3 :temperature 0.7\n#+end_ai\n")
;;                            (goto-char 1)
;;                            (cui-block-p)))
;;            ;; (info (progn (goto-char (org-element-property :begin element)) (cui-block-get-info)))
;;            )
;;       (should-error (cui-restapi-prepare-content nil element 'chat "sys1" "sys-all2" 3) :type 'error))))

;; (ert-deftest cui-tests-restapi--prepare-content2 ()
;;   (with-temp-buffer
;;     (org-mode)
;;     (let* ((element (progn (insert "#+begin_ai :stream t :sys \"A helpful LLM.\" :stream2 :max-tokens 50 :max-tokens2 :model \"gpt-3.5-turbo\" :model1 :model2 t :model3 :temperature 0.7\nss\n#+end_ai\n")
;;                            (goto-char 1)
;;                            (cui-block-p)))
;;            (res (cui-restapi-prepare-content nil element 'chat "sys1" "sys-all2" 3)))
;;       (should (eq (length res) 2))
;;       (should (string-match "sys1" (plist-get (aref res 0) :content)))
;;       (should (eql 'system (plist-get (aref res 0) :role)))
;;       (should (eql 'user (plist-get (aref res 1) :role)))
;;       (should (string-match "sys-all2" (plist-get (aref res 1) :content)))
;;       (should (string-match "ss" (plist-get (aref res 1) :content))))))

;; (ert-deftest cui-tests-restapi--prepare-content3 ()
;;   (with-temp-buffer
;;     (org-mode)
;;     (let* ((element (progn (insert "#+begin_ai :stream t :sys \"A helpful LLM.\" :stream2 :max-tokens 50 :max-tokens2 :model \"gpt-3.5-turbo\" :model1 :model2 t :model3 :temperature 0.7\nss\n[AI:]vv\n[ME:]tt\n#+end_ai\n")
;;                            (goto-char 1)
;;                            (cui-block-p)))
;;            (res (cui-restapi-prepare-content nil element 'chat "sys1" "sys-all2" 3)))
;;       (should (eq (length res) 4))
;;       (should (eql 'system (plist-get (aref res 0) :role)))
;;       (should (eql 'user (plist-get (aref res 1) :role)))
;;       (should (eql 'assistant (plist-get (aref res 2) :role)))
;;       (should (eql 'user (plist-get (aref res 3) :role)))
;;       (should (string-match "tt" (plist-get (aref res 3) :content))))))

;; -=-= For: `cui-restapi--chunk-around-pattern'
(ert-deftest cui-tests-restapi--chunk-around-pattern ()
  (let (res)
    (setq res
          (cui-restapi--chunk-around-pattern "\\[\\([^]]+\\)\\]" "[asd]vvvv[aa]bbb"))
    (should (equal res '(("" "asd" nil nil) ("vvvv" "aa" nil nil) ("bbb"))))
    (setq res
          (cui-restapi--chunk-around-pattern "\\[\\(image\\|audio\\)-\\([^:]+\\):\\([^]\t\n\r]+\\)]" "vvvv[image-png:sa]bbb[audio-mp3:vv]"))
    (should (equal res '(("vvvv" "image" "png" "sa") ("bbb" "audio" "mp3" "vv"))))
    (setq res
          (cui-restapi--chunk-around-pattern "\\[\\([^]]+\\)\\]" "vvvv"))
    (should (equal res nil))

    ;; (should-error (cui-restapi--chunk-around-pattern "\\[\\([^]]+\\)\\]" "[aa]") :type 'user-error)

    (setq res
          (cui-restapi--chunk-around-pattern "\\[\\([^]]+\\)\\]" "[aa]"))
    (should (equal res '(("" "aa" nil nil))))

    (setq res
          (cui-restapi--chunk-around-pattern "\\[\\(image\\|audio\\)-\\([^:]+\\):\\([^]\t\n\r]+\\)]" "vvvv[image-png:sa]bbb"))
    (should (equal res '(("vvvv" "image" "png" "sa") ("bbb"))))

    (setq res
          (cui-restapi--chunk-around-pattern "\\[\\(image\\|audio\\)-\\([^:]+\\):\\([^]\t\n\r]+\\)]" "[image-png:sa]bbb[audio-mp3:vv]"))
    (should (equal res '(("" "image" "png" "sa") ("bbb" "audio" "mp3" "vv"))))

    (setq res
          (cui-restapi--chunk-around-pattern "vvvv" "asdasd"))
    (should (equal res nil))))

;; -=-= For: `cui-restapi--replace-multimodal'
(ert-deftest cui-tests-restapi--replace-multimodal ()
  (let (res
        (eres '[(:type "text" :text "bla bla") (:type "image_url" :image_url (:url "data:image/jpeg;base64,ZHVtbXk=")) (:type "text" :text "vvvv\nSee media above.\ncccc")]))
    ;; 1
    (setq res
          (let* ((f (make-temp-file "test" nil ".JPG")))
            ;; (cui-restapi--chunk-around-pattern "@\\(image\\|audio\\)-\\([^:]+\\):\\([^ \t\n\r]+\\)"
            ;;                            (concat "bla bla @image-jpeg:" f " vvvv @image-jpeg:" f " cccc")))))
             (with-temp-file f (insert "dummy"))
             (prog1
                 (cui-restapi--replace-multimodal (concat "bla bla @image-jpeg:" f " vvvv @image-jpeg:" f " cccc"))
               (delete-file f))))
  (should (equal res eres))
  ;;2
  (setq res
          (let* ((f (make-temp-file "test" nil ".JPG")))
            (with-temp-file f (insert "dummy"))
            (prog1
                (cui-restapi--replace-multimodal (concat "bla bla @audio-mp3:" f " vvvv @audio-mp3:" f " cccc"))
              (delete-file f))))
  (should (equal res [(:type "text" :text "bla bla") (:type "input_audio" :input_audio (:data "ZHVtbXk=" :format "mp3")) (:type "text" :text "vvvv\nSee media above.\ncccc")]))
  ;;3
  (should (equal (cui-restapi--replace-multimodal "string") "string"))
  ;;4
  (setq res (let* ((f (make-temp-file "test" nil ".JPG")))
              (with-temp-file f (insert "dummy"))
              (prog1
                  (cui-restapi--replace-multimodal (cui-block-tags-replace (concat "bla bla [[" f "]] vvvv [[" f "]] cccc")))
                (delete-file f))))
  (should (equal res eres))
  ;;5
  (setq res (let* ((f (make-temp-file "test" nil ".JPG")))
              (with-temp-file f (insert "dummy"))
              (prog1
                  (cui-restapi--replace-multimodal (cui-block-tags-replace (concat "bla bla @" f " vvvv @" f)))
                (delete-file f))))
  (should (equal res '[(:type "text" :text "bla bla") (:type "image_url" :image_url (:url "data:image/jpeg;base64,ZHVtbXk=")) (:type "text" :text "vvvv")]))
  ;;6
  (setq res (let* ((f (make-temp-file "test" nil ".mp3")))
              (with-temp-file f (insert "dummy"))
              (prog1
                  (cui-restapi--replace-multimodal (cui-block-tags-replace (concat "[[file:" f "]]")))
                (delete-file f))))
  (should (equal res '[(:type "input_audio" :input_audio (:data "ZHVtbXk=" :format "mp3"))]))))



;; -=-= provide
(provide 'cui-tests-restapi)
;;; cui-tests-restapi.el ends here
