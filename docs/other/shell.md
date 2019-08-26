# Shell

## OSX

### Iterm2 + Solarized + OZSH + Font Awesome

* https://gist.github.com/kevin-smets/8568070

### Using Powerline Font with VS Code Terminal

* https://medium.com/@hippojs.guo/vs-code-fix-fonts-in-terminal-761cc821ef41

### My Config - 10K

```bash
ZSH_THEME="powerlevel10k/powerlevel10k"
#POWERLEVEL9K_MODE="awesome-patched"
P9KGT_BACKGROUND='dark'
P9KGT_COLORS='light'
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
        context
        dir
        vcs
        newline
        prompt_char             # prompt symbol
)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
        status
        command_execution_time
        battery
        ram
        date
        newline
        kubecontext
        time
)
```

### My Config - 9K

```bash
ZSH_THEME="powerlevel9k/powerlevel9k"
#ZSH_THEME="powerlevel10k/powerlevel10k"
POWERLEVEL9K_MODE="awesome-patched"
P9KGT_BACKGROUND='dark'
P9KGT_COLORS='light'
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
        dir
        vcs
)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
        status
        command_execution_time
        kubecontext
        battery
        ram
        time
)

POWERLEVEL9K_STATUS_ICON_BEFORE_CONTENT=true
POWERLEVEL9K_PROMPT_ON_NEWLINE=true
POWERLEVEL9K_RPROMPT_ON_NEWLINE=true
POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
```