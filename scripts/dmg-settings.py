"""Finder layout for the drag-to-install disk image (loaded by dmgbuild)."""
from pathlib import Path

application = str(Path(defines['app']).resolve())
files = [application]
symlinks = {'Applications': '/Applications'}
format = 'UDZO'
filesystem = 'HFS+'
background = 'builtin-arrow'
icon = str(Path(application) / 'Contents/Resources/AppIcon.icns')
icon_locations = {'Promecapt.app': (140, 120), 'Applications': (500, 120)}
window_rect = ((200, 160), (640, 300))
default_view = 'icon-view'
icon_size = 96
text_size = 14
show_toolbar = False
show_sidebar = False
show_status_bar = False
show_pathbar = False
show_tab_view = False
