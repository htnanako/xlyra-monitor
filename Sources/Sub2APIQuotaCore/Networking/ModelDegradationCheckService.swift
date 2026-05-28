import Foundation

public protocol ModelDegradationChecking {
    func runCheck(configuration: ModelCheckConfiguration) async throws -> ModelDegradationCheckResult
}

public struct ModelDegradationCheckService: ModelDegradationChecking {
    private let httpClient: HTTPClient
    private let now: () -> Date

    public init(
        httpClient: HTTPClient,
        now: @escaping () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.now = now
    }

    public func runCheck(configuration: ModelCheckConfiguration) async throws -> ModelDegradationCheckResult {
        let startedAt = now()
        var probes: [ModelDegradationProbeResult] = []
        var score = 0
        var responseModel: String?
        var latency: TimeInterval?

        let modelProbe = await runModelsProbe(configuration: configuration)
        probes.append(modelProbe.result)
        score += modelProbe.points

        let jsonProbe = await runJSONProbe(configuration: configuration)
        probes.append(jsonProbe.result)
        score += jsonProbe.points
        responseModel = jsonProbe.responseModel
        latency = jsonProbe.latency

        let streamProbe = await runStreamProbe(configuration: configuration)
        probes.append(streamProbe.result)
        score += streamProbe.points

        let toolProbe = await runToolProbe(configuration: configuration)
        probes.append(toolProbe.result)
        score += toolProbe.points

        let instructionProbe = await runInstructionProbe(configuration: configuration)
        probes.append(instructionProbe.result)
        score += instructionProbe.points

        let reasoningProbe = await runReasoningProbe(configuration: configuration)
        probes.append(reasoningProbe.result)
        score += reasoningProbe.points

        return ModelDegradationCheckResult(
            targetModel: configuration.model,
            responseModel: responseModel,
            score: score,
            status: status(
                for: score,
                probes: probes,
                responseModel: responseModel,
                targetModel: configuration.model
            ),
            latency: latency,
            checkedAt: startedAt,
            probes: probes
        )
    }

