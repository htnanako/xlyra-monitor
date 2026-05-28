import Foundation

public struct ModelCheckConfiguration: Equatable {
    public let baseURL: URL
    public let apiKey: String
    public let model: String

    public init(baseURL: URL, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }
}

public struct AccountModelCheckTarget: Equatable {
    public let id: Int
    public let name: String
    public let platform: String

    public init(id: Int, name: String, platform: String) {
        self.id = id
        self.name = name
        self.platform = platform
    }
}

public struct ModelDegradationCheckResult: Equatable {
    public let targetModel: String
    public let responseModel: String?
    public let score: Int
    public let scoreKind: ModelDegradationScoreKind
    public let status: ModelDegradationStatus
    public let latency: TimeInterval?
    public let checkedAt: Date
    public let probes: [ModelDegradationProbeResult]

    public init(
        targetModel: String,
        responseModel: String?,
        score: Int,
        scoreKind: ModelDegradationScoreKind = .qualityProbe,
        status: ModelDegradationStatus,
        latency: TimeInterval?,
        checkedAt: Date,
        probes: [ModelDegradationProbeResult]
    ) {
        self.targetModel = targetModel
        self.responseModel = responseModel
        self.score = score
        self.scoreKind = scoreKind
        self.status = status
        self.latency = latency
        self.checkedAt = checkedAt
        self.probes = probes
    }
}

public enum ModelDegradationScoreKind: String, Equatable {
    case qualityProbe = "能力探针"
    case verifiableHealth = "可验证项"
}

public enum ModelDegradationStatus: String, Equatable {
    case normal = "正常"
    case watch = "观察"
    case suspicious = "疑似降智"
    case modelMismatch = "模型不一致"
    case unavailable = "不可用"
    case highRisk = "高风险"
    case failed = "检测失败"
}

public struct ModelDegradationProbeResult: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let passed: Bool
    public let detail: String

    public init(id: String, title: String, passed: Bool, detail: String) {
        self.id = id
        self.title = title
        self.passed = passed
        self.detail = detail
    }
}

public enum ModelCheckError: Error, Equatable {
    case invalidConfiguration
    case requestFailed
    case invalidResponse
}
