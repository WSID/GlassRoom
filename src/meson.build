glass_room_sources = [
  'main.vala',
  'application.vala',
  'window.vala',
]

glass_room_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('gstreamer-1.0')
]

gnome = import('gnome')

glass_room_sources += gnome.compile_resources('glass_room-resources',
  'glass_room.gresource.xml',
  c_name: 'glass_room'
)

executable('glass-room', glass_room_sources,
  vala_args: '--target-glib=2.50',  dependencies: glass_room_deps,
  install: true,
)
