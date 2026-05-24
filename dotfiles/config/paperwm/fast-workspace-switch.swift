import CoreGraphics
import Foundation

private let floatMin = 1.401298464324817e-45

private func setInteger(_ event: CGEvent, _ field: Int64, _ value: Int64) {
    event.setIntegerValueField(CGEventField(rawValue: UInt32(field))!, value: value)
}

private func setDouble(_ event: CGEvent, _ field: Int64, _ value: Double) {
    event.setDoubleValueField(CGEventField(rawValue: UInt32(field))!, value: value)
}

private func workingSpaceSwitch(_ direction: Int) {
    let magnitude = direction == 0 ? -2.25 : 2.25
    let gestureValue = 200.0 * magnitude

    let event1a = CGEvent(source: nil)!
    setInteger(event1a, 0x37, 29)
    setInteger(event1a, 0x29, 33231)

    let event1b = CGEvent(source: nil)!
    setInteger(event1b, 0x37, 30)
    setInteger(event1b, 0x6E, 23)
    setInteger(event1b, 0x84, 1)
    setInteger(event1b, 0x86, 1)
    setDouble(event1b, 0x7C, magnitude)

    let magnitudeAsFloat = Float(magnitude)
    let magnitudeAsInt = Int64(Int32(bitPattern: magnitudeAsFloat.bitPattern))
    setInteger(event1b, 0x87, magnitudeAsInt)

    setInteger(event1b, 0x7B, 1)
    setInteger(event1b, 0xA5, 1)
    setDouble(event1b, 0x77, floatMin)
    setDouble(event1b, 0x8B, floatMin)
    setInteger(event1b, 0x29, 33231)
    setInteger(event1b, 0x88, 0)

    event1b.post(tap: .cghidEventTap)
    event1a.post(tap: .cghidEventTap)

    usleep(15_000)

    let event2a = CGEvent(source: nil)!
    setInteger(event2a, 0x37, 29)
    setInteger(event2a, 0x29, 33231)

    let event2b = CGEvent(source: nil)!
    setInteger(event2b, 0x37, 30)
    setInteger(event2b, 0x6E, 23)
    setInteger(event2b, 0x84, 4)
    setInteger(event2b, 0x86, 4)
    setDouble(event2b, 0x7C, magnitude)
    setInteger(event2b, 0x87, magnitudeAsInt)
    setInteger(event2b, 0x7B, 1)
    setInteger(event2b, 0xA5, 1)
    setDouble(event2b, 0x77, floatMin)
    setDouble(event2b, 0x8B, floatMin)
    setInteger(event2b, 0x29, 33231)
    setInteger(event2b, 0x88, 0)

    setDouble(event2b, 0x81, gestureValue)
    setDouble(event2b, 0x82, gestureValue)

    event2b.post(tap: .cghidEventTap)
    event2a.post(tap: .cghidEventTap)
}

private func writeStderr(_ message: String) {
    FileHandle.standardError.write(Data(message.utf8))
}

let args = CommandLine.arguments

guard args.count == 3 else {
    writeStderr("Usage: \(args[0]) <left|right> <count>\n")
    exit(1)
}

let direction: Int
if args[1] == "right" {
    direction = 1
} else if args[1] == "left" {
    direction = 0
} else {
    writeStderr("Invalid direction: \(args[1]). Use 'left' or 'right'.\n")
    exit(1)
}

guard let count = Int(args[2]), count > 0 else {
    writeStderr("Invalid count: \(args[2]). Must be a positive integer.\n")
    exit(1)
}

for index in 0..<count {
    if index > 0 {
        usleep(50_000)
    }

    workingSpaceSwitch(direction)
}
