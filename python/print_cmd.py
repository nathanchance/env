#!/usr/bin/env python3

from sys import argv
from shlex import quote

if __name__ == '__main__':
    print(' '.join([quote(argv[num]) for num in range(1, len(argv))]))
