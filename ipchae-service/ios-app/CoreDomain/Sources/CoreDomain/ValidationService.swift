import Foundation

public enum ValidationSeverity: String, Codable, Sendable {
    case error
    case warning
}

public enum ValidationIssueCode: String, Codable, Sendable {
    case thinWall = "thin_wall"
    case nonManifold = "non_manifold"
    case openEdges = "open_edges"
    case selfIntersection = "self_intersection"
    case emptyMesh = "empty_mesh"
}

public struct ValidationIssue: Codable, Sendable, Equatable {
    public var code: ValidationIssueCode
    public var severity: ValidationSeverity
    public var message: String

    public init(code: ValidationIssueCode, severity: ValidationSeverity, message: String) {
        self.code = code
        self.severity = severity
        self.message = message
    }
}

public struct ValidationReport: Codable, Sendable, Equatable {
    public var errors: [ValidationIssue]
    public var warnings: [ValidationIssue]
    public var all: [ValidationIssue]
    public var exportAllowed: Bool

    public init(errors: [ValidationIssue], warnings: [ValidationIssue], all: [ValidationIssue], exportAllowed: Bool) {
        self.errors = errors
        self.warnings = warnings
        self.all = all
        self.exportAllowed = exportAllowed
    }
}

public enum ValidationService {
    public static func validateDraftSummary(_ summary: DraftSummary) -> ValidationReport {
        var issues: [ValidationIssue] = []

        if summary.dotCount == 0 {
            issues.append(
                ValidationIssue(
                    code: .emptyMesh,
                    severity: .error,
                    message: "조형 데이터가 없습니다. 먼저 Draw/Build 단계에서 형태를 만들어 주세요."
                )
            )
        }

        if summary.dotCount > 0, summary.dotCount < 18 {
            issues.append(
                ValidationIssue(
                    code: .openEdges,
                    severity: .error,
                    message: "표면이 충분히 닫히지 않은 것으로 보입니다. 스트로크를 더 추가해 주세요."
                )
            )
        }

        if summary.averageRadius > 0, summary.averageRadius < 0.08 {
            issues.append(
                ValidationIssue(
                    code: .thinWall,
                    severity: .warning,
                    message: "벽 두께가 얇을 수 있습니다. 브러시 크기 또는 빌드 레이어를 늘려 주세요."
                )
            )
        }

        if summary.strokeCount > 0 {
            let averageDotsPerStroke = Double(summary.dotCount) / Double(max(1, summary.strokeCount))
            if averageDotsPerStroke > 420 {
                issues.append(
                    ValidationIssue(
                        code: .nonManifold,
                        severity: .warning,
                        message: "중첩/겹침이 많아 비다양체(non-manifold) 가능성이 있습니다."
                    )
                )
            }
        }

        if let bounds = summary.bounds {
            let spanX = bounds.maxX - bounds.minX
            let spanY = bounds.maxY - bounds.minY
            let spanZ = bounds.maxZ - bounds.minZ
            let minSpan = min(spanX, spanY, spanZ)
            let maxSpan = max(spanX, max(spanY, spanZ))
            if minSpan > 0, maxSpan / minSpan > 20, summary.dotCount > 80 {
                issues.append(
                    ValidationIssue(
                        code: .selfIntersection,
                        severity: .warning,
                        message: "형태 비율이 극단적이라 자기교차 가능성이 있습니다. 일부 영역을 정리해 주세요."
                    )
                )
            }
        }

        let errors = issues.filter { $0.severity == .error }
        let warnings = issues.filter { $0.severity == .warning }

        return ValidationReport(
            errors: errors,
            warnings: warnings,
            all: issues,
            exportAllowed: errors.isEmpty
        )
    }
}
