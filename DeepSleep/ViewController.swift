import UIKit

class ViewController: UIViewController, UITextFieldDelegate {

    let sliderLabels = Array("ABCDEFGHIJKL")
    var sliders: [UISlider] = []
    var volumeFields: [UITextField] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        let saveButton = UIBarButtonItem(title: "저장", style: .plain, target: self, action: #selector(savePresetTapped))
        let loadButton = UIBarButtonItem(title: "불러오기", style: .plain, target: self, action: #selector(loadPresetTapped))
        navigationItem.rightBarButtonItems = [saveButton, loadButton]
    }

    func setupUI() {
        let scrollView = UIScrollView()
        let containerView = UIView()
        let stackView = UIStackView()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            // ScrollView Constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // ContainerView Constraints.
            // (중요) 스크롤이 제대로 동작하게 하려면 contentLayoutGuide를 사용하는 것이 좋습니다.
            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            // 수직 스크롤만 필요하므로 너비는 ScrollView의 frameLayoutGuide에 맞춥니다.
            containerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            // StackView Constraints
            // (중요) StackView가 ContainerView의 크기를 결정하도록 top과 bottom을 명확히 연결합니다.
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20) // 컨텐츠의 바닥을 알려주어 스크롤 가능하게 함
        ])

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill // 자식 뷰들이 너비를 꽉 채우도록

        for labelChar in sliderLabels {
            let horizontalStack = UIStackView()
            horizontalStack.axis = .horizontal
            horizontalStack.spacing = 12
            horizontalStack.alignment = .center
            horizontalStack.distribution = .fill // 내부 요소들의 distribution 설정

            let nameLabel = UILabel()
            nameLabel.text = "\(labelChar)"
            nameLabel.widthAnchor.constraint(equalToConstant: 30).isActive = true
            nameLabel.textAlignment = .center

            let slider = UISlider()
            slider.minimumValue = 0
            slider.maximumValue = 100
            slider.value = 0
            slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
            // slider.widthAnchor.constraint(equalToConstant: 200).isActive = true // StackView의 .fill 분포에 맡기는 것이 좋을 수 있습니다. 필요시 유지.
            sliders.append(slider)

            let volumeField = UITextField()
            volumeField.borderStyle = .roundedRect
            volumeField.textAlignment = .center
            volumeField.keyboardType = .numberPad
            volumeField.delegate = self
            volumeField.text = "0"
            volumeField.widthAnchor.constraint(equalToConstant: 50).isActive = true
            volumeFields.append(volumeField)

            horizontalStack.addArrangedSubview(nameLabel)
            horizontalStack.addArrangedSubview(slider) // 슬라이더가 남는 공간을 채우도록 할 수 있습니다.
            horizontalStack.addArrangedSubview(volumeField)

            // 슬라이더가 더 많은 공간을 차지하도록 설정 (선택 사항)
            // slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
            // slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            stackView.addArrangedSubview(horizontalStack)
        }
    }

    @objc func sliderChanged(_ sender: UISlider) {
        guard let index = sliders.firstIndex(of: sender) else { return }
        let floatValue: Float = sender.value
        let value = Int(floatValue)

        if index < volumeFields.count {
            volumeFields[index].text = "\(value)"
        }
    }

    // textFieldDidEndEditing 함수 수정
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let currentIndex = volumeFields.firstIndex(of: textField) else {
            // 이 경우는 거의 발생하지 않겠지만, 안전을 위해 추가
            textField.text = "0"
            print("경고: textFieldDidEndEditing에서 textField를 찾을 수 없습니다.")
            return
        }

        let inputText = textField.text ?? "0" // 텍스트 필드가 비어있으면 "0"으로 간주
        var sliderValueToSet: Float = 0.0  // 슬라이더에 최종적으로 설정될 값
        var textToShowInField: String = "0" // 텍스트 필드에 최종적으로 표시될 문자열

        if let rawValue = Float(inputText) { // 입력값을 Float으로 변환 시도
            // Float 변환 성공
            if rawValue < 0 {
                sliderValueToSet = 0.0
                textToShowInField = "0"
            } else if rawValue > 100 {
                sliderValueToSet = 100.0
                textToShowInField = "100"
            } else {
                // 0에서 100 사이의 유효한 값 (소수점 포함 가능)
                sliderValueToSet = rawValue // 슬라이더는 Float 값을 그대로 가짐
                textToShowInField = "\(Int(rawValue))" // 텍스트 필드에는 정수 부분만 표시 (소수점 버림)
                                                     // 만약 반올림을 원하시면 Int(round(rawValue)) 로 변경
            }
        } else {
            // Float 변환 실패 (예: "abc" 같은 문자열 입력 시)
            // 이미 초기값으로 sliderValueToSet = 0.0, textToShowInField = "0"이 설정되어 있음
        }

        // 해당 슬라이더의 값을 업데이트
        if currentIndex < sliders.count {
            sliders[currentIndex].value = sliderValueToSet
        }

        // 텍스트 필드의 텍스트를 최종 값으로 업데이트
        textField.text = textToShowInField
    }
    
    @objc func loadPresetTapped() {
        let presetListVC = PresetListViewController()
        presetListVC.onPresetSelected = { [weak self] preset in
            for (i, volume) in preset.volumes.enumerated() where i < self?.sliders.count ?? 0 {
                self?.sliders[i].value = volume
                self?.volumeFields[i].text = "\(Int(volume))"
            }
        }
        navigationController?.pushViewController(presetListVC, animated: true)
    }
    
    func showWarning() {
        let warning = UIAlertController(title: "⚠️ 이름 없음", message: "프리셋 이름을 입력해야 저장됩니다.", preferredStyle: .alert)
        warning.addAction(UIAlertAction(title: "확인", style: .default))
        present(warning, animated: true)
    }
    // 키보드 "완료" 대신 리턴 키로 닫기 (숫자패드엔 기본적으로 없음)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    @objc func savePresetTapped() {
        let alert = UIAlertController(title: "프리셋 저장", message: "이름을 입력하세요", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "예: Rainy Night" }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "저장", style: .default, handler: { [weak self] _ in
            guard let self = self,
                  let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return }

            let volumes = self.sliders.map { $0.value }

            // ✅ 중복 확인
            if PresetManager.shared.getPreset(named: name) != nil {
                self.showOverwriteConfirmation(name: name, volumes: volumes)
            } else {
                PresetManager.shared.savePreset(name: name, volumes: volumes)
                self.showToast("프리셋이 저장되었습니다.")
            }
        }))
        present(alert, animated: true)
    }
    
    func showOverwriteConfirmation(name: String, volumes: [Float]) {
        let confirmAlert = UIAlertController(
            title: "중복된 이름",
            message: "'\(name)' 이름의 프리셋이 이미 존재합니다.\n덮어쓰시겠습니까?",
            preferredStyle: .alert
        )
        confirmAlert.addAction(UIAlertAction(title: "취소", style: .cancel))
        confirmAlert.addAction(UIAlertAction(title: "덮어쓰기", style: .destructive, handler: { _ in
            PresetManager.shared.savePreset(name: name, volumes: volumes)
            self.showToast("덮어쓰기 완료되었습니다.")
        }))
        present(confirmAlert, animated: true)
    }
    
    func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.font = .systemFont(ofSize: 14)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 8
        toast.clipsToBounds = true
        toast.alpha = 0

        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.widthAnchor.constraint(lessThanOrEqualToConstant: 240),
            toast.heightAnchor.constraint(equalToConstant: 35)
        ])

        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
                toast.alpha = 0
            }, completion: { _ in
                toast.removeFromSuperview()
            })
        }
    }
}
