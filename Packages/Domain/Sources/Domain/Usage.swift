/// Contagem de tokens por categoria.
public struct TokenCounts: Sendable, Hashable {
    public let input: Int
    public let output: Int
    public let cacheRead: Int
    public let cacheWrite: Int
    public let reasoning: Int

    public init(input: Int = 0, output: Int = 0, cacheRead: Int = 0, cacheWrite: Int = 0, reasoning: Int = 0) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
        self.reasoning = reasoning
    }

    public static let zero = TokenCounts()

    /// Tokens de entrada e saída somados (o que o produto exibe como "tokens").
    public var billed: Int {
        input + output
    }

    public var total: Int {
        input + output + cacheRead + cacheWrite
    }
}

/// Consumo atribuído a um modelo dentro de uma janela de tempo.
public struct ModelUsage: Sendable, Hashable, Identifiable {
    public var id: String {
        model
    }

    public let model: String
    public let calls: Int
    public let tokens: TokenCounts
    public let estimatedCost: Money

    public init(model: String, calls: Int, tokens: TokenCounts, estimatedCost: Money) {
        self.model = model
        self.calls = calls
        self.tokens = tokens
        self.estimatedCost = estimatedCost
    }

    /// Último segmento do identificador do modelo (`vendor/modelo` → `modelo`).
    public var shortName: String {
        model.split(separator: "/").last.map(String.init) ?? model
    }
}

/// Janela de agregação do consumo.
public enum UsageWindowKind: String, Sendable, CaseIterable, Identifiable {
    case today
    case lastSevenDays

    public var id: String {
        rawValue
    }
}

/// Consumo agregado de uma janela, com os modelos que mais pesaram.
public struct UsageWindow: Sendable, Hashable, Identifiable {
    public var id: UsageWindowKind {
        kind
    }

    public let kind: UsageWindowKind
    public let tokens: TokenCounts
    public let calls: Int
    public let cost: Money
    public let models: [ModelUsage]

    public init(kind: UsageWindowKind, tokens: TokenCounts, calls: Int, cost: Money, models: [ModelUsage]) {
        self.kind = kind
        self.tokens = tokens
        self.calls = calls
        self.cost = cost
        self.models = models
    }

    /// Modelos ordenados por tokens de entrada, do maior para o menor.
    public var rankedModels: [ModelUsage] {
        models.sorted { $0.tokens.input > $1.tokens.input }
    }

    /// Participação relativa de um modelo, entre 0 e 1, medida em tokens de entrada.
    public func share(of model: ModelUsage) -> Double {
        let denominator = models.reduce(0) { $0 + $1.tokens.input }
        guard denominator > 0 else { return 0 }
        return Double(model.tokens.input) / Double(denominator)
    }
}

/// Origem dos dados de consumo exibidos.
public enum UsageSource: String, Sendable {
    /// Atividade oficial da conta (chave de provisioning).
    case accountActivity
    /// Histórico local do Hermes (`state.db`).
    case localHermes
}
