;;; cui-block-msgs.el --- cui block messages functions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 github.com/Anoncheg1,codeberg.org/Anoncheg
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

;; macs -Q --batch -l ert.el -l cui-debug.el -l cui-block.el -l cui-block-msgs.el
;;   -l ./tests/cui-tests-msgs.el -f ert-run-tests-batch-and-exit

;; or

;; (eval-buffer)
;; (ert t)

;;; Code:
;; -=-= includes
(require 'cui-debug)
(require 'cui-block)

;; -=-= hooks
(defcustom cui-block-msgs-after-prepare-messages-hook nil
  "Run before sending request.
List of functions that called with plist argument that content arguments
 of `cui-restapi-request-prepare' function that may be modified.
Used to modify any parameter of request.
Executed after all preparations for messages was done.  Every function
 called with one argument from left to right and pass result to each
 other.
Each function should return plist with same order and with same keys as
 was given."
  :type 'hook
  :group 'cui)


;; -=-= parsing messages
;; cui-block-msgs
(defun cui-block-msgs--merge-by-role (messages &optional sep)
  "Merge consecutive list of plist MESSAGES with same :role.
Joining non-empty content by SEP (defaults to newline).
Return new list of plist messages with :role and :content."
  (cui--debug "cui-block-msgs--merge-by-role" messages)
  (setq sep (or sep "\n"))
  (let (result role content)
    (dolist (msg messages)
      (let ((r (plist-get msg :role))
            (c (plist-get msg :content)))
        (if
         ;; Same role: append content if it's non-empty
         (and role (eq r role))
          (when (and c (not (string-empty-p c)))
            (setq content (if (and content (not (string-empty-p content)))
                              (concat content sep c) c))) ; CONCAT!
          ;; else. New role: push previous role/content, start new batch
          (when (and role content (not (string-empty-p content)))
            (push (list :role role :content content) result))
          (setq role r content c))))
    ;; Push any remaining role/content
    (when (and role content (not (string-empty-p content)))
      (push (list :role role :content content) result))
    (nreverse result)))

;; Parse parts and build messages
(defun cui-block-msgs--parse-part (pos-beg pos-end &optional first-chat-role not-clear-properties)
  "Get part of chat as a plist with :role and :content in current buffer.
Positions POS-BEG POS-END used as limits.
Skip AI_REASON role string.
If prefix found two times error is thrown.
Uses `cui-block-roles-prefixes' variable and `cui-block--chat-prefixes-re'.
If content is empty string return nil otherwise plist.
Optional FIRST-CHAT-ROLE is \='user by default.
NOT-CLEAR-PROPERTIES used for splitting parsed messages to preserve
 region selection added by `cui-block-tags-replace'.
Return plist of message with :role and :content or nil if content is
 empty."
  (save-excursion
    (goto-char pos-beg)
    ;; - find prefix
    (let ((first-chat-role (or first-chat-role 'user))
          content ; after prefix or from pos
          role-str
          role
          pre-end-pos) ; begining of content
      ;; get role and begining of content
      (save-match-data
        (when (re-search-forward cui-block--chat-prefixes-re pos-end t)
          (setq role-str (match-string 1))
          (setq pre-end-pos (match-end 0))
          (when (re-search-forward cui-block--chat-prefixes-re pos-end t)
            (error "Another role prefix found before POS-END %s %s "(point) pos-end))))

      (unless (string= role-str "AI_REASON") ; works for nil
        ;; first - get role symbol
        (if role-str
            (setq role (or (cdr (assoc-string role-str cui-block-roles-prefixes t))
                           cui-block-roles-prefixes-unknown))
          ;; else
          (setq role first-chat-role))
        ;; get content
        (setq content (buffer-substring (or pre-end-pos pos-beg)
                                        pos-end))
        (unless not-clear-properties
          (setq content (substring-no-properties content)))
        (setq content (string-trim content))

        ;; if content is empty return nil.
        (when (not (string-empty-p content))
          ;; (cui--debug "cui-block-msgs--parse-part %s %s" role content)
          (list :role role :content content))))))

;; (defun cui-block-msgs--parse-part-from-string (string &optional first-chat-role)
;;   "Same as `cui-block-msgs--parse-part' but from string instead of buffer."
;;   (with-temp-buffer
;;     (insert string)
;;     (cui-block-msgs--parse-part (point-min) (point-max) first-chat-role)))

;; (with-temp-buffer
;;   (insert "[ai:] asd")
;;   (cui-block-msgs--parse-part (point-min) (point-max)))


(defun cui-block-msgs--collect-chat-messages-from-buffer (content-start content-end &optional first-chat-role not-clear-properties)
  "Get list of messages for content between boundaries in current buffer.
Positions CONTENT-START and CONTENT-END used as limits for parsing ai
block, may be retrieved with :contents-begin and :contents-end
properties of cui block Org element.
Don't merge roles with `cui-block-msgs--merge-by-role'.
Used in `cui-block-msgs--collect-chat-messages-at-point' is main function and
 `cui-block-msgs--collect-chat-messages-from-string' that used to split
 parsed message.
Optional argiments,
- FIRST-CHAT-ROLE is \='user by default, used for first message if
 it have no prefix.
- NOT-CLEAR-PROPERTIES if not-nil, preserve highlighting of replacement
 of links, tags and noweb fererences added by `cui-block-tags-replace',
 for `cui-expand-block'.
- MARKDOWN-CHECK if not-nil, positions counted only if not in markdown
 block.
Return list of plist with :content and :role."
  ;; 1) Positions: for prefixes [ME:], [AI:] in current buffer
  (let ((positions (cui-block--get-chat-messages-positions content-start content-end cui-block--chat-prefixes-re))
        res)
    (cui--debug "cui-block-msgs--collect-chat-messages-from-buffer %s" positions)
    (while (cdr positions)
      ;; 2) parse current block
      (push (cui-block-msgs--parse-part (car positions) (cadr positions) first-chat-role not-clear-properties)
            res)
      (setq positions (cdr positions)))
    (nreverse (remove nil res))))

