# dmgbuild settings for the Circle Sans installer disk image.
#
# The window is a 640x480 Finder icon view over the background from
# render-installer-art.py: the wordmark over the film above, a white band below.
# Two kinds of image share it: -D app=... holds the installer app, -D fonts=... the
# font files themselves (shipped while the app cannot be signed - fonts are data,
# so Font Book opens them with no Gatekeeper prompt). Either way the icons sit on
# the right so their Finder labels land in the band, where Finder's black label
# text can be read - Finder gives no say over the label colour.
#
# How much of the window is content depends on the viewer's Finder: the title bar
# alone takes about 60 points, a path bar another 30. The background is taller
# than the window, so whatever the viewer has, the image never runs out; the
# instruction and the app's label stay above the 380-point line.
#
# Used by build-installer-dmg.sh; the paths arrive as -D defines.

import os

background = defines["background"]
icon = defines.get("icon")  # the volume icon, so the mounted image shows the Aa too

if "fonts" in defines:
    fonts_dir = defines["fonts"]
    names = sorted(
        (n for n in os.listdir(fonts_dir) if n.lower().endswith(".ttf")),
        key=lambda n: ("Italic" in n, n),  # upright first
    )
    files = [os.path.join(fonts_dir, n) for n in names]
    icon_size = 112
    text_size = 12
    grid_spacing = 150  # wide enough that the file names are not truncated
    slots = [(420, 236), (560, 236)]
    icon_locations = {n: slots[i] for i, n in enumerate(names[:2])}
else:
    files = [defines["app"]]
    icon_size = 128
    text_size = 13
    grid_spacing = 100
    icon_locations = {os.path.basename(defines["app"]): (500, 236)}

symlinks = {}
format = "UDZO"
compression_level = 9

window_rect = ((200, 140), (640, 480))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 180

label_pos = "bottom"
arrange_by = None
grid_offset = (0, 0)
scroll_position = (0, 0)
