;;; itl.el -- Major mode for editing Interchange Tag Language files

;; Author: Steve Shoopak <steve@endpoint.com>
;; Created: October 20th, 2005
;; Keywords: ITL major-mode

;;; Description:
;;
;; This mode allows syntax highlighting of files with
;; embedded Interchange Tag Language.

;;; Code:
(defvar itl-mode-hook nil)
(defvar itl-mode-map nil)

(add-to-list 'auto-mode-alist '("\\.itl\\'" . itl-mode))

(defconst itl-font-lock-keywords-1
  (list
    '("\\[\\\/?\\w+" . font-lock-keyword-face)
    '("\\(\\[\\|\\]\\)" . font-lock-keyword-face)
    '("\\(\\(__\\|\\@_\\|\\@\\@\\)\\w*\\(__\\|_\\@\\|\\@\\@\\)\\)" .
font-lock-variable-name-face))
  "Basic stuff to highlight in ITL mode")

(defvar itl-font-lock-keywords itl-font-lock-keywords-1
  "ITL mode keywords.  You might append more to extend the basic list.")

(defvar itl-mode-syntax-table
  (let ((itl-mode-syntax-table (make-syntax-table)))
    (modify-syntax-entry ?_ "w" itl-mode-syntax-table)
    (modify-syntax-entry ?/ ". 124b" itl-mode-syntax-table)
    (modify-syntax-entry ?* ". 23" itl-mode-syntax-table)
    (modify-syntax-entry ?\n "> b" itl-mode-syntax-table)
    itl-mode-syntax-table)
  "Syntax table for itl-mode")

(defun itl-mode ()
  "Major mode for editing Interchange Tag Language files"
  (interactive)
  (kill-all-local-variables)
  (set-syntax-table itl-mode-syntax-table)
  (use-local-map itl-mode-map)
  (set (make-local-variable 'font-lock-defaults) '(itl-font-lock-keywords))
  (setq major-mode 'itl-mode)
  (setq mode-name "ITL")
  (run-hooks 'itl-mode-hook))

(provide 'itl-mode)