    private func runModelsProbe(configuration: ModelCheckConfiguration) async -> ProbeEvaluation {
        do {
            let response = try await send(
                path: "/v1/models/\(configuration.model)",
                method: "GET",
                configuration: configuration
            )
            guard response.statusCode == 200,
                  let payload = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
                return .fail(id: "models", title: "模型检索", detail: "模型接口不可用或返回异常")
            }

            let id = payload["id"] as? String
            if id == configuration.model {
                return .pass(id: "models", title: "模型检索", detail: "目标模型可检索", points: 10)
            }

            return .fail(id: "models", title: "模型检索", detail: "返回模型 \(id ?? "--")")
        } catch {
            return .fail(id: "models", title: "模型检索", detail: "模型接口请求失败")
        }
    }

    private func runJSONProbe(configuration: ModelCheckConfiguration) async -> ProbeEvaluation {
        let startedAt = Date()
        do {
            let body: [String: Any] = [
                "model": configuration.model,
                "temperature": 0,
                "max_tokens": 80,
                "response_format": ["type": "json_object"],
                "messages": [
                    ["role": "system", "content": "You are a strict JSON API."],
                    ["role": "user", "content": "Return exactly a JSON object with answer=42 and label=\"ok\"."]
                ]
            ]
            let response = try await sendChatCompletion(body: body, configuration: configuration)
            let elapsed = Date().timeIntervalSince(startedAt)
            guard response.statusCode == 200,
                  let payload = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
                return .fail(id: "json", title: "JSON 能力", detail: "响应异常")
            }

            let responseModel = payload["model"] as? String
            var points = 0
            var details: [String] = []

            if responseModel == configuration.model {
                points += 10
                details.append("模型一致")
            } else {
                details.append("响应模型 \(responseModel ?? "--")")
            }

            if usageLooksValid(payload["usage"]) {
                points += 10
                details.append("usage 正常")
            } else {
                details.append("usage 缺失")
            }

            if jsonAnswerLooksValid(payload) {
                points += 10
                details.append("JSON 任务通过")
            } else {
                details.append("JSON 任务失败")
            }

            return ProbeEvaluation(
                result: ModelDegradationProbeResult(
                    id: "json",
                    title: "JSON/模型一致性",
                    passed: points >= 20,
                    detail: details.joined(separator: "，")
                ),
                points: points,
                responseModel: responseModel,
                latency: elapsed
            )
        } catch {
            return .fail(id: "json", title: "JSON/模型一致性", detail: "聊天补全请求失败")
        }
    }

    private func runStreamProbe(configuration: ModelCheckConfiguration) async -> ProbeEvaluation {
        do {
            let body: [String: Any] = [
                "model": configuration.model,
                "temperature": 0,
                "max_tokens": 20,
                "stream": true,
                "messages": [
                    ["role": "user", "content": "Reply with only pong."]
                ]
            ]
            let response = try await sendChatCompletion(body: body, configuration: configuration)
            guard response.statusCode == 200,
                  let text = String(data: response.data, encoding: .utf8),
                  text.contains("data:"),
                  text.contains("[DONE]") || text.contains("\"delta\"") else {
                return .fail(id: "stream", title: "流式协议", detail: "SSE 流格式异常")
            }

            return .pass(id: "stream", title: "流式协议", detail: "SSE 流正常", points: 10)
        } catch {
            return .fail(id: "stream", title: "流式协议", detail: "流式请求失败")
        }
    }

    private func runToolProbe(configuration: ModelCheckConfiguration) async -> ProbeEvaluation {
        do {
            let body: [String: Any] = [
                "model": configuration.model,
                "temperature": 0,
                "max_tokens": 80,
                "messages": [
                    ["role": "user", "content": "Call the tool with answer 42 and label ok."]
                ],
                "tools": [[
                    "type": "function",
                    "function": [
                        "name": "mark_result",
                        "description": "Record the result.",
                        "parameters": [
                            "type": "object",
                            "properties": [
                                "answer": ["type": "integer"],
                                "label": ["type": "string"]
                            ],
                            "required": ["answer", "label"]
                        ]
                    ]
                ]],
                "tool_choice": [
                    "type": "function",
                    "function": ["name": "mark_result"]
                ]
            ]
            let response = try await sendChatCompletion(body: body, configuration: configuration)
            guard response.statusCode == 200,
                  let payload = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
                  toolCallLooksValid(payload) else {
                return .fail(id: "tool", title: "Tool Call", detail: "工具调用缺失或参数异常")
            }

            return .pass(id: "tool", title: "Tool Call", detail: "工具调用正常", points: 10)
        } catch {
            return .fail(id: "tool", title: "Tool Call", detail: "工具调用请求失败")
        }
    }

    private func runInstructionProbe(configuration: ModelCheckConfiguration) async -> ProbeEvaluation {
        do {
            let body: [String: Any] = [
                "model": configuration.model,
                "temperature": 0,
                "max_tokens": 40,
                "messages": [
                    ["role": "user", "content": "Reply with exactly this token and nothing else: OK_42"]
                ]
            ]
            let response = try await sendChatCompletion(body: body, configuration: configuration)
            guard response.statusCode == 200,
                  let payload = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
                  let content = firstMessageContent(payload) else {
                return .fail(id: "instruction", title: "指令跟随", detail: "响应异常")
            }

            let normalized = content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "`", with: "")
                .uppercased()
            if normalized == "OK_42" || normalized.contains("OK_42") {
                return .pass(id: "instruction", title: "指令跟随", detail: "格式约束正常", points: 20)
            }

            return .fail(id: "instruction", title: "指令跟随", detail: "未严格遵循输出约束")
        } catch {
            return .fail(id: "instruction", title: "指令跟随", detail: "指令探针请求失败")
        }
    }

    private func runReasoningProbe(configuration: ModelCheckConfiguration) async -> ProbeEvaluation {
        do {
            let body: [String: Any] = [
                "model": configuration.model,
                "temperature": 0,
                "max_tokens": 40,
                "messages": [
                    ["role": "user", "content": "Calculate 19 * 23 + 7. Reply with only the final number."]
                ]
            ]
            let response = try await sendChatCompletion(body: body, configuration: configuration)
            guard response.statusCode == 200,
                  let payload = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
                  let content = firstMessageContent(payload) else {
                return .fail(id: "reasoning", title: "基础推理", detail: "响应异常")
            }

            if content.contains("444") {
                return .pass(id: "reasoning", title: "基础推理", detail: "基础计算正常", points: 20)
            }

            return .fail(id: "reasoning", title: "基础推理", detail: "基础计算未通过")
        } catch {
            return .fail(id: "reasoning", title: "基础推理", detail: "推理探针请求失败")
        }
    }

    private func sendChatCompletion(body: [String: Any], configuration: ModelCheckConfiguration) async throws -> HTTPResponse {
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await send(
            path: "/v1/chat/completions",
            method: "POST",
            body: data,
            configuration: configuration
        )
    }

    private func send(
        path: String,
        method: String,
        body: Data? = nil,
        configuration: ModelCheckConfiguration
    ) async throws -> HTTPResponse {
        let url = endpoint(path: path, baseURL: configuration.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return try await httpClient.send(request, timeout: 30)
    }

    private func endpoint(path: String, baseURL: URL) -> URL {
        var base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if base.hasSuffix("/v1") && path.hasPrefix("/v1/") {
            base.removeLast(3)
        }
        return URL(string: base + path)!
    }

    private func usageLooksValid(_ usage: Any?) -> Bool {
        guard let usage = usage as? [String: Any] else {
            return false
        }
        return parseInt(usage["total_tokens"]) ?? 0 > 0
    }

    private func jsonAnswerLooksValid(_ payload: [String: Any]) -> Bool {
        guard let content = firstMessageContent(payload),
              let data = content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        return parseInt(object["answer"]) == 42 && object["label"] as? String == "ok"
    }

    private func toolCallLooksValid(_ payload: [String: Any]) -> Bool {
        guard let choices = payload["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let toolCalls = message["tool_calls"] as? [[String: Any]],
              let function = toolCalls.first?["function"] as? [String: Any],
              function["name"] as? String == "mark_result",
              let arguments = function["arguments"] as? String,
              let data = arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        return parseInt(object["answer"]) == 42 && object["label"] as? String == "ok"
    }

    private func firstMessageContent(_ payload: [String: Any]) -> String? {
        guard let choices = payload["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            return nil
        }

        return message["content"] as? String
    }

    private func parseInt(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }

    private func status(
        for score: Int,
        probes: [ModelDegradationProbeResult],
        responseModel: String?,
        targetModel: String
    ) -> ModelDegradationStatus {
        guard probes.contains(where: \.passed) else {
            return .failed
        }

        let failedProbeIDs = Set(probes.filter { $0.passed == false }.map(\.id))
        if failedProbeIDs.contains("models") {
            return .unavailable
        }
        if let responseModel, responseModel != targetModel {
            return .modelMismatch
        }
        if failedProbeIDs.contains("instruction") || failedProbeIDs.contains("reasoning") {
            return .suspicious
        }
        if failedProbeIDs.contains("json") {
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

private struct ProbeEvaluation {
    let result: ModelDegradationProbeResult
    let points: Int
    let responseModel: String?
    let latency: TimeInterval?

    static func pass(id: String, title: String, detail: String, points: Int) -> ProbeEvaluation {
        ProbeEvaluation(
            result: ModelDegradationProbeResult(id: id, title: title, passed: true, detail: detail),
            points: points,
            responseModel: nil,
            latency: nil
        )
    }

    static func fail(id: String, title: String, detail: String) -> ProbeEvaluation {
        ProbeEvaluation(
            result: ModelDegradationProbeResult(id: id, title: title, passed: false, detail: detail),
            points: 0,
            responseModel: nil,
            latency: nil
        )
    }
}
