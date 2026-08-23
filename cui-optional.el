;;; cui-optional.el --- Useful functions that not enabled by default.  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 github.com/Anoncheg1
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

;; -=-= remove-distant-empty-lines hook
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

;; -=-= remove-headers hook
(defun cui-optional-remove-headers (beg-pos end-pos)
  "Remove Org mode header prefixes, like ^**.
You may require this, because  LLMs frequently uses markdown for headers
that recognized in Org mode as headers, that break blocks.
Works at every line between BEG-POS and END-POS in the current buffer.
Uses `org-outline-regexp-bol' to match headers, respecting
user-configured prefixes."
  (interactive "r")
  (replace-regexp-in-region org-outline-regexp-bol "" beg-pos end-pos))


(defun cui-optional-remove-headers-hook-function (type _content before-pos _stream)
  "Ready for usage in `cui-block-after-chat-insertion-hook'.
Remove Org headers between BEFORE-POS and current position in current
 buffer buffer by adding space before it.
TYPE _CONTENT BEFORE-POS BUF parameters described in
`cui-block-after-chat-insertion-hook' hook.
Should be added the last to be executed first."
  (cui--debug "cui-optional-remove-headers-hook-function HOOK: %s %s %s %s"
              before-pos
              (point)
              type
              (type-of type))
  (when (member type '(text end))
    (save-excursion
      (let ((end (point-marker)))
        (goto-char before-pos)
        (while (re-search-forward org-outline-regexp-bol (marker-position end) t)
          (beginning-of-line)
          (insert " ") ; this effectively quote standard headers
          (end-of-line))))))

;; -=-= Markdown: folding - healping funcs

(defun cui-optional--markdown-heading-p ()
  "Before first heading?
like `org-before-first-heading-p'."
  (save-excursion
    (forward-line 0)
    (and (looking-at cui-block--markdown-header-re)
         (not (cui-block--markdown-block-p)))))

(defun cui-optional--markdown-back-to-heading ()
  "Go back to beginning of heading, return point or nil.
Respect message prefixes, cui blocks and --- page separator.
`org-back-to-heading-or-point-min'."
  (or (when (cui-optional--markdown-heading-p) (goto-char (line-beginning-position))) ; for returinging (point)
      (let* ((beg-of-message (cui-block--find-next-prev-region -1))
             (page-sep (save-excursion
                        (catch 'result
                          (while (re-search-backward "^---" beg-of-message t)
                            (when (save-excursion (not (cui-block--markdown-block-p)))
                              (throw 'result (line-beginning-position))))
                          nil)))
             (min-lim-pos (max beg-of-message ; begin of prefix or block
                               (or page-sep (point-min)))))
        (re-search-backward cui-block--markdown-header-re min-lim-pos t))))

(defun cui-optional--markdown-end-of-subtree ()
  "Goto to the end of a visible subtree at point and return point.
`org-end-of-subtree' uses `org-back-to-heading-or-point-min'.
Cursors should be at header.
Or set cursor at --- or at next chat prefix []: or at the end of chat
 block or end of buffer."
  (when (cui-optional--markdown-back-to-heading)
    (let* ((current-level (save-excursion
                            (beginning-of-line)
                            (if (looking-at "^\\(#+\\) ")
                                (length (match-string 1))
                              1)))
           (end-of-message (save-excursion
                             (cui-block--find-next-prev-region))) ; or end of cui block
           (page-sep (save-excursion
                       (catch 'result
                         (while (re-search-forward "^---" end-of-message t)
                           (when (save-excursion (not (cui-block--markdown-block-p)))
                             (throw 'result (line-beginning-position))))
                         nil)))
           (lim-pos (min end-of-message (or page-sep (point-max))))) ; if not found, return nil

      (end-of-line)
      (if (re-search-forward (format "^\\(#\\{1,%d\\}\\) " current-level) lim-pos t)
          (goto-char (line-beginning-position))
        ;; else
        (goto-char lim-pos)
        (beginning-of-line)
        (point)))))

;; -=-= Markdown: folding - cycling

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
  (when (and (derived-mode-p 'org-mode)
             (cui-block-p)
             (cui-optional--markdown-heading-p))
    (save-excursion
      (let ((eoh (line-end-position)) ; end of line
            (eos (save-excursion
                   (cui-optional--markdown-end-of-subtree) ; set cursor at first header after end
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
              ;; else
              (cui-optional--hide-region-text-prop eoh eos)
              ;; (org-fold-region eoh eos t 'outline) ; hide
              (org-unlogged-message "FOLDED"))))))))


(defun cui-optional-cycle-content-by-block-fields ()
  "Process fields within the block region separated by '^---'.
Collapses text below the highest-level headline found in each field."
  (interactive)
  (when-let ((block-region (cui-block--region)))
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
                (end (save-excursion (cui-optional--markdown-end-of-subtree))))

                (cui--debug "cui-optional-cycle-content-by-block-fields N3 %s" beg end)

                ;; 3. Hide the found region if valid
                (when (and end (> end beg))
                  (cui--debug "cui-optional-cycle-content-by-block-fields N31")
                  (cui-optional--hide-region-text-prop beg (1- end))

                  ;; 4. Move point to the end of the subtree to skip over hidden text
                  ;; and continue searching for the next field's headlines.

                  (cui--debug "cui-optional-cycle-content-by-block-fields N32")
                  (goto-char end))))))))





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
  (when-let ((block-region (cui-block--region)))
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
            (cui-optional-cycle-content-by-block-fields))))))       ; Hide


(defun cui-optional-markdown-folding-shifttab-advice (orig-fun &rest args)
  "Advice for cycle markdown headers in cui block with Shift-TAB.
ORIG-FUN is `org-shifttab' with its ARGS."
  (cui--debug "cui-optional-markdown-folding-shifttab-advice N1") ; %s %s" (bound-and-true-p cui-mode) (cui-block-p))
  (if (and (bound-and-true-p cui-mode)
           ;; if there is markdown headers in cui block
           (save-excursion
             (when-let ((block-region (cui-block--region)))
               (let ((block-beg (car block-region))
                     (block-end (cdr block-region)))
                 (goto-char block-beg)
                 (re-search-forward cui-block--markdown-header-re block-end t)))))

      (progn (cui--debug "cui-optional-markdown-folding-shifttab-advice N2")
      (cui-optional-cycle-block))
    ;; else
    (apply orig-fun args)))


;;;; provide
(provide 'cui-optional)
;;; cui-optional.el ends here
