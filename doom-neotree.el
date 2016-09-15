;;; doom-neotree.el

(require 'all-the-icons)

(defgroup doom-neotree nil
  "Options for doom's neotree theme"
  :group 'doom)

;;
(defface doom-neotree-folder-face '((t (:inherit neo-dir-link-face)))
  "Base face for neotree folder icons. Also see `doom-neotree-open-folder-face' and
`doom-neotree-closed-folder-face'."
  :group 'doom-neotree)

(defface doom-neotree-chevron-face '((t (:inherit neo-dir-link-face)))
  "Face for chevron icons next to folders. See
`doom-neotree-closed-chevron-icon' and `doom-neotree-open-chevron-icon'."
  :group 'doom-neotree)


;;
(defcustom doom-neotree-folder-size 1.0
  "What :height to display the folder icons at."
  :type 'float
  :group 'doom-neotree)

(defcustom doom-neotree-chevron-size 0.8
  "What :height to display the chevron icons at."
  :type 'float
  :group 'doom-neotree)

(defcustom doom-neotree-line-spacing 2
  "Line-spacing for neotree buffer."
  :type 'symbol
  :group 'doom-neotree)

(defcustom doom-neotree-enable-file-icons nil
  "If non-nil, display file icons next to each file. This can look strange on
some displays or at certain font sizes. YMMV."
  :type 'boolean
  :group 'doom-neotree)

(defcustom doom-neotree-enable-folder-icons t
  "If non-nil, display folder icons next to each file. Different icons are used
depending on whether the folder is a repo, symlink or regular folder."
  :type 'boolean
  :group 'doom-neotree)

(defcustom doom-neotree-enable-chevron-icons t
  "If non-nil, display chevron icons next to each folder."
  :type 'boolean
  :group 'doom-neotree)


;;
(defun doom--neotree-no-fringes ()
  "Remove fringes in neotree. They get reset each time you select the neotree
pane and are highlighted incorrectly."
  (set-window-fringes neo-global--window 1 0))

(defun doom--neotree-setup (&rest _)
  (setq line-spacing doom-neotree-line-spacing
        tab-width 1)
  (when (featurep 'hl-line)
    (set (make-local-variable 'hl-line-sticky-flag) t)
    (hl-line-mode +1)))

(defun doom--folder-icon-for (dir chevron)
  (let* ((path (expand-file-name dir))
         (chevron
          (if doom-neotree-enable-chevron-icons
              (all-the-icons-octicon
               (format "chevron-%s" chevron)
               :height doom-neotree-chevron-size
               :v-adjust 0.1
               :face 'doom-neotree-chevron-face)
            ""))
         (icon
          (when doom-neotree-enable-folder-icons
            (all-the-icons-octicon
             (cond ((file-symlink-p path) "file-symlink-directory")
                   ((file-exists-p (format "%s/.git" path)) "file-submodule")
                   ((all-the-icons-dir-is-submodule path) "file-submodule")
                   (t "file-directory"))
             :height doom-neotree-folder-size
             :v-adjust 0
             :face 'doom-neotree-folder-face))))
    (format "\t%s\t%s\t" chevron icon)))

(defun doom--neo-insert-fold-symbol (type file-name)
  "Custom hybrid unicode theme with leading whitespace."
  (or (and (eq type 'open)
           (insert (doom--folder-icon-for file-name "down")))
      (and (eq type 'close)
           (insert (doom--folder-icon-for file-name "right")))
      (and (eq type 'leaf)
           (insert (concat (when doom-neotree-enable-chevron-icons "\t")
                           (when doom-neotree-enable-folder-icons "\t")
                           (when doom-neotree-enable-file-icons
                             (concat "\t" (all-the-icons-icon-for-file file-name)))
                           "\t")))))

(defun doom--neo-buffer--insert-root-entry (&rest _)
  "Pretty-print pwd in neotree"
  (insert
   (format "%s %s\n"
           (all-the-icons-octicon "repo" :height 1.4 :face 'neo-root-dir-face :v-adjust -0.1)
           (propertize (projectile-project-name) 'face 'neo-root-dir-face))))

(defun doom--neo-buffer--insert-dir-entry (node depth expanded)
  (let ((node-short-name (neo-path--file-short-name node)))
    (insert-char ?\s (* (- depth 1) 2)) ; indent
    (when (memq 'char neo-vc-integration)
      (insert-char ?\s 2))
    ;; Added this line
    (doom--neo-insert-fold-symbol
     (if expanded 'open 'close) node)
    ;;
    (insert-button (concat node-short-name "/")
                   'follow-link t
                   'face neo-dir-link-face
                   'neo-full-path node
                   'keymap neotree-dir-button-keymap)
    (neo-buffer--node-list-set nil node)
    (neo-buffer--newline-and-begin)))

(defun doom--neo-buffer--insert-file-entry (node depth)
  (let ((node-short-name (neo-path--file-short-name node))
        (vc (when neo-vc-integration (neo-vc-for-node node))))
    (insert-char ?\s (* (- depth 1) 2)) ; indent
    (when (memq 'char neo-vc-integration)
      (insert-char (car vc))
      (insert-char ?\s))
    ;; Added this line
    (doom--neo-insert-fold-symbol 'leaf node-short-name)
    ;;
    (insert-button node-short-name
                   'follow-link t
                   'face (if (memq 'face neo-vc-integration)
                             (cdr vc)
                           neo-file-link-face)
                   'neo-full-path node
                   'keymap neotree-file-button-keymap)
    (neo-buffer--node-list-set nil node)
    (neo-buffer--newline-and-begin)))


;;
(eval-after-load "neotree"
  (lambda ()
    ;; Enable buffer-local hl-line and adjust line-spacing
    (add-hook 'neo-after-create-hook 'doom--neotree-setup)
    ;; Incompatible
    (setq neo-vc-integration nil)
    ;; Remove fringes in Neotree pane
    (advice-add 'neo-global--select-window :after 'doom--neotree-no-fringes)
    ;; Patch neotree to use `doom--neo-insert-fold-symbol'
    (advice-add 'neo-buffer--insert-file-entry :override 'doom--neo-buffer--insert-file-entry)
    (advice-add 'neo-buffer--insert-dir-entry  :override 'doom--neo-buffer--insert-dir-entry)
    ;; Shorter pwd in neotree
    (advice-add 'neo-buffer--insert-root-entry :override 'doom--neo-buffer--insert-root-entry)))

(provide 'doom-neotree)
;;; doom-neotree.el ends here
