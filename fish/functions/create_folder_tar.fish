#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function create_folder_tar -d "Create zstd compressed tarball of a folder"
    set folder $argv[1]
    if not test -d $folder
        print_error "$folder could not be found or is not a folder!"
        return 1
    end

    set output $TMP_FOLDER/(basename $folder)-(date +%Y-%m-%d-%H-%M).tar.zst

    tar \
        --create \
        --exclude-from $ENV_FOLDER/configs/common/tar-excludes \
        --directory (dirname $folder) \
        --file $output \
        --zstd \
        (basename $folder)

    echo
    echo "File is now available at: "(string replace $TMP_FOLDER '$TMP_FOLDER' $output)
end
