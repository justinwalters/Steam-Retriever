// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)
// Setup, all from the couch: find the Mac, pair Steam Retriever, pair streaming, test.

import SwiftUI

struct SetupView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            StepList()
            VStack(alignment: .leading, spacing: 30) {
                if let reason = model.setupReason {
                    HStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.brass)
                        Text(reason).foregroundStyle(Theme.text)
                    }
                    .font(.system(size: 26))
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.brass.opacity(0.15)))
                }
                Group {
                    switch model.setupStep {
                    case .findMac: FindMacStep()
                    case .pairRetriever: PairRetrieverStep()
                    case .pairSunshine: PairSunshineStep()
                    case .test: TestStep()
                    }
                }
                .id(model.setupStep)
                Spacer()
            }
            .padding(70)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onExitCommand { model.leaveSetup() }
    }
}

// MARK: - step list

private struct StepList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SprocketBadge(size: 140)
                .frame(maxWidth: .infinity)
            Text("Setup")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 20)
            ForEach(AppModel.SetupStep.allCases) { step in
                Button {
                    model.setupStep = step
                } label: {
                    HStack(spacing: 18) {
                        StepIcon(state: model.stepStates[step] ?? .pending, number: step.rawValue + 1)
                        Text(step.title)
                    }
                }
                .buttonStyle(RowButtonStyle(selected: model.setupStep == step))
            }
            Spacer()
            if model.api?.token != nil {
                Button("Back to library") { model.leaveSetup() }
                    .buttonStyle(RowButtonStyle())
            }
        }
        .padding(50)
        .frame(width: 520)
        .frame(maxHeight: .infinity)
        .background(Theme.panel.ignoresSafeArea())
        .focusSection()
    }
}

struct StepIcon: View {
    let state: AppModel.StepState
    var number: Int? = nil

    var body: some View {
        Group {
            switch state {
            case .ok: Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.good)
            case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.bad)
            case .skipped: Image(systemName: "minus.circle.fill").foregroundStyle(Theme.subtext)
            case .running: ProgressView()
            case .pending:
                if let number { Image(systemName: "\(number).circle") } else { Image(systemName: "circle") }
            }
        }
        .font(.system(size: 34))
        .frame(width: 40)
    }
}

/// One-line result under a step: green when done, red with the reason when not.
private struct StepResult: View {
    let state: AppModel.StepState?

    var body: some View {
        switch state {
        case .failed(let why):
            Label(why, systemImage: "xmark.circle.fill").foregroundStyle(Theme.bad)
        case .skipped(let why):
            Label(why, systemImage: "minus.circle.fill").foregroundStyle(Theme.subtext)
        case .ok:
            Label("Done", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.good)
        case .running:
            HStack(spacing: 14) { ProgressView(); Text("Working\u{2026}").foregroundStyle(Theme.subtext) }
        default:
            EmptyView()
        }
    }
}

private struct StepHeader: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 52, weight: .bold)).foregroundStyle(Theme.text)
            Text(detail).font(.system(size: 28)).foregroundStyle(Theme.subtext).frame(maxWidth: 1050, alignment: .leading)
        }
    }
}

// MARK: - 1. find the Mac

private struct FindMacStep: View {
    @Environment(AppModel.self) private var model
    @State private var address = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepHeader(title: "Find the Mac",
                       detail: "Pick the Mac running Steam Retriever, or type its address (mini.local or an IP address).")
            if model.discovery.macs.isEmpty {
                HStack(spacing: 14) {
                    ProgressView()
                    Text("Looking for Steam Retriever on your network\u{2026}").foregroundStyle(Theme.subtext)
                }
            } else {
                ForEach(model.discovery.macs) { mac in
                    Button {
                        Task { await model.connect(to: mac) }
                    } label: {
                        Label(mac.name, systemImage: "desktopcomputer")
                    }
                    .buttonStyle(RowButtonStyle(selected: model.host?.serviceName == mac.name))
                    .frame(maxWidth: 800)
                }
            }
            HStack(spacing: 30) {
                TextField("mini.local", text: $address)
                    .frame(width: 600)
                    .onSubmit { connect() }
                Button("Connect") { connect() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            StepResult(state: model.stepStates[.findMac])
        }
        .onAppear {
            if address.isEmpty { address = model.host?.address ?? "" }
            model.discovery.start()
        }
    }

    private func connect() {
        let a = address
        Task { await model.connect(address: a) }
    }
}

// MARK: - 2. pair Steam Retriever

private struct PairRetrieverStep: View {
    @Environment(AppModel.self) private var model
    @State private var code = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepHeader(title: "Pair Steam Retriever",
                       detail: "On the Mac, open Steam Retriever, click the gear and choose \u{201C}Pair Apple TV\u{2026}\u{201D}. Type the 6-digit code it shows. The code lasts 5 minutes.")
            HStack(spacing: 30) {
                TextField("6-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .frame(width: 400)
                    .onSubmit { pair() }
                Button("Pair") { pair() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(code.filter(\.isNumber).count != 6)
            }
            StepResult(state: model.stepStates[.pairRetriever])
        }
    }

    private func pair() {
        let c = code
        Task { await model.pair(code: c) }
    }
}

// MARK: - 3. pair streaming (Sunshine)

private struct PairSunshineStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepHeader(title: "Pair streaming",
                       detail: "One time only. When the PIN appears, open Sunshine's web page on the Mac (https://localhost:47990), go to the PIN tab and type it in.")
            if let pin = model.sunshinePIN {
                Text(pin)
                    .font(.system(size: 160, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.highlight)
                    .padding(.vertical, 20)
            }
            HStack(spacing: 30) {
                Button("Start pairing") { Task { await model.pairSunshine() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(model.stepStates[.pairSunshine] == .running)
                if case .skipped = model.stepStates[.pairSunshine] {
                    Button("Continue") { model.setupStep = .test }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            StepResult(state: model.stepStates[.pairSunshine])
        }
    }
}

// MARK: - 4. test

private struct TestStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepHeader(title: "Test",
                       detail: "Checks the Mac, the pairing and Sunshine. A short test stream joins this list once streaming is built in.")
            VStack(alignment: .leading, spacing: 18) {
                ForEach(model.testChecks) { check in
                    HStack(alignment: .firstTextBaseline, spacing: 18) {
                        StepIcon(state: check.state)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(check.id).font(.system(size: 30)).foregroundStyle(Theme.text)
                            switch check.state {
                            case .failed(let why), .skipped(let why):
                                Text(why).font(.system(size: 24)).foregroundStyle(Theme.subtext)
                            default:
                                EmptyView()
                            }
                        }
                    }
                }
            }
            HStack(spacing: 30) {
                Button(model.testChecks.isEmpty ? "Run test" : "Run again") { Task { await model.runTest() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(model.stepStates[.test] == .running)
                if model.testPassed {
                    Button("Go to library") { model.enterHome() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .task {
            if model.testChecks.isEmpty { await model.runTest() }
        }
    }
}