;; persistant-sys-prompts
(defun cui-block-msgs--prepare-chat-messages (parts &optional default-system-prompt not-merge separator)
  "Prepare a list of chat messages.

PARTS is a list of plists, each with :role and :content keys
 representing chat messages.

- If DEFAULT-SYSTEM-PROMPT is provided and the first message is not a
 system prompt, it is inserted at the beginning.
- If NOT-MERGE is nil, adjacent messages with the same role are merged
 using SEPARATOR (defaults to \\n).

Returns a new list of message plists with :role and :content.
Note: This function modifies the contents of the message plists in
 PARTS."
  (cui--debug "cui-block-msgs--prepare-chat-messages N1" parts)
  (cui--debug "cui-block-msgs--prepare-chat-messages N2 %s" default-system-prompt not-merge separator)
  (let* ((parts (if not-merge parts
                  ;; else
                  (cui-block-msgs--merge-by-role parts (or separator "\n")))) ; Merge messages with same role.
         (starts-with-sys-prompt-p (and parts (eql (plist-get (car parts) :role) 'system))))

      ;; 1) Parts: fix [SYS:]
      (when (and default-system-prompt (not starts-with-sys-prompt-p))
        (setq parts (cons (list :role 'system :content default-system-prompt) parts)))

      parts))

;; persistant-sys-prompts
(defun cui-block-msgs--collect-chat-messages-at-point (&optional element default-system-prompt not-merge first-chat-role separator)
  "Collect messages for cui block at current positon.
Execution in not `org-mode' is supported.
Used for main cui block call.  Should not be used for sub-calls.
Apply first step of chat messages preparation.
Call `cui-block-parse-part-hook' for parts.
For not `org-mode', content of whole buffer is used.
Optional argument ELEMENT is cui block in current buffer.
Description for SEPARATOR at
 `cui-block-msgs--collect-chat-messages-from-buffer'.
Optional argument FIRST-CHAT-ROLE may be used to change default \='user
 for the first message that may don't have chat prefix.
When NOT-MERGE is not-nil, don't merge messages after reading.
Description for DEFAULT-SYSTEM-PROMPT SEPARATOR
 at `cui-block-msgs--prepare-chat-messages'.
Return vector of plist messages with :role and :content."
  (cui--debug "cui-block-msgs--collect-chat-messages-at-point N1 %s" element)
  (let* ((element (or element (when (derived-mode-p 'org-mode)
                                (cui-block-p))))
         (content-start (if element (org-element-property :contents-begin element)
                          ;; else
                          (point-min)))
         (content-end  (if element (org-element-property :contents-end element)
                         ;; else
                         (point-max))))
    ;; (cui--debug "cui-block-msgs--collect-chat-messages-at-point N2 %s" element)
    ;; 1) get PARTS from block
    (let ((parts (cui-block-msgs--collect-chat-messages-from-buffer
                  content-start content-end first-chat-role))) ; list, preserve properties
      ;; (cui--debug "cui-block-msgs--collect-chat-messages-at-point N3" parts)
      ;; - 2) Apply hook for every message, modify parts
      (mapc (lambda (cur)
              ;; (cui--debug "cui-block-msgs--collect-chat-messages-at-point N4 %s" cur)
              (let* ((content (plist-get cur :content))
                     (new-content (cui-block--pipeline cui-block-parse-part-hook
                                                       content (plist-get cur :role))))
                ;; (cui--debug "cui-block-msgs--collect-chat-messages-at-point N5 %s" new-content)
                ;; (unless (string-equal content new-content)
                ;; (setf (plist-get cur :content) new-content)
                (plist-put cur :content new-content)))
            parts)
      ;; - 3) first step of preparation
      ;; (cui--debug "cui-block-msgs--collect-chat-messages-at-point N6" parts)
      (setq parts (cui-block-msgs--prepare-chat-messages parts default-system-prompt not-merge separator))
      (cui--debug "cui-block-msgs--collect-chat-messages-at-point N7" parts)
      (apply #'vector parts))))

(defun cui-block-msgs--collect-chat-messages-from-string (content-string &optional first-chat-role not-clear-properties)
  "Collect messages from CONTENT-STRING.
Apply first step of chat messages preparation.
Don't merge roles with `cui-block-msgs--merge-by-role'.
Optional argument FIRST-CHAT-ROLE may be used to change default \='user
 for the first message that may don't have chat prefix.
Used for `cui-block-msgs--vector-split-by-chat-prefix'.
Return list of plist messages with :role and :content.

Optional argument NOT-CLEAR-PROPERTIES if not-nil, preserve highlighting
 of replacement of links, tags and noweb fererences added by
 `cui-block-tags-replace', for `cui-expand-block'."
  (with-temp-buffer
  ;; (with-current-buffer (get-buffer-create "test11")
    (insert content-string)
    (let ((content-start (point-min))
          (content-end   (point-max)))
      (cui-block-msgs--collect-chat-messages-from-buffer
       content-start content-end first-chat-role not-clear-properties))))

;; old:
;; - cui-block-msgs--collect-chat-messages-from-string
;; - cui-block--collect-chat-messages
;; - cui-block--collect-chat-messages-at-point

;; new:
;; - cui-block-msgs--collect-chat-messages-at-point - main - call hook
;; - cui-block-collect-messages-from-buffer - subcalls
;; - cui-block-msgs--collect-chat-messages-from-string -

;; -=-= stringify-chat-messages

(defun cui-block-msg--format-message (msg)
  "Return converted to a string plist MSG.
If optional argument NO-FIRST-PREFIX is non-nil, dont add prefix if
 first message of user role.
Used in `cui-expand-block'.
Return string."
  (let* ((role (plist-get msg :role))
         (content (plist-get msg :content))
         (role-str (car (rassoc role cui-block-roles-prefixes))))
    (concat "[" role-str "]: " content)))


(defun cui-block-msgs--stringify-chat-messages (messages &optional default-system-prompt)
  "Convert a chat message to a string.
MESSAGES is a vector of plist with :role :content keys.  :role can be
\='system, \='user or \='assistant.
If DEFAULT-SYSTEM-PROMPT non-nil, a [SYS] prompt is prepended if the
first message is not a system message, otherwise DEFAULT-SYSTEM-PROMPT
argument is ignored.
Used in `cui-expand-block'.
Uses `cui-block-roles-prefixes' variable for mapping roles to prefixes.
If optional argument NO-FIRST-PREFIX is non-nil, dont add prefix if
 first message of user role.
Return string."
  ;; 1) add default-system-prompt as first [SYS]: if not exist
  (let ((messages (if (and default-system-prompt
                           (not (eql (plist-get (aref messages 0) :role) 'system))) ; enforce that vector should consist of plists
                      ;; (cl-concatenate 'vector (vector (list :role 'system :content default-system-prompt)) messages)
                      (vconcat (vector (list :role 'system :content default-system-prompt)) messages)
                    messages)))
    (string-join
     (mapcar #'cui-block-msg--format-message messages)
     "\n\n")))

;; (cui-block-msgs--stringify-chat-messages '[(:role assistant :content "Be helpful; then answer.") (:role user :content "Be hnswer.")] "as")

;; -=-= split, find, modify messages

(defun cui-block-msgs--vector-split-by-chat-prefix (vec idxs)
  "Replace elements of VEC at IDXS with their split by chat prefix.
VEC is vector with plist of messages.
Return a list of messages."
  (cui--debug "cui-block-msgs--vector-split-by-chat-prefix N1" idxs vec)
  (let ((lst (append vec nil)) ; list
        (idxs-sorted (sort (copy-sequence idxs) #'>)))
    ;; Process indexes from highest to lowest to avoid offsets.
    (dolist (idx idxs-sorted)
      (when (and (>= idx 0)
                 (< idx (length lst)))
        (let* ((el (nth idx lst)) ; plist
               (str (plist-get el :content))
               (role (plist-get el :role))
               (splits (cui-block-msgs--collect-chat-messages-from-string str role t))) ; not clear properties
          ;; replace original element at idx.
          (setq lst (append (seq-subseq lst 0 idx)
                            splits
                            (seq-subseq lst (1+ idx)))))))
    (cui--debug "cui-block-msgs--vector-split-by-chat-prefix N2" lst)
    lst))


(defun cui-block-msgs--find-last-user-index (vec)
  "Return the index of the last element in VEC whose :role is \='user, or nil."
  (let ((i (1- (length vec)))
        idx)
    (while (and (>= i 0) (not idx))
      (let ((elt (aref vec i)))
        (when (and (listp elt)
                   (eq (plist-get elt :role) 'user))
          (setq idx i)))
      (setq i (1- i)))
    idx))


(defun cui-block-msgs--modify-vector-content (vec applicant &optional role split-flag &rest rest)
  "Modify content of messages in VEC by role.
Side effect function for VEC variable!
When ROLE is non-nil, it used to filter all such messages, right part of
 `cui-block-roles-prefixes'.
APPLICANT may be string or function.  if function, it is called if a
 string, it replace :content of vector item.  Intened for usage with
 `cui-block-tags-replace'.
If ROLES is nil, modify all messages with APPLICANT.
If SPLIT-FLAG is non-nil, split content of replaceed messages if it have
 prefixes.  After splitting messages merged by role if there is a
 sequence of them with same role.
REST optional arguments are arguments that will be passed to call of
 applicant if it a function.
Return modified VEC."
  (cui--debug "cui-block-msgs--modify-vector-content N1 %s %s %s" role vec applicant)
  (if (eq (length vec) 0)
      vec
    ;; else
    (let ((i (1- (length vec)))
          ;; (vec (copy-sequence vec)) ; copy of vector with shared messages
          mes
          content
          content-old
          idxs)
      ;; loop over messages in vec
      (while (>= i 0)
        (setq mes (aref vec i)) ; from 0 to len-1

        ;; replace content for role
        (when (or (and role
                       (eql role (plist-get mes :role)))
                  (not role))
          (setq content-old (plist-get mes :content))
          (setq content (if (functionp applicant)
                            (if rest
                                (apply #'funcall applicant content-old rest)
                              ;; else
                              (funcall applicant content-old))
                          ;; else
                          applicant))
          (unless (equal content-old content) ; was modified? recursive equal on strings here.
            ;; (aset vec i
            (plist-put mes :content content)
            (push i idxs)))
        (setq i (1- i)))
      (cui--debug "cui-block-msgs--modify-vector-content N2" idxs vec)
      (if (and split-flag idxs)
          (vconcat
           (cui-block-msgs--merge-by-role
            (cui-block-msgs--vector-split-by-chat-prefix vec idxs)))
        ;; else
        vec))))


(defun cui-block-msgs--modify-vector-last-user-content (vec applicant &optional split-flag &rest rest)
  "Copy VEC with replacing last \='user :content with APPLICANT in VEC.
Used in `cui-restapi-request-prepare' to send history of conversation.
APPLICANT is either (string or function of old content), like
`cui-block-tags-replace'.
If SPLIT-FLAG is non-nil, split content of replaceed messages if it have
 prefixes.  After splitting messages merged by role if there is a
 sequence of them with same role.
Uses `cui-block-msgs--find-last-user-index`.
Optional argument REST is additional arguments for APPLICANT function.
Return new vector based on VEC."
  ;; (unless (vectorp vec)
  ;;   (user-error "Not a vector"))
  (cui--debug "cui-block-msgs--modify-vector-last-user-content %s %s" vec applicant)
  (if (eq (length vec) 0)
      vec
    ;; else
    (let ((idx (cui-block-msgs--find-last-user-index vec)))
      (or
       (let* ((elt (aref vec idx))
              (content-old (plist-get elt :content))
              (content-new (if (functionp applicant)
                               (if rest
                                   (apply #'funcall applicant content-old rest)
                                 ;; else
                                 (funcall applicant content-old))
                             ;; else
                             applicant)))
         (unless (equal content-old content-new) ; was modified? recursive equal on strings here.
           (let ((newvec (copy-sequence vec)))
             (aset newvec idx
                   (plist-put elt :content content-new)) ; plist-put return new message plist
             (if split-flag
                 (vconcat
                  (cui-block-msgs--merge-by-role
                   (cui-block-msgs--vector-split-by-chat-prefix newvec (list idx))))
               ;; else
               newvec)))) ; return
       vec))))


;;;; provide

(provide 'cui-block-msgs)
;;; cui-block-msgs.el ends here
