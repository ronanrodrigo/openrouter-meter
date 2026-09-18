import Domain
import SwiftUI

/// Saldo em destaque, com o medidor de consumo no estilo do Finder.
struct BalanceHeaderView: View {
    let account: AccountSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("SALDO RESTANTE")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(.secondary)

            Text(Formatters.money(account.remaining))
                .font(Theme.Typography.number(Theme.Typography.bigNumber))
                .accessibilityLabel("Saldo restante")
                .accessibilityValue(Formatters.money(account.remaining))

            MeterBar(
                fraction: account.consumedFraction,
                tone: .state,
                label: "Crédito consumido",
                valueText: Formatters.percent(account.consumedFraction)
            )

            HStack(spacing: Theme.Spacing.xs) {
                Text("\(Formatters.money(account.totalUsage)) de \(Formatters.money(account.totalCredits))")
                    .font(Theme.Typography.number(Theme.Typography.caption))
                    .foregroundStyle(.secondary)
                Spacer(minLength: Theme.Spacing.xs)
                Text(Formatters.percent(account.consumedFraction))
                    .font(Theme.Typography.number(Theme.Typography.caption))
                    .foregroundStyle(.secondary)
            }

            if let quota = account.freeModelQuota {
                freeQuota(quota)
            }
        }
    }

    private func freeQuota(_ quota: FreeModelQuota) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text("REQUISIÇÕES GRATUITAS")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Spacing.hairline)

            MeterBar(
                fraction: quota.fraction,
                tone: .state,
                label: "Requisições gratuitas usadas",
                valueText: "\(Formatters.integer(quota.used)) de \(Formatters.integer(quota.limit))"
            )

            Text(quotaSummary(quota))
                .font(Theme.Typography.number(Theme.Typography.caption))
                .foregroundStyle(.secondary)
        }
    }

    private func quotaSummary(_ quota: FreeModelQuota) -> String {
        let used = Formatters.integer(quota.used)
        let limit = Formatters.integer(quota.limit)
        let remaining = Formatters.integer(quota.remaining)
        return "\(used) de \(limit) · restam \(remaining)"
    }
}

#Preview("Saldo") {
    BalanceHeaderView(account: PreviewData.account)
        .padding(Theme.Metrics.panelPadding)
        .frame(width: Theme.Metrics.panelWidth)
}

#Preview("Saldo baixo") {
    BalanceHeaderView(
        account: AccountSnapshot(
            totalCredits: Money(dollars: 100),
            totalUsage: Money(dollars: 94.20),
            isFreeTier: true,
            freeModelQuota: FreeModelQuota(used: 995, limit: 1000)
        )
    )
    .padding(Theme.Metrics.panelPadding)
    .frame(width: Theme.Metrics.panelWidth)
}
