import Domain

/// Usa a primeira fonte que responder; se a primária falhar, tenta a secundária.
///
/// É a costura que permite exibir a atividade oficial da conta quando existe chave de
/// provisioning e cair para o histórico local quando ela não existe.
public struct FallbackUsageGateway: UsageGateway {
    private let primary: UsageGateway
    private let secondary: UsageGateway

    public init(primary: UsageGateway, secondary: UsageGateway) {
        self.primary = primary
        self.secondary = secondary
    }

    public var source: UsageSource {
        primary.source
    }

    public func windows(now: UnixTimestamp) async throws -> [UsageWindow] {
        do {
            return try await primary.windows(now: now)
        } catch {
            return try await secondary.windows(now: now)
        }
    }
}
