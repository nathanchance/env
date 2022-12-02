#!/usr/bin/env python3

import shlex


def print_cmd(command):
    print(f"$ {' '.join([shlex.quote(str(elem)) for elem in command])}")


def print_color(color, string):
    print(f"{color}{string}\033[0m", flush=True)


def print_green(msg):
    print_color('\033[01;32m', msg)


def print_yellow(msg):
    print_color('\033[01;33m', msg)
