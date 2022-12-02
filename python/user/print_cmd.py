#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

import sys

import lib_user

if __name__ == '__main__':
    lib_user.print_cmd(sys.argv[1:])
