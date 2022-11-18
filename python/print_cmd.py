#!/usr/bin/env python3

import shlex
import sys

if __name__ == '__main__':
    print(' '.join([shlex.quote(arg) for arg in sys.argv[1:]]))
