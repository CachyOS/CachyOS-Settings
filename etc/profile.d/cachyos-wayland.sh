if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    export WAYLAND=1
    export QT_QPA_PLATFORM='wayland;xcb'
    export GDK_BACKEND='wayland,x11'
    export MOZ_DBUS_REMOTE=1
    export MOZ_ENABLE_WAYLAND=1
    export _JAVA_AWT_WM_NONREPARENTING=1
    export BEMENU_BACKEND=wayland
    export CLUTTER_BACKEND=wayland
    export ECORE_EVAS_ENGINE=wayland_egl
    export ELM_ENGINE=wayland_egl
fi
