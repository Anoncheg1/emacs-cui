;;; cui-optional.el --- Useful functions that not enabled by default.  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 github.com/Anoncheg1
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

;; Configuration for usage:

;; (require 'cui-optional)
;; (add-hook 'cui-block-after-chat-insertion-hook
;;          #'cui-optional-remove-headers-hook-function)
;; (add-hook 'cui-block-after-chat-insertion-hook
;;          #'cui-optional-remove-distant-empty-lines-hook-function)

(require 'cl-lib) ; Ensure cl-lib is loaded for cl-defun and cl-destructuring-bind
(require 'org)
(require 'cui-block)
(require 'cui-debug)

;;; Code:

;; -=-= after-receive: remove-distant-empty-lines hook
(defun cui-optional-remove-distant-empty-lines (beg)
  "Remove excessibe empty lines from BEG to current position.
Don't remove empty lines that have more than two lines in a row before
 tham."
  (forward-line -1) ; precaution
  (let ((empty-line)
        (cl 0))
    (while (< beg (point))
      (when (eolp) ; empty line
        (when (and (<= cl 2) (> cl 0) empty-line)
          (save-excursion
            (goto-char empty-line)
            (delete-char 1)))
        (setq cl 0)
        (setq empty-line (point)))
      (setq cl (1+ cl ))
      (forward-line -1))))

(defun cui-optional-remove-distant-empty-lines-hook-function (&optional type _content before-pos stream)
  "Remove empty lines when there is too many of them.
Arguments TYPE CONTENT BEFORE-POS STREAM parameters described in
`cui-block-after-chat-insertion-hook' hook."
  (save-excursion
    (cui--debug "cui-optional-remove-distant-empty-lines-hook-function HOOK: %s %s %s %s"
                before-pos
                (point)
                type
                (type-of type))
    (if stream
        (cui-optional-remove-distant-empty-lines (save-excursion (cui-block-previous-message)))
      ;; else - not stream
      (cui-optional-remove-distant-empty-lines before-pos))))

;; -=-= after-receive: remove-headers hook
(defun cui-add-char-before-org-outline-regexp-bol
    (&optional char re beg end)
  "Insert CHAR before each match of RE between BEG and END.
CHAR defaults to \" \", RE to `org-outline-regexp-bol'.
Interactively the region must be active; no prompting.
Returns the number of replacements, or nil if RE did not match."
  (interactive
   (list nil nil
         (or (and (use-region-p) (region-beginning))
             (user-error "Active region required"))
         (region-end)))
  (replace-regexp-in-region (or re org-outline-regexp-bol)
                            (concat (or char " ") "\\&")
                            beg end))

(defun cui-optional-remove-headers-hook-function (type _content before-pos _stream)
  "Ready for usage in `cui-block-after-chat-insertion-hook'.
Remove Org headers between BEFORE-POS and current position in current
buffer by adding space before it.
TYPE _CONTENT BEFORE-POS BUF parameters described in
`cui-block-after-chat-insertion-hook' hook.
Should be added the last to be executed first."
  (cui--debug "cui-optional-remove-headers-hook-function HOOK: %s %s %s %s"
              before-pos (point) type (type-of type))
  (when (member type '(text end))
    (cui-add-char-before-org-outline-regexp-bol
     " " org-outline-regexp-bol before-pos (point))))

;; -=-= pre-send: remove-indentation hook

(defun cui-optional-markdown-blocks--function (function beg end)
  "Apply FUNCTION to every markdown block in the last user message.
Arguments BEG END are described in`cui-before-send-hook' hook."
  (cui--debug "cui-optional-markdown-blocks--function N1 HOOK: %s %s" beg end)
  (save-excursion
    (let ((bounds (nreverse (cui-block--markdown-block-regions beg end)))) ; from bottom
      (while bounds ; loop
        (let* ((block-end (pop bounds))
               (block-beg (pop bounds))
               ;; Skip the block's opening line (e.g. the ``` fence line).
               (line-beg (progn
                           (goto-char block-beg)
                           (forward-line)
                           (line-number-at-pos)))
               (line-end (progn
                           (goto-char block-end)
                           (1- (line-number-at-pos)))))
          (cui--debug "cui-optional-markdown-blocks--function N2 HOOK: %s %s" line-beg line-end)
          (when (> line-end line-beg) ; at least two lines: one body + closing
            (funcall function line-beg line-end)))))))


(defun cui-optional-markdown-blocks-remove-indentation-hook-function (beg end)
  "Remove common indentation from markdown blocks in the last user messagges.
Arguments BEG END described in `cui-before-send-hook' hook."
  (cui--debug "cui-optional-markdown-blocks-remove-indentation-hook-function N1HOOK: %s %s" beg end)
  (cui-optional-markdown-blocks--function #'cui-block--indentation-dedent-lines beg end))

;; -=-= pre-send: correct dashes characters chhook

(defun cui-optional--hex-expression-p (str)
  "Return non-nil if STR is a complete, valid hex integer literal."
  (and (stringp str)
       (or (string-match-p "\\`[+-]?\\(?:0[xX]\\|#[x]\\|#[0-9]+[rR]\\)[0-9a-fA-F]+\\'" str)
       (condition-case nil
           (let ((reg (read-from-string str)))
             (and (integerp (car reg))
                  (= (cdr reg) (length str))))
         (error nil)))))


(defun cui-optional--words-around (pos)
  "Return (BEFORE AFTER): the two words around POS.
Words are separated by `-'; the outer edges may be separated by any
non-word characters (whitespace, punctuation, quotes, ...).
Character at POS not checked.
A word is a run of non-whitespace, non-punctuation, non-quote chars,
except `#' which counts as a word character."
  (let (
        ;; (sep "^[:alnum:]#_")   ; matches separators (non-word chars)
        (word "[:alnum:]#_"))  ; matches word chars
    (list
     (save-excursion
       (goto-char pos)
       ;; (skip-chars-backward sep)
       (let ((end (point)))
         (skip-chars-backward word)
         (when (< (point) end)
           (buffer-substring-no-properties (point) end))))
     (save-excursion
       (goto-char (1+ pos))
       ;; (skip-chars-forward sep)
       (let ((start (point)))
         (skip-chars-forward word)
         (when (< start (point))
           (buffer-substring-no-properties start (point))))))))


(defun cui-optional--classify-hyphen (&optional pos)
  "Classify hyphen at POS.
Return `en-dash', `em-dash', or nil for no change."
  ;; 1) check by first character before and after hyphen
  (let ((pos (or pos (point))))
    (let ((l (char-before pos))
          (r (char-after (1+ pos))))
      (let ((l-space (memq l '(?\s ?\t)))
            (r-space (memq r '(?\s ?\t))))
        ;; (print (list l-space r-space)))))
        (unless (save-excursion
                  (goto-char pos)
                  (skip-chars-backward "[:blank:]" (line-beginning-position))
                  (bolp))
          (cond
           ((and l-space r-space) 'em-dash) ; sentences separator
           ((and l r (not l-space) (not r-space) ; not spaces
                 (or (and (cl-digit-char-p l) (cl-digit-char-p r))
                     ;; 2) check by two words before and after hyphen
                     (let ((sep "^[:alnum:]#_")   ; matches separators (non-word chars)
                           (word "[:alnum:]#_"))  ; matches word chars
                       (let ((before
                              (save-excursion
                                (goto-char pos)
                                (skip-chars-backward sep)
                                (let ((end (point)))
                                  (skip-chars-backward word)
                                  (when (< (point) end)
                                    (buffer-substring-no-properties (point) end)))))
                             (after
                              (save-excursion
                                (goto-char pos)
                                (skip-chars-forward sep)
                                (let ((start (point)))
                                  (skip-chars-forward word)
                                  (when (< start (point))
                                    (buffer-substring-no-properties start (point)))))))
                         (and before after
                              (cui-optional--hex-expression-p before)
                              (cui-optional--hex-expression-p after))))
                     ;; (and (>= l ?A) (<= l ?Z) (>= r ?A) (<= r ?Z))
                     ) 'en-dash))))))))


(defun cui-optional-markdown-blocks-correct-dashes-hook-function (beg end)
  "Replace hyphen with em-dash or en-dash in the last user messagges.
BEG END is last message in current CUI block, where we replace hyphens
 that satisfly some requirements:
- (–) en-dash for range and relationships.
- (—) em-dash to tell that here comes more detail or an aside, it marks
 a strong break in thought.
Arguments BEG END described in`cui-before-send-hook' hook."
  (cui--debug "cui-optional-markdown-blocks-correct-dashes-hook-function N1 HOOK: %s %s" beg end)
  (save-excursion
    (let ((regions (cui-block--markdown-block-regions beg end))
          changes) ; list of (cons pos en-dash/em-dash)
      ;; Pass 1: collect (pos . replacement) without mutating the buffer.
      (goto-char beg)
      (while (re-search-forward "-" end t)
        (let ((pos (1- (point))))
          (unless (or (cui-block--markdown-quotes-p (point))
                      (save-excursion (cui-block--markdown-block-p beg end regions))) ; use regions for speed
            ;; - en-dash - should be between two characters
            ;; - em-dash - should be surounded with spaces
            ;; both should not be at the begining of line or with just spaces before them. (maybe not needed to chech)
            (pcase (cui-optional--classify-hyphen pos)
              ('en-dash (push (cons pos ?–) changes))
              ('em-dash (push (cons pos ?—) changes))))))
      ;; Pass 2: apply from the end so earlier positions stay valid.
      (dolist (c (sort changes (lambda (a b) (> (car a) (car b)))))
        (goto-char (car c))
        (delete-char 1)
        (insert-char (cdr c) 1)))))

;; To Test:
;; (let ((reg (cui-block--chat-the-last-region (cui-block-p))))
;;     (let ((last-beg-m (make-marker))
;;           (last-end-m (make-marker)))
;;       (set-marker last-beg-m (car reg)) ; after perfix
;;       (set-marker last-end-m (cdr reg))
;;       (run-hook-with-args 'cui-before-send-hook last-beg-m last-end-m) ; run cui-optional-markdown-blocks-correct-dashes-hook-function
;;       (set-marker last-beg-m nil)
;;       (set-marker last-end-m nil)))

;; -=-= Org TAB key: Markdown folding

;; 1. Tell Emacs that 'cui-markdown-invisible is an alias for the 'invisible property.

(defun cui-optional-markdown-folding-activation ()
  "For `cui-mode-hook'."
  (interactive)
  ;; Establish the alias link
  (add-to-list 'char-property-alias-alist '(invisible cui-markdown-invisible))
  ;; Register our custom value to show the ellipsis (...)
  (add-to-list 'buffer-invisibility-spec '(cui-markdown-value . t)))


(defun cui-optional--isearch-open-text-prop (pos)
   "Unfold the \='cui-markdown-invisible text property block at POS during isearch."
  (let ((from (if (get-text-property pos 'cui-markdown-invisible)
                  (previous-single-property-change (min (1+ pos) (point-max)) 'cui-markdown-invisible nil (point-min))
                pos))
        (to (next-single-property-change pos 'cui-markdown-invisible nil (point-max))))
    (cui-optional--show-region-text-prop from to)))

(defun cui-optional--hide-region-text-prop (from to)
  "Hide the region between FROM and TO using a custom text property.
Also registers `cui-optional--isearch-open-text-prop' as the `isearch' handler."
  (interactive "r")
  (with-silent-modifications
    ;; 1. Use 'cui-markdown-invisible instead of 'invisible
    (put-text-property from to 'cui-markdown-invisible 'cui-markdown-value)

    ;; 2. Fix Isearch: Register the callback boundary cleanly
    (put-text-property from to 'isearch-open-invisible #'cui-optional--isearch-open-text-prop)))


(defun cui-optional--show-region-text-prop (from to)
  "Reveal the hidden text property block between FROM and TO.
Expands the boundaries to encompass the full \='cui-markdown-invisible
 block before removing the properties."
  (interactive "r")
  (cui--debug "cui-optional--show-region-text-prop %s" from to)
  (save-excursion
    ;; 1. Expand 'from' backwards if inside or at the edge of a folded block
    (when (and (> from (point-min)) (get-text-property (1- from) 'cui-markdown-invisible))
      (setq from (previous-single-property-change from 'cui-markdown-invisible nil (point-min))))
    (when (get-text-property from 'cui-markdown-invisible)
      (setq from (previous-single-property-change (min (1+ from) (point-max)) 'cui-markdown-invisible nil (point-min))))

    ;; 2. Expand 'to' forwards if inside a folded block
    (when (get-text-property to 'cui-markdown-invisible)
      (setq to (next-single-property-change to 'cui-markdown-invisible nil (point-max))))

    ;; 3. SILENTLY MANIPULATE PROPERTIES
    ;; This macro prevents the buffer from being marked as modified,
    ;; bypasses undo history tracking, and silences change hooks.
    (with-silent-modifications
      ;; Strip the custom properties
      (remove-list-of-text-properties from to '(cui-markdown-invisible isearch-open-invisible))

      ;; 4. FORCE REDISPLAY ENGINE TO UPDATE (The Magic Fix)
      ;; (put-text-property from to 'cui-markdown-invisible nil)
      ;; (put-text-property from to 'invisible nil)
      (font-lock-flush from to))))



(defun cui-optional--region-has-hidden-subregions-p (from to)
  "Return non-nil if there are any hidden subregions between FROM and TO."
  (if (>= from to)
      nil
    (and (text-property-any from to 'cui-markdown-invisible 'cui-markdown-value) t)))


(defun cui-optional-markdown-cycle (&optional _)
  "Fold/unfold Markdown header.
Only works in `org-mode'.
`org-cycle-internal-local'
`org-fold-folded-p'.
Return t if success."
  (interactive)
  (cui--debug "cui-optional-markdown-cycle")
  (when (and (derived-mode-p 'org-mode)
             (cui-block-p)
             (cui-block--markdown-heading-p))
    (save-excursion
      (let ((eoh (line-end-position)) ; end of line
            (eos (save-excursion
                   (cui-block--markdown-heading-end-of-subtree) ; set cursor at first header after end
                   (unless (eobp) (forward-char -1))
                   (point))))
        (if (= eoh eos) ; empty header
            (org-unlogged-message "EMPTY")
          ;; else
          (beginning-of-line)
          (when (not (org-invisible-p)) ; header is visible itself
            (end-of-line)
            (if (org-invisible-p)
                (progn
                  (cui-optional--show-region-text-prop eoh eos)
                  ;; (org-fold-region eoh eos nil 'outline) ; show
                  (org-unlogged-message "SUBTREE"))
              ;; else - put a single hidding block, dont show subheaders
              (cui-optional--hide-region-text-prop eoh eos)
              ;; (org-fold-region eoh eos t 'outline) ; hide
              (org-unlogged-message "FOLDED"))))))))


(defun cui-optional-cycle-content-by-block-fields ()
  "Process fields within the block region separated by '^---'.
Collapses text below the highest-level headline found in each field."
  (interactive)
  (let ((block-region (cui-block--region)))
    (when block-region
      (let ((block-beg (car block-region))
            (block-end (cdr block-region)))

        ;; 1. Reveal everything first
        (cui--debug "cui-optional-cycle-content-by-block-fields N1 %s" block-beg block-end)
        (cui-optional--show-region-text-prop block-beg block-end)

        (save-excursion
          (goto-char block-beg)
          ;; 2. Direct forward scan through the entire block
          (while (re-search-forward "^\\(#+\\) " block-end t)
            (cui--debug "cui-optional-cycle-content-by-block-fields N2 %s" (point))
            (let ((beg (line-end-position))
                  ;; Use your helper function to instantly locate the boundary
                  (end (save-excursion (cui-block--markdown-heading-end-of-subtree))))

              (cui--debug "cui-optional-cycle-content-by-block-fields N3 %s" beg end)

              ;; 3. Hide the found region if valid
              (when (and end (> end beg))
                (cui--debug "cui-optional-cycle-content-by-block-fields N31")
                (cui-optional--hide-region-text-prop beg (1- end))

                ;; 4. Move point to the end of the subtree to skip over hidden text
                ;; and continue searching for the next field's headlines.

                (cui--debug "cui-optional-cycle-content-by-block-fields N32")
                (goto-char end)))))))))


(defun cui-optional-cycle-block ()
  "Toggle visibility of the current block between \='show and \='overview.
Same as `outline-cycle-buffer'.

Determines the target block via `cui-block--region'.
- If hidden subregions exist, reveals them.
- If already fully revealed, folds contents down to top-level headlines
  via `cui-optional-cycle-content-by-block-fields'.

Safely isolates processing using `save-excursion' and `narrow-to-region'
to preserve original buffer point and narrowing state."
  (interactive)
  (cui--debug "cui-optional-cycle-global N0 %s" (cui-block--region))
  (let ((block-region (cui-block--region)))
    (when block-region
      (let ((block-beg (car block-region))
            (block-end (cdr block-region)))
        (save-excursion
          ;; (save-restriction
          ;;   (widen)
          ;;   ;; Narrow Emacs' view so string/search functions only see this block
          ;;   (narrow-to-region block-beg block-end)
          (cui--debug "cui-optional-cycle-global N1 %s" block-beg block-end)
          (if (cui-optional--region-has-hidden-subregions-p block-beg block-end)
              (progn
                (cui--debug "cui-optional-cycle-global has hidden %s %s" block-beg block-end)
                (cui-optional--show-region-text-prop block-beg block-end)) ; show
            (cui--debug "cui-optional-cycle-global")
            (cui-optional-cycle-content-by-block-fields)))))))       ; Hide


(defun cui-optional-markdown-folding-shifttab-advice (orig-fun &rest args)
  "Advice for cycle markdown headers in cui block with Shift-TAB.
ORIG-FUN is `org-shifttab' with its ARGS.
TODO: May cause error at `org-element--parse-to' at `re-search-forward'."
  (cui--debug "cui-optional-markdown-folding-shifttab-advice N1") ; %s %s" (bound-and-true-p cui-mode) (cui-block-p))
  (if (and (bound-and-true-p cui-mode)
           ;; if there is markdown headers in cui block
           (save-excursion
             (let ((block-region (cui-block--region)))
               (when block-region
                 (let ((block-beg (car block-region))
                       (block-end (cdr block-region)))
                   (goto-char block-beg)
                   (re-search-forward cui-block--markdown-header-re block-end t))))))

      (progn (cui--debug "cui-optional-markdown-folding-shifttab-advice N2")
      (cui-optional-cycle-block))
    ;; else
    (apply orig-fun args)))


;;;; provide
(provide 'cui-optional)
;;; cui-optional.el ends here
