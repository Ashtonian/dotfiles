#!/usr/bin/env bash

#######################################################################################################################################
# macOS 10.15+ (Catalina) Init script to install dependencies
#######################################################################################################################################

# Colors
ESC_SEQ="\x1b["
COL_RESET=$ESC_SEQ"39;49;00m"
COL_RED=$ESC_SEQ"31;01m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_YELLOW=$ESC_SEQ"33;01m"
COL_BLUE=$ESC_SEQ"34;01m"
COL_MAGENTA=$ESC_SEQ"35;01m"
COL_CYAN=$ESC_SEQ"36;01m"

function ok() {
    echo -e "$COL_GREEN[ok]$COL_RESET "$1
}

function bot() {
    echo -e "\n$COL_GREEN\[._.]/$COL_RESET - "$1
}

#######################################################################################################################################
# Sudo
#######################################################################################################################################

# Do we need to ask for sudo password or is it already passwordless?
grep -q 'NOPASSWD:     ALL' /etc/sudoers.d/$LOGNAME > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "no suder file"
  sudo -v

  # Keep-alive: update existing sudo time stamp until the script has finished
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

  bot "Do you want me to setup this machine to allow you to run sudo without a password?\nPlease read here to see what I am doing:\nhttp://wiki.summercode.com/sudo_without_a_password_in_mac_os_x \n"

  read -r -p "Make sudo passwordless? [y|N] " response

  if [[ $response =~ (yes|y|Y) ]];then
      if ! grep -q "#includedir /private/etc/sudoers.d" /etc/sudoers; then
        echo '#includedir /private/etc/sudoers.d' | sudo tee -a /etc/sudoers > /dev/null
      fi
      echo -e "Defaults:$LOGNAME    !requiretty\n$LOGNAME ALL=(ALL) NOPASSWD:     ALL" | sudo tee /etc/sudoers.d/$LOGNAME
      echo "You can now run sudo commands without password!"
  fi
fi;ok

# ###########################################################
# Install non-brew various tools (PRE-BREW Installs)
# ###########################################################

bot "ensuring build/install tools are available"
if ! xcode-select --print-path &> /dev/null; then

    # Prompt user to install the XCode Command Line Tools
    xcode-select --install &> /dev/null

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Wait until the XCode Command Line Tools are installed
    until xcode-select --print-path &> /dev/null; do
        sleep 5
    done

    print_result $? ' XCode Command Line Tools Installed'

    # Prompt user to agree to the terms of the Xcode license
    # https://github.com/alrra/dotfiles/issues/10

    sudo xcodebuild -license
    print_result $? 'Agree with the XCode Command Line Tools licence'
fi;ok

# ###########################################################
# install homebrew
# ###########################################################
running "checking homebrew..."
brew_bin=$(which brew) 2>&1 > /dev/null
if [[ $? != 0 ]]; then
  action "installing homebrew"
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  if [[ $? != 0 ]]; then
    error "unable to install homebrew, script $0 abort!"
    exit 2
  fi
  brew analytics off
else
  ok
  bot "Homebrew"
  read -r -p "run brew update && upgrade? [y|N] " response
  if [[ $response =~ (y|yes|Y) ]]; then
    action "updating homebrew..."
    brew update
    ok "homebrew updated"
    action "upgrading brew packages..."
    brew upgrade
    ok "brews upgraded"
  else
    ok "skipped brew package upgrades."
  fi
fi

# Just to avoid a potential bug
mkdir -p ~/Library/Caches/Homebrew/Formula
brew doctor

# ###########################################################
# Git Config
# ###########################################################
bot "OK, now I am going to update the .gitconfig for your user info:"
grep 'user = GITHUBUSER' ./homedir/.gitconfig > /dev/null 2>&1
if [[ $? = 0 ]]; then
    read -r -p "What is your git username? " githubuser

  fullname=`osascript -e "long user name of (system info)"`

  if [[ -n "$fullname" ]];then
    lastname=$(echo $fullname | awk '{print $2}');
    firstname=$(echo $fullname | awk '{print $1}');
  fi

  if [[ -z $lastname ]]; then
    lastname=`dscl . -read /Users/$(whoami) | grep LastName | sed "s/LastName: //"`
  fi
  if [[ -z $firstname ]]; then
    firstname=`dscl . -read /Users/$(whoami) | grep FirstName | sed "s/FirstName: //"`
  fi
  email=`dscl . -read /Users/$(whoami)  | grep EMailAddress | sed "s/EMailAddress: //"`

  if [[ ! "$firstname" ]]; then
    response='n'
  else
    echo -e "I see that your full name is $COL_YELLOW$firstname $lastname$COL_RESET"
    read -r -p "Is this correct? [Y|n] " response
  fi

  if [[ $response =~ ^(no|n|N) ]]; then
    read -r -p "What is your first name? " firstname
    read -r -p "What is your last name? " lastname
  fi
  fullname="$firstname $lastname"

  bot "Great $fullname, "

  if [[ ! $email ]]; then
    response='n'
  else
    echo -e "The best I can make out, your email address is $COL_YELLOW$email$COL_RESET"
    read -r -p "Is this correct? [Y|n] " response
  fi

  if [[ $response =~ ^(no|n|N) ]]; then
    read -r -p "What is your email? " email
    if [[ ! $email ]];then
      error "you must provide an email to configure .gitconfig"
      exit 1
    fi
  fi


  running "replacing items in .gitconfig with your info ($COL_YELLOW$fullname, $email, $githubuser$COL_RESET)"

  # test if gnu-sed or MacOS sed

  sed -i "s/GITHUBFULLNAME/$firstname $lastname/" ./homedir/.gitconfig > /dev/null 2>&1 | true
  if [[ ${PIPESTATUS[0]} != 0 ]]; then
    echo
    running "looks like you are using MacOS sed rather than gnu-sed, accommodating"
    sed -i '' "s/GITHUBFULLNAME/$firstname $lastname/" ./homedir/.gitconfig
    sed -i '' 's/GITHUBEMAIL/'$email'/' ./homedir/.gitconfig
    sed -i '' 's/GITHUBUSER/'$githubuser'/' ./homedir/.gitconfig
    ok
  else
    echo
    bot "looks like you are already using gnu-sed. woot!"
    sed -i 's/GITHUBEMAIL/'$email'/' ./homedir/.gitconfig
    sed -i 's/GITHUBUSER/'$githubuser'/' ./homedir/.gitconfig
  fi
