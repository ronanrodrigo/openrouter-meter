@testable import Domain
import Testing

@Suite("Money")
struct MoneyTests {
    @Test("converte dólares em micros sem perder centavos")
    func dollarConversion() {
        #expect(Money(dollars: 1).micros == 1_000_000)
        #expect(Money(dollars: 91.9).micros == 91_900_000)
        #expect(Money(dollars: 0.000001).micros == 1)
        #expect(Money(dollars: 118.100719069).micros == 118_100_719)
    }

    @Test("expõe o valor em dólares")
    func dollarsRoundTrip() {
        #expect(Money(micros: 91_900_000).dollars == 91.9)
        #expect(Money.zero.dollars == 0)
    }

    @Test("soma, subtrai e compara")
    func arithmetic() {
        #expect(Money(dollars: 210) - Money(dollars: 118.1) == Money(micros: 91_900_000))
        #expect(Money(dollars: 1) + Money(dollars: 2) == Money(dollars: 3))
        #expect(Money(dollars: 1) < Money(dollars: 2))
        #expect(Money(dollars: 3) > Money(dollars: 1))
    }

    @Test("acumula com +=")
    func compoundAssignment() {
        var total = Money(dollars: 12.34)
        total += Money(dollars: 48.10)
        #expect(total == Money(dollars: 60.44))
        #expect(total.micros == 60_440_000)
    }

    @Test("detecta zero e valor negativo")
    func signProperties() {
        #expect(Money.zero.isZero)
        #expect(!Money(dollars: 0.5).isZero)
        #expect(Money(micros: -1).isNegative)
        #expect(!Money.zero.isNegative)
    }

    @Test("é hashable pelo valor")
    func hashing() {
        #expect(Set([Money(dollars: 1), Money(micros: 1_000_000)]).count == 1)
    }
}
