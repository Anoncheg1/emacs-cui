;;; cui-tests-integ.el --- Tests for cui-restapi-request-prepare. -*- lexical-binding: t; -*-

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

;; (add-to-list 'load-path (expand-file-name "./"))
;; (eval-buffer)
;; (ert t)
;; emacs -Q --batch -l ert.el -l cui-debug.el -l cui-block.el -l cui-tests-block.el -l cui-tests-integ.el -f ert-run-tests-batch-and-exit


;; (add-to-list 'load-path default-directory)
;; (require 'cui-tests-block) ; for `cui-test-setup-buffer'

(require 'cui)
(require 'ert)
;; (defvar ert-enabled t)

;;; Commentary:
;;

;;; Code:



;;; - Help functions
;;;
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


(defun cui-tests--my-http-server-handler (proc _string)
  "Used for HTTP server as callback.
PROC is process object.  _STRING is data received."
  (process-send-string
   proc
   "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"choices\":[{\"finish_reason\":\"length\",\"message\":{\"role\":\"assistant\",\"content\":\"Your question needs clarification.\"}}]}\n")
  (delete-process proc))

(defun cui-tests--my-http-server-handler-stream (proc _string)
  "Used for HTTP server as callback.
PROC is process object.  _STRING is data received."
  (ignore _string) ; noqa Unused lexical argument
  (process-send-string
   proc
   "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\ndata: {\"choices\":[{\"content_filter_results\":{},\"delta\":{\"content\":\"\",\"refusal\":null,\"role\":\"assistant\"},\"finish_reason\":null,\"index\":0,\"logprobs\":null}],\"created\":1765253459,\"id\":\"chatcmpl-CkjLvJKSZym3rh3hBEeJKaGclbAQ6\",\"model\":\"gpt-4.1-2025-04-14\",\"obfuscation\":\"nZ2\",\"object\":\"chat.completion.chunk\",\"system_fingerprint\":\"fp_f99638a8d7\"}\n")
  (process-send-string
   proc
   "\ndata: {\"choices\":[{\"content_filter_results\":{\"hate\":{\"filtered\":false,\"severity\":\"safe\"},\"self_harm\":{\"filtered\":false,\"severity\":\"safe\"},\"sexual\":{\"filtered\":false,\"severity\":\"safe\"},\"violence\":{\"filtered\":false,\"severity\":\"safe\"}},\"delta\":{\"content\":\"It\"},\"finish_reason\":null,\"index\":0,\"logprobs\":null}],\"created\":1765253459,\"id\":\"chatcmpl-CkjLvJKSZym3rh3hBEeJKaGclbAQ6\",\"model\":\"gpt-4.1-2025-04-14\",\"obfuscation\":\"Bd4\",\"object\":\"chat.completion.chunk\",\"system_fingerprint\":\"fp_f99638a8d7\"}\n")
  (process-send-string
   proc
   "\ndata: {\"choices\":[{\"content_filter_results\":{},\"delta\":{},\"finish_reason\":\"stop\",\"index\":0,\"logprobs\":null}],\"created\":1765253489,\"id\":\"chatcmpl-CkjMPSMz0QAsT689A3eSGFsTWsgwf\",\"model\":\"gpt-4.1-2025-04-14\",\"obfuscation\":\"NqUvAU8sOf0FBAY\",\"object\":\"chat.completion.chunk\",\"system_fingerprint\":\"fp_f99638a8d7\"}\n")
  (process-send-string
   proc
   "\ndata: [DONE]\n")
  (delete-process proc))


(defun cui-tests--create-http-service ()
  "To test: curl -v 127.0.0.1:9239."
  (make-network-process
  :name "my-http-server"
  :buffer "*my-http-server*"
  :family 'ipv4
  :service 9239
  ;; Try :host nil or "127.0.0.1" for clarity
  :host "127.0.0.1"
  :server t
  :filter 'cui-tests--my-http-server-handler))

(defun cui-tests--create-http-service-stream ()
  "To test: curl -v 127.0.0.1:9239."
  (make-network-process
  :name "my-http-server"
  :buffer "*my-http-server*"
  :family 'ipv4
  :service 9239
  ;; Try :host nil or "127.0.0.1" for clarity
  :host "127.0.0.1"
  :server t
  :filter 'cui-tests--my-http-server-handler-stream))



  ;; - test:
  ;; (delete-process "my-http-server")
  ;; (advice-remove 'make-network-process #'my-make-network-process-advice)
  ;; (cui-tests--create-http-service)
;; (make-network-process :name "localhost" :host "127.0.0.1" :service 9239 :nowait t)



  ;; (with-current-buffer (url-retrieve-synchronously "http://localhost:9239/")
  ;;   (prog1 (buffer-string)(kill-buffer)))

  ;; (with-current-buffer (url-retrieve-synchronously "http://127.0.0.1:9239/")
  ;;   (prog1 (buffer-string) (kill-buffer)))

  ;; (display-buffer (url-retrieve-synchronously "http://localhost:9239/"))


  ;; (url-retrieve
  ;;  "http://localhost:9239/"
  ;;  (lambda (status)
  ;;    (goto-char (point-min))
  ;;    ;; (re-search-forward "\r\n\r\n")
  ;;    (message "Server replied: %s" (buffer-substring (point-min) (point-max)))))
  ;; )


;;; - Integration test: cui-restapi-request-prepare

(ert-deftest cui-tests-integ-nostream-test ()
  "`cui-restapi-request-prepare'."
  (condition-case nil
      (delete-process "my-http-server")
    (error nil))
  (cui-tests--create-http-service)
  ;; (sleep-for 1)
  (let ((temp-buffer (generate-new-buffer " *temp*" t)))
    ;; (let ((temp-buffer (get-buffer-create "tt" t)))
    ;; (let ((temp-buffer (current-buffer)))
    (with-current-buffer temp-buffer
      ;; (goto-char 1498)
      (org-mode)
      (cui-mode)
      (cui-test-setup-buffer "#+begin_ai :stream nil :service test :model none\nTest content\n#+end_ai")
      ;; (print (point))
      (let ((cui-restapi-con-endpoints (list :test "http://localhost:9239/v1/chat/completions"))
            (cui-restapi-con-token "test"))
        ;; (plist-put cui-restapi-con-endpoints :test "http://localhost:9239/v1/chat/completions")
                                        ; delete http service if error, but not suppress
        (condition-case err
            (progn
              (sleep-for 0.5) ; required
              (org-ctrl-c-ctrl-c)
              (sleep-for 0.5)
              ;; (print (list "point" (point)))
              (should (eq 112 (point)))
              (should (string-equal (buffer-substring-no-properties (point-min) (point-max) )
                      "#+begin_ai :stream nil :service test :model none\nTest content\n\n[ai]: Your question needs clarification.\n\n[ME]: \n#+end_ai")
              ))
          (error
           ;; (print (list "error! delete-process" (buffer-substring-no-properties (line-beginning-position) (line-end-position) )))
           (delete-process "my-http-server")   ; run your code
           (cui-timers--interrupt-current-request (current-buffer) #'cui-restapi--interrupt-url-request)
           (signal (car err) (cdr err)))) ; re-signal error (does not suppress)
        ))
    ;; (run-at-time 1 nil (lambda (buf) (with-current-buffer buf
    ;;                                    (should (eq 112 (point)))
    ;;                                    (should (string-equal
    ;;                                             (buffer-substring-no-properties (point-min) (point-max) )
    ;;                                             "#+begin_ai :stream nil :service test :model none\nTest content\n\n[AI]: Your question needs clarification.\n\n[ME]: \n#+end_ai"
    ;;                                             )
    ;;                                            ))
    ;;                      (delete-process "my-http-server")
    ;;                      ;; (cui-timers--interrupt-current-request (current-buffer) #'cui-restapi--interrupt-url-request)
    ;;                      )
    ;;              temp-buffer)
    ))

;;; - Integration test: cui-restapi-request-llm-retries

(ert-deftest cui-tests-integ-stream-test ()
  "Test `cui-restapi-request-llm-retries'."
  (progn
  (condition-case nil
      (delete-process "my-http-server")
    (error nil))
  (cui-tests--create-http-service-stream)
  ;; (sleep-for 1)
  (let ;;((temp-buffer (generate-new-buffer " *temp*" t)))
      ((temp-buffer (generate-new-buffer "ttemp" t)))
    ;; (let ((temp-buffer (get-buffer-create "tt" t)))
    ;; (let ((temp-buffer (current-buffer)))
    (with-current-buffer temp-buffer
      ;; (goto-char 1498)
      (org-mode)
      (cui-mode)
      (cui-test-setup-buffer "#+begin_ai :stream t :service test :model none\nTest content\n#+end_ai")
      ;; (print (point))
      (let ((cui-restapi-con-endpoints (list :test "http://localhost:9239/v1/chat/completions"))
            (cui-restapi-con-token "test")
            (cui-timers-duration 10))
        ;; (cui-restapi--get-headers "test"))
        ;; (print (list "cui-timers-duration" cui-timers-duration (current-buffer))))))

        ;; (plist-put cui-restapi-con-endpoints :test "http://localhost:9239/v1/chat/completions")
                                        ; delete http service if error, but not suppress
        (condition-case err
            (progn
              (sleep-for 0.5) ; required
              ;; (print (list "cui-timers-duration" cui-timers-duration))
              (org-ctrl-c-ctrl-c))
          (error
           ;; (print (list "error! delete-process" (buffer-substring-no-properties (line-beginning-position) (line-end-position) )))
           (delete-process "my-http-server")   ; run your code
           (signal (car err) (cdr err)))) ; re-signal error (does not suppress)
        ))
    (run-at-time 1 nil (lambda (buf) (with-current-buffer buf
                                       ;; (print (list "POINT" (point) (buffer-substring-no-properties (point-min) (point-max))))))
    ;;                                    (should (eq 78 (point)))
                                       (should (string-equal
                                                (buffer-substring-no-properties (point-min) (point-max) )
                                                "#+begin_ai :stream t :service test :model none\nTest content\n\n[AI]: \nIt\n\n[ME]: \n#+end_ai")
                                               ))
                         (delete-process "my-http-server"))
                 temp-buffer)
    )))


(ert-deftest cui-tests-integ-port-not-opened ()
  "`cui-restapi-request-prepare'."
  (let ((temp-buffer (generate-new-buffer " *temp*" t)))
    (condition-case nil
      (delete-process "my-http-server")
    (error nil))
    (with-current-buffer temp-buffer
      (org-mode)
      (cui-mode)
      (cui-test-setup-buffer "#+begin_ai :stream nil :service test :model none\nTest content\n#+end_ai")
      ;; IDK why but for localhost url-requst dont return error for closed port inside test only
      (let ((cui-restapi-con-endpoints (list :test "http://127.0.0.1:9230/v1/chat/completions"))
            (cui-restapi-con-token "test"))
        ;; (condition-case err
            (progn
              (sleep-for 2) ; required
              (org-ctrl-c-ctrl-c)
              (sleep-for 0.1)
              ;; check:
              (goto-char (cui-block-where-is-result))
              ;; (print (list "AAAAAAAAAAAAAAA" cui-restapi-show-error-function (cui-block-where-is-result) (point)))
              (cui--debug (list "wtf" (buffer-substring-no-properties (point) (point-max))))
              (should (string-equal (buffer-substring-no-properties (point) (point-max))
                                    "#+RESULTS:\n: Connection socket was closed by unknown reason, for http://127.0.0.1:9230/v1/chat/completions\n"
                                    ))
              )
          ;; (error
          ;;  (cui-timers--interrupt-current-request (current-buffer) #'cui-restapi--interrupt-url-request)
          ;;  (signal (car err) (cdr err)))
          ;; ) ; re-signal error (does not suppress)
        ))))


(provide 'cui-tests-integ)

;;; cui-tests-integ.el ends here
