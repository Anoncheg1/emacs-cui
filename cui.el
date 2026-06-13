;;; cui.el --- Chat blocks in org-mode for LLM and agents -*- lexical-binding: t; -*-

;; Copyright (C) 2025 github.com/Anoncheg1,codeberg.org/Anoncheg
;; Author: <github.com/Anoncheg1,codeberg.org/Anoncheg>
;; Keywords: org, comm, url, link
;; URL: https://codeberg.org/Anoncheg/emacs-cui
;; Version: 0.3.2
;; Created: 27 dec 2025
;; Package-Requires: ((emacs "29.1"))
;; Optional dependency: ((org-links "0.2"))
;; SPDX-License-Identifier: AGPL-3.0-or-later

;;; License

;; This file is NOT part of GNU Emacs.

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

;; CUI as a minor mode extend Org major mode with "cui block" that
;;   allows you to interact with the OpenAI-compatible REST APIs.

;; CUI was inspired by org-ai package of Robert Krahn <https://github.com/rksm/org-ai>

;; It allows you to:
;; - Use #+begin_cui..#+end_cui blocks for org-mode
;; - Call multiple requests from multiple block and buffers in parallel.
;; - Use tags `@Backtrace` @Bt and Org links to insert target in query.
;; - Highlighting for major elements.
;; - Autofilling, hooks, powerful debugging
;; - Noweb and tangling
;; - Customization for engineering, there is :chain for sequence of
;;   calls out-of-the-box.
;;
;; The Internet connection uses the built-in libraries url.el and url-http.el.
;;
;; See see https://github.com/Anoncheg1/emacs-cui for the full set
;; of features and setup instructions.
;;
;;; Configuration:

