#!/bin/bash

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'

# Check if the home directory and linuxtoolbox folder exist, create them if they don't
LINUXTOOLBOXDIR="$HOME/linuxtoolbox"

if [ ! -d "$LINUXTOOLBOXDIR" ]; then
    echo "${YELLOW}Creating linuxtoolbox directory: $LINUXTOOLBOXDIR${RC}"
    mkdir -p "$LINUXTOOLBOXDIR"
    echo "${GREEN}linuxtoolbox directory created: $LINUXTOOLBOXDIR${RC}"
fi

if [ -d "$LINUXTOOLBOXDIR/mybash" ]; then rm -rf "$LINUXTOOLBOXDIR/mybash"; fi

echo "${YELLOW}Cloning mybash repository into: $LINUXTOOLBOXDIR/mybash${RC}"
git clone https://github.com/xicor22/mybash "$LINUXTOOLBOXDIR/mybash"
if [ $? -eq 0 ]; then
    echo "${GREEN}Successfully cloned mybash repository${RC}"
else
    echo "${RED}Failed to clone mybash repository${RC}"
    exit 1
fi

# add variables to top level so can easily be accessed by all functions
PACKAGER=""
SUDO_CMD=""
SUGROUP=""
GITPATH=""

cd "$LINUXTOOLBOXDIR/mybash" || exit

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

installDepend() {
    ## Check for dependencies.
    DEPENDENCIES='bash bash-completion tar bat tree multitail wget unzip fontconfig'
    if ! command_exists nvim; then
        DEPENDENCIES="${DEPENDENCIES} neovim"
    fi

    echo "${YELLOW}Installing dependencies...${RC}"
    ${SUDO_CMD} ${PACKAGER} install -yq ${DEPENDENCIES}

    # Check to see if the JetBrains Mono Nerd Font is installed (Change this to whatever font you would like)
    FONT_NAME="JetBrainsMono Nerd Font"
    if fc-list :family | grep -iq "$FONT_NAME"; then
        echo "Font '$FONT_NAME' is installed."
    else
        echo "Installing font '$FONT_NAME'"
        # Change this URL to correspond with the correct font
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
        FONT_DIR="$HOME/.local/share/fonts"
        # check if the file is accessible
        if wget -q --spider "$FONT_URL"; then
            TEMP_DIR=$(mktemp -d)
            wget -q --show-progress $FONT_URL -O "$TEMP_DIR"/"${FONT_NAME}".zip
            unzip "$TEMP_DIR"/"${FONT_NAME}".zip -d "$TEMP_DIR"
            mkdir -p "$FONT_DIR"/"$FONT_NAME"
            mv "${TEMP_DIR}"/*.ttf "$FONT_DIR"/"$FONT_NAME"
            # Update the font cache
            fc-cache -fv
            # delete the files created from this
            rm -rf "${TEMP_DIR}"
            echo "'$FONT_NAME' installed successfully."
        else
            echo "Font '$FONT_NAME' not installed. Font URL is not accessible."
        fi
    fi
}

installFzf() {
    if command_exists fzf; then
        echo "Fzf already installed"
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install
    fi
}

installZoxide() {
    if command_exists zoxide; then
        echo "Zoxide already installed"
        return
    fi

    if ! curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
        echo "${RED}Something went wrong during zoxide install!${RC}"
        exit 1
    fi
}

create_fastfetch_config() {
    wget https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-aarch64.deb >> /dev/null 2>&1
    sudo dpkg -i fastfetch-linux-aarch64.deb
    rm fastfetch-linux-aarch64.deb
    ## Get the correct user home directory.
    USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
    
    if [ ! -d "$USER_HOME/.config/fastfetch" ]; then
        mkdir -p "$USER_HOME/.config/fastfetch"
    fi
    # Check if the fastfetch config file exists
    if [ -e "$USER_HOME/.config/fastfetch/config.jsonc" ]; then
        rm -f "$USER_HOME/.config/fastfetch/config.jsonc"
    fi
    ln -svf "$GITPATH/config.jsonc" "$USER_HOME/.config/fastfetch/config.jsonc" || {
        echo "${RED}Failed to create symbolic link for fastfetch config${RC}"
        exit 1
    }
}

linkConfig() {
    ## Get the correct user home directory.
    USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
    ## Check if a bashrc file is already there.
    OLD_BASHRC="$USER_HOME/.bashrc"
    if [ -e "$OLD_BASHRC" ]; then
        echo "${YELLOW}Moving old bash config file to $USER_HOME/.bashrc.bak${RC}"
        if ! mv "$OLD_BASHRC" "$USER_HOME/.bashrc.bak"; then
            echo "${RED}Can't move the old bash config file!${RC}"
            exit 1
        fi
    fi

    echo "${YELLOW}Linking new bash config file...${RC}"
    ln -svf "$GITPATH/.bashrc" "$USER_HOME/.bashrc" || {
        echo "${RED}Failed to create symbolic link for .bashrc${RC}"
        exit 1
    }
}


installDepend
installFzf
installZoxide
create_fastfetch_config

if linkConfig; then
    echo "${GREEN}Done!\nrestart your shell to see the changes.${RC}"
else
    echo "${RED}Something went wrong!${RC}"
fi
