# dmgbuild settings for the Circle Sans installer disk image.
#
# The window is a 640x480 Finder icon view over the background from
# render-installer-art.py: the wordmark on dark green above, a white band below.
# The app sits on the right so its Finder label lands in the band, where Finder's
# black label text can be read - Finder gives no say over the label colour.
#
# How much of the window is content depends on the viewer's Finder: the title bar
# alone takes about 60 points, a path bar another 30. The background is taller
# than the window, so whatever the viewer has, the image never runs out; the
# instruction and the app's label stay above the 380-point line.
#
# Used by build-installer-dmg.sh; the paths arrive as -D defines.

app = defines["app"]
background = defines["background"]
icon = defines.get("icon")  # the volume icon, so the mounted image shows the Aa too

files = [app]
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

icon_size = 128
text_size = 13
label_pos = "bottom"
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
icon_locations = {"Install Circle Sans.app": (500, 240)}
