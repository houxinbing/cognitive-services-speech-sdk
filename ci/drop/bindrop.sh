#!/bin/bash

USAGE="Usage: $0 platform configuration destination"

PLATFORM="${1?$USAGE}"
CONFIG="${2?$USAGE}"
DEST="${3?$USAGE}"
TARGET="${4-UNKNOWN}"

echo "PLATFORM = $PLATFORM"
echo "CONFIG = $CONFIG"
echo "DEST = $DEST"
echo "TARGET = $TARGET"

set -e -x -o pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Ensure Unix paths on Windows from here on
if [[ $OS = "Windows_NT" ]]; then
  DEST="$(cygpath --unix --absolute "$DEST")"
  SCRIPT_DIR="$(cygpath --unix --absolute "$SCRIPT_DIR")"
fi

SOURCE_ROOT="$SCRIPT_DIR/../.."
BUILD_ROOT="$SOURCE_ROOT/build/$PLATFORM"

SRCJAR="$BUILD_ROOT/lib/com.microsoft.cognitiveservices.speech.jar"
SRCJARSRC="$BUILD_ROOT/lib/com.microsoft.cognitiveservices.speech-src.zip"
SRCCARBONX="$BUILD_ROOT/bin/carbonx"

CSHARPSUPPORTED=false
CSHARPBINDINGSNAME=Microsoft.CognitiveServices.Speech.csharp.bindings

if [[ $OS = "Windows_NT" ]]; then
  case $TARGET in
    UNKNOWN) LIBPREFIX=Microsoft.CognitiveServices.Speech.
             DYNLIBSUFFIX=.dll
             STATLIBSUFFIX=.lib

             SRCBIN="$BUILD_ROOT/bin/$CONFIG"
             SRCLIB="$BUILD_ROOT/lib/$CONFIG"
             SRCDYNLIB="$BUILD_ROOT/bin/$CONFIG"

             SRCJAVABINDINGS="$SRCBIN/Microsoft.CognitiveServices.Speech.java.bindings.dll"
             CSHARPSUPPORTED=true
             SRCCSHARPBINDINGS="$SRCBIN/$CSHARPBINDINGSNAME.dll"
             ;;
    ANDROID) LIBPREFIX=libMicrosoft.CognitiveServices.Speech.
             DYNLIBSUFFIX=.so
             STATLIBSUFFIX=.a

             SRCBIN="$BUILD_ROOT/bin"
             SRCLIB="$BUILD_ROOT/lib"
             SRCDYNLIB="$BUILD_ROOT/lib"

             SRCJAVABINDINGS="$SRCBIN/libMicrosoft.CognitiveServices.Speech.java.bindings.so"
             ;;
    *) echo "We should never reach this point"
       echo "The fourth parameter should be empty or ANDROID"
       ;;
  esac
else
  LIBPREFIX=libMicrosoft.CognitiveServices.Speech.

  SRCBIN="$BUILD_ROOT/bin"
  SRCLIB="$BUILD_ROOT/lib"
  SRCDYNLIB="$BUILD_ROOT/lib"

  if [[ $(uname) = Linux ]]; then
    DYNLIBSUFFIX=.so
    SRCJAVABINDINGS="$SRCBIN/libMicrosoft.CognitiveServices.Speech.java.bindings.so"
  else
    DYNLIBSUFFIX=.dylib
    SRCJAVABINDINGS="$SRCBIN/libMicrosoft.CognitiveServices.Speech.java.bindings.jnilib"
  fi

  STATLIBSUFFIX=.a

  if [[ $PLATFORM = "Linux-x86" || $(uname) = Darwin ]]; then
    CSHARPSUPPORTED=false
  else
    CSHARPSUPPORTED=true
    SRCCSHARPBINDINGS="$SRCBIN/$CSHARPBINDINGSNAME.so"
  fi
fi

SRCINC="$SOURCE_ROOT/source/public"
SRCPRIVINC="$SOURCE_ROOT/source/core/include"
SRCPRIVINC2="$SOURCE_ROOT/source/core/common/include"
SRCPRIVTESTJAR="$BUILD_ROOT/bin/com.microsoft.cognitiveservices.speech.tests.jar"

