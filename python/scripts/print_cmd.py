#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils  # noqa: E402
# pylint: enable=wrong-import-position

if __name__ == '__main__':
    lib.utils.print_cmd(sys.argv[1:])
