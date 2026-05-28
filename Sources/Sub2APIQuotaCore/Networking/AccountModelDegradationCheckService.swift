import Foundation

public protocol AccountModelDegradationChecking {
    func runCheck(
        configuration: ServiceConfiguration,
        credential: LoginCredential,
        target: AccountModelCheckTarget,
        model: String
    ) async throws -> ModelDegradationCheckResult
}

public struct AccountModelDegradationCheckService: AccountModelDegradationChecking {
    private let httpClient: HTTPClient
    private let adminClient: Sub2APIAdminClient
    private let now: () -> Date

    public init(
        httpClient: HTTPClient,
        now: @escaping () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.adminClient = Sub2APIAdminClient(httpClient: httpClient)
        self.now = now
    }

    public func runCheck(
        configuration: ServiceConfiguration,
        credential: LoginCredential,
        target: AccountModelCheckTarget,
        model: String
    ) async throws -> ModelDegradationCheckResult {
        let checkedAt = now()
        let startedAt = Date()
        let token = try await adminClient.login(configuration: configuration, credential: credential)
        var earnedPoints = 0
        var applicablePoints = 0
        var responseModel: String?
        var probes: [ModelDegradationProbeResult] = []

        let modelsProbe = await runAvailableModelsProbe(
            configuration: configuration,
            token: token,
            accountID: target.id,
            model: model
        )
        probes.append(modelsProbe.result)
        earnedPoints += modelsProbe.points
        applicablePoints += modelsProbe.maxPoints

        let defaultProbe = await runAccountTestProbe(
            configuration: configuration,
            token: token,
            target: target,
            model: model,
            mode: "default",
            id: "account-test",
            title: "账号连通",
            prompt: "请只回复 PONG。",
            successDetail: "账号可用",
            failureDetail: "账号未返回有效内容",
            points: 18,
            validator: { content in
                content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }
        )
        probes.append(defaultProbe.result)
        earnedPoints += defaultProbe.points
        applicablePoints += defaultProbe.maxPoints
        responseModel = defaultProbe.responseModel

        let stabilityProbe = await runLatencyStabilityProbe(
            configuration: configuration,
            token: token,
            target: target,
            model: model,
            baseline: defaultProbe
        )
        probes.append(stabilityProbe.result)
        earnedPoints += stabilityProbe.points
        applicablePoints += stabilityProbe.maxPoints

        let modelConsistencyProbe = evaluateModelConsistencyProbe(responseModel: responseModel, targetModel: model)
        probes.append(modelConsistencyProbe.result)
        earnedPoints += modelConsistencyProbe.points
        applicablePoints += modelConsistencyProbe.maxPoints

        let streamProbe = evaluateStreamProbe(defaultProbe)
        probes.append(streamProbe.result)
        earnedPoints += streamProbe.points
        applicablePoints += streamProbe.maxPoints

        if supportsPromptValidation(target: target, model: model) {
            let instructionProbe = await runAccountTestProbe(
                configuration: configuration,
                token: token,
                target: target,
                model: model,
                mode: "default",
                id: "instruction",
                title: "指令跟随",
                prompt: "请只输出 OK_42，不要输出任何其他文字。",
                successDetail: "指令正常",
                failureDetail: "未按要求输出",
                points: 18,
                validator: { content in
                    let normalized = content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .uppercased()
                        .replacingOccurrences(of: "`", with: "")
                    return normalized == "OK_42" || normalized.contains("OK_42")
                }
            )
            probes.append(instructionProbe.result)
            earnedPoints += instructionProbe.points
            applicablePoints += instructionProbe.maxPoints

            let reasoningProbe = await runAccountTestProbe(
                configuration: configuration,
                token: token,
                target: target,
                model: model,
                mode: "default",
                id: "reasoning",
                title: "基础能力",
                prompt: "计算 19 * 23 + 7。请只输出最终数字。",
                successDetail: "基础能力正常",
                failureDetail: "基础能力测试未通过",
                points: 18,
                validator: { content in
                    content.contains("444")
                }
            )
            probes.append(reasoningProbe.result)
            earnedPoints += reasoningProbe.points
            applicablePoints += reasoningProbe.maxPoints
        }

        let compactProbe: AccountProbeEvaluation
        if target.platform.lowercased() == "openai" {
            compactProbe = await runAccountTestProbe(
                configuration: configuration,
                token: token,
                target: target,
                model: model,
                mode: "compact",
                id: "compact",
                title: "Compact 路径",
                prompt: "请只回复 COMPACT_OK。",
                successDetail: "Compact 可用",
                failureDetail: "Compact 路径不可用",
                points: 12,
                validator: { content in
                    content.uppercased().contains("COMPACT_OK") || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                }
            )
        } else {
            compactProbe = .skip(
                id: "compact",
                title: "Compact 路径",
                detail: "非 OpenAI 账号无需检测"
            )
        }
        probes.append(compactProbe.result)
        earnedPoints += compactProbe.points
        applicablePoints += compactProbe.maxPoints

        let score = normalizedScore(earnedPoints: earnedPoints, applicablePoints: applicablePoints)

        return ModelDegradationCheckResult(
            targetModel: model,
            responseModel: responseModel,
            score: score,
            scoreKind: .verifiableHealth,
            status: status(for: score, probes: probes),
            latency: Date().timeIntervalSince(startedAt),
            checkedAt: checkedAt,
            probes: probes
        )
    }

