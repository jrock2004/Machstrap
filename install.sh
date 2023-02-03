# Variables
##############################################
OS=""
USE_DESKTOP_ENV=FALSE
ARCH_APPS=()
POP_APPS=()
DOTFILES="$HOME/.dotfiles"
DOTFILES_REPO="https://github.com/jrock2004/dotfiles"

# Helper Functions
##############################################
initialQuestions() {
  echo "What OS are we setting up today?"
  echo "1) Arch"
  echo "2) Mac OSX"
  echo "3) PopOS"
  echo "q) Exit"

  read -rp "Select which OS: " choice_os

  case $choice_os in
    1)
      OS="arch"
      ;;
    2)
      OS="mac"
      ;;
    3)
      OS="debian"
      ;;
    *)
      echo "Invalid choice."

      exit 1
      ;;
  esac

  echo "Do you have a desktop environment? (y/[n])"

  read -rp "Use desktop environment? " choice_desktop

  case $choice_desktop in
    y)
      USE_DESKTOP_ENV=TRUE
      ;;
    n)
      USE_DESKTOP_ENV=FALSE
      ;;
    *)
      USE_DESKTOP_ENV=FALSE
      ;;
  esac
}

initForArch() {
  echo "Checking for some apps we need to make sure are there for this script to work"

  mapfile -t ARCH_APPS < <(curl -s https://raw.githubusercontent.com/jrock2004/Machstrap/main/archApps.txt)

  if [ -z "$(command -v git)" ]; then
    echo "Git is not installed. Installing now..."

    sudo pacman -S git
  fi

  if [ -z "$(command -v curl)" ]; then
    echo "Curl is not installed. Installing now..."

    sudo pacman -S curl
  fi

  if [ -z "$(command -v wget)" ]; then
    echo "Wget is not installed. Installing now..."

    sudo pacman -S wget
  fi

  echo "Checking for paru"

  if [ -z "$(command -v paru)" ]; then
    echo "Paru is not installed. Installing now..."

    git clone https://aur.archlinux.org/paru.git
    cd paru || exit 1
    makepkg -si
    cd ..
    rm -rf paru
  fi
}

initForDebian() {
  echo "Checking for some apps we need to make sure are there for this script to work"

  mapfile -t POP_APPS < <(curl -s https://raw.githubusercontent.com/jrock2004/Machstrap/main/popApps.txt)

  if [ -z "$(command -v git)" ]; then
    echo "Git is not installed. Installing now..."

    sudo apt-get install git
  fi

  if [ -z "$(command -v curl)" ]; then
    echo "Curl is not installed. Installing now..."

    sudo apt-get install curl
  fi

  if [ -z "$(command -v wget)" ]; then
    echo "Wget is not installed. Installing now..."

    sudo apt-get install wget
  fi
}

setupDirectories() {
  echo "Setting up directories"

  mkdir -p "$HOME/Development"

  if [ "$USE_DESKTOP_ENV" = FALSE ]; then
    mkdir -p "$HOME/Pictures"
    mkdir -p "$HOME/Pictures/avatars"
    mkdir -p "$HOME/Pictures/wallpapers"
  fi

  if [ -d "$DOTFILES" ]; then
    echo "Dotfiles directory already exists. Skipping..."
  else
    echo "Cloning dotfiles repo"

    git clone "$DOTFILES_REPO" "$DOTFILES"
  fi

  cd "$DOTFILES" || exit 1
}

installAppsForArch () {
  echo "Installing apps for arch"

  echo "${ARCH_APPS[@]}" | xargs paru -S

  if [ "$USE_DESKTOP_ENV" = "FALSE" ]; then
    echo "Installing some apps since we do not have a desktop environment"

    paru -S cronie firefox pavucontrol sddm-git

    sudo systemctl enable cronie.service
    sudo systemctl enable sddm.service

    sudo cp archfiles/slock@.service /etc/systemd/system/

    sudo systemctl enable slock@jcostanzo.service

    # Copy bluetooth keyboard rule
    curl -o /path/to/file https://example.com/file
    [ -d "/etc/udev/rules.d" ] && sudo curl -o /etc/udev/rules.d/91-keyboard-mouse-wakeup.conf https://raw.githubusercontent.com/jrock2004/Machstrap/main/91-keyboard-mouse-wakeup.conf
  fi
}

installAppsForDebian () {
  echo "Installing apps for debian based systems"

  echo "${POP_APPS[@]}" | xargs sudo apt-get install 

  # 1Password
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
  sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
  sudo apt update && sudo apt install 1password

  # Golang
  curl -OL https://golang.org/dl/go1.16.7.linux-amd64.tar.gz
  sudo tar -C /usr/local -xvf go1.16.7.linux-amd64.tar.gz
  rm go1.16.7.linux-amd64.tar.gz

  # Starship
  curl -sS https://starship.rs/install.sh | sh

  # Lazygit
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf lazygit.tar.gz lazygit
  sudo install lazygit /usr/local/bin
  rm lazygit.tar.gz
  rm lazygit
  rm -Rf ~/.config/lazygit
}

installAppsForMac () {
  echo "Installing apps for your mac"

  if [ -z "$(command -v brew)" ]; then
    sudo curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash --login

    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/jcostanzo/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  brew bundle
}

setupFzf () {
  echo "Setting up FZF"

  "$(brew --prefix)"/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
}

setupStow() {
  echo "Running Stow to link files"

  if [ "$CI" == true ]; then
    # Some things to do when running via CI
    rm -Rf ~/.gitconfig
  fi

  rm -Rf ~/.zshrc

  if [ "$(command -v brew)" ]; then
    rm -Rf ~/.zprofile

    "$(brew --prefix)"/bin/stow --ignore ".DS_Store" -v -R -t ~ -d "$DOTFILES" files
  elif [ "$(command -v stow)" ]; then
    /usr/bin/stow --ignore ".DS_Store" -v -R -t ~ -d "$DOTFILES" files
  fi
}

setupVolta() {
  echo "Setting up Volta"

  curl https://get.volta.sh | bash -s -- --skip-setup

  # For now volta needs this for node and stuff to work
  if [ "$OS" = "mac" ]; then
    softwareupdate --install-rosetta
  fi
}

setupLua() {
  echo "Setting up Lua"

  git clone https://github.com/sumneko/lua-language-server "$HOME/lua-language-server"
  cd "$HOME/lua-language-server" || exit 1
  git submodule update --init --recursive
  cd 3rd/luamake || exit 1
  compile/install.sh
  cd ../..
  ./3rd/luamake/luamake rebuild

  cd "$DOTFILES" || exit 1

  if [ "$(command -v luarocks)" ]; then
    luarocks install --server=https://luarocks.org/dev luaformatter
  else
    warning "luarocks is not in path. Need to run command after restart"
  fi
}

setupRust() {
  echo "Setting up Rust"

  curl https://sh.rustup.rs -sSf | sh
}

setupNeovim() {
  echo "Setting up Neovim"

  if [ "$OS" = "debian" ]; then
    python3 -m pip install --upgrade pynvim
  elif [ "$OS" = "arch" ]; then
    python3 -m pip install --upgrade pynvim
  elif [ "$(command -v python)" ]; then
    python -m pip install --upgrade pynvim
  fi
}

setupShell() {
  echo "Setting up shell"

  [[ -n "$(command -v brew)" ]] && zsh_path="$(brew --prefix)/bin/zsh" || zsh_path="$(which zsh)"
  if ! grep "$zsh_path" /etc/shells; then
    echo "$zsh_path" | sudo tee -a /etc/shells
  fi

  if [[ "$SHELL" != "$zsh_path" ]]; then
    chsh -s "$zsh_path"
  fi
}




# Ask to see which OS we are setting up
##############################################
initialQuestions

# Check if user select arch or popos
##############################################

if [ "$OS" = "arch" ]; then
  echo "Setting up $OS"

  initForArch
  setupDirectories
  installAppsForArch
  setupStow
  setupVolta
  setupRust
  setupNeovim
elif [ "$OS" = "popos" ]; then
  initForDebian
  setupDirectories
  installAppsForDebian
  setupStow
  setupVolta
  setupRust
  setupNeovim
elif [ "$OS" = "mac" ]; then
  setupDirectories
  installAppsForMac
  setupStow
  setupFzf
  setupVolta
  setupRust
  setupNeovim
else
  echo "Not ready yet"
  exit 1
fi


# Setup Zap ZSH
##############################################
echo "Setting up Zap ZSH"

zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh)


setupShell
