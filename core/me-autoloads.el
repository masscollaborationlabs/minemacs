;;; me-autoloads.el --- automatically extracted autoloads (do not edit)   -*- lexical-binding: t -*-
;; Generated by the `loaddefs-generate' function.

;; This file is part of GNU Emacs.

;;; Code:



;;; Generated autoloads from autoloads/me-core.el

(autoload '+log! "autoloads/me-core" "\
Log MSG and VARS using `message' when `minemacs-verbose' is non-nil.

(fn MSG &rest VARS)" nil t)
(autoload '+info! "autoloads/me-core" "\
Log info MSG and VARS using `message'.

(fn MSG &rest VARS)" nil t)
(autoload '+reset-sym "autoloads/me-core" "\
Reset SYM to its standard value.

(fn SYM)")
(autoload '+with-shutup! "autoloads/me-core" "\
Suppress new messages temporarily in the echo area and the `*Messages*' buffer while BODY is evaluated.

(fn &rest BODY)" nil t)
(autoload '+reset-var! "autoloads/me-core" "\
Reset VAR to its standard value.

(fn VAR)" nil t)
(autoload '+cmdfy! "autoloads/me-core" "\
Convert BODY to an interactive command.

(fn BODY)" nil t)
(autoload '+set-fonts "autoloads/me-core" nil t)
(autoload '+plist-keys "autoloads/me-core" "\
Return the keys of PLIST.

(fn PLIST)")
(autoload '+serialize-sym "autoloads/me-core" "\
Serialize SYM to DIR.
If FILENAME-FORMAT is non-nil, use it to format the file name (ex. \"file-%s.el\").
Return the written file name, or nil if SYM is not bound.

(fn SYM DIR &optional FILENAME-FORMAT)")
(autoload '+deserialize-sym "autoloads/me-core" "\
Deserialize SYM from DIR, if MUTATE is non-nil, assign the object to SYM.
If FILENAME-FORMAT is non-nil, use it to format the file name (ex. \"file-%s.el\").
Return the deserialized object, or nil if the SYM.el file dont exist.

(fn SYM DIR &optional MUTATE FILENAME-FORMAT)")
(autoload '+check-dependencies "autoloads/me-core" "\
Check for MinEmacs dependencies." t)
(autoload '+eval-when-idle "autoloads/me-core" "\
Queue FNS to be processed when Emacs becomes idle.

(fn &rest FNS)")
(autoload '+eval-when-idle! "autoloads/me-core" "\
Push BODY to be processed when Emacs becomes idle.

(fn &rest BODY)" nil t)
(autoload '+compile-functs "autoloads/me-core" "\
Queue FNS to be byte/natively-compiled after a brief delay.

(fn &rest FNS)")
(autoload '+env-save "autoloads/me-core" nil t)
(autoload '+env-load "autoloads/me-core" nil t)
(autoload 'minemacs-update "autoloads/me-core" nil t)
(register-definition-prefixes "autoloads/me-core" '("me--eval-when-idle-task"))


;;; Generated autoloads from ../modules/autoloads/me-ecryptfs.el

(autoload 'ecryptfs-mount-private "../modules/autoloads/me-ecryptfs" nil t)
(autoload 'ecryptfs-umount-private "../modules/autoloads/me-ecryptfs" nil t)
(register-definition-prefixes "../modules/autoloads/me-ecryptfs" '("ecryptfs-"))


;;; Generated autoloads from autoloads/me-emacs.el

(autoload '+dir-locals-reload-for-this-buffer "autoloads/me-emacs" "\
reload dir locals for the current buffer" t)
(autoload '+dir-locals-reload-for-all-buffers-in-this-directory "autoloads/me-emacs" "\
For every buffer with the same `default-directory` as the
current buffer's, reload dir-locals." t)
(autoload '+dir-locals-enable-autoreload "autoloads/me-emacs")
(autoload '+dir-locals-open-or-create "autoloads/me-emacs" "\
Open or create the dir-locals.el for the current project." t)


;;; Generated autoloads from autoloads/me-io.el

(autoload '+file-mime-type "autoloads/me-io" "\
Get MIME type for FILE based on magic codes provided by the 'file' command.
Return a symbol of the MIME type, ex: `text/x-lisp', `text/plain',
`application/x-object', `application/octet-stream', etc.

(fn FILE)")
(autoload '+file-name-incremental "autoloads/me-io" "\
Return an unique file name for FILENAME.
If \"file.ext\" exists, returns \"file-0.ext\".

(fn FILENAME)")
(autoload '+file-read-to-string "autoloads/me-io" "\
Return a string with the contents of FILENAME.

(fn FILENAME)")
(autoload '+delete-this-file "autoloads/me-io" "\
Delete PATH.

If PATH is not specified, default to the current buffer's file.

If FORCE-P, delete without confirmation.

(fn &optional PATH FORCE-P)" t)
(autoload '+move-this-file "autoloads/me-io" "\
Move current buffer's file to NEW-PATH.

If FORCE-P, overwrite the destination file if it exists, without confirmation.

(fn NEW-PATH &optional FORCE-P)" t)
(autoload '+sudo-find-file "autoloads/me-io" "\
Open FILE as root.

(fn FILE)" t)
(autoload '+sudo-this-file "autoloads/me-io" "\
Open the current file as root." t)
(autoload '+sudo-save-buffer "autoloads/me-io" "\
Save this file as root." t)
(autoload '+clean-file-name "autoloads/me-io" "\
Clean file name.

(fn FILENAME &optional CONV-DOWNCASE)")
(register-definition-prefixes "autoloads/me-io" '("+sudo-file-path"))


;;; Generated autoloads from autoloads/me-messages.el

(autoload '+messages--auto-tail-a "autoloads/me-messages" "\
Make *Messages* buffer auto-scroll to the end after each message.

(fn &rest ARG)")
(autoload '+messages-auto-tail-toggle "autoloads/me-messages" "\
Auto tail the '*Messages*' buffer." t)


;;; Generated autoloads from ../modules/autoloads/me-netextender.el

(autoload 'netextender-start "../modules/autoloads/me-netextender" "\
Launch a NetExtender VPN session." t)
(autoload 'netextender-toggle "../modules/autoloads/me-netextender" "\
Toggle connection to NetExtender." t)
(register-definition-prefixes "../modules/autoloads/me-netextender" '("netextender-"))


;;; Generated autoloads from autoloads/me-primitives.el

(autoload '+bool "autoloads/me-primitives" "\


(fn VAL)")
(autoload '+foldr "autoloads/me-primitives" "\


(fn FUN ACC SEQ)")
(autoload '+foldl "autoloads/me-primitives" "\


(fn FUN ACC SEQ)")
(autoload '+all "autoloads/me-primitives" "\


(fn SEQ)")
(autoload '+some "autoloads/me-primitives" "\


(fn SEQ)")
(autoload '+filter "autoloads/me-primitives" "\


(fn FUN SEQ)")
(autoload '+zip "autoloads/me-primitives" "\


(fn &rest SEQS)")
(autoload '+str-join "autoloads/me-primitives" "\


(fn SEP SEQ)")
(autoload '+str-split "autoloads/me-primitives" "\


(fn STR SEP)")
(autoload '+str-replace "autoloads/me-primitives" "\
Replaces OLD with NEW in S.

(fn OLD NEW S)")
(autoload '+str-replace-all "autoloads/me-primitives" "\
REPLACEMENTS is a list of cons-cells. Each `car` is replaced with `cdr` in S.

(fn REPLACEMENTS S)")


;;; Generated autoloads from autoloads/me-systemd.el

(autoload '+systemd-running-p "autoloads/me-systemd" "\
Check if the systemd SERVICE is running.

(fn SERVICE)")
(autoload '+systemd-command "autoloads/me-systemd" "\
Call systemd with COMMAND and SERVICE.

(fn SERVICE COMMAND &optional PRE-FN POST-FN)" t)
(autoload '+systemd-start "autoloads/me-systemd" "\
Start systemd SERVICE.

(fn SERVICE &optional PRE-FN POST-FN)" t)
(autoload '+systemd-stop "autoloads/me-systemd" "\
Stops the systemd SERVICE.

(fn SERVICE &optional PRE-FN POST-FN)" t)

;;; End of scraped data

(provide 'me-autoloads)

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; no-native-compile: t
;; coding: utf-8-emacs-unix
;; End:

;;; me-autoloads.el ends here
