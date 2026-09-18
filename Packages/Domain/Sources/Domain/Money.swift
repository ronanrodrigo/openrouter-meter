/// Valor monetário imutável em micro-dólares (1 dólar = 1_000_000 micros).
///
/// Micro-dólares evitam erro de ponto flutuante e mantêm o domínio livre de `Foundation`.
public struct Money: Sendable, Hashable, Comparable {
    public static let zero = Money(micros: 0)

    public let micros: Int64

    public init(micros: Int64) {
        self.micros = micros
    }

    public init(dollars: Double) {
        micros = Int64((dollars * 1_000_000).rounded())
    }

    public var dollars: Double {
        Double(micros) / 1_000_000
    }

    public var isZero: Bool {
        micros == 0
    }

    public var isNegative: Bool {
        micros < 0
    }

    public static func + (lhs: Money, rhs: Money) -> Money {
        Money(micros: lhs.micros + rhs.micros)
    }

    public static func += (lhs: inout Money, rhs: Money) {
        lhs = lhs + rhs
    }

    public static func - (lhs: Money, rhs: Money) -> Money {
        Money(micros: lhs.micros - rhs.micros)
    }

    public static func < (lhs: Money, rhs: Money) -> Bool {
        lhs.micros < rhs.micros
    }
}
