-- Original NVIDIA laptop profile. Opt in with:
-- ./install.sh --hardware-profile original
-- Monitors are handled dynamically by modules/monitors.lua (internal panel off
-- while an external output is connected).
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GL_GSYNC_ALLOWED", "1")
hl.env("__GL_VRR_ALLOWED", "1")
