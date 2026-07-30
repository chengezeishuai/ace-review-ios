import Foundation
import SwiftUI

struct CommerceView: View {
    @State private var products: [CommerceProduct] = []
    @State private var entitlements: [EntitlementItem] = []
    @State private var orders: [CommerceOrderHistoryItem] = []
    @State private var purchasingID: String?
    @State private var errorMessage = ""
    @State private var purchaseMessage = ""
    @State private var isLoading = true

    var body: some View {
        ZStack {
            ACETheme.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("服务与额度")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(ACETheme.ink)
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else if products.isEmpty {
                        emptyCatalog
                    } else {
                        ForEach(products) { product in
                            VStack(alignment: .leading, spacing: 11) {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(product.name).font(.headline)
                                        Text(product.productType == "plan" ? "套餐服务" : "加次包")
                                            .font(.caption).foregroundStyle(ACETheme.muted)
                                    }
                                    Spacer()
                                    Text(price(product.priceCent)).font(.headline)
                                }
                                Text("云端 \(product.cloudCredits) 次 · 本地 \(product.localCredits) 次")
                                    .font(.subheadline).foregroundStyle(ACETheme.ink)
                                Button {
                                    Task { await purchase(product) }
                                } label: {
                                    PrimaryActionLabel(title: purchasingID == product.id ? "正在开通" : "立即开通", systemImage: "checkmark.circle", isWorking: purchasingID == product.id)
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(purchasingID != nil)
                            }
                            .aceCard()
                        }
                    }
                    if !entitlements.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("已开通权益").font(.headline)
                            ForEach(entitlements) { item in
                                HStack { Text(item.planCode).font(.subheadline.bold()); Spacer(); Text("云端 \(item.cloudRemaining) · 本地 \(item.localRemaining)").font(.caption).foregroundStyle(ACETheme.muted) }
                            }
                        }.aceCard()
                    }
                    if !orders.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("订购记录").font(.headline)
                            ForEach(orders.prefix(8)) { order in
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(order.productCode).font(.subheadline.bold())
                                        Text(order.beneficiaryName).font(.caption).foregroundStyle(ACETheme.muted)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(order.status == "paid" ? "已开通" : order.status).font(.caption.bold())
                                        if let paidAt = order.paidAt { Text(paidAt).font(.caption2).foregroundStyle(ACETheme.muted) }
                                    }
                                }
                            }
                        }.aceCard()
                    }
                }.padding(18)
            }
        }
        .navigationTitle("服务")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("开通未完成", isPresented: Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })) { Button("知道了", role: .cancel) {} } message: { Text(errorMessage) }
        .alert("服务已开通", isPresented: Binding(get: { !purchaseMessage.isEmpty }, set: { if !$0 { purchaseMessage = "" } })) { Button("完成", role: .cancel) {} } message: { Text(purchaseMessage) }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let catalog = APIClient.shared.commerceCatalog()
            async let credits = APIClient.shared.entitlements()
            async let orderHistory = APIClient.shared.commerceOrders()
            products = try await catalog
            entitlements = try await credits.entitlements
            orders = try await orderHistory
        } catch {
            products = []
            errorMessage = error.localizedDescription
        }
    }

    private var emptyCatalog: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 30))
                .foregroundStyle(ACETheme.green)
            Text("暂未开放服务").font(.headline)
            Text("当前账号没有可购买的套餐，请稍后重试。")
                .font(.subheadline)
                .foregroundStyle(ACETheme.muted)
            Button("重新加载") { Task { await load() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
    }

    private func purchase(_ product: CommerceProduct) async {
        purchasingID = product.id
        defer { purchasingID = nil }
        do {
            let order = try await APIClient.shared.purchase(productCode: product.code)
            await load()
            purchaseMessage = "已为你的账号开通 \(product.name)：云端 \(order.cloudCredits) 次，本地 \(order.localCredits) 次。"
        }
        catch { errorMessage = error.localizedDescription }
    }

    private func price(_ cents: Int) -> String { cents == 0 ? "测试开通" : String(format: "¥%.2f", Double(cents) / 100) }
}
