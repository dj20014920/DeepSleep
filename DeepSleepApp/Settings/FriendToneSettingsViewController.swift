import UIKit

/// 친구 말투 설정 화면 (대나무숲 친구 말투/MBTI 빠른 선택)
final class FriendToneSettingsViewController: UIViewController {
    // MARK: UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stack = UIStackView()

    // 빠른 톤 선택(멀티 선택)
    private let toneChipsContainer = UIStackView()
    private var toneChipButtons: [UIButton] = []

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
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])

        // 섹션: 빠른 말투 선택
        let toneCard = buildCard(title: "빠른 말투 선택", subtitle: "여러 개 선택 가능(선택하지 않아도 됩니다)")
        toneChipsContainer.axis = .horizontal
        toneChipsContainer.spacing = 8
        toneChipsContainer.alignment = .leading
        toneChipsContainer.distribution = .fillProportionally
        toneChipsContainer.translatesAutoresizingMaskIntoConstraints = false
        toneChipsContainer.wrapInto(container: toneCard)
        stack.addArrangedSubview(toneCard)

        // 토글 칩 생성
        toneChipButtons = UserSettingsModel.FriendTonePreset.allCases.map { preset in
            let b = UIButton(type: .system)
            b.setTitle(preset.displayName, for: .normal)
            b.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            b.setTitleColor(.label, for: .normal)
            b.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            b.backgroundColor = UIColor.systemGray6
            b.layer.cornerRadius = 16
            b.layer.borderWidth = 0
            b.accessibilityIdentifier = "tone_\(preset.rawValue)"
            b.addTarget(self, action: #selector(toneChipTapped(_:)), for: .touchUpInside)
            return b
        }
        toneChipButtons.forEach { toneChipsContainer.addArrangedSubview($0) }

        // 섹션: MBTI 다이얼
        let mbtiCard = buildCard(title: "MBTI 다이얼", subtitle: "하나만 골라도 됩니다 (예: T/F만 F 선택)")
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false
        mbtiCard.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: mbtiCard.topAnchor, constant: 56),
            grid.leadingAnchor.constraint(equalTo: mbtiCard.leadingAnchor, constant: 12),
            grid.trailingAnchor.constraint(equalTo: mbtiCard.trailingAnchor, constant: -12),
            grid.bottomAnchor.constraint(equalTo: mbtiCard.bottomAnchor, constant: -12)
        ])

        grid.addArrangedSubview(buildDialRow(title: "I/E", control: ieSegment))
        grid.addArrangedSubview(buildDialRow(title: "N/S", control: nsSegment))
        grid.addArrangedSubview(buildDialRow(title: "T/F", control: tfSegment))
        grid.addArrangedSubview(buildDialRow(title: "P/J", control: pjSegment))

        [ieSegment, nsSegment, tfSegment, pjSegment].forEach { seg in
            seg.selectedSegmentIndex = 2 // 기본: 미정
            seg.addTarget(self, action: #selector(mbtiChanged), for: .valueChanged)
        }
        stack.addArrangedSubview(mbtiCard)

        // 섹션: 미리보기
        let previewCard = buildCard(title: "적용 미리보기", subtitle: "시스템 프롬프트 일부와 톤 반영 예시")
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
        return row
    }

    private func applyCurrentValues() {
        // 칩 상태
        let selected = Set(workingSettings.preferredFriendTones)
        for b in toneChipButtons {
            if let raw = b.accessibilityIdentifier?.replacingOccurrences(of: "tone_", with: ""),
               let preset = UserSettingsModel.FriendTonePreset(rawValue: raw) {
                setChip(b, selected: selected.contains(preset))
            }
        }
        // MBTI 세그먼트
        let mbti = workingSettings.mbti
        ieSegment.selectedSegmentIndex = mbti.ie.segmentIndex
        nsSegment.selectedSegmentIndex = mbti.ns.segmentIndex
        tfSegment.selectedSegmentIndex = mbti.tf.segmentIndex
        pjSegment.selectedSegmentIndex = mbti.pj.segmentIndex
    }

    @objc private func toneChipTapped(_ sender: UIButton) {
        guard let raw = sender.accessibilityIdentifier?.replacingOccurrences(of: "tone_", with: ""),
              let preset = UserSettingsModel.FriendTonePreset(rawValue: raw) else { return }
        var set = Set(workingSettings.preferredFriendTones)
        if set.contains(preset) { set.remove(preset) } else { set.insert(preset) }
        workingSettings.preferredFriendTones = Array(set)
        setChip(sender, selected: set.contains(preset))
        updatePreview()
    }

    private func setChip(_ b: UIButton, selected: Bool) {
        b.layer.borderWidth = selected ? 1.5 : 0
        b.layer.borderColor = (selected ? UIColor.systemBlue : UIColor.clear).cgColor
        b.backgroundColor = selected ? UIColor.systemBlue.withAlphaComponent(0.12) : UIColor.systemGray6
        b.setTitleColor(selected ? .systemBlue : .label, for: .normal)
    }

    @objc private func mbtiChanged() {
        workingSettings.mbti.ie = UserSettingsModel.MBTITraitOption.fromSegmentIndex(ieSegment.selectedSegmentIndex, pair: .ie)
        workingSettings.mbti.ns = UserSettingsModel.MBTITraitOption.fromSegmentIndex(nsSegment.selectedSegmentIndex, pair: .ns)
        workingSettings.mbti.tf = UserSettingsModel.MBTITraitOption.fromSegmentIndex(tfSegment.selectedSegmentIndex, pair: .tf)
        workingSettings.mbti.pj = UserSettingsModel.MBTITraitOption.fromSegmentIndex(pjSegment.selectedSegmentIndex, pair: .pj)
        updatePreview()
    }

    private func updatePreview() {
        let snippet = workingSettings.generateAIContext()
        previewLabel.text = snippet
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

private extension UIStackView {
    /// 수평 래핑 모사: 단순히 컨테이너에 addSubview로 넣고 제약만 잡는다(간단 버전)
    func wrapInto(container: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.topAnchor, constant: 56),
            leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
    }
}

