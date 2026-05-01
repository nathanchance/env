#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function create_forgejo_runner_vm -d "Easily create and deploy a Forgejo runner virtual machine"
    switch $UTS_MACH
        case aarch64
            set cpu host-passthrough
            set distro fedora
            # needed because docker only supports up to Fedora 44
            set -a mkosi_build_args --release 44
            # libvirt might not support fedora-44 as an option, just use rawhide
            set osinfo fedora-rawhide

        case x86_64
            set cpu host-model
            set distro arch
            set osinfo archlinux
    end
    if not set -q vcpus
        set vcpus (math (nproc) / 8)
        if test $vcpus -gt 8
            set vcpus 8
        end
    end
    if test $vcpus -lt 2
        set vcpus 2
    end
    if not set memory (math $vcpus x 2048) # 2GB for each core
        __print_error "vcpus value ('$cpus') likely wrong?"
        return 1
    end

    set libvirt_store $VM_FOLDER/libvirt
    mkdir -p $libvirt_store
    set base_vm_hostname forgejo-runner-$hostname-(string replace _ - $UTS_MACH)
    set vm_hostname $base_vm_hostname-(math (path filter -f $libvirt_store/$base_vm_hostname-*.raw | count) + 1)

    if not set -q output_size
        set output_size 50G
    end

    # Create disk image
    run_mkosi build \
        env \
        --distribution $distro \
        --hostname $vm_hostname \
        --image-id $vm_hostname \
        --output-directory $libvirt_store/$vm_hostname \
        --output-size $output_size \
        --profile bootable,forgejo-runner \
        $mkosi_build_args
    or return

    # Move disk image to proper location
    set old_disk_img $libvirt_store/$vm_hostname/disk.img.raw
    set new_disk_img $libvirt_store/$vm_hostname.raw
    begin
        run0 mv -v $old_disk_img $new_disk_img
        and run0 chown $USER:$USER $new_disk_img
        and run0 rm -fr (path dirname $old_disk_img)
    end
    or return

    # Create virtual machine from disk image
    virt-install \
        --name $vm_hostname \
        --vcpus $vcpus \
        --memory $memory \
        --cpu $cpu \
        --network network=default \
        --boot uefi \
        --osinfo $osinfo \
        --disk $new_disk_img \
        --import \
        --virt-type kvm \
        --console pty,target_type=serial \
        --graphics none \
        --autoconsole none
    or return

    # Automatically start virtual machine on boot
    virsh autostart $vm_hostname
end
