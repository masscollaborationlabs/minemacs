;; me-defaults.el --- MinEmacs -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Abdelhak Bougouffa

;; Author: Abdelhak Bougouffa <abougouffa@fedoraproject.org>


(setq-default font-lock-multiline 'undecided)

;;; Better defaults
(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8)
(setq default-input-method nil)

;;; Set files and directories for built-in packages
(setq backup-directory-alist (list (cons "." (expand-file-name "backup/" minemacs-local-dir)))
      auto-save-list-file-prefix (expand-file-name "auto-save-list/" minemacs-local-dir)
      pcache-directory (expand-file-name "pcache/" minemacs-cache-dir))


(setq visible-bell nil ;; set to non-nil to flash!
      ring-bell-function 'ignore
      large-file-warning-threshold (* 50 1024 1024) ;; change to 50 MiB
      use-short-answers t ;; y or n istead of yes or no
      confirm-kill-emacs 'y-or-n-p ;; confirm before quitting
      initial-scratch-message ";; MinEmacs -- start here!"
      frame-resize-pixelwise t
      delete-by-moving-to-trash t)

(setq auth-sources '("~/.authinfo.gpg") ;; Defaults to GPG
      auth-source-do-cache t
      auth-source-cache-expiry 86400 ; All day, defaut is 2h (7200)
      password-cache t
      password-cache-expiry 86400)

;;; Undo
(setq undo-limit        10000000 ;; 1MB (default is 160kB)
      undo-strong-limit 100000000 ;; 100MB (default is 240kB)
      undo-outer-limit  1000000000) ;; 1GB (default is 24MB)

;;; Editing
(setq-default display-line-numbers-width 3
              display-line-numbers-type 'relative
              truncate-lines nil
              fill-column 80
              tab-width 2
              indent-tabs-mode nil
              tab-always-indent nil)

;;; Backups
;; Disable backup and lockfiles
(setq create-lockfiles nil
      make-backup-files nil
      version-control t ;; number each backup file
      backup-by-copying t ;; copy instead of renaming current file
      delete-old-versions t ;; clean up after itself
      kept-old-versions 5
      kept-new-versions 5
      tramp-backup-directory-alist backup-directory-alist)

;;; Auto-Saving, sessions...
;; Enable auto-save (use `recover-file' or `recover-session' to recover)
(setq auto-save-default t
      auto-save-include-big-deletions t
      auto-save-file-name-transforms
      (list (list "\\`/[^/]*:\\([^/]*/\\)*\\([^/]*\\)\\'"
                  ;; Prefix tramp autosaves to prevent conflicts with local ones
                  (concat auto-save-list-file-prefix "tramp-\\2") t)
            (list ".*" auto-save-list-file-prefix t)))

(setq sentence-end-double-space nil)

;;; Scrolling
(setq hscroll-step 1
      hscroll-margin 0
      scroll-step 1
      scroll-margin 0
      scroll-conservatively 101
      scroll-up-aggressively 0.01
      scroll-down-aggressively 0.01
      scroll-preserve-screen-position 'always
      auto-window-vscroll nil
      fast-but-imprecise-scrolling t)

;; Stretch cursor to the glyph width
(setq-default x-stretch-cursor t)

(setq-default window-combination-resize t)

;; Mode-line stuff
;; Enable time in the mode-line
(setq display-time-string-forms
      '((propertize (concat 24-hours ":" minutes))))

;;; Enable global modes
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'display-line-numbers-mode)

;; Guess major mode when saving a file (from Doom Emacs)
(add-hook
 'after-save-hook
 (defun me-guess-file-mode-h ()
   "Guess major mode when saving a file in `fundamental-mode'.

Likely, something has changed since the buffer was opened. e.g. A shebang line
or file path may exist now."
   (when (eq major-mode 'fundamental-mode)
     (let ((buffer (or (buffer-base-buffer) (current-buffer))))
       (and (buffer-file-name buffer)
            (eq buffer (window-buffer (selected-window))) ;; Only visible buffers
            (set-auto-mode))))))

;;; Load fonts at startup, values are read from `me-fonts' if set in config.el,
;; and fallback to `me-default-fonts'
(add-hook 'emacs-startup-hook #'me-set-fonts)

;; From https://trey-jackson.blogspot.com/2010/04/emacs-tip-36-abort-minibuffer-when.html
(add-hook
 'mouse-leave-buffer-hook
 (defun me-minibuffer--kill-on-mouse-h ()
   "Kill the minibuffer when switching to window with mouse."
   (when (and (>= (recursion-depth) 1) (active-minibuffer-window))
     (abort-recursive-edit))))

;; Automatically cancel the minibuffer when  you avoid
;; "attempted to use minibuffer" error.
;; From https://stackoverflow.com/a/39672208/3058915
(advice-add
 'read-from-minibuffer :around
 (defun me-minibuffer--kill-on-read-a (sub-read &rest args)
   (let ((active (active-minibuffer-window)))
     (if active
         (progn
           ;; We have to trampoline, since we're IN the minibuffer right now.
           (apply 'run-at-time 0 nil sub-read args)
           (abort-recursive-edit))
       (apply sub-read args)))))

(when feat/xwidgets
  ;; Make xwidget-webkit the default browser
  (setq browse-url-browser-function #'xwidget-webkit-browse-url)
  (defalias 'browse-web #'xwidget-webkit-browse-url))

(with-eval-after-load 'minemacs-loaded
  ;; Enable battery (if available) in mode-line
  (me-with-shutup!
   (let ((battery-str (battery)))
     (unless (or (equal "Battery status not available" battery-str)
                 (string-match-p "unknown" battery-str)
                 (string-match-p "N/A" battery-str))
       (display-battery-mode 1)))

   (when (>= emacs-major-version 29)
     (pixel-scroll-precision-mode 1))

   ;; Display time in mode-line
   (display-time-mode 1)

   ;; Highlight current line
   (global-hl-line-mode 1)

   ;; Enable recentf-mode globally
   (recentf-mode 1)

   ;; Global SubWord mode
   (global-subword-mode 1)))


(provide 'me-defaults)
