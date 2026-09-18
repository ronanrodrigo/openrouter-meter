/// Cota de requisições gratuitas do dia, quando o provedor informa.
public struct FreeModelQuota: Sendable, Hashable {
    public let used: Int
    public let limit: Int

    public init(used: Int, limit: Int) {
        self.used = used
        self.limit = limit
    }

    public var remaining: Int {
        max(0, limit - used)
    }

    public var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(1, Double(used) / Double(limit))
    }
}

/// Retrato do crédito da conta no provedor.
public struct AccountSnapshot: Sendable, Hashable {
    public let totalCredits: Money
    public let totalUsage: Money
    public let dailyUsage: Money
    public let weeklyUsage: Money
    public let monthlyUsage: Money
    public let isFreeTier: Bool
    public let freeModelQuota: FreeModelQuota?

    public init(
        totalCredits: Money,
        totalUsage: Money,
        dailyUsage: Money = .zero,
        weeklyUsage: Money = .zero,
        monthlyUsage: Money = .zero,
        isFreeTier: Bool = false,
        freeModelQuota: FreeModelQuota? = nil
    ) {
        self.totalCredits = totalCredits
        self.totalUsage = totalUsage
        self.dailyUsage = dailyUsage
        self.weeklyUsage = weeklyUsage
        self.monthlyUsage = monthlyUsage
        self.isFreeTier = isFreeTier
        self.freeModelQuota = freeModelQuota
    }

    /// Saldo que ainda resta na conta.
    public var remaining: Money {
        totalCredits - totalUsage
    }

    /// Fração do crédito total já consumida, entre 0 e 1.
    public var consumedFraction: Double {
        guard totalCredits.micros > 0 else { return 0 }
        return min(1, max(0, totalUsage.dollars / totalCredits.dollars))
    }
}

/// Instante absoluto, sem depender de `Foundation`.
public struct UnixTimestamp: Sendable, Hashable, Comparable {
    public let seconds: Double

    public init(seconds: Double) {
        self.seconds = seconds
    }

    public static func < (lhs: UnixTimestamp, rhs: UnixTimestamp) -> Bool {
        lhs.seconds < rhs.seconds
    }
}

/// Relatório completo exibido pelo aplicativo.
public struct UsageReport: Sendable {
    public let account: AccountSnapshot
    public let windows: [UsageWindow]
    public let source: UsageSource
    public let capturedAt: UnixTimestamp

    public init(account: AccountSnapshot, windows: [UsageWindow], source: UsageSource, capturedAt: UnixTimestamp) {
        self.account = account
        self.windows = windows
        self.source = source
        self.capturedAt = capturedAt
    }

    public func window(_ kind: UsageWindowKind) -> UsageWindow? {
        windows.first { $0.kind == kind }
    }
}
