# Variables
##############################################
OS=""
USE_DESKTOP_ENV=FALSE
ARCH_APPS=()
DOTFILES="$HOME/.dotfiles"
DOTFILES_REPO="https://github.com/jrock2004/dotfiles.git"

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

  echo "Do you want to use brew? (y/[n])"

  read -rp "Use brew? " choice_brew

  case $choice_brew in
    y)
      USE_BREW=TRUE
      ;;
    n)
      USE_BREW=FALSE
      ;;
    *)
      USE_BREW=FALSE
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

  mapfile -t ARCH_APPS < ./archApps.txt


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

setupDirectories() {
  echo "Setting up directories"

  mkdir -p "$HOME/Development"

  if [ "$USE_DESKTOP_ENV" = FALSE ]; then
    mkdir -p "$HOME/Pictures"
    mkdir -p "$HOME/Pictures/avatars"
    mkdir -p "$HOME/Pictures/wallpapers"
  fi

  if [ ! -d "HOME/.dotfiles" ]; then
    echo "Dotfiles directory already exists. Skipping..."
  else
    echo "Cloning dotfiles repo"

    git clone "$DOTFILES_REPO $DOTFILES"
  fi

  cd "$HOME/.dotfiles" || exit 1
}

installAppsForArch () {
  echo "Installing apps for arch"

  echo "${ARCH_APPS[@]}" | xargs paru -S

  if [ "$USE_DESKTOP_ENV" = "FALSE" ]; then
    echo "Installing some apps for i3"

    paru -S cronie firefox pavucontrol sddm-git

    sudo systemctl enable cronie.service
    sudo systemctl enable sddm.service

    sudo cp archfiles/slock@.service /etc/systemd/system/

    sudo systemctl enable slock@jcostanzo.service

    # Copy bluetooth keyboard rule
    [ -d "/etc/udev/rules.d" ] && sudo cp files/91-keyboard-mouse-wakeup.conf /etc/udev/rules.d/
  fi
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
else
  echo "Not ready yet"
  exit 1
fi


# Setup Zap ZSH
##############################################
echo "Setting up Zap ZSH"

zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh)


setupShell
