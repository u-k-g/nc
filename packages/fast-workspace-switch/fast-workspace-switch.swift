import CoreGraphics
import Darwin
import Foundation

private let gestureHoldMicroseconds: useconds_t = 15_000
private let interSwitchDelayMicroseconds: useconds_t = 50_000
private let minimumPositiveFloat = 1.401298464324817e-45
private let processLockPath = "/tmp/nc-fast-workspace-switch-\(getuid()).lock"

private enum GesturePhase: Int64 {
    case began = 1
    case ended = 4
}

private enum Direction {
    case left
    case right

    var magnitude: Double {
        switch self {
        case .left: -2.25
        case .right: 2.25
        }
    }
}

private struct SwipeValues {
    let magnitude: Double
    let magnitudeAsInteger: Int64
    let gestureValue: Double

    init(direction: Direction) {
        magnitude = direction.magnitude
        magnitudeAsInteger = Int64(Int32(bitPattern: Float(magnitude).bitPattern))
        gestureValue = 200.0 * magnitude
    }
}

private func writeStderr(_ message: String) {
    FileHandle.standardError.write(Data(message.utf8))
}

private func setInteger(_ event: CGEvent, _ field: Int64, _ value: Int64) {
    event.setIntegerValueField(CGEventField(rawValue: UInt32(field))!, value: value)
}

private func setDouble(_ event: CGEvent, _ field: Int64, _ value: Double) {
    event.setDoubleValueField(CGEventField(rawValue: UInt32(field))!, value: value)
}

private func createMarkerEvent() -> CGEvent? {
    guard let event = CGEvent(source: nil) else {
        return nil
    }

    setInteger(event, 0x37, 29)
    setInteger(event, 0x29, 33231)
    return event
}

private func createSwipeEvent(_ values: SwipeValues, phase: GesturePhase) -> CGEvent? {
    guard let event = CGEvent(source: nil) else {
        return nil
    }

    setInteger(event, 0x37, 30)
    setInteger(event, 0x6E, 23)
    setInteger(event, 0x84, phase.rawValue)
    setInteger(event, 0x86, phase.rawValue)
    setDouble(event, 0x7C, values.magnitude)
    setInteger(event, 0x87, values.magnitudeAsInteger)
    setInteger(event, 0x7B, 1)
    setInteger(event, 0xA5, 1)
    setDouble(event, 0x77, minimumPositiveFloat)
    setDouble(event, 0x8B, minimumPositiveFloat)
    setInteger(event, 0x29, 33231)
    setInteger(event, 0x88, 0)

    if phase == .ended {
        setDouble(event, 0x81, values.gestureValue)
        setDouble(event, 0x82, values.gestureValue)
    }

    return event
}

private func postSwipe(_ direction: Direction) -> Bool {
    let values = SwipeValues(direction: direction)

    guard let beginMarkerEvent = createMarkerEvent(),
          let beginSwipeEvent = createSwipeEvent(values, phase: .began)
    else {
        writeStderr("Unable to create Space-switch begin events\n")
        return false
    }

    beginSwipeEvent.post(tap: .cghidEventTap)
    beginMarkerEvent.post(tap: .cghidEventTap)

    usleep(gestureHoldMicroseconds)

    guard let endMarkerEvent = createMarkerEvent(),
          let endSwipeEvent = createSwipeEvent(values, phase: .ended)
    else {
        writeStderr("Unable to create Space-switch end events\n")
        return false
    }

    endSwipeEvent.post(tap: .cghidEventTap)
    endMarkerEvent.post(tap: .cghidEventTap)
    return true
}

private func mainDisplaySpaces() -> [UInt64]? {
    guard let managedDisplaysReference = NCCopyManagedDisplaySpaces(),
          let managedDisplays = managedDisplaysReference.takeRetainedValue() as? [[String: Any]]
    else {
        return nil
    }

    var spacesByDisplay: [String: [UInt64]] = [:]
    for display in managedDisplays {
        guard let identifier = display["Display Identifier"] as? String,
              let spaces = display["Spaces"] as? [[String: Any]]
        else {
            continue
        }

        spacesByDisplay[identifier] = spaces.compactMap {
            ($0["id64"] as? NSNumber)?.uint64Value
        }
    }

    return spacesByDisplay["Main"] ?? spacesByDisplay.values.first
}

private func switchRepeatedly(_ direction: Direction, count: Int) -> Bool {
    for index in 0..<count {
        if index > 0 {
            usleep(interSwitchDelayMicroseconds)
        }

        guard postSwipe(direction) else {
            return false
        }
    }

    return true
}

private func switchBy(offset: Int) -> Bool {
    guard offset != 0 else {
        return true
    }

    let direction: Direction = offset > 0 ? .right : .left
    return switchRepeatedly(direction, count: abs(offset))
}

private func gotoSpace(_ target: Int) -> Bool {
    guard let spaces = mainDisplaySpaces() else {
        writeStderr("Unable to read Spaces state\n")
        return false
    }

    let currentSpace = NCGetActiveSpace()
    guard let currentIndex = spaces.firstIndex(of: currentSpace) else {
        writeStderr("Unable to determine current Space index\n")
        return false
    }

    return switchBy(offset: target - (currentIndex + 1))
}

private func withExclusiveProcessLock(_ operation: () -> Bool) -> Bool {
    let permissions = mode_t(S_IRUSR | S_IWUSR)
    let descriptor = open(processLockPath, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, permissions)
    guard descriptor >= 0 else {
        writeStderr("Unable to open Space-switch lock\n")
        return false
    }
    defer {
        _ = flock(descriptor, LOCK_UN)
        _ = close(descriptor)
    }

    guard flock(descriptor, LOCK_EX) == 0 else {
        writeStderr("Unable to acquire Space-switch lock\n")
        return false
    }

    return operation()
}

let arguments = CommandLine.arguments

guard arguments.count == 3 else {
    writeStderr("Usage: \(arguments[0]) <left|right> <count> | goto <1-9>\n")
    exit(1)
}

let succeeded: Bool
if arguments[1] == "goto" {
    guard let target = Int(arguments[2]), (1...9).contains(target) else {
        writeStderr("Invalid target: \(arguments[2]). Must be 1-9.\n")
        exit(1)
    }

    succeeded = withExclusiveProcessLock {
        gotoSpace(target)
    }
} else {
    let direction: Direction
    if arguments[1] == "right" {
        direction = .right
    } else if arguments[1] == "left" {
        direction = .left
    } else {
        writeStderr("Invalid direction: \(arguments[1]). Use 'left' or 'right'.\n")
        exit(1)
    }

    guard let count = Int(arguments[2]), count > 0 else {
        writeStderr("Invalid count: \(arguments[2]). Must be a positive integer.\n")
        exit(1)
    }

    succeeded = withExclusiveProcessLock {
        switchRepeatedly(direction, count: count)
    }
}

exit(succeeded ? 0 : 1)
