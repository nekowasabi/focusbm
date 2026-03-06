#ifndef CInputSource_h
#define CInputSource_h

#include <Carbon/Carbon.h>

/// Switch to ASCII-capable input source (e.g. turn off Japanese IME)
static inline void CInputSource_switchToASCII(void) {
    TISInputSourceRef source = TISCopyCurrentASCIICapableKeyboardInputSource();
    if (source) {
        TISSelectInputSource(source);
        CFRelease(source);
    }
}

#endif
