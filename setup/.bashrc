# ccache setup
export USE_CCACHE=1
ccache -M 200G

# Add Scripts directory and its subdirectories to $PATH
export PATH="${PATH}$(find ${HOME}/Scripts -name '.*' -prune -o -type d -printf ':%p')"

# Log support
export LOGDIR=${HOME}/Logs
export LOG=${LOGDIR}/Results/compile_log_$( TZ=MST date +%m_%d_%y ).log

# Export for building on Arch
export LC_ALL=C

# Build tools into PATH
export PATH=${PATH}:${HOME}/Misc/android-sdk-linux/build-tools/24.0.3

# git aliases
alias gcp='git cherry-pick'
alias gf='git fetch'
alias gpo='git push origin'
alias gpf='git push origin --force'
alias gpsu='git push --set-upstream origin'
alias ga='git add .'
alias gc='git commit'
alias gca='git commit --amend'
alias grh='git reset --hard'
alias gl='git log --format="%H: %s"'
alias gb='git branch -v'
alias gbd='git branch -D'
alias gs='git status'
alias gr='git remote'

# Flash build function
function flash_build {
   case ${1} in
      "shamu")
         export CROSS_COMPILE=/home/nathan/Kernels/Toolchains/Linaro/out/linaro-arm-eabi-6.x/bin/arm-eabi-
         export ARCH=arm
         export SUBARCH=arm ;;
      "angler")
         export CROSS_COMPILE="/home/nathan/Kernels/Toolchains/Linaro/out/aarch64-linux-android-6.x-kernel/bin/aarch64-linux-android-"
         export ARCH=arm64
         export SUBARCH=arm64 ;;
   esac

   make clean
   make mrproper
   make flash_defconfig
   make -j8
}

# Update Linux mirror function
function linux_mirror {
   cd ${HOME}/Kernels/linux
   git fetch -p origin
   git push --mirror
}
