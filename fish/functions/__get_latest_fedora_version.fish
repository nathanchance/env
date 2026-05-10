#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function __get_latest_fedora_version -d "Get latest stable Fedora version number"
    crl https://fedoraproject.org/releases.json | python3 -c "import json, sys; print(max({int(item['version']) for item in json.load(sys.stdin)}))"
end
