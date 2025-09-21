function fish_greeting
	if test "$TERM" = "xterm-kitty"
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

zoxide init fish --cmd cd | source

# pnpm
set -gx PNPM_HOME "/home/otto/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
