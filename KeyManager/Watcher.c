//
//  Watcher.c
//  KeyManager
//
//  Created by Samuel DeSota on 9/10/16.
//  Copyright © 2016 Samuel DeSota. All rights reserved.
//

#include <IOKit/hid/IOHIDLib.h>

CFMutableDictionaryRef createDeviceMatchingDictionary(UInt32 usagePage, UInt32 usage);

void (*callbackPtr)(long, int);
void callbackProxy (void *context, IOReturn result, void *sender, IOHIDValueRef value);

void startWatching(void (*theCallbackPtr)(long, int)) {
    callbackPtr = theCallbackPtr;
    
    IOHIDManagerRef hidManager = IOHIDManagerCreate(kCFAllocatorDefault,
                                                    kIOHIDOptionsTypeNone);
    
    CFMutableDictionaryRef keyboard = createDeviceMatchingDictionary(0x01, 6);
    CFMutableDictionaryRef keypad = createDeviceMatchingDictionary(0x01, 7);
    
    CFMutableDictionaryRef matchesList[] = {
        keyboard,
        keypad,
    };
    CFArrayRef matches = CFArrayCreate(kCFAllocatorDefault,
                                       (const void **)matchesList, 2, NULL);
    IOHIDManagerSetDeviceMatchingMultiple(hidManager, matches);
    
    IOHIDManagerRegisterInputValueCallback(hidManager,
                                           callbackProxy, NULL);
    
    IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(),
                                    kCFRunLoopDefaultMode);
    
    IOHIDManagerOpen(hidManager, kIOHIDOptionsTypeNone);
}

void callbackProxy (void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    IOHIDElementRef elem = IOHIDValueGetElement(value);
    
    if (IOHIDElementGetUsagePage(elem) != 0x07)
        return;
    
    uint32_t scancode = IOHIDElementGetUsage(elem);
    
    if (scancode < 4 || scancode > 231)
        return;
    
    long pressed = IOHIDValueGetIntegerValue(value);
    
    (*callbackPtr)(pressed, scancode);
    
    return;
}


CFMutableDictionaryRef createDeviceMatchingDictionary(UInt32 usagePage, UInt32 usage) {
    CFMutableDictionaryRef ret = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                           0,
                                                           &kCFTypeDictionaryKeyCallBacks,
                                                           &kCFTypeDictionaryValueCallBacks);
    
    if (!ret)
        return NULL;
    
    CFNumberRef pageNumberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usagePage);
    
    if (!pageNumberRef) {
        return NULL;
    }
    
    CFDictionarySetValue(ret, CFSTR(kIOHIDDeviceUsagePageKey), pageNumberRef);
    CFRelease(pageNumberRef);
    
    CFNumberRef usageNumberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);
    
    CFDictionarySetValue(ret, CFSTR(kIOHIDDeviceUsageKey), usageNumberRef);
    CFRelease(usageNumberRef);
    
    return ret;
}
