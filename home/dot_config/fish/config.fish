function fish_greeting
	if test "$TERM" = "xterm-ghostty"
		set_color purple
		echo - {O}
		set_color blue
		echo - $hostname (date +'%I:%M:%S %p')
		set_color cyan
		echo - (uptime -p)
	end
end

alias cat="bat"
alias ls="eza"

set -gx PATH "$HOME/.cargo/bin" $PATH

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH "$VOLTA_HOME/bin" $PATH

zoxide init fish --cmd cd | source
