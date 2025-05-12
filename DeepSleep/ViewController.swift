//
//  ViewController.swift
//  DeepSleep
//
//  Created by 추동준 on 4/15/25.
import UIKit

class MainViewController: UIViewController {

    // MARK: - 사운드 버튼 구성 (12개)
    let soundNames = [
        "Rainstorm", "Thunder", "Wave", "Bonfire",
        "Steam", "Windowsill Rain", "Forest Bird", "Cold Wind",
        "Summer Night", "Lullaby", "Fan", "White Noise"
    ]
    
    var soundButtons: [SoundSliderView] = []
    let stackView = UIStackView()

    // MARK: - 상단 라벨 + 타이머 버튼
    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "DeepSleep"
        label.font = UIFont.boldSystemFont(ofSize: 28)
        label.textAlignment = .center
        return label
    }()
    
    let timerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("⏱ 타이머", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        return button
    }()
    
    // MARK: - 뷰 생명주기
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        setupLayout()
    }

    // MARK: - 레이아웃 구성
    func setupLayout() {
        view.addSubview(titleLabel)
        view.addSubview(timerButton)
        view.addSubview(stackView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        timerButton.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            timerButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            timerButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            stackView.topAnchor.constraint(equalTo: timerButton.bottomAnchor, constant: 30),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
        ])
        
        // 사운드 버튼 구성
        stackView.axis = .vertical
        stackView.spacing = 15
        for name in soundNames {
            if let sliderView = Bundle.main.loadNibNamed("SoundSliderView", owner: nil, options: nil)?.first as? SoundSliderView {
                sliderView.soundName = name
                soundButtons.append(sliderView)
                stackView.addArrangedSubview(sliderView)
            }
        }
    }
}
