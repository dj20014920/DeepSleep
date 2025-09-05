import UIKit

/// 친구 말투 설정 화면 (대나무숲 친구 말투/MBTI 빠른 선택)
final class FriendToneSettingsViewController: UIViewController {
    // MARK: UI
    private let stack = UIStackView()

    // 빠른 톤 선택(멀티 선택) — 4x2 그리드(스크롤 없음)
    private var selectedTones = Set<UserSettingsModel.FriendTonePreset>()
    private var toneButtons: [UIButton] = []
    private let gridTones: [UserSettingsModel.FriendTonePreset] = [
        // 상단 3개
        .friendly, .professional, .calm,
        // 중단 3개
        .concise, .supportive, .analytical,
        // 하단 2개(글자 긴 항목)
        .humorous, .playful
    ]

    // MBTI 다이얼
    private let ieSegment = UISegmentedControl(items: ["I", "E", "미정"])
    private let nsSegment = UISegmentedControl(items: ["N", "S", "미정"])
    private let tfSegment = UISegmentedControl(items: ["T", "F", "미정"])
    private let pjSegment = UISegmentedControl(items: ["P", "J", "미정"])

    // 미리보기
    private let previewLabel = UILabel()

    // 현재 설정 로딩/편집 버퍼
    private var workingSettings = UserSettingsModel.loadFromUserDefaults()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "친구 말투 설정"
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        setupNav()
        setupLayout()
        applyCurrentValues()
        updatePreview()
    }

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
    }

    private func setupLayout() {
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        // 섹션: 빠른 말투 선택
        let toneCard = buildCard(title: "빠른 말투 선택", subtitle: "여러 개 선택 가능(선택하지 않아도 됩니다)")
        let grid = UIStackView(); grid.axis = .vertical; grid.spacing = 8; grid.translatesAutoresizingMaskIntoConstraints = false
        let row1 = UIStackView(); row1.axis = .horizontal; row1.spacing = 8; row1.distribution = .fillEqually
        let row2 = UIStackView(); row2.axis = .horizontal; row2.spacing = 8; row2.distribution = .fillEqually
        let row3 = UIStackView(); row3.axis = .horizontal; row3.spacing = 8; row3.distribution = .fillEqually
        toneCard.addSubview(grid)
        grid.addArrangedSubview(row1)
        grid.addArrangedSubview(row2)
        grid.addArrangedSubview(row3)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: toneCard.topAnchor, constant: 56),
            grid.leadingAnchor.constraint(equalTo: toneCard.leadingAnchor, constant: 12),
            grid.trailingAnchor.constraint(equalTo: toneCard.trailingAnchor, constant: -12),
            grid.bottomAnchor.constraint(equalTo: toneCard.bottomAnchor, constant: -12)
        ])
        // 버튼 생성(4x2)
        toneButtons = gridTones.enumerated().map { idx, preset in
            let b = UIButton(type: .system)
            b.setTitle(preset.displayName, for: .normal)
            b.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            b.layer.cornerRadius = 16
            b.tag = idx
            b.addTarget(self, action: #selector(toneButtonTapped(_:)), for: .touchUpInside)
            styleToneButton(b, selected: false)
            return b
        }
        for i in 0..<3 { row1.addArrangedSubview(toneButtons[i]) }
        for i in 3..<6 { row2.addArrangedSubview(toneButtons[i]) }
        for i in 6..<8 { row3.addArrangedSubview(toneButtons[i]) }
        stack.addArrangedSubview(toneCard)

        // 섹션: MBTI 다이얼
        let mbtiCard = buildCard(title: "MBTI 다이얼", subtitle: "선택사항입니다!(예: T/F 다이얼의 F 만 선택)")
        let mbtiGrid = UIStackView()
        mbtiGrid.axis = .vertical
        mbtiGrid.spacing = 12
        mbtiGrid.translatesAutoresizingMaskIntoConstraints = false
        mbtiCard.addSubview(mbtiGrid)
        NSLayoutConstraint.activate([
            mbtiGrid.topAnchor.constraint(equalTo: mbtiCard.topAnchor, constant: 56),
            mbtiGrid.leadingAnchor.constraint(equalTo: mbtiCard.leadingAnchor, constant: 12),
            mbtiGrid.trailingAnchor.constraint(equalTo: mbtiCard.trailingAnchor, constant: -12),
            mbtiGrid.bottomAnchor.constraint(equalTo: mbtiCard.bottomAnchor, constant: -12)
        ])

        // 세그먼트 중앙 "기본" 배치 및 동일폭
        ieSegment.removeAllSegments(); ["I","기본","E"].enumerated().forEach { ieSegment.insertSegment(withTitle: $0.element, at: $0.offset, animated: false) }
        nsSegment.removeAllSegments(); ["N","기본","S"].enumerated().forEach { nsSegment.insertSegment(withTitle: $0.element, at: $0.offset, animated: false) }
        tfSegment.removeAllSegments(); ["T","기본","F"].enumerated().forEach { tfSegment.insertSegment(withTitle: $0.element, at: $0.offset, animated: false) }
        pjSegment.removeAllSegments(); ["P","기본","J"].enumerated().forEach { pjSegment.insertSegment(withTitle: $0.element, at: $0.offset, animated: false) }

        [ieSegment, nsSegment, tfSegment, pjSegment].forEach { seg in
            seg.selectedSegmentIndex = 1 // 기본: 중앙
            seg.apportionsSegmentWidthsByContent = false // 동일폭
            seg.addTarget(self, action: #selector(mbtiChanged), for: .valueChanged)
        }

        mbtiGrid.addArrangedSubview(buildDialRow(title: "I/E", control: ieSegment))
        mbtiGrid.addArrangedSubview(buildDialRow(title: "N/S", control: nsSegment))
        mbtiGrid.addArrangedSubview(buildDialRow(title: "T/F", control: tfSegment))
        mbtiGrid.addArrangedSubview(buildDialRow(title: "P/J", control: pjSegment))
        stack.addArrangedSubview(mbtiCard)

        // 섹션: 미리보기
        let previewCard = buildCard(title: "대나무숲 친구의 성격", subtitle: nil)
        previewLabel.numberOfLines = 0
        previewLabel.font = UIFont.systemFont(ofSize: 13)
        previewLabel.textColor = UIDesignSystem.Colors.secondaryText
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewCard.addSubview(previewLabel)
        NSLayoutConstraint.activate([
            previewLabel.topAnchor.constraint(equalTo: previewCard.topAnchor, constant: 56),
            previewLabel.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 12),
            previewLabel.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -12),
            previewLabel.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: -12)
        ])
        stack.addArrangedSubview(previewCard)
    }

    private func buildCard(title: String, subtitle: String?) -> UIView {
        let card = UIView()
        card.backgroundColor = UIDesignSystem.Colors.cardBackground
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = UIDesignSystem.Colors.secondaryText
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12)
        ])
        return card
    }

    private func buildDialRow(title: String, control: UISegmentedControl) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        control.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(label)
        row.addArrangedSubview(control)
        label.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.heightAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
        return row
    }

    private func applyCurrentValues() {
        // 칩 상태
        selectedTones = Set(workingSettings.preferredFriendTones.filter { gridTones.contains($0) })
        for (idx, b) in toneButtons.enumerated() {
            let preset = gridTones[idx]
            styleToneButton(b, selected: selectedTones.contains(preset))
        }
        // MBTI 세그먼트
        let mbti = workingSettings.mbti
        ieSegment.selectedSegmentIndex = mbti.ie.segmentIndex
        nsSegment.selectedSegmentIndex = mbti.ns.segmentIndex
        tfSegment.selectedSegmentIndex = mbti.tf.segmentIndex
        pjSegment.selectedSegmentIndex = mbti.pj.segmentIndex
    }


    @objc private func mbtiChanged() {
        workingSettings.mbti.ie = UserSettingsModel.MBTITraitOption.fromSegmentIndex(ieSegment.selectedSegmentIndex, pair: .ie)
        workingSettings.mbti.ns = UserSettingsModel.MBTITraitOption.fromSegmentIndex(nsSegment.selectedSegmentIndex, pair: .ns)
        workingSettings.mbti.tf = UserSettingsModel.MBTITraitOption.fromSegmentIndex(tfSegment.selectedSegmentIndex, pair: .tf)
        workingSettings.mbti.pj = UserSettingsModel.MBTITraitOption.fromSegmentIndex(pjSegment.selectedSegmentIndex, pair: .pj)
        updatePreview()
    }

    private func updatePreview() {
        previewLabel.text = makePersonaPreviewText()
    }

    @objc private func cancelTapped() { dismiss(animated: true) }

    @objc private func saveTapped() {
        // 저장
        workingSettings.saveToUserDefaults()
        // 캐시 무효화(즉시 반영)
        AIContextManager.shared.clearCache(reason: .personaChanged, caller: "FriendToneSettings")
        let alert = UIAlertController(title: "저장 완료", message: "말투·MBTI 설정이 저장되었어요.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - Preview Builder
private extension FriendToneSettingsViewController {
    func makePersonaPreviewText() -> String {
        let tones = selectedTones.map { $0.displayName }.sorted()
        let toneLine = tones.isEmpty ? "선택된 말투: 기본" : "선택된 말투: " + tones.joined(separator: ", ")
        let mb = workingSettings.mbti
        // MBTI를 형용사로 요약: I/E, N/S, T/F, P/J 순서
        var adj: [String] = []
        switch mb.ie { case .i: adj.append("낯가리는"); case .e: adj.append("에너지 넘치는"); default: break }
        switch mb.ns { case .n: adj.append("직관적인"); case .s: adj.append("현실적인"); default: break }
        switch mb.tf { case .t: adj.append("논리적인"); case .f: adj.append("공감적인"); default: break }
        switch mb.pj { case .p: adj.append("유연한"); case .j: adj.append("체계적인"); default: break }
        let mbtiLine = adj.isEmpty ? "기본" : adj.joined(separator: ", ")
        return """
        • \(toneLine)
        • \(mbtiLine)
        """.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    @objc private func toneButtonTapped(_ sender: UIButton) {
        let preset = gridTones[sender.tag]
        if selectedTones.contains(preset) { selectedTones.remove(preset) } else { selectedTones.insert(preset) }
        workingSettings.preferredFriendTones = Array(selectedTones)
        styleToneButton(sender, selected: selectedTones.contains(preset))
        updatePreview()
    }

    private func styleToneButton(_ b: UIButton, selected: Bool) {
        b.layer.borderWidth = selected ? 1.5 : 0
        b.layer.borderColor = (selected ? UIColor.systemBlue : UIColor.clear).cgColor
        b.backgroundColor = selected ? UIColor.systemBlue.withAlphaComponent(0.12) : UIColor.systemGray6
        b.setTitleColor(selected ? .systemBlue : .label, for: .normal)
    }
}