    private func runAvailableModelsProbe(
        configuration: ServiceConfiguration,
        token: String,
        accountID: Int,
        model: String
    ) async -> AccountProbeEvaluation {
        do {
            var request = URLRequest(url: adminClient.apiURL(configuration: configuration, path: "api/v1/admin/accounts/\(accountID)/models"))
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let response = try await send(request, timeout: 20)
            guard response.statusCode == 200 else {
                return .fail(id: "models", title: "模型列表", detail: "模型列表接口返回 \(response.statusCode)", maxPoints: 12)
            }

            let models = try parseModels(from: response.data)
            if models.contains(model) {
                return .pass(id: "models", title: "模型列表", detail: "目标模型可用", points: 12)
            }

            if models.isEmpty {
                return .fail(id: "models", title: "模型列表", detail: "未返回可用模型", maxPoints: 12)
            }

            return .fail(id: "models", title: "模型列表", detail: "目标模型不在此账号列表", maxPoints: 12)
        } catch {
            return .fail(id: "models", title: "模型列表", detail: "模型列表请求失败", maxPoints: 12)
        }
    }

    private func runAccountTestProbe(
        configuration: ServiceConfiguration,
        token: String,
        target: AccountModelCheckTarget,
        model: String,
        mode: String,
        id: String,
        title: String,
        prompt: String,
        successDetail: String,
        failureDetail: String,
        points: Int,
        validator: (String) -> Bool
    ) async -> AccountProbeEvaluation {
        let startedAt = Date()
        do {
            var request = URLRequest(url: adminClient.apiURL(configuration: configuration, path: "api/v1/admin/accounts/\(target.id)/test"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(
                withJSONObject: [
                    "model_id": model,
                    "prompt": prompt,
                    "mode": mode
                ]
            )

            let response = try await send(request, timeout: 60)
            guard response.statusCode == 200 else {
                return .fail(id: id, title: title, detail: "测试接口返回 \(response.statusCode)", maxPoints: points)
            }

            let summary = parseTestEvents(from: response.data)
            if summary.success && validator(summary.content) {
                return AccountProbeEvaluation(
                    result: ModelDegradationProbeResult(id: id, title: title, passed: true, detail: successDetail),
                    points: points,
                    maxPoints: points,
                    responseModel: summary.model,
                    latency: Date().timeIntervalSince(startedAt),
                    sawContentEvent: summary.sawContentEvent
                )
            }

            return .fail(
                id: id,
                title: title,
                detail: summary.error ?? failureDetail,
                maxPoints: points,
                latency: Date().timeIntervalSince(startedAt),
                responseModel: summary.model,
                sawContentEvent: summary.sawContentEvent
            )
        } catch {
            return .fail(id: id, title: title, detail: "测试请求失败", maxPoints: points)
        }
    }

    private func evaluateModelConsistencyProbe(responseModel: String?, targetModel: String) -> AccountProbeEvaluation {
        guard let responseModel else {
            return .fail(id: "model-consistency", title: "模型一致", detail: "无法确认响应模型", maxPoints: 12)
        }

        if responseModel == targetModel {
            return .pass(id: "model-consistency", title: "模型一致", detail: "响应模型一致", points: 12)
        }

        return .fail(id: "model-consistency", title: "模型一致", detail: "响应模型不一致", maxPoints: 12)
    }

    private func runLatencyStabilityProbe(
        configuration: ServiceConfiguration,
        token: String,
        target: AccountModelCheckTarget,
        model: String,
        baseline: AccountProbeEvaluation
    ) async -> AccountProbeEvaluation {
        var probes: [AccountProbeEvaluation] = [baseline]
        for index in 1...2 {
            let probe = await runAccountTestProbe(
                configuration: configuration,
                token: token,
                target: target,
                model: model,
                mode: "default",
                id: "latency-sample-\(index)",
                title: "延迟采样",
                prompt: "请只回复 PONG。",
                successDetail: "采样正常",
                failureDetail: "采样失败",
                points: 0,
                validator: { content in
                    content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                }
            )
            probes.append(probe)
        }

        let successfulLatencies = probes.compactMap { probe in
            probe.result.passed ? probe.latency : nil
        }
        guard successfulLatencies.count == probes.count else {
            return .fail(id: "latency-stability", title: "延迟稳定", detail: "多次采样存在失败", maxPoints: 12)
        }

        guard let minLatency = successfulLatencies.min(),
              let maxLatency = successfulLatencies.max() else {
            return .fail(id: "latency-stability", title: "延迟稳定", detail: "无延迟样本", maxPoints: 12)
        }

        let spread = maxLatency - minLatency
        if maxLatency <= max(0.1, minLatency * 2.5) || spread <= 1.5 {
            return .pass(
                id: "latency-stability",
                title: "延迟稳定",
                detail: String(format: "%.2fs-%.2fs", minLatency, maxLatency),
                points: 12
            )
        }

        return .fail(
            id: "latency-stability",
            title: "延迟稳定",
            detail: String(format: "波动过大 %.2fs-%.2fs", minLatency, maxLatency),
            maxPoints: 12
        )
    }

    private func evaluateStreamProbe(_ probe: AccountProbeEvaluation) -> AccountProbeEvaluation {
        guard probe.result.passed, probe.sawContentEvent else {
            return .fail(id: "stream", title: "流式响应", detail: "SSE 内容事件异常", maxPoints: 10)
        }

        return .pass(id: "stream", title: "流式响应", detail: "SSE 正常", points: 10)
    }

    private func supportsPromptValidation(target: AccountModelCheckTarget, model: String) -> Bool {
        let platform = target.platform.lowercased()
        if platform == "gemini" {
            return true
        }

        // sub2api currently ignores arbitrary prompt text for OpenAI/Claude account tests.
        // Antigravity only routes prompt text for Gemini API-key models, and the account
        // type is not available in this target, so keep the scoring conservative.
        if platform == "antigravity", model.lowercased().hasPrefix("gemini-") {
            return true
        }

        return false
    }

    private func normalizedScore(earnedPoints: Int, applicablePoints: Int) -> Int {
        guard applicablePoints > 0 else {
            return 0
        }

        return min(100, Int((Double(earnedPoints) / Double(applicablePoints) * 100).rounded()))
    }

    private func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponse {
        do {
            return try await httpClient.send(request, timeout: timeout)
        } catch let error as QuotaErrorKind {
            throw error
        } catch let error as URLError {
            throw adminClient.map(urlError: error)
        } catch {
            throw QuotaErrorKind.network
        }
    }

    private func parseModels(from data: Data) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: data)
        let payload: Any
        if let dictionary = object as? [String: Any], let wrapped = dictionary["data"] {
            payload = wrapped
        } else {
            payload = object
        }

        guard let items = payload as? [[String: Any]] else {
            throw QuotaErrorKind.invalidResponse
        }

        return Set(items.compactMap { parseOptionalString($0["id"]) })
    }

