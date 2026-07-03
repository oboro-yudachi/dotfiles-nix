;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

(package! evil-matchit)

(package! claude-code-ide
  :recipe (:host github :repo "manzaltu/claude-code-ide.el"))

(package! difftastic
  :recipe (:host github :repo "pkryger/difftastic.el"))

(package! impatient-mode)
;; MELPAの標準レシピだと別物（emacs-web-server）を指してしまい
;; simple-httpd.el自体がビルドされない事象が起きたため、本家repoを明示指定する
(package! simple-httpd
  :recipe (:host github :repo "skeeto/simple-httpd"))
