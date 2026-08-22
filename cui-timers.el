;;; cui-timers.el --- Request Timers and notifications for cui -*- lexical-binding: t; -*-

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


;;; Commentary:
;; `interrupt-request-func' is for implementation of interrupt that
;; `cui-restapi--interrupt-url-request'

;;; Code:
(require 'cui-debug)

;; -=-= variables
(defcustom cui-timers-echo-gap 0.2
  "Echo update interval for notification about waiting."
  :type 'float
  :group 'cui)

(defcustom cui-timers-duration most-positive-fixnum
  "The total duration in seconds for which the timer should run.
Delay after which it will be killed."
  :type 'integer
  :group 'cui)

(defcustom cui-timers-retries 3
  "Amount of request attemts before give up.
Used for `cui-restapi-request-llm-retries' calling in `cui-prompt'."
  :type 'integer
  :group 'cui)

(defvar cui-timers--global-progress-reporter nil
  "Progress-reporter for request response to indical waiting.")

(defvar cui-timers--global-progress-timer nil
  "Timer for updating the progress reporter.")

(defvar cui-timers--global-progress-timer-remaining-ticks 0
  "The time when the timer started.")

(defvar-local cui-timers--current-timer nil
  "Timer for waiting for url buffer.")

(defvar-local cui-timers--current-timer-remaining-ticks 0
  "The time when the timer started.")

(defvar cui-timers--global-progress-reporter-waiting-string "Waiting for a response")

(defvar cui-timers--element-marker-variable-dict nil
  "Allow to store url buffer per block.
Pairs of url-buffer (key) -> Header-marker (variable).
So cui block may have several url-buffer running at the same time.
Intented for usage with `cui-block--copy-header-marker' and keep pairs of
\(url-retrieve buffero -> header marker).
Should be used for interactive interrup of request only.
`eq' is good for buffers, for markers we should use `equal'")

;; -=-= variable-dict
(defun cui-timers--get-variable (key)
  "Get variable (one or first) for KEY.
Get header-marker (variable) for url-buffer (key).
Key is Indented for usage with `cui-block-get-header-marker'.
Use ELEMENT only in current moment.
We use `eq' to find key which is buffer."
    (alist-get key cui-timers--element-marker-variable-dict nil nil #'eq))


(defun cui-timers--get-keys-for-variable (variable)
  "Return a list of keys.
VARIABLE is header-marker or cui block.
Return list of url-buffers.
use `cui-timers--element-marker-variable-dict'."
  (seq-uniq (mapcar #'car
                    (seq-filter (lambda (entry)
                                  (equal (cdr entry) variable)
                                       ;; (buffer-live-p (car entry))
                                       )
                                cui-timers--element-marker-variable-dict))))

;; cui-timers--set-variable
(defun cui-timers--set (key value)
  "Assign value to key.
KEY: url-buffer, VALUE: header marker.
Indented for usage with `cui-block-get-header-marker'.
Used in
- `cui-restapi-request-prepare'
- `cui-restapi-request-llm-retries'."
    (if (not value)
        (setf (alist-get key cui-timers--element-marker-variable-dict nil 'remove) nil)
      ;; else
      (setf (alist-get key cui-timers--element-marker-variable-dict) value)))

(defun cui-timers--rassq-delete-all-equal (value alist)
  "Delete from ALIST all elements whose cdr is `equal' to VALUE.
Return the modified alist.  Elements of ALIST that are not conses are ignored.
We need this,  because `rassq-delete-all' remove by `eq'  only which not
suitable for  markers which should  be compared by buffer  and position,
not by object itself."
  (delq nil
        (mapcar (lambda (elt)
                  (and (consp elt)
                       (not (equal (cdr elt) value))
                       elt))
                alist)))
;; (setq mylist '((a . 1) (b . 2) (c . (1 2)) (d . 2)))
;; (rassq-delete-all 2 mylist) ;; removes (b . 2) and (d . 2), only if value is `eq` to 2
;; (setq mylist '((a . 1) (b . 2) (c . (1 2)) (d . 2)))
;; (rassq-delete-all-equal 2 mylist) ;; removes (b . 2) and (d . 2), works for numerics
;; (rassq-delete-all-equal '(1 2) mylist) ;; removes (c . (1 2)), matches by content

(defun cui-timers--remove-variable (value)
  "Remove marker.
`equal' for markers compare buffer and positon, `eq' compare objects itself.
We use `eq' here.
Argument VALUE is Header-marker."
  (setq cui-timers--element-marker-variable-dict
        ;; eq compare objects itself
        (cui-timers--rassq-delete-all-equal value cui-timers--element-marker-variable-dict)))

;; (setq a (copy-marker (point)))
;; (setq b (copy-marker (point)))
;; (setq c (copy-marker a))
;; (eq a c)

(defun cui-timers--remove-key (key)
  "Remove buffer.  Use `eq' to find KEY, for buffer eq is ok."
  (setq cui-timers--element-marker-variable-dict
        (assq-delete-all key cui-timers--element-marker-variable-dict)))

;; (setq cui-timers--element-marker-variable-dict nil)
;; (cui-timers--set 1 'aa)
;; (cui-timers--set 2 'cc)
;; (cui-timers--set 3 'bb)
;; (cui-timers--get-variable 2)
;; (cui-timers--set (list 3 2) 'bb)
;; ;; (cui-timers--remove-key 1)
;; (print cui-timers--element-marker-variable-dict)
;; (cui-timers--get-keys-for-variable 'bb)

;; (cui-timers--get-all-variables)
;; (cui-timers--get-all-keys)
;;
;; (cui-timers--remove-variable 'aa)

;; (defun cui-timers--get-all-variables () ; not used
;;   "Get all header-makers."
;;   (seq-uniq (mapcar #'cdr cui-timers--element-marker-variable-dict)))

(defun cui-timers--get-all-keys ()
  "Get all url-buffers."
  (seq-uniq (mapcar #'car cui-timers--element-marker-variable-dict)))

;; (defun cui-timers--clear-variables () ; too simple
;;   (setq cui-timers--element-marker-variable-dict nil))

;; -=-= Timers Global
(defun cui-timers--stop-global-progress-reporter (&optional failed)
  "Stop global timer of progress reporter for restart or at success.
Don't clear list of url-buffers.
Called in
- `cui-timers--progress-reporter-run' for restart,
- `cui-timers--interrupt-current-request' for receiving response.
- `cui-timers--interrupt-all-requests' for full stop.
If Optional argument FAILED is non-nil, then explicitly notify user
about failure."
  (cui--debug "cui-timers--stop-global-progress-reporter N1 %s %s %s"
              failed
              (current-buffer)
              cui-timers--global-progress-reporter
              cui-timers--global-progress-timer)
  ;; finish notifications
  (when cui-timers--global-progress-reporter
    (if failed ; timeout
        (progn ; from `url-queue-kill-job'
          ;; (progress-reporter-done cui-timers--global-progress-reporter)
          (cui--debug "cui-timers--stop-global-progress-reporter N12 failed")
          (progress-reporter-update cui-timers--global-progress-reporter nil "- Connection failed")
          (message (concat cui-timers--global-progress-reporter-waiting-string "- Connection failed")))
      ;; else - echo success
      (progress-reporter-done cui-timers--global-progress-reporter))
    ;; when
    (setq cui-timers--global-progress-reporter nil))

  ;; clear time
  (when cui-timers--global-progress-timer
    (cui--debug "cui-timers--stop-global-progress-reporter N2")
    (cancel-timer cui-timers--global-progress-timer)
    (setq cui-timers--global-progress-timer nil)
    (cui--debug "cui-timers--stop-global-progress-reporter N3 ticks: %s" cui-timers--global-progress-timer-remaining-ticks)
    (setq cui-timers--global-progress-timer-remaining-ticks 0)))

(defvar cui-timers--cui-update-mode-line (intern "cui-update-mode-line")
  "Dependency injection from in cui.el.")

(defun cui-timers--update-global-progress-reporter (&optional failed)
  "Count url-buffers and stop reporter if it is empty.
Called from
`cui-restapi-request-llm-retries'
`cui-timers--interrupt-current-request'
`cui-timers--interrupt-all-requests'.
If Optional argument FAILED is non-nil, then explicitly notify user
about failure."
  (cui--debug "cui-timers--update-global-progress-reporter N1, dict: %s" cui-timers--element-marker-variable-dict)
  (let* ((buffers (cui-timers--get-all-keys))
         (count (length buffers))
         (count-live (length (delq nil (mapcar #'buffer-live-p buffers))))) ; used for debugging here, TODO: check that always same as count
    (cui--debug "cui-timers--update-global-progress-reporter N2, count: %s count-live: %s" count count-live)
    ;; (let ((count (length (cui-timers--get-all-keys))))
      ;; (unless cui-timers--cui-update-mode-line ;; Now, we dont show
      ;;   (error "Library cui.el should be loaded to use cui-timers--update-global-progress-reporter function"))
      ;; (funcall cui-timers--cui-update-mode-line count) ;; Now, we dont show
    (if (eql count 0)
        (cui-timers--stop-global-progress-reporter failed)
      ;; else
      (progress-reporter-force-update cui-timers--global-progress-reporter
                                      nil
                                      (concat cui-timers--global-progress-reporter-waiting-string
                                              "[" (number-to-string (length (cui-timers--get-all-keys))) "]")))))

(defun cui-timers--interrupt-all-requests (interrupt-request-func &optional failed)
  "Interrup all url requests and stop global timer.
INTERRUPT-REQUEST-FUNC may be `cui-restapi--interrupt-url-request' or
`cui-restapi--stop-tracking-url-request'.
Called from
`cui-restapi-stop-all-url-requests' by C\\-g
`cui-timers--progress-reporter-run' by global timer.
If Optional argument FAILED is non-nil, then explicitly notify user
about failure."
  (cui--debug "cui-timers--interrupt-all-requests1 %s %s" cui-timers--element-marker-variable-dict failed)
  (when-let ((buffers (cui-timers--get-all-keys)))
    (cui--debug "cui-timers--interrupt-all-requests2 %s" buffers)
    ;; stop requests
    (mapc (lambda (url-buffer)
            (funcall interrupt-request-func url-buffer))
          buffers))
  (cui--debug "cui-timers--interrupt-all-requests3")
  ;; clear list
  (setq cui-timers--element-marker-variable-dict nil)

  ;; stop global timer
  (cui--debug "cui-timers--interrupt-all-requests4")
  (cui-timers--update-global-progress-reporter failed)
  ;; (cui--debug "cui-timers--interrupt-all-requests5")
  )

;; -=-= Timers Local
(defun cui-timers--interrupt-current-request (url-buffer interrupt-request-func)
  "Interrupt every buffer, remove buffer from list, update global timer.
URL-BUFFER one or several buffers.
Should be called in target buffer with global timer.
INTERRUPT-REQUEST-FUNC may be `cui-restapi--stop-tracking-url-request'
or `cui-restapi--interrupt-url-request'
Called from
`cui-restapi--url-request-on-change-function' for  not stream after  reply or
\"DONE\" string found for stream.
`cui-restapi-stop-url-request'."
  (cui--debug "cui-timers--interrupt-current-request %s %s %s" (buffer-live-p url-buffer) interrupt-request-func url-buffer)

  (if (sequencep url-buffer) ;; if several
      (mapc (lambda (b)
              (cui-timers--remove-key b)
              (cui--debug "cui-timers--interrupt-current-request lambda")
              (funcall interrupt-request-func b))
            url-buffer)
    ;; else - if one
    ;; - Remove variable
    (cui-timers--remove-key url-buffer)
    ;; - Clear time and kill buffer
    (funcall interrupt-request-func url-buffer))
    ;; - Update global timer
    (cui-timers--update-global-progress-reporter))



;; -=-= Main - constructor
(defun cui-timers--progress-reporter-run (interrupt-request-func &optional duration)
  "Start or update progress notification.
1) Save pair (HEADER-MARKER->URL-BUFFER)
2) INTERRUPT-REQUEST-FUNC - When timer expired kill all by calling for
every buffer.
Require that url-buffer was saved with `cui-timers--set', to count them.
Called from `cui-restapi-request-prepare'.
Set:
- `cui-timers--global-progress-reporter' - lambda that return a string,
- `cui-timers--global-progress-timer' - timer that output /-\ to echo area.
- `cui-timers--global-progress-timer-remaining-ticks'.
- `cui-timers--current-timer' - count life of url buffer,
- `cui-timers--current-timer-remaining-ticks'.
Optional argument DURATION may be used to replace `cui-timers-duration'
value."
  (cui--debug "cui-timers--progress-reporter-run %s %s" (length (cui-timers--get-all-keys)) cui-timers--element-marker-variable-dict)
  ;; - update mode-line
  ;; We make delay because this function run after url-retrieve and url-buffer may be not saved.
  ;; (run-with-timer 1.0 nil (lambda () (funcall cui-timers--cui-update-mode-line (length (cui-timers--get-all-keys))))) ;; Now, we dont show

  ;; - reporter: add remaining ticks. precalculate ticks based on duration, 25/ 0.2 = 125 ticks
  (setq cui-timers--global-progress-timer-remaining-ticks
        (fround (/ (or duration cui-timers-duration) cui-timers-echo-gap)))

  (cui--debug "cui-timers--progress-reporter-run1")
  ;; - Create reporter:
  ;; - reporter: if not exist, create, else update count in message
  (let ((r-message (concat cui-timers--global-progress-reporter-waiting-string
                           (when (> (length (cui-timers--get-all-keys)) 1) ; output only >1 to not overload context
                            (concat "[" (number-to-string (length (cui-timers--get-all-keys))) "]")))))
    (if (not cui-timers--global-progress-reporter)
        (setq cui-timers--global-progress-reporter
              (make-progress-reporter r-message))
      ;; else - update message with count
      (progress-reporter-force-update cui-timers--global-progress-reporter nil r-message)))

  (cui--debug "cui-timers--progress-reporter-run2 %s" cui-timers--global-progress-timer)
  (when (not cui-timers--global-progress-timer)
    (cui--debug "cui-timers--progress-reporter-run3")
    ;; timer1
    (setq cui-timers--global-progress-timer
          (run-with-timer ; do not respect `with-current-buffer'
           1.0 cui-timers-echo-gap ; start after 1 sec
           (lambda ()
             "timer1 in current buffer"
             ;; expired or closed?
             (if (or (<= cui-timers--global-progress-timer-remaining-ticks 0)
                     (not cui-timers--global-progress-reporter))
                 (progn
                   (cui--debug "cui-timers--progress-reporter-run expired")
                   ;; - stop timer:
                   (cui-timers--interrupt-all-requests interrupt-request-func 'failed))
               ;; else -  ticks -= 1
               (setq cui-timers--global-progress-timer-remaining-ticks
                     (1- cui-timers--global-progress-timer-remaining-ticks))
               (progress-reporter-update cui-timers--global-progress-reporter)))))))


(provide 'cui-timers)
;;; cui-timers.el ends here
