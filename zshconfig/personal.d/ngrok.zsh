# ngrok completions. `ngrok completion` ignores its arguments and picks the shell
# from $SHELL, which still says fish (or bash, ...) in a zsh started before or
# outside a `chsh`, and fish output is a parse error here. Pin it to zsh.
if (( $+commands[ngrok] )); then
  __cached_eval ngrok ngrok env SHELL=/bin/zsh ngrok completion
fi
