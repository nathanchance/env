#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

import shlex
import sys

if __name__ == '__main__':
    print(' '.join([shlex.quote(arg) for arg in sys.argv[1:]]))
