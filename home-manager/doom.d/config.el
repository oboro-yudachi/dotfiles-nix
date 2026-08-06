;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(setq select-enable-clipboard t)
(setq evil-want-clipboard t)

(setq doom-theme 'doom-one)
(setq doom-font (font-spec :family "Hack Nerd Font Mono" :size 16))
(setq doom-variable-pitch-font (font-spec :family "Hack Nerd Font Mono" :size 16))

(setq display-line-numbers-type nil)
(add-to-list 'default-frame-alist '(fullscreen . maximized))
(which-function-mode 1)
(setq-default tab-width 2)

(after! indent-bars
  (setq indent-bars-color-by-depth '(:regexp "outline-\\([0-9]+\\)" :blend 0.6)
        indent-bars-highlight-current-depth '(:blend 0.8)
        indent-bars-width-frac 0.25
        indent-bars-pad-frac 0.1
        ;; Retina等のHiDPI環境だとビットマップ(stipple)描画がピクセル計算で
        ;; 崩れて単色(黒)になる既知の不具合があるため、文字ベース描画に切り替える。
        indent-bars-prefer-character t))

(setq org-directory "~/dev/org/")
(setq org-roam-directory org-directory)

(setq org-agenda-files (list org-directory
                             (expand-file-name "roam" org-directory)))

(setq org-roam-node-display-template
      (concat "{title:*} "
              (propertize "${tags:25}" 'face 'org-tag)))

(org-roam-db-autosync-enable)

(after! org
  (add-to-list 'org-capture-templates
        `("m" "Work memo" plain
          (file (lambda ()
                  (org-capture-put :my-title (read-string "Title: "))
                  (expand-file-name
                   (concat (org-capture-get :my-title) ".org")
                   "~/dev/org/roam")))
          ,(concat ":PROPERTIES:\n"
                  ":ID: %(org-id-new)\n"
                  ":END:\n"
                  "#+TITLE: %(org-capture-get :my-title)\n"
                  "#+OPTIONS: broken-links:t toc:nil \\n:t ^:nil num:nil\n"
                  "#+DATE: %<%Y-%m-%d>\n"
                  "#+LANGUAGE: ja\n"
                  "#+FILETAGS: %?"
                  "Notion:")
          :jump-to-captured t)))

(defconst my/org-capture-id-drawer
  ":PROPERTIES:\n:ID:       %(org-id-new)\n:END:\n"
  "captureテンプレートの見出し直下に入れるIDプロパティドロワー。")

(after! org
  (dolist (spec `(("t" . ,(concat "* TODO %?\n" my/org-capture-id-drawer "%i"))
                  ("n" . ,(concat "* %u %?\n" my/org-capture-id-drawer "%i"))
                  ("j" . ,(concat "* %U %?\n" my/org-capture-id-drawer "%i"))))
    (when-let ((tpl (assoc (car spec) org-capture-templates)))
      (setf (nth 4 tpl) (cdr spec)))))

(defun my/org-roam--select-directory ()
  "org-roam-directory 配下の既存サブディレクトリを選択、または新規ディレクトリ名を入力する。
空文字のまま確定するとルート直下に作成する。"
  (let* ((subdirs (thread-last
                     (directory-files-recursively org-roam-directory "" t)
                     (seq-filter #'file-directory-p)
                     (mapcar (lambda (d) (file-relative-name d org-roam-directory)))
                     (cons "")
                     (delete-dups)))
         (choice (completing-read "Directory (空欄でルート直下): " subdirs nil nil)))
    (if (string-empty-p choice)
        org-roam-directory
      (let ((dir (expand-file-name choice org-roam-directory)))
        (make-directory dir t)
        dir))))

(after! org-roam
  (setq org-roam-capture-templates
        '(("d" "default" plain "%?"
           :target (file+head "%(my/org-roam--select-directory)/${slug}.org"
                               ":PROPERTIES:\n:ID:       %(org-id-new)\n:END:\n#+TITLE: ${title}\n#+OPTIONS: broken-links:t toc:nil \\n:t ^:nil num:nil\n#+DATE: %<%Y-%m-%d>\n#+LANGUAGE: ja\n")
           :unnarrowed t))))

(defun my/org-roam-buffer-select ()
  "org-roam backlinksバッファを（無ければ開いてから）選択する。"
  (interactive)
  (unless (get-buffer-window org-roam-buffer)
    (org-roam-buffer-toggle))
  (when-let ((win (get-buffer-window org-roam-buffer)))
    (select-window win)))

