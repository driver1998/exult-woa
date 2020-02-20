
NATIVE_BIN=$PWD/native_bin
mkdir $NATIVE_BIN

# Build native exult for tools
pushd exult
for p in ../patches/exult/*.patch; do patch -p1 < "$p"; done
./autogen.sh
./configure || exit 1
make -j $(nproc) || exit 1
cp usecode/ucxt/head2data tools/expack $NATIVE_BIN
make distclean
popd

export HOST=$ARCH-w64-mingw32
export PREFIX=$PWD/$HOST
export MINGW_ROOT=$PWD/$(find llvm-mingw* -maxdepth 1 -type d | head -n 1)
export PATH=$PATH:$MINGW_ROOT/bin:$NATIVE_BIN:$PREFIX/bin
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$PREFIX/lib/pkgconfig

export CFLAGS="-O2 -I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib"
export CXXFLAGS=$CFLAGS
export CPPFLAGS=$CFLAGS

echo Building for $HOST

# For some reason MinGW ARM is missing serveral libs compared to x86
# Build lib for $ARCH from i686 version
# $1 : The lib filename, in MinGW convention
#      xyz.dll -> libxyz.a
function build_lib() {
    LIBFILE=$1
    MODULE=$(echo $LIBFILE | sed 's/lib\(.*\?\)\.a/\1/g')
    DLLFILE=$(echo $MODULE | tr '/a-z/' '/A-Z/').dll
    (
        echo LIBRARY $DLLFILE
        echo EXPORTS
        $HOST-nm $MINGW_ROOT/i686-w64-mingw32/lib/$LIBFILE --just-symbol-name |
            sed '/^$/d' | sed "/^$DLLFILE/d" | sed '/\.idata/d' | sed '/__imp/d' | sed '/__NULL_IMPORT/d' |
            sed '/_NULL_THUNK_DATA/d' | sed '/__IMPORT_DESCRIPTOR/d' | sed 's/@.*$//g' | sed 's/^_//g'
    ) > $MODULE.def
    $HOST-dlltool -d $MODULE.def -l $MINGW_ROOT/$HOST/lib/$LIBFILE
}

if [ $ARCH == "aarch64" ]; then build_lib "libsetupapi.a"; fi

# zlib
pushd $(find zlib-* -maxdepth 1 -type d | head -n 1)
make -j $(nproc) -f win32/Makefile.gcc PREFIX=$HOST- || exit 1
make -f win32/Makefile.gcc install SHARED_MODE=1 \
     BINARY_PATH=$PREFIX/bin \
     INCLUDE_PATH=$PREFIX/include \
     LIBRARY_PATH=$PREFIX/lib || exit 1
popd

# libpng
pushd $(find libpng-* -maxdepth 1 -type d | head -n 1)
./configure --prefix=$PREFIX --host=$HOST || exit 1
make -j $(nproc) || exit 1
make install     || exit 1
popd

# libogg
pushd $(find libogg-* -maxdepth 1 -type d | head -n 1)
./configure --prefix=$PREFIX --host=$HOST || exit 1
make -j $(nproc) || exit 1
make install     || exit 1
popd

# libvorbis
pushd $(find libvorbis-* -maxdepth 1 -type d | head -n 1)
./configure --prefix=$PREFIX --host=$HOST || exit 1
make -j $(nproc) || exit 1
make install     || exit 1
popd

# SDL2
pushd $(find SDL2-* -maxdepth 1 -type d | head -n 1)
patch -p1 < ../patches/sdl2-fix-arm-build.patch
aclocal
autoconf
./configure --prefix=$PREFIX --host=$HOST --disable-video-opengl \
            --disable-video-opengles --disable-video-opengles1 \
            --disable-video-opengles2 --disable-video-vulkan || exit 1
make -j $(nproc) || exit 1
make install     || exit 
popd

pushd $PREFIX/bin
sed -i 's/-Dmain=SDL_main//g' sdl2-config
popd


# exult
pushd exult
./configure --prefix=$PREFIX --host=$HOST || exit 1
make -j $(nproc) || exit 1
make install     || exit 1
popd