    private func parseTestEvents(from data: Data) -> TestEventSummary {
        guard let text = String(data: data, encoding: .utf8) else {
            return TestEventSummary(model: nil, success: false, error: "响应不可读", content: "", sawContentEvent: false)
        }

        var model: String?
        var success = false
        var error: String?
        var content = ""
        var sawContentEvent = false

        for line in text.split(whereSeparator: \.isNewline) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix("data:") else {
                continue
            }

            let jsonText = trimmedLine.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            guard jsonText.isEmpty == false,
                  let jsonData = jsonText.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }

            switch parseOptionalString(event["type"]) {
            case "test_start":
                model = parseOptionalString(event["model"]) ?? model
            case "content":
                if let text = parseOptionalString(event["text"]) {
                    sawContentEvent = true
                    content += text
                }
            case "test_complete":
                success = parseOptionalBool(event["success"]) ?? true
            case "error":
                error = parseOptionalString(event["error"]) ?? parseOptionalString(event["text"])
            default:
                continue
            }
        }

        return TestEventSummary(
            model: model,
            success: success,
            error: error,
            content: content,
            sawContentEvent: sawContentEvent
        )
    }

    private func parseOptionalString(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }

        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedString.isEmpty ? nil : trimmedString
    }

    private func parseOptionalBool(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }

    private func status(for score: Int, probes: [ModelDegradationProbeResult]) -> ModelDegradationStatus {
        guard probes.contains(where: \.passed) else {
            return .failed
        }

        let failedProbeIDs = Set(probes.filter { $0.passed == false }.map(\.id))
        if failedProbeIDs.contains("account-test") || failedProbeIDs.contains("models") {
            return .unavailable
        }
        if failedProbeIDs.contains("model-consistency") {
            return .modelMismatch
        }
        if failedProbeIDs.contains("instruction") || failedProbeIDs.contains("reasoning") {
            return .suspicious
        }
        if failedProbeIDs.contains("stream") || failedProbeIDs.contains("compact") {
            return .watch
        }
        if failedProbeIDs.contains("latency-stability") {
            return .watch
        }

        if score >= 90 {
            return .normal
        }
        if score >= 75 {
            return .watch
        }
        if score >= 60 {
            return .suspicious
        }
        return .highRisk
    }
}

