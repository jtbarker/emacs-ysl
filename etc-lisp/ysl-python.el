(require 'ysl-init)

(defvar ysl/python-active-virtualenv "default")
(defvar ysl/python-executable "/usr/bin/python")
(defvar ysl/python-syntax-checker "/usr/bin/pychecker")

(autoload 'python-mode "python-mode" "Python Mode." t)
(add-to-list 'auto-mode-alist '("\\.py\\'" . python-mode))
(add-to-list 'auto-mode-alist '("\\.rpy\\'" . python-mode))
(add-to-list 'interpreter-mode-alist '("python" . python-mode))

(define-key python-mode-map (kbd "C-c C-c") 'compile-python)

;; compile python code {{
(defun compile-python ()
  "Use compile to run python programs"
  (interactive)
  (if ysl/python-active-virtualenv
      (compile (concat "python"
                       " " (buffer-file-name)))
    (compile (concat ysl/python-executable " " (buffer-file-name)))))
;; }}

;;Ryan's python specific tab completion
(defun ryan-python-tab ()
  ; Try the following:
  ; 1) Do a yasnippet expansion
  ; 2) Do a Rope code completion
  ; 3) Do an indent
  (interactive)
  (if (not (ac-start))
      (indent-for-tab-command)))
;; }}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Auto-completion
;;;  Integrates:
;;;   1) Rope
;;;   2) Yasnippet
;;;   all with AutoComplete.el
;;; http://www.enigmacurry.com/2009/01/21/autocompleteel-python-code-completion-in-emacs/
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun prefix-list-elements (list prefix)
  (let (value)
    (nreverse
     (dolist (element list value)
       (setq value (cons (format "%s%s" prefix element) value))))))

(defvar ac-source-rope
  '((candidates
     . (lambda ()
         (prefix-list-elements (rope-completions) ac-target))))
  "Source for Rope")

(defun ac-python-find ()
  "Python `ac-find-function'."
  (require 'thingatpt)
  (let ((symbol (car-safe (bounds-of-thing-at-point 'symbol))))
    (if (null symbol)
        (if (string= "." (buffer-substring (- (point) 1) (point)))
            (point)
          nil)
      symbol)))

(defun ac-python-candidate ()
  "Python `ac-candidates-function'"
  (let (candidates)
    (dolist (source ac-sources)
      (if (symbolp source)
          (setq source (symbol-value source)))
      (let* ((ac-limit (or (cdr-safe (assq 'limit source)) ac-limit))
             (requires (cdr-safe (assq 'requires source)))
             cand)
        (if (or (null requires)
                (>= (length ac-target) requires))
            (setq cand
                  (delq nil
                        (mapcar (lambda (candidate)
                                  (propertize candidate 'source source))
                                (funcall (cdr (assq 'candidates source)))))))
        (if (and (> ac-limit 1)
                 (> (length cand) ac-limit))
            (setcdr (nthcdr (1- ac-limit) cand) nil))
        (setq candidates (append candidates cand))))
    (delete-dups candidates)))

;; setup flymake {{
(defun flymake-pyflakes-init ()
(let* ((temp-file (flymake-init-create-temp-buffer-copy
				   'flymake-create-temp-inplace))
	   (local-file (file-relative-name
					temp-file
					(file-name-directory buffer-file-name))))
  (list ysl/python-syntax-checker (list local-file))))

(add-to-list 'flymake-allowed-file-name-masks
		   '("\\.py\\'" flymake-pyflakes-init))
(add-to-list 'flymake-allowed-file-name-masks
		   '("\\.rpy\\'" flymake-pyflakes-init))

;; }}

;; Initialize Pymacs {{
;; use the pymacs shipped with python-mode
(setenv "PYMACS_INSTALL_DIR" (concat conf-root-dir "/el-get/python-mode"))
(autoload 'pymacs-apply "pymacs")
(autoload 'pymacs-call "pymacs")
(autoload 'pymacs-eval "pymacs" nil t)
(autoload 'pymacs-exec "pymacs" nil t)
(autoload 'pymacs-load "pymacs" nil t)
(autoload 'pymacs-autoload "pymacs" nil t)
;; }}

; check if rope-completions exists

(if (file-exists-p ysl/python-executable)
  (progn
    (message "found python at %s" ysl/python-executable)
    (pymacs-load "ropemacs" "rope-")
    (unless (fboundp 'rope-completions)
      (error "rope-completions not found, try development version of ropemacs"))))

;; Ropemacs Settings {{
(setq ropemacs-enable-shortcuts nil
      ropemacs-local-prefix "C-c C-p"
      ropemacs-codeassist-maxfixes 3 ;; Stops from erroring if there's a syntax err
      ropemacs-guess-project t
      ropemacs-enable-autoimport t
      ropemacs-confirm-saving 'nil)
;; }}

;; initial hook {{
(add-hook 'python-mode-hook
          (lambda ()
;            (auto-complete-mode 1)
            (setq indent-tabs-mode nil
                  tab-width 4
                  python-indent 4
                  py-indent-offset 4
                  py-smart-indentation nil)
            (set (make-local-variable 'virtualenv-workon-starts-python) nil)
            (set (make-local-variable 'ac-sources)
                 (append ac-sources '(ac-source-ropemacs) '(ac-source-yasnippet)))

            (set (make-local-variable 'ac-find-function) 'ac-python-find)
            (set (make-local-variable 'ac-candidate-function) 'ac-python-candidate)
 ;          (set (make-local-variable 'ac-auto-start) nil)

            (unless (eq buffer-file-name nil) (flymake-mode))
            (local-set-key "\C-m" 'newline-and-indent)
            (local-set-key "\C-d" 'py-help-at-point)
            ;; initialize virtualenv
            (if ysl/python-active-virtualenv
                (progn
                  (require 'virtualenv)
                  (virtualenv-minor-mode-on)
                  (virtualenv-workon ysl/python-active-virtualenv)))))
;; }}

;; remap tab key {{
; (define-key python-mode-map "\t" 'ryan-python-tab)

(provide 'ysl-python)
