#!/usr/bin/env python3

import shlex
import sys

if __name__ == '__main__':
    print(' '.join([shlex.quote(argv[num]) for num in range(1, len(sys.argv))]))
