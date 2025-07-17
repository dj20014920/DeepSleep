import UIKit
import Core

// ❶ 감정 분석 결과를 받는 클로저 타입
typealias EmotionInputHandler = (_ emotion: EmotionType, _ rawText: String) -> Void

class EmotionInputViewController: UIViewController, UITextViewDelegate {

    // MARK: –– Public API
    /// 분석이 끝나면 이 클로저를 통해 호출됩니다.
    var onEmotionInputComplete: EmotionInputHandler?

    // MARK: –– UI 컴포넌트
    private let questionLabel: UILabel = {
        let lb = UILabel()
        lb.text = "오늘 하루는 어땠나요?"
        lb.font = .systemFont(ofSize: 20, weight: .semibold)
        lb.textAlignment = .center
        lb.translatesAutoresizingMaskIntoConstraints = false
        return lb
    }()

    private let textView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        tv.layer.borderWidth = 1
        tv.layer.borderColor = UIColor.systemGray4.cgColor
        tv.layer.cornerRadius = 8
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let emojiStack: UIStackView = {
        let emojis = ["😴","😢","😠","😊","😔","😐"]
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 12
        sv.translatesAutoresizingMaskIntoConstraints = false
        for e in emojis {
            let btn = UIButton(type: .system)
            btn.setTitle(e, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 32)
            btn.tag = emojis.firstIndex(of: e)!
            sv.addArrangedSubview(btn)
        }
        return sv
    }()

    private let nextButton: UIButton = {
        let bt = UIButton(type: .system)
        bt.setTitle("다음", for: .normal)
        bt.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        bt.translatesAutoresizingMaskIntoConstraints = false
        return bt
    }()

    // MARK: –– 내부 상태
    private var selectedEmoji: String?

    // MARK: –– Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "감정 입력"

        setupUI()
        textView.delegate = self
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        // 각 이모지 버튼에 액션 연결
        for case let btn as UIButton in emojiStack.arrangedSubviews {
            btn.addTarget(self, action: #selector(emojiTapped(_:)), for: .touchUpInside)
        }
    }

    // MARK: –– UI 세팅
    private func setupUI() {
        [questionLabel, textView, emojiStack, nextButton].forEach {
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            questionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            questionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            questionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            textView.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textView.heightAnchor.constraint(equalToConstant: 150),

            emojiStack.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 16),
            emojiStack.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            emojiStack.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
            emojiStack.heightAnchor.constraint(equalToConstant: 44),

            nextButton.topAnchor.constraint(equalTo: emojiStack.bottomAnchor, constant: 32),
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // MARK: –– 액션
    @objc private func emojiTapped(_ sender: UIButton) {
        // 선택된 이모지 하이라이트
        selectedEmoji = (sender.titleLabel?.text ?? "")
        for case let btn as UIButton in emojiStack.arrangedSubviews {
            btn.alpha = (btn == sender ? 1.0 : 0.5)
        }
        // 텍스트 입력 해제
        textView.resignFirstResponder()
    }

    @objc private func nextTapped() {
        // 1) 우선순위: 텍스트가 있으면 텍스트 분석
        let rawText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawText.isEmpty {
            let emotionString = EmotionAnalyzer.analyze(text: rawText)
            let emotion = EmotionType(rawValue: emotionString) ?? .neutral
            onEmotionInputComplete?(emotion, rawText)
            return
        }

        // 2) 텍스트가 없고 이모지 선택됐으면 매핑
        if let e = selectedEmoji {
            let emotionString = EmotionAnalyzer.mapEmojiToEmotion(e)
            let emotion = EmotionType(rawValue: emotionString) ?? .neutral
            onEmotionInputComplete?(emotion, e)
            return
        }

        // 3) 둘 다 없으면 경고
        let alert = UIAlertController(
            title: "입력 필요",
            message: "이모지나 일기를 입력해주세요.",
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "확인", style: .default))
        present(alert, animated: true)
    }

    // MARK: –– UITextViewDelegate: 이모지 선택 해제
    func textViewDidBeginEditing(_ textView: UITextView) {
        selectedEmoji = nil
        for case let btn as UIButton in emojiStack.arrangedSubviews {
            btn.alpha = 1.0
        }
    }
}
