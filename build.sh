#!/bin/bash

# Colors
NC='\033[0m'
RED='\033[0;31m'
LRD='\033[1;31m'
LGR='\033[1;32m'

# Set default variables
kernel_dir="${PWD}"
CCACHE=$(command -v ccache)
objdir="${kernel_dir}/out"
anykernel="$HOME/kernel/AnyKernel3"
kernel_name="Requiem-Nightly"
export ARCH="arm64"
export KBUILD_BUILD_HOST="Requiem"
export KBUILD_BUILD_USER="Rasenkai"
export DEFCONFIG="waipio-gki_defconfig"
BASE_DEFCONFIG="gki_defconfig"
FRAGMENT_CONFIG="vendor/cupid_GKI.config"

export PATH="$HOME/kernel/toolchain/clang-r416183b/bin:${PATH}"

# Function: Generate defconfig
make_defconfig() {
    START=$(date +"%s")
    echo -e "${LGR}" "############### Cleaning ################${NC}"
    rm "$anykernel"/dtb*
    rm "$anykernel"/Image*

    echo -e "${LGR}" "########### Generating Defconfig ############${NC}"
    make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-O3 "$DEFCONFIG"
}

# Function: Compile kernel
compile() {
    cd "$kernel_dir"
    echo -e "${LGR}" "######### Compiling kernel #########${NC}"
    make ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-O3 O=out -j$(nproc --all)
}

# Function: Package the output
completion() {
    cd "$objdir"
    zip_name="$kernel_name-$(date +"%d%m%Y")-ZEUS.zip"
    COMPILED_IMAGE=arch/arm64/boot/Image
    mv -f "$COMPILED_IMAGE" "$anykernel"
    cd "$anykernel"
    find . -name "*.zip" -type f -delete
    zip -r AnyKernel.zip *
    mv AnyKernel.zip "$zip_name"
    mv "$anykernel"/"$zip_name" "$output_path"/"$zip_name"
    END=$(date +"%s")
    DIFF=$(($END - $START))
    echo -e "${LGR}" "############################################"
    echo -e "${LGR}" "############# OkThisIsEpic!  ##############"
    echo -e "${LGR}" "############################################${NC}"
}

# Function: Print usage message
print_usage() {
    echo "Usage: $0 [OPTION]"
    echo "Options:"
    echo "  -r, --regen          Regenerate defconfig"
    echo "  -rf, --regen-full    Regenerate defconfig without fragments"
    echo "  -m, --merge-fragments Merge defconfig with GKI fragments"
    echo "  -b, --build          Build the kernel"
    echo "  -h, --help           Display this help message"
    exit 1
}

# Main script
if [[ $# -eq 0 ]]; then
    print_usage
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
    -r | --regen)
        make_defconfig
        git diff --exit-code || (echo -e "${LRD}Error: There are uncommitted changes. Commit or stash them before regenerating defconfig.${NC}" && exit 1)
        cp out/defconfig arch/arm64/configs/"$DEFCONFIG"
        git commit -am "defconfig: regenerate"
        echo -e "\n${LGR}BUILD HELPER:${NC} ${LGR}Successfully regenerated defconfig at${NC} $DEFCONFIG"
        shift
        ;;
    -rf | --regen-full)
        export ARCH=arm64
        make "$DEFCONFIG"
        git diff --exit-code || (echo -e "${LRD}Error: There are uncommitted changes. Commit or stash them before regenerating defconfig.${NC}" && exit 1)
        cp .config arch/arm64/configs/"$DEFCONFIG"
        git commit -am "defconfig: regenerate"
        shift
        ;;
    -m | --merge-fragments)
        KCONFIG_CONFIG=arch/arm64/configs/"$DEFCONFIG" \
            scripts/kconfig/merge_config.sh -m -r \
            arch/arm64/configs/"$BASE_DEFCONFIG" \
            arch/arm64/configs/"$FRAGMENT_CONFIG"
        echo -e "\n${LGR}BUILD HELPER:${NC} ${LGR}Successfully generated defconfig from GKI fragments at${NC} $DEFCONFIG"
        shift
        ;;
    -b | --build)
        output_path="$HOME/Desktop" # Change this to the desired output directory
        make_defconfig
        compile
        completion
        shift
        ;;
    -h | --help)
        print_usage
        shift
        ;;
    *)
        echo "Invalid option: $1"
        print_usage
        exit 1
        ;;
    esac
done

cd "$kernel_dir"