(map! :leader
      :desc "Select org-roam buffer"
      "n r w" #'my/org-roam-buffer-select)

(use-package! websocket
  :after org-roam)

(use-package! org-roam-ui
  :after org-roam
  :config
  (setq org-roam-ui-sync-theme t      ; Emacsのテーマとブラウザ側の配色を同期
        org-roam-ui-follow t          ; Emacsで開いたノードにグラフが追従
        org-roam-ui-update-on-save t  ; 保存時にグラフを更新
        org-roam-ui-open-on-start t)) ; org-roam-ui-mode起動時にブラウザを開く

(map! :leader
      :desc "org-roam-ui"
      "n r u" #'org-roam-ui-mode)

(defvar my/org-auto-export-backends
  '(("md"      . org-pandoc-export-to-gfm)
    ("html"    . org-html-export-to-html)
    ("gfm"     . org-pandoc-export-to-gfm)
    ("docx"    . org-pandoc-export-to-docx))
  "AUTO_EXPORTキーワードの値と対応するexport関数の対応表。
新しいバックエンドを増やしたい時はここに追加する。")

(defun my/org-auto-export-if-requested ()
  "バッファ先頭に #+AUTO_EXPORT: があれば、保存時に自動でexportする。"
  (when (derived-mode-p 'org-mode)
    (when-let* ((keyword (cadr (assoc "AUTO_EXPORT"
                                       (org-collect-keywords '("AUTO_EXPORT")))))
                (backends (split-string keyword)))
      (dolist (name backends)
        (if-let ((fn (cdr (assoc name my/org-auto-export-backends))))
            (progn
              (funcall fn)
              (message "AUTO_EXPORT: %s へexportしました" name))
          (message "AUTO_EXPORT: 未知のバックエンド %s" name))))))

(add-hook 'after-save-hook #'my/org-auto-export-if-requested)

(use-package! impatient-mode
  :commands (impatient-mode imp-visit-buffer imp-set-user-filter))

(after! impatient-mode
  ;; 編集のたびに毎回exportすると重いので、0.5秒の無操作を挟んでから更新する
  (setq impatient-mode-delay 0.5))

(defun my/imp-org-html-filter (buffer)
  "orgバッファの内容をHTMLへexportしてimpatient-modeに渡すフィルタ。
imp--send-stateからstandard-outputが出力先バッファにbindされた状態で呼ばれるため、
princでそこに書き込む。"
  (princ (with-current-buffer buffer
           (org-export-as 'html nil nil nil))))

(defun my/org-impatient-preview ()
  "現在のorgバッファを、実ブラウザでホットリロードしながらプレビューする。"
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "org-modeバッファで実行してください"))
  (imp-set-user-filter #'my/imp-org-html-filter)
  (imp-visit-buffer))

(map! :map org-mode-map
      :localleader
      :desc "Live HTML preview" "P" #'my/org-impatient-preview)

(map! :map org-mode-map
      :localleader
      :desc "Present (org-tree-slide)" "S" #'org-tree-slide-mode)

(after! org-tree-slide
  (map! :map org-tree-slide-mode-map
        :n [right] #'org-tree-slide-move-next-tree
        :n [left]  #'org-tree-slide-move-previous-tree
        :n "q"     #'org-tree-slide-mode))

(after! org-tree-slide
  (advice-remove 'org-tree-slide--display-tree-with-narrow
                 #'+org-present--hide-first-heading-maybe-a))

(after! org
  (org-link-set-parameters "file"
    :export (lambda (link description _format _info)
              (or description link))))

(setq org-export-with-broken-links nil)

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "RET")
              (lambda ()
                (interactive)
                (if (org-in-item-p)
                    (org-insert-item)
                  (org-return)))))

(setq org-return-follows-link t)

(defun my/im-select-abc ()
  (when (executable-find "im-select")
    (start-process "im-select" nil "im-select" "com.apple.keylayout.ABC")))

(add-hook 'evil-insert-state-exit-hook #'my/im-select-abc)
(add-hook 'minibuffer-exit-hook #'my/im-select-abc)

(after! lsp-mode
  (setq lsp-imenu-sort-methods '(position)))

(after! lsp-mode
  (dolist (re '("[/\\\\]tmp\\'"
                "[/\\\\]coverage\\'"
                "[/\\\\]\\.bundle\\'"))
    (add-to-list 'lsp-file-watch-ignored-directories re)))

(setq treesit-language-source-alist
      '((typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src")
        (tsx        "https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src")))

(dolist (lang (mapcar #'car treesit-language-source-alist))
  (unless (treesit-language-available-p lang)
    (ignore-errors (treesit-install-language-grammar lang))))

(after! lsp-mode
  (setq lsp-ruby-lsp-use-bundler nil)
  (setq lsp-disabled-clients (append lsp-disabled-clients '(ruby-ls rubocop-ls)))
  (setq lsp-inlay-hint-enable t)
  (setq lsp-javascript-format-enable nil)
  (setq lsp-typescript-format-enable nil)
  (add-hook 'lsp-mode-hook #'lsp-lens-mode))

(add-hook 'ruby-mode-hook #'lsp)
(add-hook 'tsx-ts-mode-hook #'lsp)
(add-hook 'typescript-ts-mode-hook #'lsp)

(use-package lsp-ui)
(after! lsp-mode
  (setq lsp-signature-auto-activate nil)   ; スペース入力での自動表示を止める
  (setq lsp-signature-render-documentation nil))  ; ドキュメント部分も非表示

(after! lsp-ui
  (setq lsp-ui-doc-enable nil))  ; hover ドキュメントも念のため無効化

(map! :leader
      :desc "Toggle LSP signature" "t s"
      (cmd! (setq lsp-signature-auto-activate
                  (not lsp-signature-auto-activate))))

(map! :leader
      :desc "Toggle LSP headerline breadcrumb"
      "l b" #'lsp-headerline-breadcrumb-mode)

(map! :leader
      :desc "treemacs select window"
      "l w" #'treemacs-select-window)

(use-package! evil-matchit
  :hook (after-init . global-evil-matchit-mode)
  :config
  (evilmi-load-plugin-rules '(ruby-ts-mode) '(simple ruby))
  ;; ジャンプ後にキーワード上にカーソルを置く（デフォルトは行頭/行末になる）
  (advice-add 'evilmi-jump-items :after
              (lambda (&rest _)
                (when (memq major-mode '(ruby-mode ruby-ts-mode))
                  (let ((kw-re "\\_<\\(do\\|end\\|if\\|elsif\\|else\\|unless\\|while\\|until\\|for\\|def\\|class\\|module\\|begin\\|case\\|when\\|rescue\\|ensure\\)\\_>"))
                    (back-to-indentation)
                    (unless (looking-at kw-re)
                      (when (re-search-forward kw-re (line-end-position) t)
                        (goto-char (match-beginning 0)))))))))

(after! treemacs
  (setq treemacs-width-is-initially-locked nil
        treemacs-width 50) ; デフォルト幅

  (defun my/treemacs-set-width (width)
    "Treemacs の幅を WIDTH（列数）に設定する。"
    (interactive "nTreemacs width: ")
    (setq treemacs-width width)
    (when-let ((win (treemacs-get-local-window)))
      (adjust-window-trailing-edge win (- width (window-total-width win)) t)))

  (add-hook 'treemacs-mode-hook
            (lambda ()
              (set-window-parameter (selected-window) 'no-other-window nil))))

(defun open-in-cursor ()
  "Open the current file in Cursor."
  (interactive)
  (let ((filename (buffer-file-name)))
    (if filename
        (start-process "open-in-cursor" nil "open" "-a" "Cursor" filename)
      (message "No file associated with this buffer."))))

(map! :leader
      :desc "Open in Cursor"
      "o C" #'open-in-cursor)

(use-package! claude-code-ide
  :config
  (claude-code-ide-emacs-tools-setup)) ; Optionally enable Emacs MCP tools

(map! :leader
      :desc "Claude Code IDE Menu"
      "c m" #'claude-code-ide-menu)

(use-package! difftastic
  :after magit
  :config
  (eval-after-load 'magit-diff
    '(transient-append-suffix 'magit-diff '(-1 -1)
       [("D" "Difftastic diff (dwim)" difftastic-magit-diff)
        ("S" "Difftastic show" difftastic-magit-show)]))
  (setq difftastic-requested-window-width-function #'frame-width)
  (setq difftastic-display-buffer-function
        (lambda (buffer _requested-width)
          (switch-to-buffer buffer))))

(map! :leader
      :desc "Toggle Scroll Bar"
      "l s" #'scroll-bar-mode)

(map! :leader
      :desc "Vertico project search"
      "/" #'+vertico/project-search)

(map! :leader
      :desc "Toggle Eldoc Mode"
      "t e" #'eldoc-mode)

(map! :leader
      :desc "Toggle indent-bars"
      "t i" #'indent-bars-mode)

(after! doom-modeline
  (setq doom-modeline-vcs-max-length 80))

(dolist (dir (list (expand-file-name "~/.local/share/mise/shims")
                   (format "/etc/profiles/per-user/%s/bin" (user-login-name))
                   "/run/current-system/sw/bin"))
  (when (file-directory-p dir)
    (add-to-list 'exec-path dir)
    (setenv "PATH" (concat dir ":" (getenv "PATH")))))

(defun get-db-password (host)
  (funcall (plist-get (car (auth-source-search :host host)) :secret)))

(defun get-db-user (host)
  (plist-get (car (auth-source-search :host host)) :user))

(defun get-db-port (host)
  (string-to-number (plist-get (car (auth-source-search :host host)) :port)))

(defun set-mysql-pwd (host)
  (setenv "MYSQL_PWD" (get-db-password host))
  nil)

(setq eldoc-display-functions '(eldoc-display-in-echo-area))
