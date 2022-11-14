#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_rb_fd -d "Rebase generic Fedora kernel on latest linux-next"
    in_container_msg -c; or return

    set fd_src $CBL_BLD/fedora
    pushd $fd_src; or return

    # Update and patch kernel
    git ru --prune origin; or return
    git rh origin/master

    # Patching
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end

    echo "diff --git a/drivers/gpu/drm/amd/display/dc/core/dc.c b/drivers/gpu/drm/amd/display/dc/core/dc.c
index 9c3704c4d7e4..f4e0605a9d01 100644
--- a/drivers/gpu/drm/amd/display/dc/core/dc.c
+++ b/drivers/gpu/drm/amd/display/dc/core/dc.c
@@ -1130,10 +1130,12 @@ static void disable_dangling_plane(struct dc *dc, struct dc_state *context)
 			 * The OTG is set to disable on falling edge of VUPDATE so the plane disable
 			 * will still get it's double buffer update.
 			 */
+#ifdef CONFIG_DRM_AMD_DC_DCN
 			if (old_stream->mall_stream_config.type == SUBVP_PHANTOM) {
 				if (tg->funcs->disable_phantom_crtc)
 					tg->funcs->disable_phantom_crtc(tg);
 			}
+#endif
 		}
 	}
 " | git ap; or return
    git ac -m "drm/amd/display: Guard usage of ->disable_phantom_crtc()

Link: https://lore.kernel.org/Y20bFlEcKX3gbge8@dev-arch.thelio-3990X/"

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
