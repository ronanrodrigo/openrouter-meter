import Foundation

/// O que o aplicativo mostra na barra de menus.
enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Sendable {
    /// Saldo que ainda resta na conta.
    case remainingBalance
    /// Custo acumulado no dia.
    case todayCost

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .remainingBalance: "Saldo restante"
        case .todayCost: "Custo de hoje"
        }
    }
}

/// Cadência da atualização periódica do relatório.
enum RefreshInterval: Int, CaseIterable, Identifiable, Sendable {
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case oneHour = 3600

    /// Padrão do aplicativo: cinco minutos.
    static let `default`: RefreshInterval = .fiveMinutes

    var id: Int {
        rawValue
    }

    /// Intervalo em segundos.
    var seconds: Double {
        Double(rawValue)
    }

    var title: String {
        switch self {
        case .oneMinute: "1 minuto"
        case .fiveMinutes: "5 minutos"
        case .fifteenMinutes: "15 minutos"
        case .oneHour: "1 hora"
        }
    }
}
