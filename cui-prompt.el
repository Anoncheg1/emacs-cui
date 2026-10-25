;;; cui-prompt.el --- Chains of requests to LLM -*- lexical-binding: t; -*-

;; Copyright (C) 2026 github.com/Anoncheg1,codeberg.org/Anoncheg
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
;;
;; `cui-agent-call-function' -> `cui-prompt-request-switch' -> `cui-prompt-request-chain'
;;
;; Re1
;; Sys: You a helpful.  Give plan of 3 parts to research for answer
;; and do only first part.  user: How to make it?
;;
;; "choices": ["message": {"role": "assistant", "content": "To..."}}]
;;
;; Re2
;; Sys: You a helpful.  Give plan of 3 parts to research for answer
;;      and do only first part.
;; user: How to make it?
;; Assist: Plan and solution for 1) step.
;; user: Research 2-th part and what was missed before.
;;
;; Re3
;; Sys: You a helpful.  Give plan of 3 parts to research for answer
;;      and do only first part with summary.
;; user: How to make it?
;; Assist: Plan and solution for 1) step.
;; user: Research 2-th part and what was missed before.
;; Assist: sum for 1), new plan, 2) step.
;; user: Research 3-th part and what was missed before, summarize
;;       results give final answer.

;; -=-= includes
(require 'cui-block)
(require 'cui-block-msgs)
(require 'cui-block-tags)
(require 'cui-restapi)
(require 'cui-async1)
(require 'cui-timers)

;;; Code:
;; -=-= all
(defvar cui-prompt-chain-list
  (list "Give three steps plan. Do only the first step of the plan. Provide tiny seed answer."
        "Complete the second step of plan only. Enhance answer."
        "Do the third step. Provide a final full answer."))


(defun cui-prompt-collect-chat-research-steps-prompt (commands ind messages &optional default-system-prompt max-tokens)
  "Compose messages for LLM for IND step of COMMANDS.
Add to result of `cui-restapi--collect-chat-messages' CoT prompts.
Compose IND request for COMMANDS and ind-1 response.
MESSAGES is result of `cui-restapi-prepare-content'.
IND count from 0.  RESP-QUEST  is list of string  of lengh IND+1  - raw
content of cui block or answer from  LLM.  We assume that commands and AI
answers except of the first one are already in MESSAGES."
  (let* ((recom (if (and cui-restapi-add-max-tokens-recommendation max-tokens)
                    (cui-restapi--get-length-recommendation max-tokens)))
         (comm0 (nth 0 commands))
         (comm0 (if (and (= ind 0) recom)
                    (concat comm0 " " recom)
                  comm0))
         (comm0 (if (and default-system-prompt (not (string-empty-p default-system-prompt)))
                         (concat default-system-prompt " " comm0)
                       ;; else
                       comm0))
         (comm (nth ind commands))
         (comm (if recom (concat comm " " recom) comm))
         (sys0 (list :role 'system :content
                     comm0)))
    (apply #'vector sys0 (append messages
                                ;; command after AI answer
                                (when (> ind 0)
                                  (list (list :role 'system :content comm)))))))



(defun cui-prompt-request-prepare-chain (&rest args)
  "Check if there is :chain at cui block parameters and call chain function.
For assiging to `cui-agent-call-function' with all normal ARGS.
Return t if we replace default call implementation
`cui-restapi-request-prepare'."
  ;; element = (nth 1 args)
  (when (not (eql 'x (alist-get :chain (cui-block-get-info (nth 1 args)) 'x)))
      (apply #'cui-prompt-request-chain args)
      t))

(defun cui-prompt-prepare-chain-prepare (step header-marker noweb-control sys-prompt max-tokens)
  "Prepare messages for request in STEP of chain.
Use `cui-prompt-chain-list'.
Arguments
- HEADER-MARKER is a result of `cui-block-get-header-marker' function
 for cui block.
- NOWEB-CONTROL SYS-PROMPT MAX-TOKENS, explained in
 `cui-restapi-request-prepare' function.
This function may modify the match data."
  (let* ((messages (with-current-buffer (marker-buffer header-marker)
                     ;; get messages vector
                     (cui-block-tags-get-content-ai-messages (cui-block-element-by-marker header-marker)
                                                             noweb-control
                                                             nil ; links-only-last
                                                             nil ; not-clear-properties
                                                             nil ; cui-block-markers
                                                             nil ; disable-tags
                                                             'chat))) ; req-type
         (messages (cui-prompt-collect-chat-research-steps-prompt cui-prompt-chain-list
                                                                  step
                                                                  messages
                                                                  sys-prompt
                                                                  max-tokens))
         (messages (cui-block-msgs--modify-vector-content messages #'cui-block-tags-replace 'user))
         (messages (cui-block-msgs--modify-vector-content messages #'cui-block-tags--clear-properties 'user))
         ;; (messages (cui-block--pipeline cui-restapi-after-prepare-messages-hook messages))
         )
    messages))

(defun cui-prompt-request-chain (req-type element model max-tokens top-p temperature frequency-penalty presence-penalty service stream sys-prompt noweb-control)
  "Use :chain parameter to activate and use :step to execute chain of prompt.
Aspects:
1) start and stop reporter at begining and at the end (final callback).
2) error handling: kill reporter, kill tmp buffer, kill timers
Execution Chain:
`cui-restapi-request-llm-retries'
`cui-restapi--url-request-slim'
Modeline notification:
1) `cui-timers--set' used in `cui-restapi-request-llm-retries'.
2) `cui-timers--set' here
3) `cui-timers--progress-reporter-run' - here
For REQ-TYPE, ELEMENT, NOWEB-CONTROL, SYS-PROMPT,
SYS-PROMPT-FOR-ALL-MESSAGES, MODEL, MAX-TOKENS, TOP-P, TEMPERATURE,
FREQUENCY-PENALTY, PRESENCE-PENALTY, SERVICE, STREAM, INFO see
`cui-restapi-request-prepare'."
  ;; element noweb-control sys-prompt model max-tokens top-p temperature frequency-penalty presence-penalty service _stream &optional _info
  ;; (if (not (eql 'x (alist-get :chain (cui-block-get-info element) 'x))) ; check if :my exist
  (cui--debug "cui-prompt-request-chain service, model, buf: %s %s %s" service model (current-buffer))
  ;; - My request
  (let ((service (or service 'github))
        (end-marker (cui-block--get-content-end-marker element))
        (header-marker (cui-block-get-header-marker element))
        ;; (gap-between-requests 3) ; TODO
        ;; (step (alist-get :step (cui-block-get-info element))) ; Works? not tested TODO
        (cui-timers-duration-copy cui-timers-duration)
        (cui-timers-retries-copy cui-timers-retries))

    (let ((call (lambda (step) ; called 3 times
                  (lambda (_data callback)
                    (cui--debug "cui-prompt-request-chain1 step %s" step) ; 0, 1, 2
                    (cui--debug "cui-prompt-request-chain1 buffer %s" (current-buffer))
                    (cui--debug "cui-prompt-request-chain1 max-tokens %s header-marker %s sys-prompt %s" max-tokens header-marker sys-prompt)
                    (let* ((content (cui-prompt-prepare-chain-prepare step  header-marker noweb-control sys-prompt max-tokens))
                           (params (cui-block--pipeline-macro (req-type content element model max-tokens top-p temperature frequency-penalty presence-penalty service stream)
                                                              cui-block-msgs-after-prepare-messages-hook)))
                      (seq-let (_req-type content _element model max-tokens top-p temperature frequency-penalty presence-penalty service _stream) params
                        ;; also save request for timer
                        (cui-restapi-request-llm-retries service
                                                         model
                                                         cui-timers-duration-copy ; use current-buffer
                                                         callback
                                                         :retries cui-timers-retries-copy ; use current-buffer
                                                         :messages content
                                                         :max-tokens max-tokens
                                                         :header-marker header-marker
                                                         :temperature temperature
                                                         :top-p top-p
                                                         :frequency-penalty frequency-penalty
                                                         :presence-penalty presence-penalty))))))
          (callbackmy (lambda (data callback)
                        "Called in (current-buffer)."
                        (when data ; if not data it is fail
                          (cui--debug "calbackmy %s %s %s" cui-timers--element-marker-variable-dict (current-buffer) data)
                          (cui-block--insert-single-response end-marker data nil 'not-final)
                          (run-at-time 0 nil callback data))))
          (calbafin (lambda (data _callback)
                      (when data ; if not data it is fail
                        (cui--debug "calbafin")
                        (cui-block--insert-single-response end-marker data t)
                        (cui-timers--interrupt-current-request (cui-timers--get-keys-for-variable header-marker) #'cui-restapi--stop-tracking-url-request)))))

      (cui--debug "cui-prompt-request-chain2 %s %s %s %s" header-marker service model cui-timers-duration)
      (condition-case err
          (progn
            (cui-timers--progress-reporter-run #'cui-restapi--stop-tracking-url-request (* cui-timers-duration cui-timers-retries-copy) )
            (cui--debug "cui-prompt-request-chain3")

            ;; There is a problem that we handle error in callback before timer may be run.
            ;; And we can't run timer before.
            (cui-async1-start nil
                              (list (funcall call 0)
                                    callbackmy
                                    (funcall call 1)
                                    callbackmy
                                    (funcall call 2)
                                    calbafin))
            (cui--debug "cui-prompt-request-chain4"))
        (user-error
         (funcall cui-restapi-show-error-function (error-message-string err)
                  header-marker)
         (cui-timers--interrupt-current-request (cui-timers--get-keys-for-variable header-marker) #'cui-restapi--stop-tracking-url-request))))))


;;; provide
(provide 'cui-prompt)
;;; cui-prompt.el ends here
