;; me-lib-extra.el -- MinEmacs Library (extra features and commands) -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2024  Abdelhak Bougouffa

;; Author: Abdelhak Bougouffa (rot13 "nobhtbhssn@srqbencebwrpg.bet")

;;; Commentary:

;;; Code:

(make-obsolete '+deferred-when! "This macro will be removed, use (when COND (+deferred! BODY)) instead." "2024-05-18")
(make-obsolete '+deferred-unless! "This macro will be removed, use (unless COND (+deferred! BODY)) instead.." "2024-05-18")
(make-obsolete '+lazy-when! "This macro will be removed, use (when COND (+lazy! BODY)) instead.." "2024-05-18")
(make-obsolete '+lazy-unless! "This macro will be removed, use (unless COND (+lazy! BODY)) instead.." "2024-05-18")

;;; Minemacs' core functions and macros

;;;###autoload
(defmacro +deferred-when! (condition &rest body)
  "Like `+deferred!', with BODY executed only if CONDITION is non-nil."
  (declare (indent 1))
  `(when ,condition (+deferred! ,@body)))

;;;###autoload
(defmacro +deferred-unless! (condition &rest body)
  "Like `+deferred!', with BODY executed only if CONDITION is nil."
  (declare (indent 1))
  `(unless ,condition (+deferred! ,@body)))

;;;###autoload
(defmacro +lazy-when! (condition &rest body)
  "Like `+lazy!', with BODY executed only if CONDITION is non-nil."
  (declare (indent 1))
  `(when ,condition (+lazy! ,@body)))

;;;###autoload
(defmacro +lazy-unless! (condition &rest body)
  "Like `+lazy!', with BODY executed only if CONDITION is nil."
  (declare (indent 1))
  `(unless ,condition (+lazy! ,@body)))

;; Adapted from: github.com/d12frosted/environment
;;;###autoload
(defmacro +hook-with-delay! (hook secs function &optional depth local)
  "Add the FUNCTION to the value of HOOK.
The FUNCTION is delayed to be evaluated in SECS once HOOK is
triggered.
DEPTH and LOCAL are passed as is to `add-hook'."
  (let* ((f-name (make-symbol (format "+%s-on-%s-delayed-%.2fs-h" (+unquote function) (+unquote hook) secs)))
         (f-doc (format "Call `%s' in %d seconds" (symbol-name (+unquote function)) secs)))
    `(eval-when-compile
       (defun ,f-name () ,f-doc
        (run-with-idle-timer ,secs nil ,function))
       (add-hook ,hook #',f-name ,depth ,local))))



;;;###autoload
(defun minemacs-run-build-functions (&optional dont-ask-p)
  "Run all build functions in `minemacs-build-functions'.

Call functions without asking when DONT-ASK-P is non-nil."
  (interactive "P")
  (dolist (fn minemacs-build-functions)
    (message "[MinEmacs]: Running `%s'" fn)
    (if dont-ask-p
        ;; Do not ask before installing
        (cl-letf (((symbol-function 'yes-or-no-p) #'always)
                  ((symbol-function 'y-or-n-p) #'always))
          (funcall-interactively fn))
      (funcall-interactively fn))))

;;;###autoload
(defun minemacs--bump-packages ()
  "Bump MinEmacs packages to the latest revisions."
  ;; Backup the current installed versions, this file can be restored if version
  ;; upgrade does break some packages.
  (message "[MinEmacs]: Creating backups for the current versions of packages")
  (let* ((backup-dir (concat minemacs-local-dir "minemacs/versions/"))
         (dest-file (concat backup-dir (format-time-string "default-%Y%m%d%H%M%S.el")))
         (src-file (concat straight-base-dir "straight/versions/default.el")))
    (unless (file-directory-p backup-dir) (mkdir backup-dir 'parents))
    (when (file-exists-p src-file)
      (message "[MinEmacs]: Creating backup from \"%s\" to \"%s\"" src-file dest-file)
      (copy-file src-file dest-file)))

  ;; Update straight recipe repositories
  (straight-pull-recipe-repositories)

  ;; Run `straight's update cycle, taking into account the explicitly pinned
  ;; packages versions.
  (message "[MinEmacs]: Pulling packages")
  (straight-x-pull-all)
  (message "[MinEmacs]: Freezing packages")
  (straight-x-freeze-versions)
  (message "[MinEmacs]: Rebuilding packages")
  (straight-rebuild-all)

  ;; Run package-specific build functions (ex: `pdf-tools-install')
  (message "[MinEmacs]: Running additional package-specific build functions")
  (minemacs-run-build-functions 'dont-ask))

;;;###autoload
(defun minemacs-bump-packages ()
  "Update MinEmacs packages to the last revisions (can cause breakages)."
  (interactive)
  (let ((default-directory minemacs-root-dir)
        (compilation-buffer-name-function (lambda (_) "" "*minemacs-bump-packages*")))
    (compile "make bump")))

;;;###autoload
(defun minemacs-restore-locked-packages (restore-from-backup)
  "Restore lockfile packages list. Takes into account the pinned ones.
When called with \\[universal-argument] or with RESTORE-FROM-BACKUP, it will
restore the lockfile from backups, not Git."
  (interactive "P")
  (let* ((lockfile (concat straight-base-dir "straight/versions/default.el"))
         (default-directory (vc-git-root lockfile))
         (backup-dir (concat minemacs-local-dir "minemacs/versions/")))
    ;; Update straight recipe repositories
    (straight-pull-recipe-repositories)
    (if (not restore-from-backup)
        (progn
          (message "[MinEmacs] Reverting file \"%s\" to the original" lockfile)
          (unless (zerop (vc-git-revert lockfile))
            ;; Signal an error when the `vc-git-revert' returns non-zero
            (user-error "[MinEmacs] An error occurred when trying to revert \"%s\"" lockfile)))
      (message "[MinEmacs] Trying to restore the lockfile from backups.")
      (if-let* ((_ (file-exists-p backup-dir))
                (backups (directory-files backup-dir nil "[^.][^.]?\\'"))
                (restore-backup-file (completing-read "Select which backup to restore: " backups))
                (last-backup (expand-file-name restore-backup-file backup-dir)))
          (if (not (file-exists-p last-backup))
              (user-error "[MinEmacs] No backup file")
            (copy-file last-backup lockfile 'overwrite-existing)
            (message "[MinEmacs] Restored the last backup from \"%s\"" restore-backup-file))))
    ;; This will ensure that the pinned lockfile is up-to-date
    (straight-x-freeze-pinned-versions)
    ;; Restore packages to the versions pinned in the lockfiles
    (when (file-exists-p (concat straight-base-dir "versions/pinned.el"))
      (message "[MinEmacs] Restoring pinned versions of packages")
      (straight-x-thaw-pinned-versions))
    (message "[MinEmacs] Restoring packages from the global lockfile versions")
    (straight-thaw-versions)
    ;; Rebuild the packages
    (message "[MinEmacs] Rebuilding packages")
    (straight-rebuild-all)
    ;; Run package-specific build functions (ex: `pdf-tools-install')
    (message "[MinEmacs] Running additional package-specific build functions")
    (minemacs-run-build-functions 'dont-ask)))

;;;###autoload
(defun minemacs-upgrade (pull-minemacs)
  "Upgrade MinEmacs and its packages to the latest pinned versions (recommended).

When PULL-MINEMACS is non-nil, run a \"git pull\" in MinEmacs' directory.

This calls `minemacs-update-restore-locked' asynchronously."
  (interactive "P")
  (let ((default-directory minemacs-root-dir)
        (compilation-buffer-name-function (lambda (_) "" "*minemacs-upgrade*"))
        (cmd (format "sh -c '%smake locked'" (if pull-minemacs "git pull && " ""))))
    (compile cmd)))

;;;###autoload
(defun +minemacs-root-dir-cleanup ()
  "Cleanup MinEmacs' root directory."
  (let ((default-directory minemacs-root-dir))
    (mapc (+apply-partially-right #'+delete-file-or-directory 'trash 'recursive)
          (directory-files minemacs-root-dir nil (rx (seq bol (or "eln-cache" "auto-save-list" "elpa") eol))))))

;;;###autoload
(defun +straight-prune-build-cache ()
  "Prune straight.el build directories for old Emacs versions."
  (let* ((default-directory (file-name-concat straight-base-dir "straight/")))
    ;; Prune the build cache and build directory.
    (straight-prune-build)
    ;; Prune old build directories
    (mapc (+apply-partially-right #'+delete-file-or-directory 'trash 'recursive)
          (seq-filter
           (lambda (name)
             (not (member name (list straight-build-dir (concat straight-build-dir "-cache.el") "versions" "repos"))))
           (directory-files default-directory nil "[^.][^.]?\\'")))))

;;;###autoload
(defun +minemacs-cleanup-emacs-directory ()
  "Cleanup unwanted files/directories from MinEmacs' directory."
  (interactive)
  (when (featurep 'native-compile)
    (+info! "Trying to clean outdated native compile cache")
    ;; Delete outdated natively compiled files when Emacs become idle
    (+shutup! (native-compile-prune-cache)))
  (+info! "Trying to clean outdated straight build cache")
  (+shutup! (+straight-prune-build-cache))
  (+info! "Trying to clean MinEmacs' root directory")
  (+shutup! (+minemacs-root-dir-cleanup)))



;;; Files, directories and IO helper functions

;;;###autoload
(defun +file-mime-type (file)
  "Get MIME type for FILE based on magic codes provided by the \"file\" command.
Return a symbol of the MIME type, ex: `text/x-lisp', `text/plain',
`application/x-object', `application/octet-stream', etc."
  (if-let ((file-cmd (executable-find "file"))
           (mime-type (shell-command-to-string (format "%s --brief --mime-type %s" file-cmd file))))
      (intern (string-trim-right mime-type))
    (error "The \"file\" command isn't installed")))

;;;###autoload
(defun +file-name-incremental (filename)
  "Return a unique file name for FILENAME.
If \"file.ext\" exists, returns \"file-0.ext\"."
  (let* ((ext (file-name-extension filename))
         (dir (file-name-directory filename))
         (file (file-name-base filename))
         (filename-regex (concat "^" file "\\(?:-\\(?1:[[:digit:]]+\\)\\)?" (if ext (concat "\\." ext) "")))
         (last-file (car (last (directory-files dir nil filename-regex))))
         (last-file-num (and last-file (string-match filename-regex last-file) (match-string 1 last-file)))
         (num (1+ (string-to-number (or last-file-num "-1")))))
    (file-name-concat dir (format "%s%s%s" file (if last-file (format "-%d" num) "") (if ext (concat "." ext) "")))))

;;;###autoload
(defun +directory-root-containing-file (files &optional start-path)
  "Return the path containing a file from FILES starting from START-PATH."
  (let ((dir (or start-path (and buffer-file-name (file-name-directory buffer-file-name)) default-directory)))
    (catch 'root
      (while dir
        (when (cl-some #'file-exists-p (mapcar (+apply-partially-right #'expand-file-name dir) (ensure-list files)))
          (throw 'root dir))
        (setq dir (file-name-parent-directory dir))))))

;;;###autoload
(defun +delete-this-file (&optional path force-p)
  "Delete PATH.

If PATH is not specified, default to the current buffer's file.

If FORCE-P, delete without confirmation."
  (interactive
   (list (buffer-file-name (buffer-base-buffer))
         current-prefix-arg))
  (let* ((path (or path (buffer-file-name (buffer-base-buffer))))
         (short-path (abbreviate-file-name path)))
    (unless (and path (file-exists-p path))
      (user-error "Buffer is not visiting any file"))
    (unless (file-exists-p path)
      (error "File doesn't exist: %s" path))
    (unless (or force-p (y-or-n-p (format "Really delete %S?" short-path)))
      (user-error "Aborted"))
    (unwind-protect
        (progn (delete-file path delete-by-moving-to-trash) t)
      (when (file-exists-p path)
        (error "Failed to delete %S" short-path)))))

;;;###autoload
(defun +delete-file-or-directory (file-or-directory &optional trash recursive)
  "Delete FILE-OR-DIRECTORY with `delete-file' or `delete-directory'.

Move to trash when TRASH is non-nil, delete directories recursively when
RECURSIVE is non-nil."
  (if (file-directory-p file-or-directory)
      (delete-directory file-or-directory recursive trash)
    (delete-file file-or-directory trash)))

;; Rewrite of: crux-delete-file-and-buffer, proposes also to delete VC
;; controlled files even when `vc-delete-file' fails (edited, conflict, ...).
;;;###autoload
(defun +delete-this-file-and-buffer (&optional filename)
  "Delete FILENAME and its associated visiting buffer."
  (interactive)
  (when-let ((filename (or filename (buffer-file-name)))
             (short-path (abbreviate-file-name filename)))
    (if (vc-backend filename)
        (or (ignore-errors (vc-delete-file (buffer-file-name)))
            (+delete-this-file filename)
            (kill-buffer))
      (when (y-or-n-p (format "Are you sure you want to delete %s? " short-path))
        (delete-file filename delete-by-moving-to-trash)
        (message "Deleted file %s" short-path)
        (kill-buffer)))))

;;;###autoload
(defun +tramp-sudo-file-path (file)
  "Construct a Tramp sudo path to FILE. Works for both local and remote files."
  (tramp-make-tramp-file-name "sudo" tramp-root-id-string nil (or (file-remote-p file 'host) "localhost") nil file))

;;;###autoload
(defun +sudo-find-file (file)
  "Open FILE as root."
  (interactive "FOpen file as root: ")
  (find-file (+tramp-sudo-file-path file)))

;;;###autoload
(defun +sudo-this-file ()
  "Open the current file as root."
  (interactive)
  (if-let ((this-file (or buffer-file-name
                          (when (derived-mode-p 'dired-mode 'wdired-mode)
                            default-directory))))
      (find-file (+tramp-sudo-file-path this-file))
    (user-error "Current buffer not bound to a file")))

;;;###autoload
(defun +sudo-save-buffer ()
  "Save this buffer as root. Save as new file name if called with prefix."
  (interactive)
  (if-let ((file (or (and (or (not buffer-file-name) current-prefix-arg)
                          (read-file-name "Save as root to: "))
                     buffer-file-name))
           (file (+tramp-sudo-file-path (expand-file-name file)))
           (dest-buffer (find-file-noselect file))
           (src-buffer (current-buffer)))
      (progn
        (copy-to-buffer dest-buffer (point-min) (point-max))
        (unwind-protect (with-current-buffer dest-buffer (save-buffer))
          (unless (eq src-buffer dest-buffer) (kill-buffer dest-buffer))
          (with-current-buffer src-buffer (revert-buffer t t))))
    (user-error "Unable to open %S" (abbreviate-file-name file))))

;;;###autoload
(defun +yank-this-file-name ()
  "Yank the file name of this buffer."
  (interactive)
  (if-let ((file (buffer-file-name)))
      (with-temp-buffer
        (insert file)
        (kill-ring-save (point-min) (point-max)))
    (user-error "This buffer isn't bound to a file")))

;;;###autoload
(defun +clean-file-name (filename &optional downcase-p)
  "Clean FILENAME, optionally convert to DOWNCASE-P."
  ;; Clean slashes, backslashes, ":", ";", spaces, and tabs
  (replace-regexp-in-string
   "[:;\t\n\r /\\_]+" "-"
   (replace-regexp-in-string
    "[‘’‚“”„\"`'()&]+" ""
    (if downcase-p (downcase filename) filename))))



;;; Exporter and converters

(defcustom +html2pdf-default-backend 'wkhtmltopdf
  "The default backend to convert HTML files to PDFs in `+html2pdf'."
  :group 'minemacs-utils
  :type '(choice
          (const wkhtmltopdf)
          (const htmldoc)
          (const weasyprint)
          (const pandoc+context)
          (const pandoc)))

(defcustom +html2pdf-backend-config-file nil
  "A config file to use with the backend tool (pandoc, weasyprint, ...)."
  :group 'minemacs-utils
  :type 'file)

;;;###autoload
(defun +html2pdf (infile outfile &optional backend)
  "Convert HTML file INFILE to PDF and save it to OUTFILE.
When BACKEND is provided, the corresponding program is used, otherwise, the
value of `+html2pdf-default-backend' is used."
  (if-let ((default-directory (file-name-directory infile))
           (backend (or backend +html2pdf-default-backend))
           (backend-command
            (pcase backend
              ('wkhtmltopdf
               (list "wkhtmltopdf"
                     "--images" "--disable-javascript" "--enable-local-file-access"
                     "--encoding" "utf-8"
                     infile outfile))
              ('htmldoc
               (list "htmldoc"
                     "--charset" "utf-8"
                     "--bodyfont" "sans" "--textfont" "sans" "--headfootfont" "sans"
                     "--top" "50#mm" "--bottom" "50#mm" "--right" "50#mm" "--left" "50#mm"
                     "--fontsize" "10"
                     "--size" "a4"
                     "--continuous"
                     "--outfile" outfile infile))
              ('weasyprint
               (list "weasyprint"
                     "--encoding" "utf-8"
                     "--stylesheet" (or +html2pdf-backend-config-file
                                        (expand-file-name "templates/+html2pdf/weasyprint-pdf.css" minemacs-assets-dir))
                     infile outfile))
              ('pandoc+context
               (list "pandoc"
                     "--pdf-engine=context"
                     "--variable" "fontsize=10pt"
                     "--variable" "linkstyle=slanted"
                     "-o" outfile infile))
              ('pandoc
               (list "pandoc"
                     "--defaults" (or +html2pdf-backend-config-file
                                      (expand-file-name "templates/+html2pdf/pandoc.yaml" minemacs-assets-dir))
                     "-o" outfile infile)))))
      (apply #'call-process (append (list (car backend-command) nil nil nil) (cdr backend-command)))
    (user-error "Backend \"%s\" not available" backend)))

;;;###autoload
(defun +txt2html (infile outfile &optional mail-mode-p)
  "Convert plain-text file INFILE to HTML and save it to OUTFILE.
When MAIL-MODE-P is non-nil, --mailmode is passed to \"txt2html\"."
  (apply #'call-process (append '("txt2html" nil nil nil "-8")
                                (when mail-mode-p '("--mailmode"))
                                (list "--outfile" outfile infile))))

(defvar +save-as-pdf-filename nil
  "File name to use, if non-nil, for the output file.")

;;;###autoload
(defun +save-as-pdf (infile &optional mail-mode-p)
  "Save URL as PDF.
This function's signature is compatible with `browse-url-browser-function'
so it can be used to save HTML pages or emails to PDF.
When MAIL-MODE-P is non-nil, treat INFILE as a mail."
  (let* ((infile (string-trim-left infile "file://"))
         (outfile (+file-name-incremental
                   (or +save-as-pdf-filename
                       (expand-file-name
                        (file-name-with-extension (file-name-base infile) ".pdf")
                        (file-name-directory infile))))))
    (if (zerop
         ;; For HTML files (with extension ".html" or ".htm"), just call `+html2pdf'
         (if (string-match-p "^html?$" (file-name-extension infile))
             (+html2pdf infile outfile)
           ;; For non-HTML (plain-text) files, convert them to HTML then call `+html2pdf'
           (let ((tmp-html (make-temp-file "txt2html-" nil ".html")))
             (+txt2html infile tmp-html mail-mode-p)
             (+html2pdf tmp-html outfile))))
        (message "Exported PDF to %S"
                 (truncate-string-to-width (abbreviate-file-name outfile) (/ (window-width (minibuffer-window)) 2) nil nil t))
      (user-error (if (file-exists-p outfile) "PDF created but with some errors!" "An error occurred, cannot create the PDF!")))))

(defcustom +single-file-executable "single-file"
  "The executable for \"single-file\" which is used archive HTML pages."
  :type 'string
  :group 'minemacs-utils)

;;;###autoload
(defun +single-file (url out-file)
  "Save URL into OUT-FILE as a standalone HTML file."
  (interactive
   (let ((url (or (thing-at-point 'url) (read-string "URL to save: "))))
     (list url (read-file-name "Save to: " nil nil nil (url-filename (url-generic-parse-url url))))))
  (if (executable-find +single-file-executable)
      (make-process
       :name "single-file-cli"
       :buffer "*single-file*"
       :command (list +single-file-executable
                      "--browser-executable-path" browse-url-chromium-program
                      url (expand-file-name out-file)))
    (user-error "Please set `+single-file-executable' accordingly")))



;;; Serial port

(autoload 'term-send-string "term")
(defcustom +serial-port "/dev/ttyUSB0"
  "The default port (device) to use."
  :group 'minemacs-utils
  :type 'file)

(defcustom +serial-baudrate 115200
  "The default baudrate to use."
  :group 'minemacs-utils
  :type 'natnum)

(defcustom +serial-first-commands nil
  "A list of commands to run in the serial terminal after creation."
  :group 'minemacs-utils
  :type '(repeat string))

(defvar +serial-buffer nil)
(defvar +serial-process nil)

;;;###autoload
(defun +serial-running-p ()
  "Is there a serial port terminal running?"
  (buffer-live-p +serial-buffer) (process-live-p +serial-process))

(defun +serial--run-commands (port baud &rest commands)
  "Run COMMANDS on a device via serial communication.

Connect at PORT with baudrate BAUD."
  (let ((commands (ensure-list commands)))
    (unless (+serial-running-p)
      (setq +serial-buffer (serial-term port baud)
            +serial-process (get-buffer-process +serial-buffer)
            commands (append +serial-first-commands commands)))
    (if (+serial-running-p)
        (term-send-string +serial-process (string-join (append commands '("\n")) "\n"))
      (user-error "Unable to communicate with the serial terminal process"))))

;;;###autoload
(defun +serial-run-commands (commands &optional port baud)
  "Run COMMANDS on a device via serial communication.

If PORT or BAUD are nil, use values from `+serial-port' and `+serial-baudrate'."
  (interactive (list (read-shell-command (format "Run command via serial port: "))))
  (let ((port (or port +serial-port))
        (baud (or baud +serial-baudrate)))
    (+log! "Dev %s@%d: running commands %S" port baud commands)
    (apply #'+serial--run-commands (append (list port baud) (ensure-list commands)))))



;;; Networking

(defvar +net-default-device "wlan0")

;;;###autoload
(defun +net-get-ip-address (&optional dev)
  "Get the IP-address for device DEV (default: eth0) of the current machine."
  (let ((dev (or dev +net-default-device)))
    (format-network-address (car (network-interface-info dev)) t)))



;;; Github

;;;###autoload
(defun +github-latest-release (repo &optional fallback-release)
  "Get the latest release of REPO. Strips the \"v\" at left.

Fallback to FALLBACK-RELEASE when it can't get the last one."
  (if-let ((latest
            (ignore-errors
              (with-temp-buffer
                (url-insert-file-contents
                 (format "https://api.github.com/repos/%s/releases/latest" repo))
                (json-parse-buffer :object-type 'plist)))))
      (string-trim-left
       (car (last (split-string (plist-get latest :html_url) "/")))
       "v")
    fallback-release))



;;; Directory local tweaks & hacks

;;;###autoload
(defun +dir-locals-reload-for-this-buffer ()
  "Reload directory-local for the current buffer."
  (interactive)
  (let ((enable-local-variables :all))
    (hack-dir-local-variables-non-file-buffer)
    (+info! "Reloaded directory-local variables for buffer %s"
            (buffer-name (current-buffer)))))

;;;###autoload
(defun +dir-locals-reload-for-all-buffers-in-this-directory ()
  "Reload dir-locals for all buffers in the current `default-directory'."
  (interactive)
  (let ((dir default-directory))
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (when (equal default-directory dir)
          (+dir-locals-reload-for-this-buffer))))))

(defun +dir-locals--autoreload-h ()
  "Is it relevant to auto reload dir-locals for his buffer."
  (when (and (buffer-file-name)
             (equal dir-locals-file (file-name-nondirectory (buffer-file-name))))
    (+dir-locals-reload-for-all-buffers-in-this-directory)
    (message "Reloaded directory-local variables defined in %s." dir-locals-file)))

(defvar +dir-locals--autoreload-p nil)

;;;###autoload
(defun +dir-locals-toggle-autoreload (&optional enable)
  "Toggle autoloading dir-local variables after editing the \".dir-locals\" file.

If ENABLE is non-nil, force enabling autoreloading."
  (interactive)
  (if (or enable (not +dir-locals--autoreload-p))
      (progn
        (remove-hook 'after-save-hook #'+dir-locals--autoreload-h)
        (setq +dir-locals--autoreload-p nil)
        (message "Disabled auto-reloading directory-locals."))
    (add-hook 'after-save-hook #'+dir-locals--autoreload-h)
    (setq +dir-locals--autoreload-p t)
    (message "Enabled auto-reloading directory-locals.")))

;;;###autoload
(defun +dir-locals-open-or-create ()
  "Open or create the dir-locals.el for the current project."
  (interactive)
  (let* ((file-name (buffer-file-name))
         (base-dir (car (ensure-list (dir-locals-find-file file-name)))))
    (find-file
     (cond (base-dir (expand-file-name dir-locals-file base-dir))
           ((project-current) (expand-file-name dir-locals-file (project-root (project-current))))
           ((vc-root-dir) (expand-file-name dir-locals-file (vc-root-dir)))
           (t (expand-file-name dir-locals-file (file-name-directory file-name)))))))



;;; Misc Emacs tweaks

;; Adapted from: rougier/nano-emacs
;;;###autoload
(defun +what-faces (pos)
  "Get the font faces at POS."
  (interactive "d")
  (let ((faces (remq nil
                     (list
                      (get-char-property pos 'read-face-name)
                      (get-char-property pos 'face)
                      (plist-get (text-properties-at pos) 'face)))))
    (message "Faces: %s" faces)))

(defcustom +screenshot-delay 5
  "A delay to wait before taking the screenshot.
Applicable only when calling `+screenshot-svg' with a prefix."
  :group 'minemacs-utils
  :type 'number)

;; Inspired by: reddit.com/r/emacs/comments/idz35e/comment/g2c2c6y
;;;###autoload
(defun +screenshot-svg (outfile)
  "Save a screenshot of the current frame as an SVG image to OUTFILE.

If launched with a prefix or universal argument, it waits for a moment (defined
by `+screenshot-delay') before taking the screenshot."
  (interactive "FSave to file: ")
  (let ((outfile (file-name-with-extension outfile "svg")))
    (if current-prefix-arg
        (run-with-timer +screenshot-delay nil (apply-partially #'+screenshot-svg--take-screenshot outfile))
      (+screenshot-svg--take-screenshot outfile))))

(defun +screenshot-svg--take-screenshot (&optional outfile)
  "Save a SVG screenshot of the current frame to OUTFILE."
  (let* ((tmp-file (make-temp-file "emacs-" nil ".svg"))
         (data (x-export-frames nil 'svg)))
    (with-temp-file tmp-file (insert data))
    (when (stringp outfile) (copy-file tmp-file outfile))
    (message "Screenshot saved to %s" (or outfile tmp-file))))

;; Kill the minibuffer even when in another windown.
;; Adapted from: trey-jackson.blogspot.com/2010/04/emacs-tip-36-abort-minibuffer-when.html
;;;###autoload
(defun +minibuffer-kill-minibuffer ()
  "Kill the minibuffer when switching to window with mouse."
  (interactive)
  (when (and (>= (recursion-depth) 1) (active-minibuffer-window))
    (abort-recursive-edit)))

;;;###autoload
(defun +region-or-thing-at-point ()
  "Return the region or the thing at point."
  (when-let ((thing (ignore-errors
                      (or (prog1 (thing-at-point 'region t)
                            (deactivate-mark))
                          (cl-some (+apply-partially-right #'thing-at-point t)
                                   '(symbol email number string word))))))
    ;; If the matching thing has multi-lines, join them
    (string-join (string-lines thing))))

(defvar +webjump-read-string-initial-query nil)

(defun +webjump-read-string-with-initial-query (prompt)
  (let ((input (read-string (concat prompt ": ") +webjump-read-string-initial-query)))
    (unless (webjump-null-or-blank-string-p input) input)))

;;;###autoload
(defun +webjump ()
  "Like `webjump', with initial query filled from `+region-org-thing-at-point'."
  (interactive)
  (require 'webjump)
  (let ((+webjump-read-string-initial-query (+region-or-thing-at-point)))
    (cl-letf (((symbol-function 'webjump-read-string) #'+webjump-read-string-with-initial-query))
      (webjump))))



;;; Eglot extras

;; From: github.com/MaskRay/ccls/wiki/eglot#misc
;;;###autoload
(defun +eglot-ccls-inheritance-hierarchy (&optional derived)
  "Show inheritance hierarchy for the thing at point.
If DERIVED is non-nil (interactively, with prefix argument), show
the children of class at point."
  (interactive "P")
  (if-let* ((res (jsonrpc-request
                  (eglot--current-server-or-lose)
                  :$ccls/inheritance
                  (append (eglot--TextDocumentPositionParams)
                          `(:derived ,(if derived t :json-false))
                          '(:levels 100) '(:hierarchy t))))
            (tree (list (cons 0 res))))
      (with-help-window "*ccls inheritance*"
        (with-current-buffer standard-output
          (while tree
            (pcase-let ((`(,depth . ,node) (pop tree)))
              (cl-destructuring-bind (&key uri range) (plist-get node :location)
                (insert (make-string depth ?\ ) (plist-get node :name) "\n")
                (make-text-button
                 (+ (pos-bol 0) depth) (pos-eol 0)
                 'action (lambda (_arg)
                           (interactive)
                           (find-file (eglot--uri-to-path uri))
                           (goto-char (car (eglot--range-region range)))))
                (cl-loop for child across (plist-get node :children)
                         do (push (cons (1+ depth) child) tree)))))))
    (eglot--error "Hierarchy unavailable")))

;; Inspired by Doom Emacs
(defvar +eglot--default-read-process-output-max nil)
(defvar +eglot--default-gcmh-high-cons-threshold nil)
(defvar +eglot--optimization-active-p nil)

;;;###autoload
(define-minor-mode +eglot-optimization-mode
  "Deploys universal GC and IPC optimizations for `eglot'."
  :global t
  :init-value nil
  (if (not +eglot-optimization-mode)
      (setq-default read-process-output-max +eglot--default-read-process-output-max
                    gcmh-high-cons-threshold +eglot--default-gcmh-high-cons-threshold
                    +eglot--optimization-active-p nil)
    ;; Only apply these settings once!
    (unless +eglot--optimization-active-p
      (setq +eglot--default-read-process-output-max (default-value 'read-process-output-max)
            +eglot--default-gcmh-high-cons-threshold (default-value 'gcmh-high-cons-threshold))
      (setq-default read-process-output-max (* 1024 1024)
                    gcmh-high-cons-threshold (* 2 +eglot--default-gcmh-high-cons-threshold))
      (gcmh-set-high-threshold)
      (setq +eglot--optimization-active-p t))))

;; From: https://github.com/doomemacs/doomemacs/blob/master/modules/tools/lsp/autoload/eglot.el
;; HACK: Eglot removed `eglot-help-at-point' in joaotavora/eglot@a044dec for a
;; more problematic approach of deferred to eldoc. Here, I've restored it.
;; This handler try to open documentation in a separate window (so it can be
;; copied or kept open), but doing so with an eldoc buffer is difficult because
;; a) its contents are generated asynchronously, making them tough to scrape,
;; and b) their contents change frequently (every time you move your cursor).
(defvar +eglot--help-buffer nil)

;;;###autoload
(defun +eglot-help-at-point ()
  "Request documentation for the thing at point."
  (interactive)
  (eglot--dbind ((Hover) contents range)
      (jsonrpc-request (eglot--current-server-or-lose) :textDocument/hover (eglot--TextDocumentPositionParams))
    (let ((blurb (and (not (seq-empty-p contents)) (eglot--hover-info contents range)))
          (hint (thing-at-point 'symbol)))
      (if blurb
          (with-current-buffer (or (and (buffer-live-p +eglot--help-buffer) +eglot--help-buffer)
                                   (setq +eglot--help-buffer (generate-new-buffer "*eglot-help*")))
            (with-help-window (current-buffer)
              (rename-buffer (format "*eglot-help for %s*" hint))
              (with-current-buffer standard-output (insert blurb))
              (setq-local nobreak-char-display nil)))
        (display-local-help)))))



;;; Binary files tweaks

;;;###autoload
(defun +binary-objdump-p (filename)
  "Can FILENAME be recognized by \"objdump\"."
  (when-let* ((file (and filename (file-truename filename))))
    (and +binary-objdump-executable
         (executable-find +binary-objdump-executable)
         (not (file-remote-p file))
         (file-exists-p file)
         (not (file-directory-p file))
         (not (zerop (file-attribute-size (file-attributes file))))
         (not (string-match-p "file format not recognized"
                              (shell-command-to-string
                               (format "%s --file-headers %s"
                                       +binary-objdump-executable
                                       (shell-quote-argument file))))))))

;;;###autoload
(defun +binary-objdump-buffer-p (&optional buffer)
  "Can the BUFFER be viewed as a disassembled code with objdump."
  (and +binary-objdump-enable (+binary-objdump-p (buffer-file-name buffer))))

;; A predicate for detecting binary files. Inspired by:
;; emacs.stackexchange.com/q/10277/37002)
;;;###autoload
(defun +binary-buffer-p (&optional buffer)
  "Return whether BUFFER or the current buffer is binary.

A binary buffer is defined as containing at least one null byte.

Returns either nil, or the position of the first null byte."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (search-forward (string ?\x00) nil t 1))))

;;;###autoload
(defun +binary-file-p (file &optional chunk)
  "Is FILE a binary?

This checks the first CHUNK of bytes, defaults to 1024."
  (with-temp-buffer
    (insert-file-contents-literally file nil 0 (or chunk 1024))
    (goto-char (point-min))
    (search-forward (string ?\x00) nil t 1)))

;;;###autoload
(defun +binary-hexl-buffer-p (&optional buffer)
  "Does BUFFER (defaults to the current buffer) should be viewed using `hexl-mode'."
  (and +binary-hexl-enable
       (+binary-buffer-p buffer)
       ;; Executables are viewed with objdump mode
       (not (+binary-objdump-buffer-p buffer))))

;;;###autoload
(define-derived-mode objdump-disassemble-mode
  special-mode "Objdump Mode"
  "Major mode for viewing executable files disassembled using objdump."
  (if-let* ((file (buffer-file-name))
            (objdump-file (+binary-objdump-p file)))
      (let ((buffer-read-only nil))
        (message "Disassembling %S using objdump." (file-name-nondirectory file))
        (erase-buffer)
        (set-visited-file-name (file-name-with-extension file "_dias.objdump"))
        (call-process "objdump" nil (current-buffer) nil "-d" file)
        (goto-char (point-min))
        (buffer-disable-undo)
        (set-buffer-modified-p nil)
        (view-mode 1)
        (read-only-mode 1)
        ;; Apply syntax highlighting from `asm-mode'
        (require 'asm-mode)
        (set-syntax-table (make-syntax-table asm-mode-syntax-table))
        (modify-syntax-entry ?# "< b") ; use # for comments
        (setq-local font-lock-defaults '(asm-font-lock-keywords)))
    (user-error "Objdump can not be used with this buffer")))

;;;###autoload
(defun +binary-hexl-mode-maybe ()
  "Activate `hexl-mode' if relevant for the current buffer."
  (interactive)
  (when (and (not (eq major-mode 'hexl-mode)) (+binary-hexl-buffer-p))
    (hexl-mode 1)))



;;; Buffer related tweaks

;; From: emacswiki.org/emacs/download/misc-cmds.el
;; Candidate as a replacement for `kill-buffer', at least when used interactively.
;; For example: (define-key global-map [remap kill-buffer] 'kill-buffer-and-its-windows)
;; We cannot just redefine `kill-buffer', because some programs count on a
;; specific other buffer taking the place of the killed buffer (in the window).
;;;###autoload
(defun +kill-buffer-and-its-windows (buffer &optional msgp)
  "Kill BUFFER and delete its windows.  Default is `current-buffer'.
BUFFER may be either a buffer or its name (a string)."
  (interactive (list (read-buffer "Kill buffer: " (current-buffer) 'existing) 'MSGP))
  (setq buffer (get-buffer buffer))
  (if (buffer-live-p buffer) ; Kill live buffer only.
      (let ((wins (get-buffer-window-list buffer nil t))) ; On all frames.
        (when (kill-buffer buffer) ; Only delete windows if buffer killed.
          (dolist (win wins) ; (User might keep buffer if modified.)
            (when (window-live-p win)
              ;; Ignore error, in particular,
              ;; "Attempt to delete the sole visible or iconified frame".
              (condition-case nil (delete-window win) (error nil))))))
    (when msgp (user-error "Cannot kill buffer.  Not a live buffer: `%s'" buffer))))

;; From: emacswiki.org/emacs/download/misc-cmds.el
;;;###autoload
(defun +region-to-buffer (start end buffer arg)
  "Copy region to BUFFER: At beginning (prefix >= 0), end (< 0), or replace.
START and END are the region boundaries.
BUFFER is a buffer or its name (a string).
With prefix ARG >= 0: `append-to-buffer':
  Append contents of region to end of BUFFER.
  (Point is moved to end of BUFFER first.)
With prefix ARG < 0:  `prepend-to-buffer':
  Prepend contents of region to beginning of BUFFER.
  (Point is moved to beginning of BUFFER first.)
With no prefix ARG (nil): `copy-to-buffer'.
  Write region to BUFFER, replacing any previous contents."
  (interactive
   (let ((arg (and current-prefix-arg (prefix-numeric-value current-prefix-arg))))
     (list (region-beginning)
           (region-end)
           (read-buffer
            (concat (if arg
                        (if (natnump arg) "Append" "Prepend")
                      "Write")
                    " region to buffer: ")
            (if (fboundp 'another-buffer) ; Defined in `misc-fns.el'.
                (another-buffer nil t)
              (other-buffer (current-buffer))))
           arg)))
  (setq buffer (get-buffer-create buffer)) ; Convert to buffer.
  (when (eq buffer (current-buffer)) (error "Cannot copy region to its own buffer"))
  (cond ((natnump arg)
         (with-current-buffer buffer (goto-char (point-max)))
         (append-to-buffer buffer start end))
        (arg
         (with-current-buffer buffer (goto-char (point-min)))
         (prepend-to-buffer buffer start end))
        (t (copy-to-buffer buffer start end))))

;; From: emacswiki.org/emacs/download/misc-cmds.el
;;;###autoload
(defun +region-to-file (start end filename arg)
  "With prefix arg, this is `append-to-file'.  Without, it is `write-region'.
START and END are the region boundaries.
Prefix ARG non-nil means append region to end of file FILENAME.
Prefix ARG nil means write region to FILENAME, replacing contents."
  (interactive
   (list (region-beginning)
         (region-end)
         (read-file-name (concat (if current-prefix-arg "Append" "Write")
                                 " region to file: "))
         current-prefix-arg))
  (let* ((curr-file (buffer-file-name))
         (same-file-p (and curr-file (string= curr-file filename))))
    (cond ((or (not same-file-p)
               (progn (when (fboundp 'flash-ding) (flash-ding))
                      (yes-or-no-p
                       (format
                        "Do you really want to REPLACE the contents of `%s' by just the REGION? "
                        (file-name-nondirectory curr-file)))))
           (write-region start end filename arg)
           (when same-file-p (revert-buffer t t)))
          (t (message "OK.  Not written.")))))

;;;###autoload
(defun +kill-some-buffers (&optional list)
  "Kill some buffers.  Asks the user whether to kill the modified ones.
Non-interactively, if optional argument LIST is non-nil, it
specifies the list of buffers to kill, asking for approval for each one.
See `kill-some-buffers'."
  (interactive)
  ;; Replace the `kill-buffer-ask' locally (used by `kill-some-buffers')
  ;; with our function which don't ask about unmodified buffers.
  (cl-letf (((symbol-function 'kill-buffer-ask) #'+kill-buffer-ask-if-modified))
    (kill-some-buffers list)))

(defcustom +kill-buffer-no-ask-list
  (list (or (bound-and-true-p messages-buffer-name) "*Messages*") "*Warnings*")
  "A list of buffer names to be killed without confirmation."
  :group 'minemacs-buffer
  :type '(repeat string))

(with-eval-after-load 'comp
  (when (featurep 'native-compile)
    (setq
     +kill-buffer-no-ask-list
     (append +kill-buffer-no-ask-list
             (ensure-list (bound-and-true-p comp-async-buffer-name))
             (ensure-list (bound-and-true-p comp-log-buffer-name))))))

;;;###autoload
(defun +kill-buffer-ask-if-modified (buffer)
  "Like `kill-buffer-ask', but kills BUFFER without confirmation when unmodified.
Kill without asking for buffer names in `+kill-buffer-no-ask-list'."
  (when (or (not (buffer-modified-p buffer))
            (member (buffer-name buffer) +kill-buffer-no-ask-list)
            (yes-or-no-p (format "Buffer %s HAS BEEN MODIFIED.  Kill? "
                                 (buffer-name buffer))))
    (kill-buffer buffer)))

;; From: emacswiki.org/emacs/download/misc-cmds.el
;;;###autoload
(defun +delete-extra-windows-for-buffer ()
  "Delete all other windows showing the selected window's buffer."
  (interactive)
  (let* ((selwin (selected-window))
         (buf (window-buffer selwin)))
    (walk-windows
     (lambda (ww)
       (unless (eq ww selwin)
         (when (eq (window-buffer ww) buf)
           (delete-window ww))))
     'NO-MINI 'THIS-FRAME)))

;; From: emacswiki.org/emacs/download/misc-cmds.el
;;;###autoload
(defun +delete-window-maybe-kill-buffer ()
  "Delete selected window.
If no other window shows its buffer, kill the buffer too."
  (interactive)
  (let* ((selwin (selected-window))
         (buf (window-buffer selwin)))
    (delete-window selwin)
    (unless (get-buffer-window buf 'visible) (kill-buffer buf))))

;;;###autoload
(defun +replace-in-buffer (old new)
  "Replace OLD with NEW in the current buffer."
  (save-excursion
    (goto-char (point-min))
    (let ((case-fold-search nil)
          (matches 0))
      (while (re-search-forward old nil t)
        (replace-match new)
        (cl-incf matches))
      matches)))

;;;###autoload
(defun +clear-frenchy-ponctuations ()
  "Replace french ponctuations (like unsectable space) by regular ones."
  (interactive)
  (let ((chars
         '(("[\u00a0\u200b]" . "") ;; Non-breaking and zero-width spaces
           ;; Special spaces and quads
           ("[\u2000-\u200A\u202F\u205F\u3000]" . " ")
           ("[‘’‚’]" . "'")
           ("[“”„”«»]" . "\"")))
        (matches 0))
    (dolist (pair chars)
      (cl-incf matches (+replace-in-buffer (car pair) (cdr pair))))
    (message "Replaced %d match%s." matches (if (> matches 1) "es" ""))))

;;;###autoload
(defun +kill-region-as-paragraph ()
  "Kill (copy) region as one paragraph.
This command removes new line characters between lines."
  (interactive)
  (when (use-region-p)
    (let ((text (buffer-substring-no-properties (region-beginning) (region-end))))
      (with-temp-buffer
        (insert text)
        (goto-char (point-min))
        (let ((case-fold-search nil))
          (while (re-search-forward "\n[^\n]" nil t)
            (replace-region-contents
             (- (point) 2) (- (point) 1)
             (lambda (&optional a b) " ")))
          (kill-new (buffer-string)))))
    (deactivate-mark)))

;;;###autoload
(defun +first-line-empty-p ()
  "Return t when the first line of the buffer is empty."
  (save-excursion (goto-char (point-min))
                  (and (bolp) (eolp))))



;;; Project tweaks

;;;###autoload
(defun +project-add-project (dir &optional dont-ask)
  "Switch to another project at DIR.
When DIR is not detected as a project, ask to force it to be by adding a
\".project.el\" file. When DONT-ASK is non-nil, create the file without asking."
  (interactive (list (project-prompt-project-dir)))
  (project-switch-project dir)
  (when (and (not (project-current))
             (or dont-ask
                 (yes-or-no-p "Directory not detected as a project, add \".project.el\"? ")))
    (with-temp-buffer
      (write-file (expand-file-name ".project.el" dir)))))

;;;###autoload
(defun +project-forget-zombie-projects ()
  "Forget all known projects that don't exist any more.

Like `project-forget-zombie-projects', but handles remote projects differently,
it forget them only when we are sure they don't exist."
  (interactive)
  (dolist (proj (project-known-project-roots))
    (unless (or (and (file-remote-p proj nil t) (file-readable-p proj)) ; Connected remote + existent project
                (file-remote-p proj) ; Non connected remote project
                (file-exists-p proj)) ; Existent local project
      (project-forget-project proj))))

;;;###autoload
(defun +project-gdb ()
  "Invoke `gdb' in the project's root."
  (interactive)
  (let ((default-directory (project-root (project-current t))))
    (call-interactively #'gdb)))

;;;###autoload
(defun +project-list-cleanup ()
  "Forget all duplicate known projects (/home/user/proj, ~/proj)."
  (interactive)
  (let* ((projs (mapcar #'expand-file-name (project-known-project-roots)))
         (projs-dups (cl-set-difference projs (cl-remove-duplicates projs :test #'string=))))
    (mapc #'project-forget-project projs-dups)
    (project-forget-zombie-projects)
    (dolist (proj projs)
      (let ((proj-abbrev (abbreviate-file-name proj)))
        (unless (string= proj proj-abbrev)
          (project-forget-project proj)
          (project-remember-projects-under proj-abbrev))))))



;;; Systemd helpers

;;;###autoload
(defun +systemd-running-p (service)
  "Check if the systemd SERVICE is running."
  (zerop (call-process "systemctl" nil nil nil "--user" "is-active" "--quiet" service ".service")))

;;;###autoload
(defun +systemd-command (service command &optional pre-fn post-fn)
  "Call systemd with COMMAND and SERVICE."
  (when pre-fn (funcall pre-fn))
  (let ((success (zerop (call-process "systemctl" nil nil nil "--user" command service ".service"))))
    (unless success
      (user-error "[systemd]: Failed on calling '%s' on service %s.service" command service))
    (when post-fn (funcall post-fn success))
    success))

;;;###autoload
(defun +systemd-start (service &optional pre-fn post-fn)
  "Start systemd SERVICE. Optionally run PRE-FN and POST-FN."
  (+systemd-command service "start" pre-fn post-fn))

;;;###autoload
(defun +systemd-stop (service &optional pre-fn post-fn)
  "Stops the systemd SERVICE. Optionally run PRE-FN and POST-FN."
  (+systemd-command service "stop" pre-fn post-fn))



;;;###autoload
(defun +list-external-dependencies ()
  "Show the list of declared external dependencies."
  (interactive)
  (require 'me-external-tools)
  (with-current-buffer (get-buffer-create "*external-dependencies*")
    (read-only-mode -1)
    (delete-region (point-min) (point-max))
    (insert "# External Tools
To get the maximum out of this configuration, you would need to install some
external tools, either in your development machine, docker, remote host, etc.
The presence of these programs isn't mandatory, however, for better experience,
you might need install some of these tools.\n\n")
    (let ((counter 0))
      (dolist (dep minemacs-external-dependencies)
        (insert (format "%d. [%s](%s) - %s\n"
                        (cl-incf counter)
                        (string-join (mapcar (apply-partially #'format "`%s`")
                                             (ensure-list (plist-get dep :tool)))
                                     ", ")
                        (plist-get dep :link)
                        (plist-get dep :desc)))))
    (markdown-mode)
    (read-only-mode 1)
    (pop-to-buffer (current-buffer))))




(provide 'me-lib-extra)

;;; me-lib-extra.el ends here
