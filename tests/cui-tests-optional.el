;;; cui-tests-optional.el --- Tests. -*- lexical-binding: t; -*-

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

(require 'ert)
(require 'cui-optional)
(defvar ert-enabled nil)
;; (eval-buffer)
;; (ert t)
;;

;;; Code:

;; -=-= Help function
(defmacro cui-tests-optional--with-special-context (&rest body)
  `(with-temp-buffer
     (org-mode)
     (transient-mark-mode)
     (prog1
         (let ((cui-restapi-con-token '(:openai "test-token-openai")))
           (insert "#+begin_ai\n")
           (let ((p1 (point)))
             (insert "\n#+end_ai")
             (goto-char p1)
             ,@body))
      (set-buffer-modified-p nil))))


;; -=-= For `cui-optional-remove-distant-empty-lines'

(ert-deftest cui-tests-optional--remove-distant-empty-lines1 ()
  (should
   (string-equal "line 1\n\nline 2\nline 3\nline 4\nline 5\n\nline 6\n"
               (let ((string "line 1\n\n\nline 2\n\n\nline 3\n\nline 4\nline 5\n\nline 6\n"))
                 (with-temp-buffer
                   ;; Set up initial buffer content
                   (insert string)
                   (cui-optional-remove-distant-empty-lines (point-min))
                   (buffer-substring-no-properties                           (point-min)
                                                                             (point-max)))))))

(ert-deftest cui-tests-optional--remove-distant-empty-lines2 ()
  (should
   (string-equal "line 1\n\nline 2\nline 3\nline 4\nline 5.\n[ME]:line 6\n"
               (with-temp-buffer
                 ;; Set up initial buffer content
                 (insert "line 1\n\nline 2\n\nline 3\n\n\n\nline 4\n\nline 5.\n[ME]:line 6\n")
                 (cui-optional-remove-distant-empty-lines (point-min))
                 (buffer-substring-no-properties                           (point-min)
                                                                           (point-max))))))

;; -=-= For `cui-optional-remove-headers-hook-function'
(ert-deftest cui-tests-optional--remove-headers-hook-function ()
  (with-temp-buffer
    (let (
          (cui-debug-buffer nil)
          p1
          p2
          res)
      (insert "** Something Importent1\n")
      (insert "#+begin_ai\n")
      (setq p1 (point))
      (insert "** not important **\n")
      (insert "#+end_ai\n")
      (setq p2 (point))
      (insert "** Something Importent2\n")
      (goto-char p2)
      (cui-optional-remove-headers-hook-function 'end "" p1 nil)
      (setq res (string-split (buffer-substring-no-properties (point-min) (point-max)) "\n"))
      (should
       (string-equal
        (nth 0 res) "** Something Importent1"))
      (should
       (string-equal
        (nth 1 res) "#+begin_ai"))
      (should
       (string-equal
        (nth 2 res) " ** not important **"))
      (should
       (string-equal
        (nth 3 res) "#+end_ai"))
      (should
       (string-equal
        (nth 4 res) "** Something Importent2")))))



;; -=-= For `cui-optional-markdown-cycle'

(ert-deftest cui-tests-optional--markdown-cycle ()
  (cui-tests-optional--with-special-context
   (cui-optional-markdown-folding-activation) ; folding activation
   (add-hook 'org-tab-first-hook #'cui-optional-markdown-cycle) ; For TAB key on "# headers"
   (advice-add 'org-shifttab :around #'cui-optional-markdown-folding-shifttab-advice)
   (let ((p (point)))
     (insert "# test header")
     (insert "\nsdasd\nasd\n[ai]:\n")
     ;; (buffer-substring-no-properties (line-beginning-position) (line-end-position))
     ;; - Fold
     (goto-char p)
     (org-cycle)
     (goto-char p)
     (should-not (text-properties-at (point)))
     (forward-line 1)
     (should (member 'cui-markdown-invisible  (text-properties-at (point))))
     (should (eq 'cui-markdown-value (get-text-property (point) 'cui-markdown-invisible)))

     ;; - UnFold
     (goto-char p)
     (org-cycle)
     (should-not (text-properties-at (point)))
     (forward-line 1)
     (should-not (text-properties-at (point)))
     ;; - Fold block
     (cui-optional-cycle-block)
     (should (eq 'cui-markdown-value (get-text-property (point) 'cui-markdown-invisible)))
     (goto-char p)
     (should-not (text-properties-at (point)))
     ;; - UnFold
     (cui-optional-cycle-block)
     (should-not (text-properties-at (point)))
     (forward-line 1)
     (should-not (text-properties-at (point)))
     ;; (goto-char p)
     ;; (text-properties-at (point))
     ;; (print (member 'cui-markdown-invisible  (text-properties-at (point))))
   ;; (buffer-substring-no-properties (point-min) (point-max))
   )))

(provide 'cui-tests-optional)

;;; cui-tests-optional.el ends here