fi

bot "cloning dotfiles locally"
cd $HOME 
git clone https://github.com/Ashtonian/dotfiles.git
ok 

bot "linking makcup file from dotfile to directory"
ln -s $HOME/.dotfiles/.mackup.cfg $HOME/.mackup.cfg
ok 

bot "creating sync directory"
mkdir $HOME/.sync
cd $HOME/.sync
ok

bot "clone iterm dracula theme"
git clone https://github.com/dracula/iterm.git $HOME/.sync/dracula-iterm
ok

bot "download alfred and mackup directory"
cd $HOME/.sync
git clone https://github.com/Ashtonian/alfred
git clone https://github.com/Ashtonian/mackup
ok

bot "download bypass paywall"
cd $HOME/.sync
git clone https://github.com/iamadamdev/bypass-paywalls-chrome.git
ok 

bot "running configure script"
/bin/bash -c $HOME/.doftfiles/config.sh
ok


sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/TamCore/autoupdate-oh-my-zsh-plugins $ZSH_CUSTOM/plugins/autoupdate
git clone https://github.com/tysonwolker/iterm-tab-colors.git  $ZSH_CUSTOM/plugins/zsh-tab-colors
git clone https://github.com/chrissicool/zsh-256color $ZSH_CUSTOM/plugins/zsh-256color
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-completions $ZSH_CUSTOM/plugins/zsh-completions
git clone https://github.com/zdharma/zsh-diff-so-fancy $ZSH_CUSTOM/plugins/zsh-diff-so-fancy
git clone https://github.com/sei40kr/zsh-fast-alias-tips.git  $ZSH_CUSTOM/plugins/fast-alias-tips
git clone https://github.com/aperezdc/zsh-fzy $ZSH_CUSTOM/plugins/zsh-fzy
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

cd $ZSH_CUSTOM/plugins/fast-alias-tips
make 

TODO: runn all apps
TODO: Fix dock - add applications folder + utilities
TODO: fix login items 
TODO: finder siderbar

# TODO:s
# * finder sidebar
#   * rm tags section
#   * add 'OS X' aka local mac install drive to finder sidebar
#   * adjust favorites
#     * [FinderSidebarEditor](https://github.com/robperc/FinderSidebarEditor)
#     * (home folder)
#     * Projects
#     * Recents
#     * Downloads
#     * Desktop
#     * Documents
#     * Applications
#     * Utilities
#     * cloud accounts...
#     * run monolingual
# * after init.sh option to remove dockutil and others
#
# * defaults write com.agilebits.onepassword7 "ShortcutRecorder BrowserActivation" -dict "keyChars" -string '\' "keyCharsIgnoringModifiers" -string '\' "keyCode" -int 42 "modifierFlags" -int 1048576 "modifiers" -int 256 "ShortcutRecorder GlobalLock", "ShortcutRecorder GlobalActivation", and "ShortcutRecorder BrowserActivation"
# * Last login: Sun Jan 24 18:55:04 on ttys000
# * init.sh uses comments to deliniate between laptop / desktop setups
# * config f.lux, including rm annon stats
# * ask user for project folder target
# * ask user for dotfiles

# //TODO:
# TODO: ls nicer, ping
# alias ls='ls -aGFh'
# alias ll='ls -l'
# alias rm='rm -i'
# alias ne='emacs'
# alias dev='cd ~/dev'
# alias ports='sudo netstat -tulanp'
# * alias newtab='open -na "Brave Browser" --args -new-tab'
# * alias amend='git commit --amend --no-edit
# alias nano="vim"
# alias reboot='sudo reboot'
# alias ..='cd ..'
# alias grep="grep --color=auto"
# alias fgrep="fgrep --color=auto"
# alias egrep="egrep --color=auto"
# # make less accept color codes and re-output them
# alias less="less -R"
# 	alias ls="ls -F --color=auto --group-directories-first"
# alias diff

# alias yoink="open -a Yoink"

# timezsh() {
#   shell=${1-$SHELL}
#   for i in $(seq 1 10); do /usr/bin/time $shell -i -c exit; done
# }
# if bash -n prettyping alias ping 

# if bash -n lsp 
  # alias lsp 
# if ! install? go get https://github.com/dborzov/lsp
# TODO: [oh-my-zsh]     compaudit | xargs chmod g-w,o-w  permissions zsh