private struct TestEventSummary {
    let model: String?
    let success: Bool
    let error: String?
    let content: String
    let sawContentEvent: Bool
}

private struct AccountProbeEvaluation {
    let result: ModelDegradationProbeResult
    let points: Int
    let maxPoints: Int
    let responseModel: String?
    let latency: TimeInterval?
    let sawContentEvent: Bool

    static func pass(id: String, title: String, detail: String, points: Int) -> AccountProbeEvaluation {
        AccountProbeEvaluation(
            result: ModelDegradationProbeResult(id: id, title: title, passed: true, detail: detail),
            points: points,
            maxPoints: points,
            responseModel: nil,
            latency: nil,
            sawContentEvent: false
        )
    }

    static func skip(id: String, title: String, detail: String) -> AccountProbeEvaluation {
        AccountProbeEvaluation(
            result: ModelDegradationProbeResult(id: id, title: title, passed: true, detail: detail),
            points: 0,
            maxPoints: 0,
            responseModel: nil,
            latency: nil,
            sawContentEvent: false
        )
    }

    static func fail(
        id: String,
        title: String,
        detail: String,
        maxPoints: Int = 0,
        latency: TimeInterval? = nil,
        responseModel: String? = nil,
        sawContentEvent: Bool = false
    ) -> AccountProbeEvaluation {
        AccountProbeEvaluation(
            result: ModelDegradationProbeResult(id: id, title: title, passed: false, detail: detail),
            points: 0,
            maxPoints: maxPoints,
            responseModel: responseModel,
            latency: latency,
            sawContentEvent: sawContentEvent
        )
    }
}
