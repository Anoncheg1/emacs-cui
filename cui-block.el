;;; cui-block.el --- ai special block related variables and code -*- lexical-binding: t; -*-

;; Copyright (C) 2025 github.com/Anoncheg1,codeberg.org/Anoncheg
;; SPDX-License-Identifier: AGPL-3.0-or-later
;; Author: <github.com/Anoncheg1,codeberg.org/Anoncheg>

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

;;; Commentary:

;; Defines functions for dealing with cui block as Org special-block

;; None Org babel: We choose not to fake as babel source block and use
;; functionality because it require too much advices.

;; Note Org terms:
;; - element - "room" you are in (e.g., a paragraph) (TYPE PROPS) (org-element-at-point)

;; - context - "furniture" you are touching within that room (e.g., a
;;   bold word, a link). (TYPE PROPS) (org-element-context)
;; - org-dblock-start-re
;;
;;; TODO:
;; - replace all cl-lib with built-in Elisp code
;; - simplify some functions
;; - get rid of lambdas.
;; - ### without text break highlighting for [ME]:

;;; Code:
;; -=-= includes
(require 'org)
(require 'org-element)
(require 'org-macs)
(require 'ob) ; for tangling
(require 'cl-lib) ; for `cl-letf', cl-defun, cl-loop, cl-case
(require 'cui-debug)

;; -=-= customizable variables
(defcustom cui-block-fontify-markdown-flag t
  "Non-nil means enable fontinfication for ```lang blocks."
  :type 'boolean
  :group 'cui)

(defcustom cui-block-fontify-org-tables-flag nil
  "Non-nil means enable fontinfication for Org tables."
  :type 'boolean
  :group 'cui)

(defcustom cui-block-fontify-markdown-headers-and-formatting t
  "Non-nil means enable fontinfication for Org tables."
  :type 'boolean
  :group 'cui)

(defcustom cui-block-fontify-latex t
  "Non-nil means enable fontinfication for not quoted LaTex."
  :type 'boolean
  :group 'cui)

(defcustom cui-block-roles-prefixes '(("SYS" . system)
                                      ("ME" . user)
                                      ("ai" . assistant) ; lowercase for style, but case is ignored
                                      ("AI_REASON" . assistant_reason)) ; "AI_REASON" used in `cui-block-msgs--parse-part'
  "Map cui roles to chat prefixes to output to user.
When restapi -> prefix, first matched is used.
Used in `cui-block-msgs--parse-part' with ignoring case..
Closely bound with `cui-block--chat-prefixes-re' variable."
  :type '(repeat (cons (string :tag "Role Name")
                       (symbol :tag "Role Symbol")))
  :group 'cui)

;; (let ((role "Me"))
;;   (cdr (assoc-string role cui-block-roles-prefixes t))) ;; => 'user

(defcustom cui-block-roles-restapi
  '(("system" . system)
    ("user" . user)
    ("assistant" . assistant)
    ("assistant_reason" . assistant_reason))
  "Map RestAPI JSON reply roles to cui roles.
Used by `cui-block--insert-stream-response' in sensitive to case way."
  :type '(repeat (cons (string :tag "Role Name")
                       (symbol :tag "Role Symbol")))
  :group 'cui)

;; (cdr (assoc-string "assistant" cui-block-roles-restapi)) ; => assistant
;; (car (rassoc ' cui-block-roles-restapi)) ; => "+me"

(defvar cui-block-after-chat-insertion-hook nil
  "Hook that is called when a chat response is inserted.
Note this is called for every stream response so it will typically only
contain fragments.
For STREAM executed for every word and one time with TYPE=\'end.
For non-STREAM executed one time with TYPE=\'end.
Arguments: type, role-text, pos, buffer
- TYPE - simbol \='role, \='text or'end,
- ROLE-TEXT - text or role name,
- POS - position before text insertion
- STREAM - stream mode or a single insertion.")


(defcustom cui-block-parse-part-hook nil
  "Run before request preparation after splitting cui block to chat messages.
Call hook function with raw string of current block after role prefix.
 Implemented as a list of functions that called with two argument
 content string after prefix and role prefix as a symbol from from
 `cui-block-roles-prefixes'.  Executed from left to right and pass
 result content string to each other."
  :type 'hook
  :group 'cui)

(defcustom cui-block-jump-to-end-of-block t
  "If non-nil, jump to the end of the block after inserting response."
  :type 'boolean
  :group 'cui)

(defcustom cui-block-fill-function #'cui-block-fill-insert
  "If non-nil this function will be called after insertion of text.
Current buffer is buffer with cui block with position of pointer right
after insertion of text.
Accept parameters: POS before insertion and and STREAM boolean flag.
Should check that position is not inside markdown block
and string is not quoted with \"> \".  Should be executed in
save-excursion to preserve relative point position.
TODO: for streaming: save and pass begining of paragraph or line."
  :type '(choice (const :tag "None" nil)
                 (function :tag "Function"))
  :group 'cui)

;; -=-= faces
(defface cui-block-quote
    '((((class color) (min-colors 88) (background dark)) :background "#282828" :foreground "shadow")
      (((class color) (min-colors 88) (background light)) :background "#eeeeee" :foreground "gray")
      (((class color) (min-colors 8)) (:background "cyan" :foreground "black"))
      (t :background "gray" :extend t))
  "Face for single markdown quoted text."
  :group 'cui-faces)

(defface cui-block-m-header1
  '((((background dark)) :foreground "yellow" :weight light)
    (((background light)) :foreground "green" :weight bold))
  "Face for single markdown header single # character."
  :group 'cui-faces)

(defface cui-block-m-header2
  '((((background dark)) :foreground "gold2" :weight light)
    (((background light)) :foreground "gold3" :weight bold))
  "Face for single markdown header two # characters."
  :group 'cui-faces)

(defface cui-block-m-header3
  '((((background dark)) :foreground "orange" :weight light)
    (((background light)) :foreground "gold4" :weight light))
  "Face for single markdown header three and more # characters."
  :group 'cui-faces)

(defface cui-block-m-header4
  '((((background dark)) :foreground "orange3" :weight light)
    (((background light)) :foreground "orange4" :weight light))
  "Face for single markdown header three and more # characters."
  :group 'cui-faces)

(defcustom cui-block-m-header-colors '(cui-block-m-header1 cui-block-m-header2 cui-block-m-header3 cui-block-m-header4)
  "Colors that used to fontify markdown headers.
First is used for one # character 4 for ####, for 5 and more 4 is used."
  :type '(repeat face)
  :group 'cui-faces)

(defface cui-chat-role	   ;Copied from `font-lock-variable-name-face'
  '((((class color) (min-colors 16) (background light)) (:foreground "sienna" :slant italic))
    (((class color) (min-colors 16) (background dark)) (:foreground "DarkGoldenrod" :slant italic))
    (((class color) (min-colors 8)) (:foreground "yellow" :weight light))
    (t :inverse-video t))
  "Face used for [AI]: [ME]:."
  :group 'cui-faces)

(defface cui-bold '((t :inherit default))
  "Face used for *,** and *** Org and markdown text formatting."
  :group 'cui-faces)

;; -=-= variables
(defvar cui-block-roles-restapi-unknown 'assistant
  "Used for restapi reply if role in JSON was not found.
In `cui-block--insert-stream-response'.")

(defvar cui-block-roles-prefixes-unknown 'assistant
  "Used in `cui-block-msgs--parse-part' for prefix not found.
In `cui-block-roles-prefixes'.")

;; ;; RestAPI -> Prefix
;; (let ((role 'user1))
;;   (or (car (rassoc role cui-block-roles-prefixes))
;;       (car (rassoc cui-block-roles-restapi-unknown cui-block-roles-prefixes)))) ; => "ai+"

;; ;; Prefix -> system
;; (let ((role "+me1"))
;;   (or (cdr (assoc-string role cui-block-roles-prefixes)) ; Get value by key
;;       cui-block-roles-prefixes-unknown)) ; => assistant

(defconst cui-block--cui-block-begin-re "^[ \t]*#\\+begin_\\(ai\\|cui\\).*$")
(defconst cui-block--cui-block-end-re "^[ \t]*#\\+end_\\(ai\\|cui\\).*$")
(defconst cui-block--cui-block-begin-end-re "^[ \t]*#\\+\\(begin\\|end\\)_\\(ai\\|cui\\).*$")
;; org-babel-src-name-regexp)
(defvar cui-block--markdown-begin-re "^\\s-*```\\([^\s\t\n[{]+\\)[\s\t]*$")
(defvar cui-block--markdown-end-re "^[\s\t]**```[\s\t]*$")
;; (defvar cui-block--markdown-beg-end-re "^[\s\t]*```\\(.*\\)$")
(defvar cui-block--markdown-beg-end-re "^[\s\t]*```\\([^`\n]*\\)$")
(defvar cui-block--chat-prefixes-re "^[\s\t]*\\[\\([^\]]+\\)\\(:\\]\\|\\]:\\)\\s-*"
  "Prefix should be at the begining of the line with spaces or without.
Or roles regex.")
(defvar cui-block--markdown-header-re "^\\(#+\\)\\s-+\\([0-9a-zA-Z][).]\\)?\\s-*\\(.*\\)$"
  "Match markdown headers starting with one or more # character.
Used for highlighting and for jumping.")


(defface cui-block--me-ai-chat-prefixes-font-face
  '((t :weight bold))
  "Face font for chat roles (default bold).
You can customize this font with `set-face-attribute'."
  :group 'cui)

;; -=-= fn: block-p, element-by-marker
;; `org-element-with-disabled-cache' is not available pre `org-mode' 9.6.6, i.e.
;; emacs 28 does not ship with it
;; (defmacro cui-block--org-element-with-disabled-cache (&rest body)
;;   "Run BODY without active org-element-cache."
;;   (declare (debug (form body)) (indent 0))
;;   `(cl-letf (((symbol-function #'org-element--cache-active-p) (lambda (&rest _) nil)))
;;      ,@body))


(defun cui-block-p (&optional element)
  "Check if point at cui block or ELEMENT is cui block if provided.
Optional argument ELEMENT is returned by `org-element-at-point', when
 non-nil, checked if it is cui block, if not nil is retuned.
If ELEMENT is not provider, current position in buffer used to get ai
 block.
Raise error if ELEMENT is not cui block or there is no cui block at
 current position.
Like `org-in-src-block-p'.
Return element or nil."
  (if (and element
           (or (string-equal "ai" (org-element-property :type element))
               (string-equal "cui" (org-element-property :type element))))
      element
    ;; else
    ;; (cui-block--org-element-with-disabled-cache ;; with cache enabled we get weird Cached element is incorrect warnings
    ;; (let* ((org-element-use-cache nil)
    (org-element-with-disabled-cache
      (let ((sel (org-element-lineage
                  (save-match-data (org-element-context)) (list 'special-block) t)))
        (when (and sel (or (string-equal "ai" (org-element-property :type sel))
                           (string-equal "cui" (org-element-property :type sel))))
          sel)))))


;; -=-= info fn: get-info, get-request-type, get-sys
(defun cui-block-get-info (&optional element no-eval)
  "Parse the header of cui block.
ELEMENT is the element of the special block.
Like `org-babel-get-src-block-info' but instead of list return only
arguments.
To get value use: (alist-get :value (cui-block-get-info))
Use ELEMENT only in current moment.
When optional argument NO-EVAL is non-nil, do not evaluate Lisp
in parameters.
Return an alist of key-value pairs."
  (org-babel-parse-header-arguments
   (org-element-property
    :parameters
    (or element (cui-block-p))) no-eval))


(defun cui-block--get-request-type (info)
  "Look at the header of cui block.
returns the type of request.  INFO is the alist of key-value
  pairs from `cui-block-get-info'."
  ; (alist-get :chat info 'x) - return x if  there is no :chat, if present return string or number value or nil if no value
  (cond
   ((not (eql 'x (alist-get :chat info 'x))) 'chat)
   ((not (eql 'x (alist-get :completion info 'x))) 'completion)
   ((not (eql 'x (alist-get :complete info 'x))) 'completion)
   (t 'chat)))

(cl-defun cui-block--get-sys (&key info default)
  "Check if :sys exist in #+begin_cui parameters.
If exist return nil or string, if not exist  return `default'.
Argument INFO is the alist of key-value pairs from `cui-block-get-info'.
DEFAULT is a string with default system prompt for LLM."
  (let ((sys-raw  (alist-get :sys info 'x)))
    ;; if 'x - not resent
    (if (eql 'x sys-raw)
        default
      ;; else - nil or string
      sys-raw)))

;; -=-= macro: let-params

;; Logic & Purpose:
;;  ----------------
;;  Cui blocks require parameters that may be defined in three distinct scopes.
;;  This macro provides a unified "Waterfall" lookup and type-safety layer:
;;
;;  1. Priority Sourcing (The Waterfall):
;;     - Local Header (INFO):  Explicit block arguments (e.g., :model "gpt-4").
;;                             If a key exists without a value (e.g., :flag),
;;                             it is treated as a boolean `t`.
;;     - Subtree Properties:   Inherited Org-mode properties. These are
;;                             ALWAYS strings (e.g., #+PROPERTY: model gpt-4).
;;     - Default Value:        The hardcoded fallback if no other source exists.
;;
;;  2. Type Normalization (The Coercion):
;;     Org properties return strings, but Elisp logic needs types. This
;;     logic handles "human" input error (e.g., typing "nil" or "off" in Org):
;;
;;     - 'number:  Converts strings; handles "nil" strings and empty switches as nil.
;;     - 'bool:    Strict whitelist. Only "t", "true", "yes", "on", "1" are `t`.
;;                 Strings like "off", "no", or "0" become `nil`.
;;     - 'string:  Filters out bare switches (t) and "nil" strings to return
;;                 a clean Elisp `nil` symbol.

;; Everything inside the mapcar (like intern and symbol-name) happens
;;  while the code is being loaded or compiled. The cui-block--get-val
;;  function is what actually does the work when the code is executed.


(defun cui-block--get-val (info key &optional prop default type)
  "Resolve and cast VALUE from INFO, Org properties, or DEFAULT.
Arguments
- KEY is keyword as in header specified.
- PROP is keyword without column first character converted to string, used
 to get org property with `org-entry-get-with-inheritance'.
- TYPE is a symbol: number, bool or string or nil to pass is it was
 detected in info.
Return new value."
  (let* ((entry (assoc key info))
         ;; 1. Value sourcing: Priority (Header Alist > Org Prop > Default)
         (v (or (and entry
                     (or (cdr entry) t))
                (and prop (org-entry-get-with-inheritance prop))
                default)))
    ;; 2. Declarative Type Casting
    (pcase type
      ('number (cond ((or (null v) (eq v t) (and (stringp v) (string-equal v "nil"))) nil) ; key without value or "nil"
                     ((stringp v) (string-to-number v))
                     ((numberp v) v)
                     (t (user-error "Invalid number: %s" v))))
      ('bool   (when (and v (or (eq v t)
                          (and (stringp v)
                               (member (downcase v) '("t" "true" "yes" "on" "1")))))
                 t))
      ('string (if (or (eq v t) ; key without value
                       (string-equal v "nil")) ; key with nil
                       nil
                 ;; else
                 v))
      (_ v))))

;; info cases:
;; - string: '((:model . "openai/gpt-4.1"))
;; - int: '((:max-tokens . 3000))
;; - 'nil: '((:model))
;; - only key: '((:model))
;; - nil: '((:model . "nil"))
;; get value from info:
;; - (alist-get :model '((:model . "nil"))) => "nil"
;; - (alist-get :model '((:model))) => nil
;; - (alist-get :model '(())) => nil
;; - (assoc :model '(())) => nil => (cdr nil) => nil
;; - (assoc :model '((:model))) => (:model) => (cdr '(:model)) => nil
;; - (assoc :model '((:model . "nil"))) => (:model . "nil") => (:model . "nil") => "nil"
;; (concat \":\" (symbol-name sym))
;; Solution:
;; (let* ((v1 (assoc :model '((:model))))
;;           (v2 (cdr v1)))
;;     (if (and v1 (not v2))
;;         "nil"
;;       v2))

;; -=-= get-content: help fn
(defun cui-block--replace-string-in-string (string from to replacement)
  "Replace the substring of STRING from FROM to TO with REPLACEMENT."
  (concat (substring string 0 from)
          replacement
          (substring string to)))

(defun cui-block--apply-noweb (string)
  "Expand noweb Org links in STRING.
Add text property around replaced part to highlight it.
Used as argument for `cui-block-msgs--modify-vector-last-user-content' and
 `cui-block-msgs--modify-vector-content'."
  (cui--debug "cui-block--apply-noweb"  string)
  ;; (org-babel-expand-noweb-references (list "markdown" string))
  (let ((pos 0) beg end replacement)
    (while (string-match "<<\\([^\n]+?\\)>>" string pos)
      (setq beg (match-beginning 0))
      (setq end (match-end 0))

      (setq replacement (org-babel-expand-noweb-references
                        (list "markdown" (substring (substring
                                                     string
                                                     beg end)))))
      (setq pos (+ beg (length replacement)))
      (setq string (cui-block--replace-string-in-string
                    string
                    beg end
                    replacement))
      (add-text-properties beg (+ beg (length replacement)) '(face region) string)))
  string)


(defun cui-block--contents-region (&optional element)
  "Return cons with start and end position of cui block content.
Start and first line after header, end at of line of the first not empty
 line before footer.
Same as `org-src--contents-area', but without content.
Optional argument ELEMENT should be cui block if specified.
Return nil or cons."
  (when-let ((element (or element (cui-block-p))))
    (let ((beg (org-element-property :contents-begin element))
          (end (org-element-property :contents-end element)))
      (cui--debug "cui-block--contents-region %s" beg end)
      (save-excursion
        (if (and beg end)
            (progn
              (goto-char end)
              ;; skip empty lines
              (while (and (bolp) (>= (point) beg))
                (backward-char))
              (forward-char)
              (cons beg (point)))
          ;; else - empty block
          (org-with-wide-buffer
           (goto-char (org-element-property :begin element))
           (cons (line-beginning-position 2) (line-beginning-position 2))))))))


(defun cui-block--region (&optional element)
  "Return whole cui block cons start and end positions.
Execution in not `org-mode' is supported.
In not `org-mode' return whole buffer min max position.
Start at header begining of line, end at footer end of line.
Optional argument ELEMENT is cui block."
  (if-let ((element (or element (when (derived-mode-p 'org-mode)
                                    (cui-block-p)))))
    (cons (org-element-property :begin element)
	  (save-excursion
            (goto-char (org-element-property :end element))
	    (skip-chars-backward " \r\t\n")
            (point)))
    ;; else
    (when (not (derived-mode-p 'org-mode))
      (cons (point-min) (point-max)))))

;; -=-= get-content: fn

(defun cui-block-get-content (&optional element noweb-control noweb-context not-clear-properties)
  "Extracts the text content of the #+begin_cui...#+end_cui block.
Don't support tags and Org links expansion, for that use
 `cui-block-tags-get-content' instead.
ELEMENT is the element of the cui block, use only in current moment, if
 buffer modified you will need new ELEMENT.
If NOWEB-CONTROL boolean is non-nil, activate no noweb references.
If NOWEB-CONTEXT  is non-nil,  NOWEB-CONTROL is  not used,  Org property
 :eval is used, that may be \"yes\" \"tangle\" \"no-export\", etc.
NOWEB-CONTEXT may be one of :tangle, :export or :eval, the last is by
 default, more documentation in `org-babel-noweb-p' function.
same as `org-babel--normalize-body'.
Return string without properties or nil.
Optional argument NOT-CLEAR-PROPERTIES, prevent cleaning of properties,
 we add properties to highlight expanded noweb references for
 previewing."
  (when-let ((reg (cui-block--contents-region element)))
    (let ((con-beg (car reg))
          (con-end (cdr reg)))
      (cui--debug "cui-block-get-content %s %s" con-beg con-end)
      (org-with-wide-buffer
       (let* ((unexpanded-content (if (or (not con-beg) (not con-end))
                                      (error "Empty block")
                                    ;; else
                                    (string-trim (buffer-substring-no-properties con-beg con-end))))
              (noweb-control (or noweb-control
                                 (org-babel-noweb-p (cui-block-get-info element)
                                                    (or noweb-context :eval))
                                 (org-entry-get (point) "cui-noweb" t)))
              (content (if noweb-control
                           ;; pass info
                           (if not-clear-properties
                               (cui-block--apply-noweb unexpanded-content)
                             ;; else
                             (org-babel-expand-noweb-references (list "markdown" unexpanded-content))) ; main
                         unexpanded-content)))
         (string-trim content))))))

;; -=-= help function to call hooks as pipeline with one argument
(defun cui-block--pipeline (funcs init-val &rest args)
  "Process INIT-VAL through a pipeline of functions FUNCS.
Each function in FUNCS is called as (func val &rest ARGS), where VAL is
 the result of previous function (or INIT-VAL for the first), and ARGS
 are optional additional arguments supplied to this function.
Used for `cui-restapi-after-prepare-messages-hook'.
Returns the result of the final function in FUNCS, or INIT-VAL if FUNCS
 is nil."
  (if funcs
      (let ((result init-val))
        (dolist (f funcs result)
          (setq result (apply f result args))))
    ;; else
    init-val))

(defmacro cui-block--pipeline-macro (var-list func-list)
  "Apply FUNC-LIST sequentially to a plist created from VAR-LIST.

Useful for pipelining variable transformations, e.g. in hooks.
Each function should accept and return a plist.  The macro constructs the plist
from VAR-LIST variable names (as keywords) and their current values, then passes
it through each function in FUNC-LIST.

Returns a list of resulting values for VAR-LIST, in order.
If func-list is nil return original VAR-LIST."
  `(let* ((initial-plist
           (list ,@(apply #'append
                          (mapcar (lambda (v)
                                    (list (intern (concat ":" (symbol-name v))) v))
                                  var-list))))
          (result
           (let ((plist initial-plist))
             (dolist (f ,func-list plist)
               (setq plist (funcall f plist)))))
          (vals
           (mapcar (lambda (v)
                     (plist-get result (intern (concat ":" (symbol-name v)))))
                   ',var-list)))
     vals))

;; -=-= fn: find-region by position

(defun cui-block--find-region-with-position (regions pos)
  "Find region for POS in REGIONS provided.
Return ((START . END) . N) [the region boundaries and region number]
REGION boundary points (sorted, e.g.  (10 20 30)), is positions returned
 by `cui-block--markdown-block-regions' or
 `cui-block--chat-role-regions'.
POS should be within any region, or at its left boundary.  Else return
 nil."
  ;; Initialization: 'start' and 'end' will hold the current region's boundaries.
  ;; 'i' counts regions found so far.
  (let ((start nil)
        (end nil)
        (i -1))
    ;; Iterate through 'regions' list.
    (dolist (x regions)
      ;; Update start and count if x <= pos.
      (if (<= x pos)
          (setq start x i (1+ i))
        ;; If x > pos and 'end' not set, set end boundary.
        (unless end (setq end x))))
    ;; If both start and end found, return region and index.
    (if (and start end)
        (cons (cons start end) i)
      ;; Special case: pos == start and it's at a region boundary.
      (if (and start (not end)
               (eq pos start)
               (> (length regions) 1))
          (cons (cons (nth (- (length regions) 2) regions)
                      start)
                (- i 1))
        ;; else - If not found, return nil.
        ;; (if (and start (not end))
        ;;     (cons (cons start end) i)
          ;; else
          nil))))

;; -=-= fns: Markdown block check pos

(defun cui-block--markdown-block-regions (beg end)
  "Return position of markdown subblocks begining and ending headers.
Execution in not `org-mode' is supported.
BEG and END is a range in which to search markdown.
Careful, move pointer.
Positions in list are begining of lines.
Return list of integers or nil."
  (goto-char beg)
  (let (regions markdown-beg)
    (while (and (< (point) end)
                ;; 1) find begining of block
                (and (re-search-forward cui-block--markdown-beg-end-re end t)  ; point is at end of line now or next line
                     (setq markdown-beg (line-beginning-position)))
                ;; 2) find end of block
                (re-search-forward cui-block--markdown-end-re end t)) ; may be at the end of line or at next line
      (push markdown-beg regions)
      (push (line-beginning-position) regions))
    ;; if last block without ending, we presume that it ends and "end"
    (when (and regions
               (not (member markdown-beg regions))
               (progn (goto-char markdown-beg)
                      (looking-at cui-block--markdown-begin-re)))
      (push markdown-beg regions)
      (push end regions))
    ;; (print (list regions (member markdown-beg regions)))
    (when regions
      (reverse regions))))


(defun cui-block--markdown-block-p (&optional limit-start limit-end)
  "Return (cons beg end) if pos is inside markdown block.
Execution in not `org-mode' is supported.
Caution: move pointer at the end of the last markdown subblock footer.
If POS is not provided current cursor position is used.
LIMIT-START and LIMIT-END are parameters for
 `cui-block--markdown-block-regions', if not provided cui block
 content region is used or `point-min' and `point-max`.
If POS at the footer of block, return nil.

Return (cons beg end), Where beg is bol for markdown block, end is bol
 of next line after markdown block.  If not found return nil."
  (cui--debug "cui-block--markdown-block-p N0 %s %s" limit-start limit-end)
  ;; - preparation
  (let ((pos (line-beginning-position))
        (reg (unless (and limit-start limit-end)
               (if (derived-mode-p 'org-mode)
                   (or (cui-block--contents-region)
                       (error "Not at cui block in Org mode"))
                 ;; else
                 (cons (point-min) (point-max))))))
    (let ((limit-start (or limit-start (car reg)))
          (limit-end (or limit-end (cdr reg))))
      ;; - main
      (cui--debug "cui-block--markdown-block-p N1 %s %s" limit-start limit-end)
      (when-let* ((regions (cui-block--markdown-block-regions limit-start limit-end))
                  (res (cui-block--find-region-with-position regions pos)))
        (cui--debug "cui-block--markdown-block-p N10 %s %s %s" (point) regions res)
        (if (zerop (mod (cdr res) 2)) ; we need 0 2 4
            (car res)
          ;; else - special case - pointer at the footer line.
          (cui--debug "cui-block--markdown-block-p N11" regions res)
          (goto-char pos)
          (when (and (looking-at cui-block--markdown-end-re)
                     (> (length regions) (cdr res)))
            ;; second attempt
            (forward-line -1)
            (let ((res (cui-block--find-region-with-position regions (point))))
              (cui--debug "cui-block--markdown-block-p N2" res)
              (when (zerop (mod (cdr res) 2))
                (car res)))))))))

(defun cui-block--markdown-block-content-range (m-block-start m-block-end)
  "For markdown subblock return cons of content start and content ends.
M-BLOCK-START M-BLOCK-END are line begin position of markdown range with
 header and footer as returned by `cui-block--markdown-block-p',
 `cui-block--markdown-block-regions'.  Caution, move pointer."
  (goto-char m-block-end) ; begin of line at ```
  (while (bolp)
    (backward-char))
  (cons (save-excursion
          (goto-char m-block-start)
          (forward-line)
          (point))
        (point)))

(defun cui-block--at-special-p (pos &optional dont-check-tables)
  "Check if POS in markdown block, quoted or is a table.
Optional argument LIM-BEG is cui block begining position.
Return t if pos in markdown block, table or quote.
Side-effect: set pointer position to POS.
If Optional argument DONT-CHECK-TABLES is not-nil disable checking if
pos at Org table."
  (goto-char pos)
  (prog1
      ;; not quoted, in tables
      (progn (goto-char pos)
             (beginning-of-line)
             (or (looking-at "^\\s-*> ") ; from `cui-block-fill-region-as-paragraph'
                 (and (not dont-check-tables) (looking-at "^[ \t]*\\(|\\|\\+-[-+]\\).*")))) ; skip tables
    (goto-char pos)))

(defun cui-block--markdown-quotes-at-line-p (pos &optional delimiter beg end)
  "Return t if POS is inside any markdown quotes at current line.
if BEG END not provided, look for DELIMITER at the current line only.
DELIMITER should be a string (\"`\" or \"```\"), defaults to \"`\"."
  (save-excursion
    (let ((delimiter (or delimiter "`"))
          (bol (or beg
                   (progn (goto-char pos) (line-beginning-position))))
          (eol (or end
                   (progn (goto-char pos) (line-end-position))))
          (found nil))
      (goto-char bol)
      (while (and (search-forward delimiter eol t) (not found))
        (let ((start (match-beginning 0)))
          (when (search-forward delimiter eol t)
            (let ((end (match-end 0)))
              (when (and (>= pos start)
                         (< pos end))
                (setq found t))))))
      found)))

(defun cui-block--markdown-quotes-p (pos)
  "Return t if POS is inside any markdown backquote block at line.
on the current line.
\(`...` or ```...```\) on current line or at quote itself."
  (or (cui-block--markdown-quotes-at-line-p pos "`")
      (cui-block--markdown-quotes-at-line-p pos "```")))

;; -=-= response: insert
(defun cui-block--insert-single-response (end-marker &optional text insert-me not-final)
  "Insert result to cui block.
If text is nil, it counts as INSERT-ME and FINAL.

Set as callback `cui-restapi--url-request-on-change-function' in
`cui-restapi--url-request'.
- END-MARKER is where to put result, is a buffer and position at the end
  of block, from `cui-block--get-content-end-marker' function.
- TEXT  is  string  from  the  response of  OpenAI  API  extracted  with
  `cui-restapi--get-single-response-text'.
- if INSERT-ME is not nil, [ME] inserted.
- if NOT-FINAL is non-nill, fill-function is not used.
Variable `cui-block-roles-prefixes' is used to format role to text."
  (cui--debug "cui-block--insert-single-response end-marker %s \n insert-me %s \n not-final %s \n text:"
              end-marker insert-me not-final text)
  (let ((buffer (marker-buffer end-marker))
        (pos (marker-position end-marker))
        (text (when text (string-trim text))))
    (cui--debug "cui-block--insert-single-response buffer,pos:" buffer pos "")
    ;; - write in target buffer
    (with-current-buffer buffer ; Where target cui block located.
      (save-excursion
        ;; set mark (point) to allow user "C-u C-SPC" command to easily select the generated text
        (push-mark end-marker t)
        ;; - go  to the end of previous line and open new one
        (goto-char (1- pos)) ; to use insert before end-marker to preserve it at the end of block

        (when (and text (not (string-empty-p text)))
          ;; - remove empty lines between end of block and user question.
          (while (bolp)
            (delete-char -1))
          (newline)
          (newline)
          ;; - insert [ai]: and response
          (insert "[" (car (rassoc 'assistant cui-block-roles-prefixes)) "]: "
                  (if (string-match "\n" text) ; multiline answer we start with a new line.
                      "\n"
                    ;; else
                    "")
                  text)

          ;; - update marker
          (forward-char) ; for [ME] to the line of end block
          (set-marker end-marker (point))
          ;; - hook
          (undo-boundary)
          (run-hook-with-args 'cui-block-after-chat-insertion-hook 'end text pos nil)
          ;; - "auto-fill"
          (when (and cui-block-fill-function
                     (not not-final))
            (undo-boundary)
            (funcall cui-block-fill-function pos nil))

          (org-element-cache-reset)

          (setq pos (marker-position end-marker))
          (goto-char pos))

        ;; - Insert [ME]
        (when insert-me
          (while (bolp)
            (delete-char -1))
          (newline)
          (newline)
          (insert "[" (car (rassoc 'user cui-block-roles-prefixes)) "]: \n")
          (forward-char -1)
          (setq pos (point))
          (set-marker end-marker pos)))

      (when (or insert-me (and text (not (string-empty-p text))))
        (when cui-block-jump-to-end-of-block
          (goto-char pos))
        ;; final
        (org-element-cache-reset)
        (undo-boundary)))))

;; Used in `cui-restapi--normalize-response' and in `cui-block--insert-stream-response'
(cl-deftype cui-block--response-type ()
  '(member role text stop error))

(cl-defstruct cui-block--response ; :type is not enforced now
  (type (user-error "No default value") :type cui-block--response-type)
  (payload (user-error "No default value") :type string))

;; (make-cui-block--response :type 'role :payload "user") ; #s(cui-block--response role "user")
;; (make-cui-block--response :type 'role) ; error
;; (make-cui-block--response :payload "role") ; error
;; (make-cui-block--response :type nil :payload "role") ; #s(cui-block--response nil "role")
;; (make-cui-block--response :type 'role :payload nil) ; #s(cui-block--response role nil)
;; (cui-block--response-type (make-cui-block--response :type 'role :payload "asd")) ; 'role
;; (cui-block--response-payload (make-cui-block--response :type 'role :payload "asd")) ; "asd"

(defvar-local cui-block--current-insert-position-marker nil
  "Where to insert the result.
Used for `cui-block--insert-stream-response'.")

(defvar-local cui-block--current-chat-role nil
  "During chat response streaming, this holds the role of the \"current speaker\".
Used for `cui-block--insert-stream-response'.")

(defun cui-block--insert-stream-response (end-marker &optional responses insert-me)
  "Insert result to cui block for chat mode.
When first chunk received we stop waiting timer for request.
END-MARKER'is where to put result,
RESPONSES is a list of cui-block--response, processed by
`cui-restapi--normalize-response', consist of type symbol and payload
string.
Used as callback for `cui-restapi--url-request', called in url buffer.

Called within url-buffer.
Use buffer-local variables:
`cui-block--current-insert-position-marker',
`cui-block--current-chat-role'.

If response is multiline `cui-block-fill-function' may not
work properly.(may be old)
Argument INSERT-ME insert [ME]: at stop type of message."
  ;; (cui--debug "cui-block--insert-stream-response1 %s" (cui-restapi--normalize-response response)) ; response
  (cui--debug "cui-block--insert-stream-response1" responses)
  (when responses
    (let ((buffer (marker-buffer end-marker))
          (pos (or cui-block--current-insert-position-marker
                   (marker-position end-marker)))
          (c-chat-role cui-block--current-chat-role)
          stop-flag)
      ;; (cui--debug "cui-block--insert-stream-response2 %s" normalized)
      ;; (cui--debug "cui-block--insert-stream-response" normalized)
      (unwind-protect ; we need to save variables to url buffer
          (with-current-buffer buffer ; target buffer with block
            (save-excursion
              ;; - LOOP Per message
              (dolist (response responses)
                (let ((type (cui-block--response-type response)) ; symbol
                      (payload (cui-block--response-payload response))) ; string
                  ;; (cui--debug "cui-block--insert-stream-response: %s %s %s" type end-marker cui-block--current-insert-position-marker)
                  ;; - Type of message: error
                  (when (eq type 'error)
                    (error (cui-block--response-payload response))) ; not used

                  (goto-char pos)
                  ;; - Remove lines above and provide space below, should be covered with tests.
                  (when (looking-at cui-block--cui-block-end-re) ; "#\\+end"
                    (goto-char (1- pos)) ; to use insert before end-marker to preserve it at the end of block
                    (while (bolp)
                      (delete-char -1))
                    (setq pos (point)))

                  ;; - Type of message
                  (pcase type
                    ('role (when (not (string= payload c-chat-role)) ; payload = role
                             (goto-char pos)

                             (setq c-chat-role payload)
                             (let* ((role-cui (or (cdr (assoc-string payload cui-block-roles-restapi))
                                                  cui-block-roles-restapi-unknown)) ; string to symbol
                                    (role-prefix (car (rassoc role-cui cui-block-roles-prefixes))))

                               (insert "\n[" role-prefix "]: " (when (eql role-cui 'assistant) "\n")) ; "\n[ME:] " or "\n[AI:] \n"

                               (run-hook-with-args 'cui-block-after-chat-insertion-hook 'role payload pos t)

                               (setq pos (point)))))
                    ('text (progn ; payload = text
                             (goto-char pos)
                             (insert payload)
                             ;; - "auto-fill" if not in code block
                             (when cui-block-fill-function
                               (funcall cui-block-fill-function pos t))

                             (run-hook-with-args 'cui-block-after-chat-insertion-hook 'text payload pos t)

                             (setq pos (point))))

                    ('stop (progn ; payload = stop_reason
                             (cui--debug "cui-block--insert-stream-response3 stop_reason: %s" payload)
                             (goto-char pos)
                             (run-hook-with-args 'cui-block-after-chat-insertion-hook 'end nil pos t)
                             (let ((text (concat "\n\n[" (car (rassoc 'user cui-block-roles-prefixes)) "]: "))) ; "ME"
                               (if insert-me
                                   (insert text)
                                 ;; else
                                 (setq text ""))
                               (setq pos (point)))

                             (org-element-cache-reset)
                             (setq stop-flag t)))))))
            ;; - without save-excursion - stop: go to the end.
            (when (and cui-block-jump-to-end-of-block
                       stop-flag)
              ;; for jumping
              (unless (region-active-p)
                (push-mark nil t))

              (goto-char pos)))
        ;; - after buffer - UNWINDFORMS - save variables to url-buffer
        (setq cui-block--current-insert-position-marker pos)
        (setq cui-block--current-chat-role c-chat-role)))))

;; -=-= chat: collect-chat-messages
(defun cui-block--get-chat-messages-positions (content-start content-end &optional prefix-re markdown-check)
  "Return a flat list of positions for chat messages in current buffer.
Positions CONTENT-START CONTENT-END used as boundaries.
If MARKDOWN-CHECK is not-nil, positions counted only if not in markdown
 block.
Return positions  as start points  that match PREFIX-RE (normally  it is
`cui-block--chat-prefixes-re'), and additional positions of content start
and content end at the beginin and the end of flat list."
  (when (< content-end content-start)
    (error "Point is at wrong position"))
  (cui--debug "cui-block--get-chat-messages-positions %s" markdown-check)
  ;; (cui--debug "cui-block--get-chat-messages-positions N2" (buffer-substring-no-properties content-start content-end))
  (save-excursion
    (let ((prefix-re (or prefix-re cui-block--chat-prefixes-re))
          (positions))
      (goto-char content-start)
      ;; Collect all chat header positions
      (while (re-search-forward prefix-re content-end t) ; point at begin of next line or after space
        ;; (cui--debug "messages-positions1 %s" (point))
        ;; check that we are not in markdown subblock
        (if markdown-check ; if t enable markdown check
            (unless (save-match-data
                      (cui-block--markdown-block-p content-start content-end))
              (push (match-beginning 0) positions))
          ;; else
          ;; (print(buffer-substring-no-properties (1- (match-beginning 0)) (match-end 0)))
          (push (match-beginning 0) positions))
        (goto-char (match-end 0)))
      (setq positions (nreverse positions))
      ;; Ensure content-start is included first
      (unless (and positions (= (car positions) content-start))
        (push content-start positions))
      ;; Ensure content-end is included at last
      (unless (and positions (= (car (last positions)) content-end))
        (setq positions (append positions (list content-end))))
      ;; return
      positions)))

(defun cui-block--chat-role-regions (&optional element)
  "Splits the special block by role prompt.
Execution in not `org-mode' is supported.
Optional argument ELEMENT should be cui block
Return line begining positions of first line of content, roles,
 #+end_cui line."
  (let* ((element (or element (when (derived-mode-p 'org-mode)
                                (cui-block-p))))
         (reg (or (when element (cui-block--contents-region element))
                  (cons (point-min) (point-max)))) ; in ai file
         (con-beg (car reg))
         (con-end (cdr reg)))
    (cui-block--get-chat-messages-positions con-beg con-end cui-block--chat-prefixes-re)))



;; -=-= Interactive: mark-at-point

(defun cui-block-mark-last-region ()
  "Mark the last prompt in an cui block."
  (interactive)
  (when (cui-block-p)
    (let* ((regions (reverse (cui-block--chat-role-regions)))
           (last-region-end (pop regions))
           (last-region-start (pop regions)))
      (goto-char last-region-end)
      (push-mark last-region-start t t))))


(defun cui-block-mark-chat-message-at-point ()
  "Mark the prompt at point: [ME:], [AI:]."
  (interactive)
  (when (cui-block-p)
    (when-let* ((regions (cui-block--chat-role-regions))
                (reg (car (cui-block--find-region-with-position regions (point))))
                (beg (car reg))
                (end (cdr reg)))
      (unless (region-active-p)
        (goto-char beg)
        (push-mark end t t)
        reg))))

;; -=-= Interactive: jump forward/backward

(defun cui-block--find-next-prev-region (&optional direction current-point regions)
  "Find the N-th next or previous region boundary.
DIRECTION is an integer: positive to move forward N regions, negative to
 move backward.
CURRENT-POINT is the position to start from (defaults to point).
REGIONS is a list of region boundaries (defaults to
 `cui-block--chat-role-regions`).
Returns the position of the N-th region boundary in the given DIRECTION,
 or nil if not found."
  (let* ((direction (or direction 1))
         (n (abs direction))
         (current-point (or current-point (point)))
         (regions (or regions (cui-block--chat-role-regions)))
         (count 0))
    (catch 'found
      (dolist (r (if (> direction 0) regions (reverse regions)))
        (when (if (> direction 0)
                  (> r current-point)
                (< r current-point))
          (setq count (1+ count))
          (when (= count n)
            (throw 'found r))))
      nil)))

(defun cui-block-next-message (&optional arg)
  "Navigate between cui block messages based on ARG.
Execution in not `org-mode' is supported.
ARG may be nil, forward if positive or backward if negative between
 roles in cui block.
Set cursor at next chat role or end block line or end of buffer."
  (interactive "^p")
  (or arg (setq arg 1))
  (when (and arg (< arg 0))
    (forward-line -1))
  (let ((target-region (cui-block--find-next-prev-region arg)))
    (cui--debug "cui-block-next-message %s %s" target-region arg)
    ;; Save cursor position if no region is active
    (unless (region-active-p) (push-mark nil t))
    ;; Jump to the target region if it exists
    (when target-region
      (goto-char target-region))))

(defun cui-block-previous-message (&optional arg)
  "Call `org-previous-visible-heading' or jump to previous ai message.
Work if cursor in cui block.
If at the first message, jump to the begining of current cui block.
Optional ARG should be positiove, 1 mean previous message."
  (interactive "^p")
  (cui-block-next-message (- (or arg 1))))

(defun cui-block-next-item (&optional arg)
  "Jump forward/backward by items, item type detected by cursor position.
Optional ARG may be positive or negative to indicate direction and
 steps."
  (interactive "^p")
  (or arg (setq arg 1))
  (let* ((reg (or (cui-block--contents-region) (cons (point-min) (point-max))))
         (beg (car reg))
         (end (cdr reg)))
  (cond
   ;; begin/end of cui block
   ((save-excursion
      (move-beginning-of-line 1)
      (looking-at cui-block--cui-block-begin-end-re))
    (cui--debug "cui-block-next-item 1 begin/end")
    (end-of-line)
    (while (/= arg 0)
      (if (> arg 0)
          (progn
            (end-of-line)
            (re-search-forward cui-block--cui-block-begin-end-re nil t)
            (setq arg (1- arg)))
        (beginning-of-line)
        (re-search-backward cui-block--cui-block-begin-end-re nil t)
        (setq arg (1+ arg)))
      (beginning-of-line)))
   ;; markdown-headers
   ((save-excursion
      (move-beginning-of-line 1)
      (looking-at cui-block--markdown-header-re))
    (cui--debug "cui-block-next-item 2 markdown-headers")
    (end-of-line)
    (while (/= arg 0)
      (if (> arg 0)
          (progn
            (end-of-line)
            (re-search-forward cui-block--markdown-header-re end t)
            (setq arg (1- arg)))
        (beginning-of-line)
        (re-search-backward cui-block--markdown-header-re beg t)
        (setq arg (1+ arg)))
      (beginning-of-line)))
   ;; markdown-block beg/end
   ((save-excursion
      (move-beginning-of-line 1)
      (looking-at cui-block--markdown-beg-end-re))
    (cui--debug "cui-block-next-item 3 markdown-block-beg/end")
    (while (/= arg 0)
      (if (> arg 0)
          (progn
            (end-of-line)
            (re-search-forward cui-block--markdown-beg-end-re end t)
            (setq arg (1- arg)))
        (beginning-of-line)
        (re-search-backward cui-block--markdown-beg-end-re beg t)
        (setq arg (1+ arg)))
      (beginning-of-line)))
   ;; message
   (t
    (cui--debug "cui-block-next-item 4 message")
    (cui-block-next-message arg)))))

(defun cui-block-previous-item (&optional arg)
  "Jump backward by items, item type detected by cursor position.
ARG should be positive number or nil."
  (interactive "^p")
  (cui-block-next-item (- (or arg 1))))

;; -=-= Interactive: mark-at-point

(defun cui-block-mark-at-point-by-steps ()
  "Progressively mark a larger region in cui block at point.
Steps:
  0. Org element
  1. Markdown block
  2. Markdown block with header
  3. Chat message
  4. Block content
  5. Whole block.
If ARG optional universal argument is non-nil, then we select message of
 chat strictly.
Return number of marked content."
  (interactive)
  (let ((pos (point))
        (expanded nil)
        (cur-size (if (use-region-p) (- (region-end) (region-beginning)) 0))
        (inx 0)
        (prev-inx 0)
        found-beg found-end
        step)
    (save-mark-and-excursion
      (when-let ((block-region (cui-block--region)))
        (let* ((block-beg (car block-region))
               (block-end (cdr block-region))
               ;; (mark-markdown
               ;;  (lambda ()
               ;;    (message "MBlock")
               ;;    (let ((res (cui-block--markdown-area (point) block-beg block-end)))
               ;;      (cons (car res) (cdr res))))) ; beg-cont end-cont
               (steps
                (list
                 ;; Step 0: Org element
                 (lambda ()
                   ;; Additionally check if point is in markdown block
                   ;; that element is less than block.
                   (let* ((reg (cui-block--markdown-block-p))
                          (block-size (when reg (- (car reg) (cdr reg))))) ; may be nil
                     (deactivate-mark)
                     (goto-char pos)
                     (ignore-errors                    ;; wrong-type-argument number-or-marker-p nil) at begining of the buffer.
                       (message "Org Element")
                       (org-mark-element)
                       (if (and block-size (> (- (region-end) (region-beginning)) block-size))
                           nil
                         ;; else
                         (list (region-beginning) (region-end))))))
                 ;; Step 1: Markdown block
                 (lambda ()
                   (message "MBlock content")
                   (when-let* ((rng1 (cui-block--markdown-block-p block-beg block-end))
                               (rng2 (cui-block--markdown-block-content-range (car rng1) (cdr rng1))))
                     ;; (print (list rng1 (car rng1) (cdr rng1) rng2))
                     (list (car rng2) (cdr rng2))))

                 ;; Step 2: Markdown block with header and footer
                 (lambda ()
                   (message "MBlock with header")
                   (when-let ((rng (cui-block--markdown-block-p block-beg block-end)))
                     (list (car rng) (progn (goto-char (cdr rng)) (line-end-position)))))
                 ;; Step 3: Chat message
                 (lambda ()
                   (message "Chat message")
                   (cui-block-mark-chat-message-at-point)
                   (list (region-beginning) (region-end)))
                 ;; Step 4: Block content
                 (lambda ()
                   (message "Block content")
                   (let ((reg (cui-block--contents-region)))
                     (when reg
                       (list (car reg) (cdr reg)))))
                 ;; Step 5: Block whole
                 (lambda () (message "Block whole") (list block-beg block-end)))))

          ;; Step sequentially
          (when (region-active-p) (setq inx 1)) ; skip org element if region active.
          (while (and (< inx 6)
                      (not expanded))
            (setq step (nth inx steps))
            (setq inx (1+ inx))

            (deactivate-mark)
            (goto-char pos)
            (when-let* ((reg (funcall step))
                        (beg (car reg))
                        (end (cadr reg))
                        (new-size (- end beg)))
              (when (<= new-size cur-size)
                (setq prev-inx (1- inx)))
              ;; Compare new region size
              (cui--debug "cui-block-mark-at-point %s %s %s %s" inx reg (when beg (- end beg)) cur-size)
              (when (and beg end
                         (> new-size cur-size)
                         (> new-size (1+ cur-size))) ; and more than one character (it is new line between MBlock and chat message
                (goto-char beg)
                (set-mark end)

                (setq expanded t
                      cur-size (- end beg)
                      found-beg beg
                      found-end end)))))))
    ;; If nothing expanded, just mark whole block
    (when expanded
      (deactivate-mark)
      (goto-char found-beg)
      (set-mark found-end)
      ;; (activate-mark)
      )
    (list prev-inx inx)))

(defun cui-block-mark-at-point (&optional arg)
  "Should be called at cui block.
If region is not active, check if point at message or at cui block header
 and mark it.
If universal argument ARG is non-nil, mark content of cui block."
  (interactive "P")
  (if (region-active-p)
      (cui-block-mark-at-point-by-steps)
    ;; else
    (if (not arg)
        (cond
         ;; at header
         ((save-excursion
            (move-beginning-of-line 1)
            (looking-at cui-block--cui-block-begin-end-re))
          (let* ((reg (cui-block--region))
                 (beg (car reg))
                 (end (cdr reg)))
            (goto-char beg)
            (set-mark end)
            (message "Block whole")))
         ;; at message
         ((save-excursion
            (move-beginning-of-line 1)
            (looking-at cui-block--chat-prefixes-re))
          (message "Chat message")
          (cui-block-mark-chat-message-at-point))
         (t
          (cui-block-mark-at-point-by-steps))) ; without arg
      ;; else - with arg
      (let* ((reg (cui-block--contents-region))
            (beg (car reg))
            (end (cdr reg)))
        (goto-char beg)
        (unless (eq beg end)
          (setq end (1- end)))
        (set-mark end))
      (message "Block content"))))


;; -=-= fn: set-block-parameter

(defun cui-block-set-block-parameter (parameter &optional value not-jump-back)
  "Set PARAMETER in ai or src block header.
Uses marker for original position.
Removes next word after PARAMETER if it doesn't start with ':'.
If VALUE is provided and NOT-JUMP-BACK is nil, restores cursor."
  (if-let ((element (or (cui-block-p)
                        (org-element-lineage
                         (save-match-data (org-element-context)) (list 'src-block) t))))
      (let ((param-str (if (symbolp parameter) (symbol-name parameter) parameter))
            (orig-marker (copy-marker (point)))
            ;; Force case-insensitive.
            (case-fold-search t))
        (goto-char (org-element-property :begin element)) ; (goto-char (car (cui-block--region)))
        ;; (goto-char (car (cui-block--region)))
        ;; Find parameter or insert it if missing
        (if (search-forward param-str (line-end-position) t)
            ;; Remove next word if not starts with ":"
            (let ((p (point)))
              (skip-chars-forward " \t")
              (let ((wn (thing-at-point 'word)))
                (unless (string-prefix-p ":" wn)
                  (delete-region p (+ p (1+ (length wn)))))
                (goto-char p)))
            ;; else - not found
          (re-search-forward "_\\(src\\|ai\\)\\s-*\\(\\w+\\)?" (line-end-position) t)
          (insert " " param-str))

        ;; Insert value if provided
        (if value
            (progn
              (insert (format " %s" value))
              (backward-word))
          ;; else
          (insert " "))
        ;; Jump back if needed
        (when (and value (not not-jump-back))
          (goto-char orig-marker)))
    ;; else
    (message "Not cui block here.")))

;; -=-= fn: find named block (Not used)
(defun cui-find-named-block (name)
  "Find block by NAME from begining of current buffer.
Like `org-babel-find-named-block'.
Return the location of the block identified by source
NAME, or nil if no such block exists."
  (save-excursion
    (goto-char (point-min))
    (let ((regexp (concat org-babel-src-name-regexp
	                  (concat (if name (regexp-quote name) "\\(?9:.*?\\)") "[ \t]*" )
	                  "\\(?:\n[ \t]*#\\+\\S-+:.*\\)*?"
	                  "\n")))
      (or (and (looking-at regexp)
	       (progn (goto-char (match-beginning 0))
                      (line-beginning-position)))
          (ignore-errors (org-next-block 1 nil regexp))))))


;; -=-= Markers

(defun cui-block-element-by-marker (marker)
  "Get cui block at MARKER position at marker buffer.
Used in prompt engineering only: cui-prompt.el."
  (with-current-buffer (marker-buffer marker)
    (save-excursion
      (goto-char marker)
      (cui-block-p))))

(defun cui-block--get-content-end-marker (&optional element)
  "Return a marker for the :contents-end property of ELEMENT.
Used in `cui-call-block'"
  (when-let* ((el (or element (cui-block-p)))
              (contents-end-pos (org-element-property :contents-end el)))
    (copy-marker contents-end-pos)))

(defun cui-block-get-header-marker (&optional element)
  "Return marker for current cui block or begining of buffer.
Execution in not `org-mode' is supported.
Pointer between # an + characters if it is `org-mode', otherwisde get
 marker from begining of current buffer.
If optional argument ELEMENT is non-nil it is used as cui block."
  (let* ((el (or element
                 (when (derived-mode-p 'org-mode)
                   (cui-block-p)))))
    (save-excursion
      (if el
          (progn
            (goto-char (org-element-property :begin el))
            (forward-char)) ; between # an + characters
        ;; else - just begining of buffer
        (goto-char (point-min)))
      (point-marker))))

;; -=-= Result

(defun cui-block-insert-result-message (message header-marker)
  "Insert MESSAGE to #+RESULT of block in buffer of HEADER-MARKER."
  (with-current-buffer (marker-buffer header-marker)
    (save-excursion
      (goto-char header-marker)
      (cui-block-insert-result message))))

(defun cui-block-insert-result (result &optional result-params hash _exec-time)
  "Modified `org-babel-insert-result' function.
Insert RESULT into the current buffer.
TODO: EXEC-TIME.
Optional argument RESULT-PARAMS not used.
Optional argument HASH not used."
  (cui--debug "cui-block-insert-result" result)
  (when (stringp result)
    (setq result (substring-no-properties result)))
  (save-excursion
    (let* ((visible-beg (point-min-marker))
           (visible-end (copy-marker (point-max) t))
           (existing-result (cui-block-where-is-result t nil hash))
           ;; When results exist outside of the current visible
           ;; region of the buffer, be sure to widen buffer to
           ;; update them.
           (outside-scope (and existing-result
                               (buffer-narrowed-p)
                               (or (> visible-beg existing-result)
                                   (<= visible-end existing-result))))
           beg end
           ;; indent
           )
      (when outside-scope (widen)) ;; ---- WIDDEN
      (goto-char existing-result) ;; must be true
      ;; (setq indent (current-indentation))
      (forward-line 1)
      (setq beg (point))
      (cond
       ((member "replace" result-params)
        (delete-region (point) (org-babel-result-end)))
       ((member "append" result-params)
        (goto-char (org-babel-result-end))
        (setq beg (point-marker))))
      (goto-char beg) (insert result "\n")
      (setq end (copy-marker (point) t))
      (org-babel-examplify-region beg end "")
      ;; finally
      (when outside-scope (narrow-to-region visible-beg visible-end)))) ;; ---- NARROW
  t)

(defun cui-block-where-is-result (&optional insert _info hash)
  "Find a result block strictly related to CURRENT src block.
Modified `org-babel-where-is-src-block-result' function.
If Optional argument INSERT is non-nil just enshure that result field
 exist.
For _INFO HASH check `org-babel-where-is-src-block-result' function."
  (cui--debug "cui-block-where-is-result %s %s" insert hash)
  (let ((context (cui-block-p)))
    (catch :found
      (org-with-wide-buffer
       (let* ((name (org-element-property :name context))
              (named-results (and name (org-babel-find-named-result name))))
         (goto-char (or named-results (org-element-property :end context)))
         ;; Named result: Use as before.
         (cond
          (named-results
           (when (org-babel--clear-results-maybe hash)
             (org-babel--insert-results-keyword name hash))
           (throw :found (point)))
          ;; If named but no result, fall-through.
          (name)
          ;; Anonymous result: Check only immediately after block.
          ((let* ((after-src (org-element-property :end context))
                  (empty-result-re (concat org-babel-result-regexp "$"))
                  (case-fold-search t))
             ;; Step 1: Skip whitespace directly after src block.
             (goto-char after-src)
             (skip-chars-forward " \t\n")
             ;; Step 2: Check if current point is a result keyword.
             (when (looking-at empty-result-re)
               (forward-line 0) ;; Move to beginning of line.
               (when (org-babel--clear-results-maybe hash)
                 (org-babel--insert-results-keyword nil hash))
               (throw :found (point)))))
          ;; No result found in correct scope.
          ))
       ;; Insert a new result keyword if requested and none present.
      (when insert
        (save-excursion
          (goto-char (min (org-element-property :end context) (point-max)))
          (skip-chars-backward " \t\n")
          (forward-line)
          (unless (bolp) (insert "\n"))
          (insert "\n")
          (org-babel--insert-results-keyword
           (org-element-property :name context) hash)
          (point)))))))


(defun cui-block-remove-result (&optional info keep-keyword)
  "Remove the result of the current source block.
INFO argument is currently ignored.
When KEEP-KEYWORD is non-nil, keep the #+RESULT keyword and just remove
the rest of the result."
  (interactive)
  (let ((location (cui-block-where-is-result nil info))
	(case-fold-search t))
    (when location
      (save-excursion
        (goto-char location)
	(when (looking-at org-babel-result-regexp)
	  (delete-region
	   (if keep-keyword (line-beginning-position 2)
	     (save-excursion
	       (skip-chars-backward " \r\t\n")
	       (line-beginning-position 2)))
	   (progn (forward-line) (org-babel-result-end))))))))


;; -=-= Fontify: help functions
(defun cui-block--fontify-markdown-subblocks (start end)
  "Fontify ```language ... ``` fenced mardown code blocks.
Support markdown blocks with and without language specified.
We search for begining of block, then for end of block, then fontify
 with `org-src-font-lock-fontify-block'.
Argument START and END are limits for searching."
  ;; (print (list "cui-block--fontify-markdown-subblocks" start end))
  (goto-char start)
  (let ((case-fold-search t))
    (while (and (< (point) end)
                (re-search-forward cui-block--markdown-beg-end-re end t))
      (let ((lang (match-string 1))
            (block-begin (match-end 0))
            (block-begin-begin (match-beginning 0)))
        ;; no ``` at the same line
        (when (re-search-forward cui-block--markdown-end-re end t)
          (let ((block-end (match-beginning 0))
                (block-end-end (match-end 0)))
            ;; - fontify begin and end of markdown block
            (remove-text-properties block-begin-begin block-begin
                                    (list 'face '(org-block)))
            (remove-text-properties block-end block-end-end
                                    (list 'face '(org-block)))
            (add-text-properties
             block-begin-begin block-begin
             '(face org-block-begin-line))
            (add-text-properties
             block-end block-end-end
             '(face org-block-end-line))

            (remove-text-properties block-begin block-end '(face nil org-emphasis))

            ;; Add Org faces.
            (let ((src-face (nth 1 (assoc-string lang org-src-block-faces t))))
              (when (or (facep src-face) (listp src-face))
                (font-lock-append-text-property block-begin block-end 'face src-face))
              (font-lock-append-text-property block-begin block-end 'face 'org-block))

            (when (and lang
                       (not (string-match-p "```" lang))
                       (fboundp (org-src-get-lang-mode lang))) ; for org-src-font-lock-fontify-block
              ;; - fontify code inside markdown block
              (org-src-font-lock-fontify-block lang block-begin block-end)
              ;; - text property
              (put-text-property block-begin block-end
                                 'cui-markdown-block t)
              t)))))))


(defun cui-block--fontify-org-tables (start end)
  "Set face for lines like Org tables.
For current buffer in position between START and END.
Executed in `font-lock-defaults' chain."
  (let (mbeg)
    (goto-char start) ; in case
    (while (re-search-forward "^[\s-]*|" end t)
      (setq mbeg (match-beginning 0)) ; (prop-match-beginning match))
      (unless (cui-block--at-special-p mbeg)
        (end-of-line)
        (remove-text-properties mbeg (point)
                                (list 'face))
        (put-text-property mbeg (point)
                           'face 'org-table)
        t))))


(defun cui-block--fontify-markdown-headers (start end)
  "Fontify started with # character headers.
Argument START END are block begin and end, used as limits here."
  (goto-char start)

  (while (re-search-forward cui-block--markdown-header-re end t)
    ;; (print (point))

    (let ((b1 (match-beginning 1))
          (e1 (match-end 1))
          (b2 (match-beginning 2))
          (e2 (match-end 2))
          (b3 (match-beginning 3))
          (e3 (match-end 3))
          (hash-chars-length (1- (length (match-string 1)))))
      (let ((color (if (< hash-chars-length (length cui-block-m-header-colors)) ; 4
                       (nth hash-chars-length cui-block-m-header-colors)
                     ;; else
                     'cui-block-m-header4)))
        (remove-text-properties b3 e3
                                  (list 'face 'org-block nil '(org-block)))
        ;; Group 1: the first '#' chars
        (put-text-property b1 e1 'face color)
        ;; Group 2: 1) a) - numeration
        (when (and b2 e2)
          (put-text-property b2 e2 'face color))

        (when (and b3 e3)
          (remove-text-properties b3 e3
                                  (list '(org-block) 'org-block)))
        ;; ;; fontify bold more
        ;; (goto-char b3)

        ;; (when (re-search-forward (re-search-forward "\\*\\{1,3\\}\\(\\w[^*\n]+\\)\\*\\{1,3\\}" end t) end t)
          ;;   (put-text-property (match-beginning 1) (match-end 1)
          ;;                      'face (nth (1- i) colors))
          ;;   ;; (print (list "cyes" (match-string 1)))
          ;;   )
          ;; )
          ;; (put-text-property b1 e1
          ;;                    'face 'outline-2)
          ;; ;; Group 2: the header text
          ;; (put-text-property b2 e2
          ;;                    'face 'outline-1)
          ;; )
          )))
  (goto-char end))


(defun cui-block--fontify-markdown-single-quotes-and-formatting (start end)
  "Fontify markdown features between START and END.
- Bold markers (*, ** and ***).
- Headers: '#' and header text.
Org vs Markdown -
- Markdown - formatting only applies to contiguous spans of text
 with the markers on the same line.
- Org - may be split with new line.
We dont support Org-like split.  LLMs commonly think that Org dont
support splitting."
  (let (b1 e1 b2 e2)
    (goto-char start)
    ;; 1. *Bold*
    (while (re-search-forward "\\*\\{1,3\\}\\(\\w[^*\n]+\\)\\*\\{1,3\\}" end t)
      ;; (if (re-search-forward "\\*\\{2,3\\}\\(\\w[^*]+\\)\\*\\{2,3\\}" (line-end-position) t)
      (progn
        (setq b1 (match-beginning 0))
        (setq e1 (match-end 0))
        (setq b2 (match-beginning 1)) ; **asd**
        (setq e2 (match-end 1))
        (unless (cui-block--at-special-p b2)


          ;; Only fontify the marker, not surrounding text
          (remove-text-properties b1 e1 '(face nil org-emphasis))
          (put-text-property b1 e1 'face (list :inherit '(org-block)))
          (beginning-of-line)
          (if (looking-at "^\\(#+\\)\\s-+")
              (put-text-property b2 e2 'face 'bold)
            ;; else
            (add-text-properties
	     b2 e2
	     (list 'face
		   (list :inherit
			 (append '(bold)
				 '(org-block))))))
          (goto-char e1))))

    ;; 2. `quote` RosyBrown1
    (goto-char start)
    (while (re-search-forward "`[^`]" end t) ; lines not started with *
      (goto-char (match-beginning 0))
      (if (re-search-forward "`\\([^`]+\\)`" (line-end-position) t)
          ;; (if (re-search-forward "`\\(\\([^`]+\\|\\)\\)`" (line-end-position) t)
          (progn
            (setq e1 (match-end 0))
            (setq b2 (match-beginning 1))
            (setq e2 (match-end 1))
            (unless (cui-block--at-special-p b2)


              ;; Only fontify the marker, not surrounding text
              (put-text-property b2 e2
                                 'face 'cui-block-quote)) ; org-clock-overlay org-agenda-restriction-lock
            (goto-char e1))
        ;; else
        (forward-line)))
    (goto-char end))) ;; Return t if performed work.


(defun cui-block--fontify-me-ai-chat-prefixes (lim-beg lim-end)
  "Fontify chat message prefixes like [ME:] with face.
Argument LIM-BEG cui block begining.
Argument LIM-END cui block ending."
  (let (sbeg send)
    (goto-char lim-beg)
    (prog1 (while (re-search-forward cui-block--chat-prefixes-re lim-end t)
             (setq sbeg (match-beginning 0))
             (setq send (match-end 0))
             (unless (cui-block--at-special-p send)
               (put-text-property sbeg send 'face 'cui-chat-role))) ; 'cui-block--me-ai-chat-prefixes-font-face
      (goto-char lim-end))))

(defun cui-block--fontify-latex-blocks (lim-beg lim-end)
  "Fontify LaTeX math blocks.
We search for \\[...\\] multiline \\(...\\) from LIM-BEG to LIM-END."
  (let (sbeg send)
    (goto-char lim-beg)
    ;; Multiline \\[ ... \\]
    (while (re-search-forward "^[\s-]*\\\\\\[\\(.\\|\n\\)*?\\\\\\]" lim-end t)
      ;; Mybe we should use two separate regexs?: "^[ \t]*\\\\\\[[ \t]*$" and "^[ \t]*\\\\\\][ \t]*$"
      (setq sbeg (match-beginning 0))
      (setq send (match-end 0))

      (unless (or (cui-block--at-special-p send t) ; multiline block with language
                  (cui-block--markdown-quotes-p send)) ; line
        (org-src-font-lock-fontify-block "latex" sbeg send))
      (goto-char send))
    ;; Inline \\( ... \\) - at one line
    (goto-char lim-beg)
    (while (re-search-forward "[^\\(]\\\\\(.*\\\\\)[^\\)]" lim-end t)
      (setq sbeg (match-beginning 0))
      (setq send (match-end 0))
      (unless (or (cui-block--at-special-p send t)
                  (cui-block--markdown-quotes-p send)) ; line
        (org-src-font-lock-fontify-block "latex" sbeg send))
      (goto-char send))
    (goto-char lim-end)))

;; -=-= Fontify: main
(defun cui-block--font-lock-fontify-markdown-and-org (limit)
  "Fontify markdown elements in cui blocks, up to LIMIT.
This is special fontify function, that return t when match found.
We insert advice right after `org-fontify-meta-lines-and-blocks-1' witch
called as a part of Org Font Lock mode configuration of keywords (in
`org-set-font-lock-defaults' and corresponding font-lock highlighting
rules in `font-lock-defaults' variable.
TODO: fontify if there is only end of cui block on page."
  (let ((case-fold-search t)
        beg end)
    (while (and (< (point) limit)
                (re-search-forward cui-block--cui-block-begin-re limit t))
      (setq beg (match-end 0))
      (if (re-search-forward cui-block--cui-block-end-re limit t)
          (setq end (match-beginning 0))
        ;; else - end of block not found, apply block to the limit
        (setq end limit))
      ;; - apply fontification
      ;; As a general rule, we apply the element (container) faces
      ;; first and then prepend the object faces on top.
      (save-match-data

        ;; [AI]: [ME]:
        (cui-block--fontify-me-ai-chat-prefixes beg end)
        ;; table
        (when cui-block-fontify-org-tables-flag
          (cui-block--fontify-org-tables beg end))
        ;; headers and *bold*
        (when cui-block-fontify-markdown-headers-and-formatting
          ;; Headers should be after bold formatting, because we
          ;; remove org-block from bold text on header and for bold
          ;; don't place org-block if on header
          (cui-block--fontify-markdown-headers beg end)
          (cui-block--fontify-markdown-single-quotes-and-formatting beg end))
        ;; LaTeX startin with [ or (
        (when cui-block-fontify-latex
          (cui-block--fontify-latex-blocks beg end)))
      (goto-char end))
    ;; required by font lock mode:
    (goto-char limit))) ; return t

(defun cui-block--font-lock-fontify-markdown-blocks (limit)
  "Fontify markdown subblocks in cui blocks, up to LIMIT.
Used as separate function with `cui-block--font-lock-fontify-markdown-and-org'
for applying after others to replace smaller elements.
TODO: fontify if there is only end of cui block on page."
  ;; (print (list "cui-block--font-lock-fontify-markdown-and-org" (point) limit))
  (let ((case-fold-search t)
        beg end)
    (while (and (< (point) limit)
                (re-search-forward cui-block--cui-block-begin-re limit t))
      (setq beg (match-end 0))
      (if (re-search-forward cui-block--cui-block-end-re limit t)
          (setq end (match-beginning 0))
        ;; else - end of block not found, apply block to the limit
        (setq end limit))
      ;; - apply fontification
      ;; As a general rule, we apply the element (container) faces
      ;; first and then prepend the object faces on top.
      (save-match-data
        ;; ```block
        (when cui-block-fontify-markdown-flag
          (cui-block--fontify-markdown-subblocks beg end)))
      (goto-char end))
    ;; required by font lock mode:
    (goto-char limit))) ; return t

;; -=-= Fill-region, paragraph

(defmacro cui-block--apply-to-region-lines (func start end &rest args)
  "Apply FUNC to each line in region from START to END with ARGS.
START and END is a pointer.  FUNC is called with
\(line-start line-end . ARGS) for each line.
FUNC should place  point to to the  next line after execution  if end at
the end of the line.
Return marker of END."
  `(let ((end-marker (copy-marker ,end)))
     (save-excursion
       (goto-char ,start)
       (while (< (point) (marker-position end-marker))
         (let ((line-start (line-beginning-position)) ; may be replace to just (point)
               (line-end (line-end-position)))
           (if (< line-start line-end) ; not empty line
               (apply ,func line-start line-end (list ,@args))
             (forward-line)))))
     end-marker))

(defun cui-block-fill-region-as-paragraph (from to &optional justify nosqueeze squeeze-after)
  "Ignore lines that begin with \"< \".
For `fill-region-as-paragraph' that applied per lines.
Argument FROM TO JUSTIFY NOSQUEEZE SQUEEZE-AFTER is arguments of
fill-region-as-paragraph."
  ;; (cui--debug "cui-block-fill-region-as-paragraph %s %s" from to)
  (cui--debug "cui-block-fill-region-as-paragraph %s %s" from to justify nosqueeze squeeze-after)
  (goto-char (min from to))
  (if (not (and (looking-at "^> ")
               (looking-at "^[ \t]*\\(|\\|\\+-[-+]\\).*"))) ; tables
      (funcall #'fill-region-as-paragraph from to justify nosqueeze squeeze-after)
    ;; else - next line
    (goto-char to)
    (unless (bolp)
      (forward-line))))

(defun cui-block-fill-region (beg end &optional justify)
  "Fill region, ignore markdown blocks, quoted lines and tables.
Used for not streaming one time insertion of response.
BEG END and JUSTIFY have same as in `fill-region-as-paragraph'.
TODO: use `forward-paragraph' instead of `forward-line'.
Return t if text was changed, nil otherwise."
  (cui--debug "cui-block-fill-region N1 %s" beg end justify)
  (when (/= beg end)
    (let* ((modified-flag (buffer-chars-modified-tick))
           (end (copy-marker end))
           (cur beg)
           middle-end reg)
      ;; Content exist?
      (save-excursion
        (while (< cur end)
          (goto-char cur)
          ;; (cui--debug "cui-block-fill-region N2 %s" cur)
          (setq reg (cui-block--markdown-block-p beg (marker-position end))) ; move pointer to end of markdown footer
          (if reg ; inside markdown block
              (progn
                (goto-char (cdr reg))
                (forward-line)
                (setq cur (point))
                (cui--debug "cui-block-fill-region N21 %s" reg cur))
            ;; else - not in markdown block
            (goto-char cur)
            ;; find next markdown block - middle-end = end or begining of next markdown
            ;; (cui--debug "cui-block-fill-region N3")
            (re-search-forward cui-block--markdown-beg-end-re (marker-position end) t)
            (beginning-of-line)
            ;; (cui--debug "cui-block-fill-region N4")
            (setq middle-end (car (cui-block--markdown-block-p beg (marker-position end))))
            (setq middle-end (if (and middle-end (< middle-end end))
                                 middle-end
                               ;; else
                               end))
            ;; (cui--debug "cui-block-fill-region N5")
            (setq cur (marker-position
                       (cui-block--apply-to-region-lines #'cui-block-fill-region-as-paragraph
                                                         cur
                                                         middle-end
                                                         justify))))))
      (/= (buffer-chars-modified-tick) modified-flag))))

(defun cui-block-fill-insert (&optional pos stream)
  "Fill cui block for not streaming and for streaming.
Uses current position in current buffer as the end.
Full line by line.
Ignore markdown blocks, quoted text and Org tables.
If STREAM is non-nil this function called after insertion of a chink of
 text, use current cursor position and fill current line.
If STREAM is nil, then region from POS to current position is filled.
POS is position before insertion."
  (interactive)
  ;; (setq _pos _pos) ; for melpazoid
  (cui--debug "cui-block-fill-insert %s %s" (point) pos stream (region-active-p))
  (save-excursion
    (if stream
        ;; if at current line ``` or we are at begining of markdown block in cui block.
        (let ((case-fold-search t) ; if nil
              (end (point)))
          (unless
              ;; not markdown blocks
              (or (with-syntax-table org-mode-transpose-word-syntax-table
                    ;; backward for cui block
                    (when (re-search-backward cui-block--cui-block-begin-re nil t)
                      (goto-char end)
                      ;; backward for markdown block "begin". Same logic as in finction `cui-block-tags--is-special'
                      (when (re-search-backward cui-block--markdown-begin-re (match-end 0) t)
                        (goto-char end)
                        ;; backward for markdown block "end" after "begin"
                        (not (re-search-backward cui-block--markdown-end-re nil t)))))
                  ;; not quotes and not tables
                  (progn (goto-char end)
                         (beginning-of-line)
                         (or (looking-at "^> ") ; from `cui-block-fill-region-as-paragraph'
                             (looking-at "^[ \t]*\\(|\\|\\+-[-+]\\).*")))) ; skip tables
            (goto-char end)
            (fill-region-as-paragraph (line-beginning-position) (line-end-position)
                                      nil
                                      stream ; nosqueeze - dont remove space " " for stream
                                      )))
      ;; else not stream, single response.
      (let ((end (or pos (line-beginning-position))))
        (cui-block-fill-region end (point))))))

;; (defun my/org-fill-element-advice (orig-fun &optional justify)
;;   "Advice around `org-fill-element`.
;; If at headline, skip filling. Otherwise call original function."
;;   (let ((element (save-excursion (end-of-line) (org-element-at-point))))
;;     (unless (cui-block-tags--markdown-fenced-code-body-get-range)
;;       (funcall orig-fun justify))))

;; (advice-add 'org-fill-element :around #'my/org-fill-element-advice)


;; (defun cui-restapi--forward-paragraph (arg)
;;   "Normal with `forward-paragraph' Skipping markdown blocks.
;; Works for positive ARG now only, negative not supported now."
;;   (print (list "cui-restapi--forward-paragraph" arg))
;;   (funcall #'forward-paragraph arg)
;;   (or arg (setq arg 1))
;;   (when-let* ((r (cui-block-tags--markdown-fenced-code-body-get-range))
;;                     (beg (car r)) ; after header
;;                     (end (cadr r))) ; at end line
;;     (when (< arg 0) (not (bobp))
;;           (when (> end (point))
;;             (goto-char beg)
;;             (forward-line -1)))
;;     (when (> arg 0) (not (eobp))
;;         ;; inside or at the first line? if at first line, do nothin, if in the middle of mardkown, then go to the end
;;         (unless (save-excursion (forward-line -1) (eq beg (point)))
;;           (goto-char end)
;;           (forward-line)))))

;; -=-= Fill-region, paragraph - interactive

(defun cui-block-fill-paragraph (&optional justify region)
  "Fill every line as paragraph in the current cui block.
Interacive function for cui block, like `org-fill-paragraph', that fill
 message or whole block.
Optional arguments:
- JUSTIFY is parameter of `fill-paragraph'.
- if REGION is non-nil if called interactively; in that
case, if Transient Mark mode is enabled and the mark is active,
fill each of the elements in the active region, instead of just
filling the current element.
Return t paragraph was filled-changed."
  (interactive (progn
                 (barf-if-buffer-read-only)
                 (list (when current-prefix-arg 'full)
                       (and (region-active-p)
                            (not (= (region-beginning) (region-end)))))))
  ;; inspired by `org-fill-element'
  (cui--debug "cui-block-fill-paragraph N1 %s %s %s %s" justify region (point) (current-buffer) (region-active-p))

  (with-syntax-table org-mode-transpose-word-syntax-table
    ;; Determine the boundaries of the content
    (when-let* ((element (cui-block-p))
                (reg (cui-block--contents-region element))
                (beg (car reg))
                (end (cdr reg)))

      (unless (= beg end)
        (cui--debug "cui-block-fill-paragraph N11 %s %s %s %s" region (region-active-p))
        (when-let* ((reg
                     (cond
                      ;; region
                      (region
                       (cui--debug "cui-block-fill-paragraph N12 %s %s %s %s" region (region-active-p))
                       (let ((rbeg (region-beginning))
                             (rend (region-end)))
                         (cui--debug "cui-block-fill-paragraph N13 %s %s %s %s" rbeg rend beg end)
                         (cons rbeg rend)))
                      ;; at header
                      ((save-excursion
                         (move-beginning-of-line 1)
                         (looking-at cui-block--cui-block-begin-end-re))
                       (when (called-interactively-p 'any)
                         (message "Block content"))
                       (cons beg end))
                      ;; at message
                      ((save-excursion
                         (move-beginning-of-line 1)
                         (looking-at cui-block--chat-prefixes-re))
                       (when (called-interactively-p 'any)
                         (message "Chat message"))
                       (car (cui-block--find-region-with-position (cui-block--chat-role-regions) (point))))))
                    (beg (car reg))
                    (end (cdr reg)))
          (cui--debug "cui-block-fill-paragraph N2 %s" beg end)
          (cui-block-fill-region beg end)) ; return t if changed
        ))))


;;;; provide
(provide 'cui-block)
;;; cui-block.el ends here
