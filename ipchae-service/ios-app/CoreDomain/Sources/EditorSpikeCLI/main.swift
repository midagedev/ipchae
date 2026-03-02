import CoreDomain
import Foundation

struct CLIArgs {
    var strokes = 120
    var points = 120
    var undoRatio = 0.2
}

func parseArgs() -> CLIArgs {
    var parsed = CLIArgs()
    let args = CommandLine.arguments

    var index = 1
    while index < args.count {
        let arg = args[index]
        switch arg {
        case "--strokes":
            if index + 1 < args.count, let value = Int(args[index + 1]) {
                parsed.strokes = value
                index += 1
            }
        case "--points":
            if index + 1 < args.count, let value = Int(args[index + 1]) {
                parsed.points = value
                index += 1
            }
        case "--undo-ratio":
            if index + 1 < args.count, let value = Double(args[index + 1]) {
                parsed.undoRatio = value
                index += 1
            }
        default:
            break
        }
        index += 1
    }

    return parsed
}

let args = parseArgs()
let result = EditorSpikeBenchmark.run(
    config: EditorSpikeConfig(
        strokeCount: args.strokes,
        pointsPerStroke: args.points,
        undoRatio: args.undoRatio
    )
)

let payload: [String: Any] = [
    "strokeCount": result.strokeCount,
    "pointsPerStroke": result.pointsPerStroke,
    "totalPointsBuilt": result.totalPointsBuilt,
    "totalPointsRemaining": result.totalPointsRemaining,
    "buildDurationMs": result.buildDurationMs,
    "undoDurationMs": result.undoDurationMs,
    "buildPointsPerSec": result.buildPointsPerSec,
    "validationAllowed": result.validationAllowed
]

if JSONSerialization.isValidJSONObject(payload),
   let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
   let text = String(data: data, encoding: .utf8) {
    print(text)
} else {
    print("Failed to build benchmark payload")
    exit(1)
}
