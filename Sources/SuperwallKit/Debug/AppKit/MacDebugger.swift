#if os(macOS)
import AppKit
import Combine
import SwiftUI

/// Native preview controls for dashboard and local-development deep links.
@MainActor
final class MacDebugger: NSObject, ObservableObject, NSWindowDelegate {
  struct Choice: Identifiable {
    let id: String
    let name: String
    let identifier: String
  }

  @Published var choices: [Choice] = []
  @Published var selection = ""
  @Published var locale = ""
  @Published var freeTrial = false
  @Published var message = "Loading paywalls…"
  @Published var isLoading = false
  private var window: NSWindow?
  private var cancellable: AnyCancellable?
  private let initialLocale: String?
  private unowned let manager: DebugManager

  init(manager: DebugManager) {
    self.manager = manager
    initialLocale = Superwall.shared.options.localeIdentifier
    super.init()
    locale = initialLocale ?? ""
  }

  func show(paywallId: String?, surfaceId: String?) async {
    let controller = MacDebugViewController(rootView: MacDebuggerView(model: self))
    let window = NSWindow(contentViewController: controller)
    window.isReleasedWhenClosed = false
    window.title = "Superwall Preview"
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.setContentSize(NSSize(width: 480, height: 280))
    window.delegate = self
    self.window = window
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    choices = (manager.devServer?.surfaces ?? []).map {
      Choice(id: $0.id, name: "Local: \($0.id)", identifier: $0.previewIdentifier)
    }
    do {
      let published = try await Superwall.shared.dependencyContainer.network.listPreviewPaywalls()
      choices += published.data.map { Choice(id: $0.id, name: $0.name, identifier: $0.identifier) }
      message = choices.isEmpty ? "No paywalls available." : ""
    } catch {
      message = choices.isEmpty
        ? error.localizedDescription
        : "Published paywalls unavailable; local previews are ready."
    }
    selection = choices.first { $0.id == (surfaceId ?? paywallId) }?.id ?? choices.first?.id ?? ""
  }

  func preview() {
    guard let choice = choices.first(where: { $0.id == selection }),
      let presenter = window?.contentViewController else { return }
    Superwall.shared.options.localeIdentifier = locale.isEmpty ? nil : locale
    let request = Superwall.shared.dependencyContainer.makePresentationRequest(
      .fromIdentifier(choice.identifier, freeTrialOverride: freeTrial),
      presenter: presenter,
      isDebuggerLaunched: true,
      isPaywallPresented: Superwall.shared.isPaywallPresented,
      type: .presentation
    )
    let publisher = PassthroughSubject<PaywallState, Never>()
    isLoading = true
    message = ""
    cancellable = publisher.receive(on: DispatchQueue.main).sink { [weak self] state in
      self?.isLoading = false
      switch state {
      case .presentationError(let error): self?.message = error.localizedDescription
      case .skipped(let reason): self?.message = "Paywall skipped: \(reason)"
      default: break
      }
    }
    Task { await Superwall.shared.internallyPresent(request, publisher) }
  }

  func close() {
    window?.delegate = nil
    window?.close()
    window = nil
    cancellable = nil
    Superwall.shared.options.localeIdentifier = initialLocale
    manager.isDebuggerLaunched = false
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    Task {
      await Superwall.shared.dismiss()
      await manager.closeDebugger(animated: false)
    }
    return false
  }
}

final class MacDebugViewController: NSHostingController<MacDebuggerView> {}

struct MacDebuggerView: View {
  @ObservedObject var model: MacDebugger

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Picker("Paywall", selection: $model.selection) {
        ForEach(model.choices) { choice in Text(choice.name).tag(choice.id) }
      }
      TextField("Locale override (e.g. en_US)", text: $model.locale)
      Toggle("Free trial available", isOn: $model.freeTrial)
      if !model.message.isEmpty {
        Text(model.message).font(.callout).foregroundStyle(.secondary)
      }
      HStack {
        Spacer()
        Button("Preview") { model.preview() }
          .keyboardShortcut(.defaultAction)
          .disabled(model.selection.isEmpty || model.isLoading)
      }
    }
    .padding(24)
    .frame(width: 480)
  }
}
#endif