DESTPUBLIB="$DEST/public/lib"
DESTPUBLIBNET461="$DEST/public/lib/net461"
DESTPUBLIBNETSTANDARD20="$DEST/public/lib/netstandard2.0"
DESTPUBLIBUTF32NETSTANDARD20="$DEST/public/lib/utf32/netstandard2.0"
DESTPUBBIN="$DEST/public/bin"
DESTPUBINC="$DEST/public/include"
DESTPRIVLIB="$DEST/private/lib"
DESTPRIVBIN="$DEST/private/bin"
DESTPRIVINC="$DEST/private/include"
DESTPRIVINC2="$DEST/private/include.common"

DESTCSHARPBINDINGS="$DESTPUBLIB/$CSHARPBINDINGSNAME.dll"

printf "\nCopying files to drop location\n"

# N.B. no long option for -p (parents) on OSX.
mkdir -p "$DESTPUBLIB" "$DESTPUBLIBNET461" "$DESTPUBLIBNETSTANDARD20" "$DESTPUBLIBUTF32NETSTANDARD20" "$(dirname "$DESTPUBINC")" "$DESTPRIVLIB" "$DESTPRIVBIN" "$(dirname "$DESTPRIVINC")" "$(dirname "$DESTPRIVINC2")"  "$DESTPUBLIB"

# N.B. no long option for -v (verbose) and -p (preserve) on OSX.
CPOPT="-v -p"

cp $CPOPT "$SRCDYNLIB"/$LIBPREFIX*$DYNLIBSUFFIX "$DESTPUBLIB"
# On Windows and not Android, copy import libraries
#   (On Debug, also copy PDBs)
if [[ $OS = "Windows_NT" ]]; then
  if [[ $TARGET != "ANDROID" ]]; then
    cp $CPOPT "$SRCLIB"/$LIBPREFIX*.lib "$DESTPUBLIB"
    cp $CPOPT "$SRCDYNLIB"/$LIBPREFIX*.pdb "$DESTPUBLIB"    

    cp $CPOPT "$SRCDYNLIB"/net461/$LIBPREFIX*.{pdb,xml,dll} "$DESTPUBLIBNET461"
    cp $CPOPT "$SRCDYNLIB"/netstandard2.0/$LIBPREFIX*.{pdb,xml,dll} "$DESTPUBLIBNETSTANDARD20"    
    cp $CPOPT "$SRCDYNLIB"Utf32/netstandard2.0/$LIBPREFIX*.{pdb,xml,dll} "$DESTPUBLIBUTF32NETSTANDARD20"   
  fi
fi

# Copy .jar
cp $CPOPT "$SRCJAR" "$DESTPUBLIB"
cp $CPOPT "$SRCJARSRC" "$DESTPUBLIB"
cp $CPOPT "$SRCJAVABINDINGS" "$DESTPUBLIB"

# Copy (private) test .jar
cp $CPOPT "$SRCPRIVTESTJAR" "$DESTPRIVBIN"

if [[ "$CSHARPSUPPORTED" = true ]]; then
  cp $CPOPT "$SRCCSHARPBINDINGS" "$DESTCSHARPBINDINGS"
fi

# copy carbonx if available
[[ -e $SRCCARBONX ]] && mkdir -p "$DESTPUBBIN" && cp $CPOPT "$SRCCARBONX" "$DESTPUBBIN"


# N.B. no long option for -R (recursive) on OSX.
cp $CPOPT -R "$SRCINC"* "$DESTPUBINC"

# N.B. Using '-I -n 1' and replacement instead of "cp --target" since --target
# is not available on OSX.
find "$SRCLIB" -type f -name \*$STATLIBSUFFIX -not -name $LIBPREFIX\* -print0 |
  xargs -n 1 -0 -I % cp % "$DESTPRIVLIB"

cp $CPOPT -R "$SRCPRIVINC" "$DESTPRIVINC"
cp $CPOPT -R "$SRCPRIVINC2" "$DESTPRIVINC2"
