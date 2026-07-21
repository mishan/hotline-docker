# GtkHx CI base image.
#
# Fedora + the full GtkHx build/test dependency set, pre-installed so CI
# runs skip the per-run `dnf install` (which otherwise costs a couple of
# minutes downloading + installing on every job).
#
# The GtkHx repo's CI builds the tree TWICE — voice-disabled (no
# GStreamer) then voice-enabled — so historically it installed the base
# deps first and the GStreamer stack second. Here we bake BOTH sets in;
# a pre-built image can't lazily split them, and having GStreamer present
# for the voice-disabled build is harmless (that build just doesn't use
# it). The package list mirrors the two `dnf -y install` blocks in the
# GtkHx repo's .github/workflows/tests.yml — keep them in sync.
#
# Fedora is pinned to a major (43) so a surprise-breaking Fedora release
# doesn't silently change the toolchain under CI. 43 specifically because
# its glycin-loaders ship the 2+ loader protocol the `glycin` 3.x crate
# (and the GNOME 49 Flatpak runtime GtkHx targets) need.
#
# Build:   docker build -t gtkhx-ci-base images/ci-base
# Publish: pushed to ghcr.io/mishan/gtkhx-ci-base by
#          .github/workflows/publish-ci-base.yml
# Consume: see docs/consuming-in-gtkhx-ci.md

FROM fedora:43

# One layer, cache cleaned, so the published image stays lean.
#
#   meson/ninja/gcc/pkgconf ....... build system + compiler
#   gtk4 / libadwaita / glib / gir  toolkit
#   gsound ........................ chat alert playback
#   gettext ....................... i18n build
#   desktop-file-utils / appstream  validate-desktop / validate-metainfo tests
#   libpanel ...................... UI dep
#   libseccomp / lcms2 / fontconfig misc deps (glycin sandbox, colour, fonts)
#   glycin-loaders ................ hx-image-decode decode tests (2+ loaders)
#   git / rust / cargo ............ VCS + Rust workspace
#   mold .......................... fast linker (GtkHx CI links with `mold -run`)
#   libnice-gstreamer1 / libsoup3 / gstreamer1-* .. voice (WebRTC) stack
RUN dnf -y install \
        meson ninja-build pkgconf-pkg-config gcc \
        gtk4-devel libadwaita-devel \
        glib2-devel gobject-introspection-devel \
        gsound-devel \
        gettext-devel \
        desktop-file-utils appstream \
        libpanel-devel \
        libseccomp-devel lcms2-devel fontconfig-devel \
        glycin-loaders \
        git rust cargo \
        mold \
        libnice-gstreamer1 \
        libsoup3-devel \
        gstreamer1-devel \
        gstreamer1-plugins-base-devel \
        gstreamer1-plugins-bad-free-devel \
        gstreamer1-plugins-bad-free-extras \
        gstreamer1-plugins-good \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Sanity: print the toolchain versions at build time so the publish log
# records exactly what a given tag contains. (The GtkHx CI still runs its
# own MSRV assertion against the tree; this is just a build-time record.)
RUN gcc --version | head -1 \
    && meson --version \
    && rustc --version \
    && cargo --version \
    && mold --version | head -1
