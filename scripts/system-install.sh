#!/usr/bin/env bash

set -eu -o pipefail

export SUDO=""
if command -v sudo && sudo true; then
	export SUDO=sudo
fi

function update_llvm_alternative {
    if ! command -v update-alternatives >/dev/null; then
        echo "[ERROR] could not find update-alternatives"
        exit 1
    fi

	VERSION="$1"
	$SUDO update-alternatives \
		--install /usr/bin/clang clang "/usr/bin/clang-$VERSION" 700 \
		--slave /usr/bin/clang++ clang++ "/usr/bin/clang++-$VERSION" \
		--slave /usr/bin/clang-cpp clang-cpp "/usr/bin/clang-cpp-$VERSION"

	$SUDO update-alternatives \
		--install /usr/bin/llvm-config llvm-config "/usr/bin/llvm-config-$VERSION" 200 \
		--slave /usr/bin/llvm-ar llvm-ar "/usr/bin/llvm-ar-$VERSION" \
		--slave /usr/bin/llvm-as llvm-as "/usr/bin/llvm-as-$VERSION" \
		--slave /usr/bin/llvm-bcanalyzer llvm-bcanalyzer "/usr/bin/llvm-bcanalyzer-$VERSION" \
		--slave /usr/bin/llvm-cov llvm-cov "/usr/bin/llvm-cov-$VERSION" \
		--slave /usr/bin/llvm-diff llvm-diff "/usr/bin/llvm-diff-$VERSION" \
		--slave /usr/bin/llvm-dis llvm-dis "/usr/bin/llvm-dis-$VERSION" \
		--slave /usr/bin/llvm-dwarfdump llvm-dwarfdump "/usr/bin/llvm-dwarfdump-$VERSION" \
		--slave /usr/bin/llvm-extract llvm-extract "/usr/bin/llvm-extract-$VERSION" \
		--slave /usr/bin/llvm-link llvm-link "/usr/bin/llvm-link-$VERSION" \
		--slave /usr/bin/llvm-mc llvm-mc "/usr/bin/llvm-mc-$VERSION" \
		--slave /usr/bin/llvm-mcmarkup llvm-mcmarkup "/usr/bin/llvm-mcmarkup-$VERSION" \
		--slave /usr/bin/llvm-nm llvm-nm "/usr/bin/llvm-nm-$VERSION" \
		--slave /usr/bin/llvm-objdump llvm-objdump "/usr/bin/llvm-objdump-$VERSION" \
		--slave /usr/bin/llvm-ranlib llvm-ranlib "/usr/bin/llvm-ranlib-$VERSION" \
		--slave /usr/bin/llvm-readobj llvm-readobj "/usr/bin/llvm-readobj-$VERSION" \
		--slave /usr/bin/llvm-rtdyld llvm-rtdyld "/usr/bin/llvm-rtdyld-$VERSION" \
		--slave /usr/bin/llvm-size llvm-size "/usr/bin/llvm-size-$VERSION" \
		--slave /usr/bin/llvm-stress llvm-stress "/usr/bin/llvm-stress-$VERSION" \
		--slave /usr/bin/llvm-symbolizer llvm-symbolizer "/usr/bin/llvm-symbolizer-$VERSION" \
		--slave /usr/bin/llvm-tblgen llvm-tblgen "/usr/bin/llvm-tblgen-$VERSION"
}

if command -v pacman; then
	$SUDO pacman -Syu --noconfirm --needed
	$SUDO pacman-db-upgrade
	$SUDO pacman -Syu --noconfirm --needed \
		git wget curl unzip bash jq python python-pip \
		clang llvm lld libc++ \
		meson cmake ninja \
		libunwind binutils \
		rust rust-analyzer \
		time \
		jq \
		gdb

	$SUDO pacman -Scc --noconfirm
fi

