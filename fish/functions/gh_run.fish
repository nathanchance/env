#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function gh_run -d "Run GitHub Actions Workflow"
    if test (count $argv) -lt 3
        print_error "Expected repo, branch name, and workflow as arguments, in that order!"
        return 1
    end

    set repo $argv[1]
    set branch $argv[2]
    set workflow $argv[3]
    set run_args $argv[4..-1]

    gh workflow run \
        --ref $branch \
        --repo $repo \
        $run_args \
        $workflow

    # Make sure that 'gh run list' call succeeds
    sleep 3

    set json_key databaseId
    set workflow_id (gh run list \
        --json $json_key \
        --jq .[].$json_key \
        --limit 1 \
        --repo $repo \
        --workflow $workflow)

    gh run view \
        --repo $repo \
        $workflow_id
end
