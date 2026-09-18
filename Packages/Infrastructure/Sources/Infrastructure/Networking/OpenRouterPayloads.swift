import Foundation

// Formatos JSON devolvidos pelos endpoints públicos do OpenRouter.
//
// Ficam isolados da camada de domínio: o adaptador traduz estes tipos para Money,
// TokenCounts e congêneres.

// MARK: - GET /credits

struct CreditsResponse: Decodable {
    let data: CreditsPayload
}

struct CreditsPayload: Decodable {
    let totalCredits: Double
    let totalUsage: Double

    enum CodingKeys: String, CodingKey {
        case totalCredits = "total_credits"
        case totalUsage = "total_usage"
    }
}

// MARK: - GET /key

struct KeyResponse: Decodable {
    let data: KeyPayload
}

struct KeyPayload: Decodable {
    let usageDaily: Double?
    let usageWeekly: Double?
    let usageMonthly: Double?
    let isFreeTier: Bool?
    let freeModelDailyRequests: FreeModelDailyRequests?

    enum CodingKeys: String, CodingKey {
        case usageDaily = "usage_daily"
        case usageWeekly = "usage_weekly"
        case usageMonthly = "usage_monthly"
        case isFreeTier = "is_free_tier"
        case freeModelDailyRequests = "free_model_daily_requests"
    }
}

struct FreeModelDailyRequests: Decodable {
    let used: Int
    let limit: Int
}

// MARK: - GET /activity

struct ActivityResponse: Decodable {
    let data: [ActivityEntry]
}

struct ActivityEntry: Decodable {
    let date: String
    let model: String
    let usage: Double?
    let requests: Int?
    let promptTokens: Int?
    let completionTokens: Int?
    let reasoningTokens: Int?

    enum CodingKeys: String, CodingKey {
        case date
        case model
        case usage
        case requests
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case reasoningTokens = "reasoning_tokens"
    }
}
