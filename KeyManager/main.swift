import Foundation

let options : NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

var activeFlags: CGEventFlags? = nil
var cancelNext: Int64? = nil

var numberMapping: [Int64: Int64] = [
    0: 83,
    1: 87,
    2: 92,
    3: 89,
    5: 85,
    4: 82,
    38: 91,
    40: 86,
    37: 88,
    41: 84
]
var keypadActive = false
var lcmd = false
var rcmd = false

open class Timer {
    fileprivate var callback: () -> Void
    fileprivate var timer: Foundation.Timer?
    
    init(interval: Double, repeats: Bool, callback: @escaping () -> Void) {
        self.callback = callback;
        
        self.timer = Foundation.Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(run), userInfo: nil, repeats: repeats)
    }
    
    @objc fileprivate func run() -> Void {
        self.callback()
    }
    
    open func end() {
        self.timer!.invalidate()
    }
}

let defaults = UserDefaults.standard
let keyRepeat = Double(defaults.integer(forKey: "KeyRepeat")) * 0.015
let keyRepeatDelay = Double(defaults.integer(forKey: "InitialKeyRepeat")) * 0.015
func mapHIDKeyToKey(_ from: CGKeyCode, to: CGKeyCode) -> (_ pressed: CLong, _ key: CInt) -> Void {
    let eventDown = CGEvent(keyboardEventSource: nil, virtualKey: to, keyDown: true)
    let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: to, keyDown: false)
    var initialRepeating: Timer?
    var repeating: Timer?
    return {(pressed, key) in
        if UInt16(key) == from {
            if let flags = activeFlags {
                eventDown?.flags = flags
                eventUp?.flags = flags
            }
            if pressed == 1 {
                eventDown?.post(tap: CGEventTapLocation.cghidEventTap);
                initialRepeating = Timer(interval: keyRepeatDelay, repeats: false, callback: {() in
                    repeating = Timer(interval: keyRepeat, repeats: true, callback: {() in
                        eventDown?.post(tap: CGEventTapLocation.cghidEventTap);
                    })
                })
            } else {
                initialRepeating?.end()
                repeating?.end()
                eventUp?.post(tap: CGEventTapLocation.cghidEventTap);
            }
        }
    }
}

func mapKeyWhenPressedAloneToKey(_ from: CGKeyCode, to: CGKeyCode) -> (_ pressed: CLong, _ key: CInt) -> Void {
    var down = false
    var otherPressed = false
    let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: to, keyDown: false)
    let eventDown = CGEvent(keyboardEventSource: nil, virtualKey: to, keyDown: true)
    return {(pressed, key) in
        if (UInt16(key) == from) {
            if (pressed == 1) {
                down = true
            } else {
                if (!otherPressed && !keypadActive) {
                    eventDown?.post(tap: CGEventTapLocation.cghidEventTap)
                    eventUp?.post(tap: CGEventTapLocation.cghidEventTap)
                }
                down = false
                otherPressed = false
            }
        } else if down && !otherPressed {
            otherPressed = true
        }
    }
}

func cmdcmdNumbers () -> (_ pressed: CLong, _ key: CInt) -> Void {
    return {(pressed, key) in
        if key == 227 {
            lcmd = pressed == 1 ? true : false
        }
        
        if key == 231 {
            rcmd = pressed == 1 ? true : false
        }
        
        if (key == 227 || key == 231)  {
            keypadActive = rcmd && lcmd
        }
    }
}

let capsToDelete = mapHIDKeyToKey(57, to: 51)
let cmdToEsc = mapKeyWhenPressedAloneToKey(231, to: 53)
let numberKeys = cmdcmdNumbers()
//let deleteModalKeypad = modalKeypad(42)
var lastScanCode: Int32? = nil
func callback (_ pressed: CLong, key: CInt) {
    lastScanCode = key
    capsToDelete(pressed, key)
    cmdToEsc(pressed, key)
    numberKeys(pressed, key)
}

startWatching(callback)

let emptyFlags = CGEventFlags()
func myCGEventCallback(_ proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: Optional<UnsafeMutableRawPointer>) -> Optional<Unmanaged<CGEvent>> {
    if [.keyDown , .keyUp].contains(type) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        if (keypadActive) {
            if let mapTo = numberMapping[keyCode] {
                event.setIntegerValueField(.keyboardEventKeycode, value: mapTo)
            }
            
            event.flags.remove(CGEventFlags.maskCommand)
        }
    }
    
    return Unmanaged.passRetained(event)
}

let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
guard let eventTap = CGEvent.tapCreate(tap: CGEventTapLocation.cghidEventTap,
                                      place: CGEventTapPlacement.headInsertEventTap,
                                      options: CGEventTapOptions.defaultTap,
                                      eventsOfInterest: CGEventMask(eventMask),
                                      callback: myCGEventCallback,
                                      userInfo: nil) else {
                                        print("failed to create event tap")
                                        exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)

CFRunLoopRun()