if command -v apt-get; then
	export DEBIAN_FRONTEND=noninteractive
	$SUDO apt-get update -q
	if ! command -v lsb_release; then
		$SUDO apt-get install -q -y lsb-release
	fi
	$SUDO apt-get full-upgrade -q -y

	codename="$(lsb_release -sc)"
	if [[ "$codename" == "focal" ]]; then
		echo "[+] Warning: Ubuntu Focal is not well tested/supported"
		if ! grep 'focal-updates' /etc/apt/sources.list; then
			echo "[!] focal-updates must be enabled for LLVM 11!"
			echo "...enabling now!"
			cat /etc/apt/source.list |
				grep "focal main" |
				sed 's/focal/focal-updates/g' \
					>/etc/apt/sources.list.d/00-lts-updates.list
		fi
		$SUDO apt-get update -q
		$SUDO apt-get install libstdc++-10-dev gcc-9-plugin-dev
    elif [[ "$codename" == "groovy" ]]; then
        $SUDO apt-get install \
            llvm-11 clang-11 llvm-11-dev llvm-11-tools lld-11 clang-format-11 \
            libc++1-11 libc++-11-dev libc++abi1-11 libc++abi-11-dev
    elif [[ "$codename" == "hirsute" ]]; then
        $SUDO apt-get install \
            llvm-12 clang-12 llvm-12-dev llvm-12-tools lld-12 clang-format-12 \
            libc++1-12 libc++-12-dev libc++abi1-12 libc++abi-12-dev
    elif [[ "$codename" == "impish" ]]; then
        $SUDO apt-get install \
            llvm-13 clang-13 llvm-13-dev llvm-13-tools lld-13 clang-format-13 \
            libc++1-13 libc++-13-dev libc++abi1-13 libc++abi-13-dev
	else
		echo "[+] Warning: debian-based distribution, which was not tested/supported"
		lsb_release -a
		echo "here be dragons"
	fi

	$SUDO apt-get install -q -y \
		git wget curl unzip subversion \
		build-essential cmake meson ninja-build automake autoconf texinfo flex bison pkg-config \
		binutils-multiarch binutils-multiarch-dev \
		libfontconfig1-dev libgraphite2-dev libharfbuzz-dev libicu-dev libssl-dev zlib1g-dev \
		libtool-bin python3-dev libglib2.0-dev libpixman-1-dev clang python3-setuptools llvm \
		python3 python3-dev python3-pip python-is-python3 \
		bash \
		gcc-multilib gcc-10-multilib \
		libunwind-dev libunwind8 \
		gcc-10-plugin-dev \
		jq \
		time \
		gdb
	$SUDO apt-get clean -y

	if [[ "$(llvm-config --version)" == 13* ]]; then
		echo "[+] LLVM 13 set up"
	elif [[ "$(llvm-config --version)" == 12* ]]; then
		echo "[+] LLVM 12 set up"
	elif [[ "$(llvm-config --version)" == 11* ]]; then
		echo "[+] LLVM 11 set up"
	else
		if command -v llvm-config-13; then
			echo "[+] defaulting to LLVM 13"
			update_llvm_alternative 13
		elif command -v llvm-config-12; then
			echo "[+] defaulting to LLVM 12"
			update_llvm_alternative 12
		elif command -v llvm-config-11; then
			echo "[+] defaulting to LLVM 11"
			update_llvm_alternative 11
        else
			echo "[ERROR] cannot find proper LLVM. Are you sure a proper LLVM (>= 11) is installed?"
            if command -v llvm-config >/dev/null; then
                echo "found llvm-config but for unsupported version:"
                llvm-config --version
            fi
			exit 1
		fi
	fi

	if ! command -v rustup; then
		echo "installing rustup!"
		wget -q -O /tmp/rustup.sh https://sh.rustup.rs && sh /tmp/rustup.sh -y
		echo "make sure to set your PATH to contains '\$HOME/.cargo/bin'"
		echo "or to 'source \"\$HOME/.cargo/env\"'"
	fi
	source "$HOME/.cargo/env"
fi

if [[ "$UPDATE_MODULES" -eq 1 || -z "$UPDATE_MODULES" ]]; then
    git submodule update --init
elif [[ "$UPDATE_MODULES" == "bump" ]]; then
    make bump
fi

export EFCF_INSTALL_PATH="$(realpath "$PWD")"

pushd src/AFLplusplus
make clean
# make source-only NO_SPLICING=1 NO_PYTHON=1 NO_NYX=1
make source-only NO_PYTHON=1 NO_NYX=1
$SUDO make install
popd

# we install all kinds of solidity versions using solc-select
PIP=$(command -v pip3 || echo pip)
$PIP install -U solc-select
export PATH=$PATH:$HOME/.local/bin/:$HOME/.solc-select:$HOME/.solc-select/artifacts/
solc-select install all

pushd src/evm2cpp
make clean
make
$SUDO make install
popd >/dev/null

pushd src/ethmutator
make clean
make
$SUDO make install
popd >/dev/null

pushd src/launcher
$SUDO pip install .
popd >/dev/null

pushd "$HOME"
if ! grep "EFCF" .bashrc; then
	cat >>.bashrc <<EOF
# ----
# EFCF PATH setup
source "\$HOME/.cargo/env"
export PATH=\$PATH:\$HOME/.local/bin/:\$HOME/.solc-select:\$HOME/.solc-select/artifacts/
export EFCF_INSTALL_PATH=$EFCF_INSTALL_PATH
# ----
EOF
fi
popd
