;;; cui-debug.el --- Logging for cui in separate buffer  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 github.com/Anoncheg1,codeberg.org/Anoncheg
;; SPDX-License-Identifier: AGPL-3.0-or-later
;; Author: <github.com/Anoncheg1,codeberg.org/Anoncheg>

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
;; To disable debugging, set cui-debug-buffer to nil.
;; Used as a help function `cui--debug' for conditional output of
;; debug messages.
;;
;; ert-enabled variable if bound enable debugging during ert tests.

;;; Code:

(require 'backtrace) ; for `cui-debug--get-caller' (not used now)

;; -=-= customization and function
(defgroup cui-debug nil
  "CUI package customization."
  :group 'cui)

(defcustom cui-debug-buffer nil
  "If non-nil, enable debuging to a new buffer with such name.
Set to something like *debug-cui*.  to enable debugging."
  :type '(choice (const :tag "No debugging" nil)
                 (string :tag "Name of buffer"))
  :group 'cui-debug)

(defcustom cui-debug-timestamp-flag t
  "Non-nil means add timestamp to every debug message."
  :type 'boolean
  :group 'cui-debug)

(defcustom cui-debug-filter nil
  "If non-nil output only strings that contains this string."
  :type '(choice (const :tag "No filter" nil)
                 (string :tag "Regex string for filter"))
  :group 'cui-debug)


;; NOT USED
(defun cui-debug--get-caller ()
  "Return string with name of function of caller function.
Heavy to execute."
  (let* ((backtrace-line-length 20) ; used by `backtrace-get-frames'
         (print-level 3)
         (print-length 10)
         (bt
          ;; (with-output-to-string (backtrace))
          (backtrace-to-string (backtrace-get-frames 'backtrace)))
         (caller))
         (seq-find
          ; - predicate
          (lambda (line)
            (let* ( (mpos (string-match "(" line))
                   (sline (substring line 0 mpos))
                   (tline (string-trim-right (string-trim-left sline))))
                   (if (and (not (string-empty-p tline))
                            (not (member tline '("cui-debug--get-caller" "cui--debug" ) )))
                       (setq caller tline)
                     nil ; else
                     )))
          ;; - lines
          (cdr (string-split bt "\n" t)))
         caller))


(defun cui-debug--format-argument (args)
  "Convert ARGS to a string.
ARGS may be any Elisp object.
Used to prepare arguments of `cui--debug' for output by converting to a
string.
Always return string."
  (if (equal (type-of args) 'string)
      (format "%s\n" args)
    (concat (prin1-to-string args) "\n")))

(defun cui-debug--safe-format (fmt &rest args)
  "Format with fixing count of '%s' in FMT according to lenght of ARGS.
Formats by removing all '%s' from FMT and appending ' %s' for each ARGS."
  ;; Remove all "%s" from fmt
  (let* ((fmt (replace-regexp-in-string " ?%s" "" fmt))
         (num-args (length args))
         (fmt (concat fmt " "
                   (string-join (make-list num-args "%s") " ")
                   "\n")))
    (apply #'format fmt args)))


;; -=-= Main
(defun cui--debug (&rest args)
  "If firt argument of ARGS is a stringwith %s than behave like format.
Otherwise format every to string and concatenate.
Return last argument, but should not be used for return value."
  (when (and (or cui-debug-buffer
                 (bound-and-true-p ert-enabled))
             args)

    (save-excursion
      (let* ((buf-exist (and cui-debug-buffer (get-buffer cui-debug-buffer)))
             (bu (or buf-exist
                     (and (bound-and-true-p ert-enabled) (current-buffer))
                     (get-buffer-create cui-debug-buffer)))
             (current-window (selected-window))
             (bu-window (or (get-buffer-window bu)
                            (when (not (eq last-input-event 7)) ; not C-g exit - too much verbose
                              (let ((w-width (if (>= (count-windows) 2)
                                                0.2
                                              0.33)))
                                (display-buffer-in-direction
                                 bu
                                 (list (cons 'direction 'left)
                                       (cons 'window 'new)
                                       (cons 'window-width w-width)))))
                            (when (not (eq last-input-event 7)) ; not C-g exit - too much verbose
                              (select-window current-window))))
             (timestamp (when cui-debug-timestamp-flag
                          (format-time-string "%M:%S.%3N " (current-time))))
             result-string)

        (with-current-buffer bu
          ;; - 1) move point to  to bottom
          (when buf-exist ; was not created
              (goto-char (point-max))
            ;; else buffer just created
            (local-set-key "q" #'quit-window))
           ;; - scroll debug buffer down
          (when (and bu-window (not (bound-and-true-p ert-enabled)))
              (with-selected-window (get-buffer-window bu)
                   (goto-char (point-max))))
          ;; ;; - output caller function ( working, but too heavy)
          ;; (let ((caller
          ;;        (cui-debug--get-caller)))
          ;;   (when caller
          ;;     (insert "Din ")
          ;;     (insert caller)
          ;;     (insert " :")))
          ;; - 2) prepare output in result-string variable
          (save-match-data
            ;; if first line is a string with %s we output all at one line
            (if (and (equal (type-of (car args)) 'string)
                     (string-match "%s" (car args)))
                ;; "safe format"
                (setq result-string (apply #'cui-debug--safe-format args)) ; (concat (apply #'format (car args) (cdr args)) "\n"))

              ;; else - "```debug" with line by line
              (setq result-string (concat (cui-debug--format-argument (car args))
                                          (when (cdr args)
                                            (concat
                                             "```debug\n" (apply #'concat (mapcar #'cui-debug--format-argument
                                                                               (cdr args)))
                                             "```\n")))))
            (when (and cui-debug-filter
                       (not (string-match-p (regexp-quote cui-debug-filter) result-string)))
                    (setq result-string nil))
            ;; - 3) output as: timestamp - function - ```debug or "safe-format"
            (when result-string
              ;; - two ways to output: for ert.el and to debug buffer.
              (if (bound-and-true-p ert-enabled)
                  (princ (concat timestamp result-string "\n"))
                ;; else
                ;; first word insert as a link
                (when timestamp (insert timestamp))
                (if (string-match "[\s\n]+" result-string)
                    (let ((first-part (substring result-string 0 (match-beginning 0)))
                          (second-part (substring result-string (match-beginning 0))))
                        (insert-text-button first-part
                                            'type 'help-function-def
                                            'help-args (list (intern first-part) nil))
                        (insert second-part))
                    ;; else - as one
                    (insert result-string)))))))))
  (car (reverse args)))

;; -=-= Helping function
(defun cui-debug--prettify-json-string (json-string)
  "Convert a compact JSON string to a prettified JSON string.
This function uses a temporary buffer to perform the prettification.
Returns the prettified JSON string.
Argument JSON-STRING string with json."
  (condition-case err
      (let* ((parsed-json (json-read-from-string json-string))
             ;; 1. First, encode the JSON object. This will be compact with your json-encode.
             (compact-json (json-encode parsed-json)))
        (with-temp-buffer
           (insert compact-json)
           (json-pretty-print-buffer)
           (buffer-string)))
    (error
        (message "Error formatting JSON: %S" err)
        (message "Input JSON: %S" json-string))))


;; (cui--debug "test %s" 2)
;; (cui--debug "test" 2 3 "sd")

;; -=-= interactive toggle
(defun cui-debug-toggle ()
  "Enable/disable debug."
  (interactive)
  (if cui-debug-buffer
      (progn
        (setq cui-debug-buffer nil)
        (message "Disable cui debugging"))
    ;; else
    (setq cui-debug-buffer   "*debug-cui*")
    (message "Enable cui debugging")))


(provide 'cui-debug)
;;; cui-debug.el ends here