;; (add-to-list 'load-path "path/to/cui") ; (optional)
;; (require 'cui)
;; (setq cui-restapi-con-token "xxx") ; cui-restapi.el (optional)
;; (add-hook 'org-mode-hook #'cui-mode) ; cui.el
;;
;; ;; Optional hooks:
;; (add-hook 'cui-block-after-chat-insertion-hook
;;   #'cui-optional-remove-distant-empty-lines-hook-function)
;; (add-hook 'cui-block-after-chat-insertion-hook
;;   #'cui-optional-remove-headers-hook-function)

;; First hook remove empty lines if there is too much of them in response.
;; Second fix conflict with Org mode when LLM return string starting
;;  with "*" character.

;; You will need an OpenAI API key-token.
;; It can be stored in variable or in file ~/.authinfo.gpg with format:
;;  "machine api.openai.com login cui password <your-api-key>"
;; The file is picked up when the package is loaded.
;;
;; Keys binded by default:
;; - In block #+begin_cui..#+end_cui blocks:
;;     - C-c C-c - to send the text to the OpenAI API and insert a response
;;     - C-c . - to inspect raw data (and C-u C-c .)
;;     - C-c C-.  - to see url.el raw HTTP data (working only during request)
;;     - M-h - recursive mark element (C-u M-h - mark chat message)
;;     - C-c C-t - set :max-tokens
;;     - C-g - to stop requst (in debug-buffer - stop all requests).

;;;; Notes

;; For links pointing to to file with ".ai" extension, they will be
;;  included directly without wrapping in markdown block as chat extension.

;;;; Customization:

;; M-x customize-group RET cui
;; M-x customize-group RET cui-faces

;; Terms:
;; - chat roles or prefixes - [AI]: [ME:]
;; - parts or messages - major parts of chat with prefixes of roles
;; - two steps of preparing messages:
;;   1) apply additional system messages from info. `cui-block-msgs--prepare-chat-messages'
;;   2) expand links and noweb references. `cui-block-tags-get-content-ai-messages' and others.

;;;; Known issues:

;; - Exporting dont properly format markdown code blocks and quotes "> "

;;;; Other packages:

;; - Modern navigation in major modes https://github.com/Anoncheg1/firstly-search
;; - Search with Chinese	https://github.com/Anoncheg1/pinyin-isearch
;; - Ediff no 3-th window	https://github.com/Anoncheg1/ediffnw
;; - Dired history		https://github.com/Anoncheg1/dired-hist
;; - Selected window contrast	https://github.com/Anoncheg1/selected-window-contrast
;; - Copy link to clipboard	https://github.com/Anoncheg1/emacs-org-links
;; - Solution for "callback hell"	https://github.com/Anoncheg1/emacs-async1
;; - Restore buffer state	https://github.com/Anoncheg1/emacs-unmodified-buffer1
;; - outline.el usage		https://github.com/Anoncheg1/emacs-outline-it

;;;; Donate:

;; - BTC (Bitcoin) address: 1CcDWSQ2vgqv5LxZuWaHGW52B9fkT5io25
;; - USDT (Tether) address: TVoXfYMkVYLnQZV3mGZ6GvmumuBfGsZzsN
;; - TON (Telegram) address: UQC8rjJFCHQkfdp7KmCkTZCb5dGzLFYe2TzsiZpfsnyTFt9D

;;;; TODO:

;; - make cui-variable.el and pass them to -api.el functions as parameters.
;; - provide ability to replace url-http with plz or cui-restapi with llm(plz)
;; - implement "#+PROPERTY: var foo=1" and "#+begin_cui :var
;;       foo=1" and to past to text in [foo]
;; - more tags? like: "Fix @problems then document the
;;         changes in @/CHANGELOG.md" @url, @file, @folder, @header? (Org)
;; - use cui-restapi-prepare-content for :chain
;; - Think about to pass callback for writing to chain implementations
;;    and main implementation, to make it more general.
;; - make org-block-tags optional or not
;; - key to enable full Org highlighting? think about it
;; - fontify latex [[file:/usr/share/emacs/30.2/lisp/org/org.el::16097::(defun org-inside-latex-macro-p ()]]
;; [[file:/usr/share/emacs/30.2/lisp/textmodes/tex-mode.el::1277::(setq-local font-lock-defaults]]
;; - small markdown mode on highlighting
;; - simple Elisp function to ask LLM
;; - add guide to use `cui-restapi--url-request' and with retries for simple
;;   ELisp LLM call and get result for TAB key and some place in buffer.
;; - add option for tag to expand only the last user prompt or in all.
;; - C-c C-k should jump to current bexgining of message, not next
;; - add buttons: 1) generate button based on LLM answer 2) handle clicking.
;; - default requst as one plist configuration
;; - support for https://github.com/LionyxML/markdown-ts-mode
;; - check big markdown-mode for insights for us.
;; - stop previous request if new one called with all equal parameters
;; - fill-paragraph should not break markdown quotes and bolds
;; - make font-lock better like in [[file:/usr/share/emacs/30.2/lisp/gnus/message.el
;; ::1701::(defun message-font-lock-make-cited-text-matcher (level maxlevel)]]
;; - make `cui-expand-block' executed with `org-babel-expand-src-block'.
;; - provide place or hook to add custom expansion of link to one line for user defined mode
;; - support vars as tags    https://orgmode.org/manual/Environment-of-a-Code-Block.html
;; - noweb evaluation with support of variables with some text. like <<call("as")>>
;; - implement my/org-execute-in-source-block for markdown that use
;;  `org-src--edit-element', for that `org-babel-do-in-edit-buffer'
;;  should be rewrited, in which org-edit-src-code should be executed
;;  with content, not current block
;; - add optional function to put text in markdown language block to the
;;  begining of the line by removing indentation
;; - make key to remove all messages and left only the last
;; - support "C-c '" (call-interactively 'org-edit-special)
;; - dont fill lines that surounded with single *.

;;; Code:

;; Touch: Pain, water and warm.

;; -=-= includes
(require 'cui-debug)
(require 'cui-block)
(require 'cui-block-tags)
(require 'cui-block-msgs) ; for `cui-block-msgs-after-prepare-messages-hook'
(require 'cui-restapi)
(require 'cui-prompt) ; for `cui-prompt-request-chain'

;; -=-= Customs and groups
(defgroup cui nil
  "CUI package customization."
  :group 'cui)

(defgroup cui-faces nil
  "Faces for CUI blocks."
  :tag "CUI Faces"
  :group 'cui)

(defcustom cui-fontification-flag t
  "Non-nil means enable fontification for markdown and Org elements in block."
  :type 'boolean
  :group 'cui)

(defcustom cui-req-type-functions (list :default	#'cui-request
                                        :chat		#'cui-request
                                        :completion	#'cui-request ; calls `cui-restapi-request-prepare' from cui-restapi.el
                                        :chain		#'cui-request-chain) ; calls `cui-prompt-request-chain' from cui-prompt.el
  "Custom variants to execute request.
If you specify :chain at block parameters line, associated function will
 be called.  See `cui-call-block' and `cui-restapi-request-prepare' for
 parameters."
  :type '(plist :key-type symbol
                :value-type function
                :tag "Property list (symbol => funcion)")
  :group 'cui)

;; -=-= C-c C-c main interface
(defun cui-ctrl-c-ctrl-c ()
  "Remove result and parse cui block header parameters."
  (when (cui-block-p)
    (cui-block-remove-result)
    (cui-call-this-or-that cui-req-type-functions ; plist: (:key #'function)
                           (plist-get cui-req-type-functions :default)) ; when not specified
    t)) ; return, required by Org


;; plan call function without arguments 2) parse request type in *let-params-macro info*
(defun cui-request (req-type)
  "Ctrl-c-ctrl-c main function for :chat and :completion.
REQ-TYPE symbol is completion or chat mostly.  Set by
  `cui-req-type-functions'."
  (cui--debug "cui-request %s" req-type)
  (seq-let (element noweb-control sys-prompt model max-tokens top-p temperature frequency-penalty presence-penalty service stream _info) (cui-parse-org-header)
    (let ((content (cui-prepare-messages req-type element noweb-control sys-prompt max-tokens)))
      (apply #'cui-restapi-request-prepare ; at cui-restapi.el
             ;; hook - allow you to modify any parameters
             (cui-block--pipeline-macro (req-type content element model max-tokens top-p temperature frequency-penalty presence-penalty service stream)
                                        cui-block-msgs-after-prepare-messages-hook)))))


(defun cui-request-chain (req-type)
  "Call `cui-prompt-request-chain' and and apply hook without messages.
Used decrease coupling with cui-prompt.el.
REQ-TYPE here is :chain, not used."
  (seq-let (element noweb-control sys-prompt model max-tokens top-p temperature frequency-penalty presence-penalty service stream _info) (cui-parse-org-header)
    ;; hook called after every step
    (funcall #'cui-prompt-request-chain
           req-type element model max-tokens top-p temperature frequency-penalty presence-penalty service stream sys-prompt noweb-control)))

;; -=-= help functions to call main functions
(defun cui-call-this-or-that (fn-list &optional fn-default args)
  "Get req-type and call appropriate function.
Call function from FN-LIST by comparing keyword from INFO and in
 FN-LIST.
If you specify :chain in cui block, we call related function.
FN-LIST is`cui-req-type-functions' variable.
FN-DEFAULT is default function to call if no keyword was found.
Optional argument ARGS will be passed to fn call."
  (let ((info (or (car (last args))
                  (cui-block-get-info (cui-block-p))))
        called)
    ;; loop over `cui-req-type-functions'
    (while (and fn-list (not called))
      (let ((key (pop fn-list))
            (fn (pop fn-list)))
        (when (and fn ; skip keys with missing value
                   (not (eq 'x (alist-get key info 'x)))) ; check key exist in info
          (setq called (apply fn
                              (cons (intern (substring (symbol-name key) 1)) ; key to symbol for req-type
                                    args))))))  ; (apply fn args)
    (unless called ; executed if key exist but evaluation return nil or key not exist
      (when fn-default
        (apply fn-default (cons 'chat args)))))) ; call default function


(defun cui-parse-org-header ()
  "Parsing cui block header and parameters.
Return list values from cui block header or ORG properties set by looking
 at all up levels."
  (let* ((element (cui-block-p)) ; cui-block.el
         (info (cui-block-get-info element)) ; ((:max-tokens . 150) (:service . "together") (:model . "xxx")) ; cui-block.el
         (service (cui-block--get-val info 		:service "SERVICE" cui-restapi-con-service 'string))) ; used to set model
    (let ((noweb-control (or (org-babel-noweb-p info :eval)
                             (org-babel-noweb-p (list (cons :noweb (org-entry-get-with-inheritance "cui-noweb"))) :eval)))

          (sys-prompt (cui-block--get-val info		:sys "SYS" cui-restapi-default-chat-system-prompt 'string))
          (model (cui-block--get-val info		:model "MODEL" (car (cui-restapi--get-values cui-restapi-con-model service)) 'string))
          (max-tokens (cui-block--get-val info		:max-tokens "MAX-TOKENS" cui-restapi-default-max-tokens 'number))
          (top-p (cui-block--get-val info		:top-p "TOP-P" nil 'number))
          (temperature (cui-block--get-val info	:temperature "TEMPERATURE" nil 'number))
          (frequency-penalty (cui-block--get-val info	:frequency-penalty "FREQUENCY-PENALTY" nil 'number))
          (presence-penalty (cui-block--get-val info	:presence-penalty "PRESENCE-PENALTY" nil 'number))
          (stream (cui-block--get-val info		:stream "STREAM" t 'bool)))
      (when (and info (not (assoc :model info)))
        (user-error "Model not specified nor in cui block nor in cui-restapi-con-model.  Please add :model key without value to header to disable.?"))
      (list element noweb-control sys-prompt model max-tokens top-p temperature frequency-penalty presence-penalty service stream ; model params
            info))))

;; cui-prepare-messages
(defun cui-prepare-messages (req-type element noweb-control sys-prompt max-tokens)
  "Read content of cui block and prepare it to request.
REQ-TYPE is a symbol as a key without : from `cui-req-type-functions'.
ELEMENT is cui block ORG element.
NOWEB-CONTROL is bool a result of processing ai header and Org
 properties.
SYS-PROMPT is :sys keyword of cui block that will be placed as the first
 system message in chat.
MAX-TOKENS is integer limit for LLM output.
Return string or vector."
  (if (eql req-type 'completion) ; old
      (cui-block-tags-replace (string-trim (cui-block-get-content element))) ; return string
    ;; else - chat - vector
    (cui-block-tags-get-content-ai-messages
     element
     noweb-control
     cui-restapi-links-only-last ; links-only-last
     nil ; not-clear-properties
     nil ; cui-block-markers
     nil ; disable-tags
     req-type sys-prompt
     ;; max-tokens-string
     (when (and max-tokens cui-restapi-add-max-tokens-recommendation)
       (cui-restapi--get-length-recommendation max-tokens)))))

;; -=-= interactive fn: key M-x: cui-expand-block
(defun cui-expand-block-deep ()
  "Output almost RAW information about request with headers and messages.
Return list of strings to print."
  ;; `cui-parse-org-header'
  (seq-let (element noweb-control sys-prompt model max-tokens top-p temperature frequency-penalty presence-penalty service stream info) (cui-parse-org-header)
    (let* ((req-type (cui-block--get-request-type info))
           (max-tokens-string (when (and max-tokens
                                         cui-restapi-add-max-tokens-recommendation)
                                (cui-restapi--get-length-recommendation max-tokens)))
           (messages (unless (eql req-type 'completion)
                       ;; - split content to messages
                       (cui-block-tags-get-content-ai-messages
                        element
                        noweb-control
                        nil ; links-only-last
                        nil ; not-clear-properties
                        nil ; cui-block-markers
                        nil ; disable-tags
                        req-type sys-prompt max-tokens-string)))) ; for else see :prompt
      (list
       (cui-restapi--get-endpoint messages service)
       (cui-restapi--get-headers service)
       (cui-restapi--payload :prompt (when (eql req-type 'completion) (cui-block-get-content element t)) ; legacy
                             :messages messages
			     :model model
			     :max-tokens max-tokens
			     :temperature temperature
			     :top-p top-p
			     :frequency-penalty frequency-penalty
			     :presence-penalty presence-penalty
			     :service service
			     :stream stream)))))

(defun cui-expand-block (arg)
  "Show a temp buffer with what the cui block expands to.
If there is cui block at current position in current buffer.
This is what will be sent to the api.  ELEMENT is the cui block.
Like `org-babel-expand-src-block'.
Set `help-window-select' variable to to t to get focus.
When universal  ARG specifide  output more  raw information  splitted by
messages.
Return expanded content if at current point of current buffer supported
block was found, otherwise nil."
  ; org-babel-expand-src-block put overlay with `org-src--make-source-overlay'
  ; We add text properties in `cui-block-tags--replace-last-regex-smart'
  (interactive "P")
  (when-let* ((element (cui-block-p)) ; (cui-block-tags--block-at-point))) ; cui-block.el
              (res-str (if arg
                           (pp-to-string (cui-expand-block-deep))
                         ;; - just content with expanded links:
                         (cui-block-tags-get-content element
                                                     t		; noweb-control
                                                     nil	; links-only-last
                                                     t))))	; not-clear-properties
    (if (called-interactively-p 'any)
        (let ((buf (get-buffer-create "*CUI Preview*")))
          (with-help-window buf (with-current-buffer buf
                                  (insert res-str)))
          (switch-to-buffer buf)
          t)
      ;; else
      res-str)))

;; -=-= interactive fn: key C-g: keyboard quit
(defun cui-keyboard-quit ()
  "Keyboard quit advice.
- If there is an active region at current position in current buffer, do
  nothing (normal \\<mapvar> & \\[keyboard-quit] will deactivate it).
- in debug-buffer - kill all requests."
  (interactive)
  ;; Checks:
  ;; - 1) no region mode?
  (when (not (region-active-p))
    ;; - 2) cui debug buffer?
    (if (string-equal (buffer-name (current-buffer)) cui-debug-buffer) ; in debug-buffer - kill all
        (cui-restapi-stop-all-url-requests)
      ;; - else: 3) cui-mode in current buffer or
      (when (and (bound-and-true-p cui-mode)
                     (not (minibufferp (window-buffer (selected-window))))) ; not in minubuffer
        ;; - stop current request
        (if (bound-and-true-p cui-debug-buffer)
            ;; - show all errors in debug mode
            (call-interactively #'cui-restapi-stop-url-request) ; cui-restapi.el
          ;; else - suppress error in normal mode
          (condition-case _
              (call-interactively #'cui-restapi-stop-url-request) ; cui-restapi.el
            (error nil)))))))

;; -=-= interactive fn: M-x cui-toggle-debug
(defalias 'cui-toggle-debug #'cui-debug-toggle)

;; -=-= fn: Help function to rebind major mode with chaining
(defun cui--call-next-remap-protected (command &optional seen)
  "Call the next remapping of COMMAND, skipping any commands already in SEEN.
If no further remappings found, calls COMMAND interactively if possible."
  (let ((minor-mode-map-alist (cdr minor-mode-map-alist)))
    (let ((binding (key-binding (vector 'remap command))))
      (cond
       ;; No binding found, or recursion, fallback to original
       ((or (null binding) (memq binding seen))
        (when (commandp command)
          (call-interactively command)))
       ;; Valid binding, try further
       ((commandp binding)
        (cui--call-next-remap-protected command (cons binding seen)))))))

(defun cui--call-next-key-remap-protected (key &optional seen)
  "Call the next binding of KEY, skipping handlers already in SEEN.
If no further binding found, calls the major mode's or global binding.
KEY is a string representing the keystroke.
SEEN is a list of commands already called, used to prevent recursion."

  ;; Locally shadow minor-mode-map-alist to remove the highest-priority minor mode map.
  (let ((minor-mode-map-alist (cdr minor-mode-map-alist)))
    ;; Find the current binding for KEY after skipping the top minor mode.
    (let ((binding (key-binding (kbd key) nil nil)))
      (cond
       ;; If no binding found or we've already seen this binding, try major mode and then global map.
       ((or (null binding) (memq binding seen))
        ;; Attempt to find the binding in the major mode's keymap.
        (let* ((major-mode-map (current-local-map))
               (binding-major (and major-mode-map (lookup-key major-mode-map (kbd key)))))
          (if (commandp binding-major)
              ;; If found and it's a command, call interactively.
              (call-interactively binding-major)
            ;; Otherwise, try the global map for the key.
            (let ((global-binding (key-binding (kbd key) t t)))
              (if (commandp global-binding)
                  (call-interactively global-binding)
                ;; If no valid binding anywhere, notify the user.
                (message "No valid binding for %s" key))))))
       ;; If binding is a command, recursively try to find the next remapped binding,
       ;; and add this binding to SEEN for recursion protection.
       ((commandp binding)
        (cui--call-next-key-remap-protected key (cons binding seen)))
       ;; Handle the case where binding is not a command (function, lambda, etc.).
       (t
        (message "Binding for %s is not a command" key))))))

;; -=-= interactive fns: Org keys
(defun cui-expand-block-org ()
  "Show a temp buffer with what the cui block expands to."
  (interactive)
  (if (not (call-interactively #'cui-expand-block))
    ;; else
    (cui--call-next-key-remap-protected "C-c .")))

(defun cui-set-max-tokens-org ()
  "Jump to header of cui block and set max-tokens."
  (interactive)
  (if (cui-block-p)
      (cui-block-set-block-parameter :max-tokens cui-restapi-default-max-tokens)
    ;; else
    (cui--call-next-key-remap-protected "C-c C-t")))

;; -=-= interactive fns: Org keys remapings
(defun cui-mark-at-point-org (&optional arg)
  "Call `org-mark-element' if cant mark element of cui block.
Works if cursor in cui block, otherwise call original function.
Increase region at next execution.
If optional argument ARG is non-nil, mark whole content of cui block."
  (interactive "P")
  (if (cui-block-p)
      (cui-block-mark-at-point arg)
    ;; else
    (cui--call-next-remap-protected #'org-mark-element))) ; #'mark-paragraph

(defun cui-fill-paragraph ()
  "Call `org-fill-paragraph' to selected item in cui block.
Universal interactive version of `cui-block-fill-paragraph'.
Works if cursor in cui block.
If optional argument ARG is non-nil, mark current message of chat."
  (interactive)
  ;; (cui--debug "cui-fill-paragraph")
  (if-let ((element (cui-block-p)))
      ;; (or
       (call-interactively #'cui-block-fill-paragraph)
          ;; (when (cui-block-fill-region (point)
          ;;                              (save-excursion (forward-paragraph)
          ;;                                              (point)))
          ;;        (message "Line"))) ; ? TODO: fix this
    ;; else
    (cui--call-next-remap-protected #'org-fill-paragraph)))

(defun cui-next-item (arg)
  "Call `org-next-visible-heading' or move to next ai item.
Works if cursor in cui block.
Item may be header of cui block, markdown
 ### header, markodown subblock, otherwise chat messages used as items.
With ARG, repeats or can move backward if negative."
  (interactive "p")
  (if (derived-mode-p 'org-mode)
    (if (cui-block-p)
        (cui-block-next-item arg)
      ;; else
      (cui--call-next-remap-protected #'org-next-visible-heading))
    ;; else - not org mode
    (cui-block-next-item arg)))

(defun cui-previous-item (arg)
  "Call `org-previous-visible-heading' or move to previous ai item.
Works if cursor in cui block.
Item may be header of cui block, markdown
 ### header, markodown subblock, otherwise chat messages used as items.
ARG may be positive or nil."
  (interactive "p")
  (if (derived-mode-p 'org-mode)
      (if (cui-block-p)
          (cui-block-previous-item arg)
        ;; else
        (cui--call-next-remap-protected #'org-previous-visible-heading))
    ;; else - not org mode
    (cui-block-previous-item arg)))

;; -=-= Minor mode: keymap
;;;###autoload
(defvar-keymap cui-mode-map
  :repeat nil
  :parent nil
  ;; "<remap> <outline-next-visible-heading>" #'cui-next-item ; C-c C-n todo make org
  ;; "<remap> <outline-previous-visible-heading>" #'cui-previous-item ; C-c C-p todo make org
  "C-c C-p" #'cui-previous-item
  "C-c C-n" #'cui-next-item
  "<remap> <org-mark-element>" #'cui-mark-at-point-org ; M-h
  "<remap> <mark-paragraph>" #'cui-block-mark-at-point ; M-h
  "<remap> <fill-paragraph>" #'cui-fill-paragraph ; M-q
  "C-c ." #'cui-expand-block-org
  "C-c C-." #'cui-open-request-buffer
  "C-c C-t" #'cui-set-max-tokens-org)

;; -=-= Minor mode: hook - Fontify Markdown blocks and Tags - function for hook

(defun cui--insert-after (list pos element)
  "Insert ELEMENT at after position POS in LIST.
Used to inject font-locks to `org-font-lock-extra-keywords' variable."
  (nconc (take (1+ pos) list) (list element) (nthcdr (1+ pos) list)))


(defun cui--add-cui-font-lock-to-org-keywords ()
  "Hook, that Insert our fontify functions in Org font lock keywords."
  ;; add fontify-ai-subblocks - markdown blocks and tables.
  ;; Put in order to `org-font-lock-keywords': (cui-block--font-lock-fontify-markdown-and-org) (cui-block-tags--font-lock-fontify-links) (cui-block--font-lock-fontify-markdown-blocks)
  (when cui-fontification-flag
    ;; 3) fontify markdown blocks (and clear small)
    (setq org-font-lock-extra-keywords (cui--insert-after
                                        org-font-lock-extra-keywords
                                        (seq-position org-font-lock-extra-keywords '(org-fontify-meta-lines-and-blocks))
                                        '(cui-block--font-lock-fontify-markdown-blocks)))
    ;; 2) fontify-links (and clear small)
    (setq org-font-lock-extra-keywords (cui--insert-after
                                        org-font-lock-extra-keywords
                                        (seq-position org-font-lock-extra-keywords '(org-fontify-meta-lines-and-blocks))
                                        '(cui-block-tags--font-lock-fontify-links)))
    ;; 1) fontify small elements
    (setq org-font-lock-extra-keywords (cui--insert-after
                                        org-font-lock-extra-keywords
                                        (seq-position org-font-lock-extra-keywords '(org-fontify-meta-lines-and-blocks))
                                        '(cui-block--font-lock-fontify-markdown-and-org)))))

;; -=-= Tangling advices
(defun cui--org-babel-get-src-block-info (no-eval datum)
  "Used for Tangling as advice for `org-babel-get-src-block-info'.
Return caontent with help of `cui-block-get-content',
 `cui-block-tags-get-content' DATUM is not optional here.
If NO-EVAL is non-nil, do not evaluate Lisp in parameters."
  (cui--debug "cui--org-babel-get-src-block-info" no-eval datum)
  (let* ((lang "ai")
         (name (org-element-property :name datum))
         ;;
         (info
	  (list
	   lang ; "elisp"
           ;; 1) content: here we replace links in all messages for code simplicity.
           (cui-block-tags--clear-properties
            (cui-block-tags-replace (cui-block-get-content datum nil :tangle nil)
                                    (cui-block-get-header-marker datum)))
           ;; 2) org-babel-default-header-args + default "lang" parameters:
           (apply #'org-babel-merge-params
		  org-babel-default-header-args
		  ;; org-babel-default-header-args:ai ; (eval org-babel-default-header-args:ai t)
		  (append
		   ;; If DATUM is provided, make sure we get node
		   ;; properties applicable to its location within
		   ;; the document.
		   (org-with-point-at (org-element-property :begin datum)
		     (org-babel-params-from-properties lang no-eval))
		   (mapcar (lambda (h)
			     (org-babel-parse-header-arguments h no-eval))
			   (cons (org-element-property :parameters datum)
				 (org-element-property :header datum)))))
           ;; 3,4,5,6)
	   (or (org-element-property :switches datum) "")
           name
	   (org-element-property :post-affiliated datum)
	   (org-src-coderef-format datum))))
    (unless no-eval
      (setf (nth 2 info) (org-babel-process-params (nth 2 info))))
    (setf (nth 2 info) (org-babel-generate-file-param name (nth 2 info)))
    info))

(defun cui--org-babel-where-is-src-block-head-advice (orig-fun &rest args)
  "Advice for `org-babel-tangle' related function.
ORIG-FUN is `org-babel-where-is-src-block-head' and its ARGS."
  (if-let ((element (or (and args (cui-block-p (car args)))
                      (cui-block-p))))
      (org-element-property :begin element)
    ;; else
  (apply orig-fun args)))


(defun cui--org-babel-get-src-block-info-advice (orig-fun &rest args)
  "Advice for `org-babel-tangle' related function.
ORIG-FUN is `cui--org-babel-get-src-block-info-advice' and its ARGS."
  (seq-let (no-eval datum) args
    (if-let ((datum (or (cui-block-p datum) (cui-block-p))))
      (cui--org-babel-get-src-block-info no-eval datum)
      ;; else
      (apply orig-fun args))))
;; -=-= xref for Markdown blocks

(defun cui-xref-elisp-advice (orig-fun &rest args)
  "If inside makrdown block, jump to definition using the language.
Support only elisp.
Argument ORIG-FUN is `xref-find-definitions'.
Optional argument ARGS is `xref-find-definitions' related arguments."
  (if (bound-and-true-p cui-mode)
      (let* ((beg (car (save-excursion (cui-block--markdown-block-p))))
             (lang (when beg (save-excursion (goto-char beg)
                                             (when (looking-at cui-block--markdown-begin-re)
                                               (match-string 1))))))
        (if (member lang '("lisp" "elisp" "emacs-lisp"))
            (let ((xref-backend-functions '(elisp--xref-backend)))
              (setq xref-backend-functions xref-backend-functions)  ; noqa for: Warning: Unused lexical variable
              (with-syntax-table emacs-lisp-mode-syntax-table
                (apply orig-fun args)))
          ;; else
          (apply orig-fun args)))
    ;; else
    (apply orig-fun args)))

;; -=-= Minor mode

;;;###autoload
(define-minor-mode cui-mode
  "Minor mode for `org-mode' integration with the OpenAI API."
  :init-value nil
  :lighter cui-mode-line-string ; " cui" string
  :keymap cui-mode-map
  :group 'cui
  (unless (derived-mode-p 'org-mode)
    (user-error "Cant enable cui-mode in current buffer, not Org mode"))

  (if cui-mode
      (progn
        (add-hook 'org-ctrl-c-ctrl-c-hook #'cui-ctrl-c-ctrl-c nil 'local)
        (advice-add 'keyboard-quit :before #'cui-keyboard-quit)
        (when cui-fontification-flag
          (add-hook 'org-font-lock-set-keywords-hook #'cui--add-cui-font-lock-to-org-keywords nil 'local)
          (org-set-font-lock-defaults)
          (font-lock-refresh-defaults))
        ;; - activate "ai" block in Org mode
        (when (and (boundp 'org-protecting-blocks) (listp org-protecting-blocks))
          (add-to-list 'org-protecting-blocks "ai")
          (add-to-list 'org-protecting-blocks "cui"))
        (when (boundp 'org-structure-template-alist)
          (add-to-list 'org-structure-template-alist '("A" . "cui")))
        ;; - Tangle: advice
        (advice-add 'org-babel-get-src-block-info :around #'cui--org-babel-get-src-block-info-advice)
        (advice-add 'org-babel-where-is-src-block-head :around #'cui--org-babel-where-is-src-block-head-advice)
        (add-to-list 'org-babel-tangle-lang-exts '("ai" . "ai")) ; language . ext
        (add-to-list 'org-babel-tangle-lang-exts '("cui" . "cui"))
        ;; - xref for Markdown blocks
        (advice-add 'xref-find-definitions :around #'cui-xref-elisp-advice))
    ;; else - off
    (remove-hook 'org-ctrl-c-ctrl-c-hook #'cui-ctrl-c-ctrl-c 'local)
    (advice-remove 'keyboard-quit #'cui-keyboard-quit)
    ;; font lock refrash
    (remove-hook 'org-font-lock-set-keywords-hook #'cui--add-cui-font-lock-to-org-keywords)
    (org-set-font-lock-defaults)
    (font-lock-refresh-defaults)
    ;; tangle
    ;; (advice-remove 'org-babel-get-src-block-info #'cui--org-babel-get-src-block-info-advice)
    ;; (advice-remove 'org-babel-where-is-src-block-head #'cui--org-babel-where-is-src-block-head-advice)
    ;; (setq org-babel-tangle-lang-exts
    ;;   (remove '("ai" . "ai") org-babel-tangle-lang-exts))
    ;; (setq org-babel-tangle-lang-exts
    ;;   (remove '("cui" . "cui") org-babel-tangle-lang-exts))
    ))

(defun cui--get-buffers-for-element (&optional element)
  "Simplify getting url buffers associated with cui block ELEMENT.
Or for cui block at current position in current buffer.
Used in `cui-open-request-buffer'."
  (when-let ((element (or element (cui-block-p))))
      (cui-timers--get-keys-for-variable (cui-block-get-header-marker element))))

(defun cui-open-request-buffer ()
  "Opens the url request buffer for cui block at current position."
  (interactive)
  (if-let ((element (cui-block-p)))
      (if-let* ((url-buffer (car (cui--get-buffers-for-element element)))
                (display-buffer-base-action
                 (list '(
                         ;; display-buffer--maybe-same-window  ;FIXME: why isn't this redundant?
                         display-buffer-reuse-window ; pop up bottom window
                         display-buffer-in-previous-window ;; IF RIGHT WINDOW EXIST
                         display-buffer-in-side-window ;; right side window - MAINLY USED
                         display-buffer--maybe-pop-up-frame-or-window ;; create window
                         ;; ;; If all else fails, pop up a new frame.
                         display-buffer-pop-up-frame )
                       '(window-width . 0.6) ; 80 percent
                       '(side . right))))
          (progn
            (pop-to-buffer url-buffer)
            (with-current-buffer url-buffer
              (local-set-key (kbd "C-c ?") 'delete-window)))
        ;; else
        (message "No url buffer found"))
  ;; - else - no element - call original Org key
  (cui--call-next-key-remap-protected "C-c C-.")))

;; -=-= Minor mode - string line
(defvar cui-mode-line-string "")

(defun cui-update-mode-line (count)
  "Used in ora-timers.el to show COUNT of active requests."
  (cui--debug "cui-update-mode-line %s" count)
  (if (and count (> count 0))
      (setq cui-mode-line-string (format " cui[%d]" count))
    ;; else
    (setq cui-mode-line-string " cui"))
  (force-mode-line-update t))

;; -=-= aliases
(defalias 'cui-tangle #'org-babel-tangle)
;; -=-= provide
(provide 'cui)
;;; cui.el ends here
