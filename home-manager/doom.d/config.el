;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(setq doom-theme 'doom-one)
(setq display-line-numbers-type nil)
(setq org-directory "~/org/")

(defun my/im-select-abc ()
  (when (executable-find "im-select")
    (start-process "im-select" nil "im-select" "com.apple.keylayout.ABC")))

;; insertから抜けたタイミング
(add-hook 'evil-insert-state-exit-hook #'my/im-select-abc)

;; minibuffer（コマンド入力）終了時も寄せたい場合
(add-hook 'minibuffer-exit-hook #'my/im-select-abc)

;; 下のgitのブランチ窓を広くする
(after! doom-modeline
  (setq doom-modeline-vcs-max-length 60))

;; GUIアプリ起動時にシェルのPATHが引き継がれないため、必要なパスを明示的に追加
(dolist (p (list (expand-file-name "~/.local/share/mise/shims")
                 "/etc/profiles/per-user/taguchishoh/bin"
                 "/run/current-system/sw/bin"
                 "/nix/var/nix/profiles/default/bin"))
  (setenv "PATH" (concat p ":" (getenv "PATH")))
  (add-to-list 'exec-path p))

(which-function-mode 1)

(add-to-list 'default-frame-alist '(fullscreen . maximized))

(setq-default tab-width 2)

(after! lsp-mode
  ;; bundle exec経由でruby-lspを起動しない（GemfileにはrubyLSPは含まれていないため）
  (setq lsp-ruby-lsp-use-bundler nil)
  ;; solargraphを無効化してruby-lspを使う（lsp-modeのデフォルトはsolargraph=ruby-ls）
  (setq lsp-disabled-clients (append lsp-disabled-clients '(ruby-ls rubocop-ls)))
  (setq lsp-inlay-hint-enable t)
  (setq lsp-javascript-format-enable nil)
  (setq lsp-typescript-format-enable nil)
  (add-hook 'lsp-mode-hook #'lsp-lens-mode))

(add-hook 'ruby-mode-hook #'lsp)
(add-hook 'tsx-ts-mode-hook #'lsp)
(add-hook 'typescript-ts-mode-hook #'lsp)

(use-package lsp-ui)

;; evilの設定
(use-package! evil-matchit
  :hook (after-init . global-evil-matchit-mode)
  :config
  ;; ruby-ts-modeを追加（ruby-modeはevilmi-init-pluginsが自動登録する）
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
;; treemacsの設定
(after! treemacs
  ;; 幅を固定ロックしない（手で調整可能にする）
  (setq treemacs-width-is-initially-locked nil
        treemacs-width 50) ; デフォルト幅

  (defun my/treemacs-set-width (width)
    "Treemacs の幅を WIDTH（列数）に設定する。"
    (interactive "nTreemacs width: ")
    (setq treemacs-width width)
    (when-let ((win (treemacs-get-local-window)))
      (adjust-window-trailing-edge win (- width (window-total-width win)) t))))

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

(map! :leader
      :desc "Toggle LSP headerline breadcrumb"
      "l b" #'lsp-headerline-breadcrumb-mode)

(map! :leader
      :desc "treemacs select window"
      "l w" #'treemacs-select-window)

(map! :leader
      :desc "Toggle Scroll Bar"
      "l s" #'scroll-bar-mode)

(map! :leader
      :desc "Vertico project search"
      "/" #'+vertico/project-search)
