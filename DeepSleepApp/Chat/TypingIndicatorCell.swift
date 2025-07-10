//
//  TypingIndicatorCell.swift
//  DeepSleep
//
//  Created by Assistant on 2025-07-10.
//

import UIKit

class TypingIndicatorCell: UITableViewCell {
    static let identifier = "TypingIndicatorCell"
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let dotsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let dots: [UIView] = {
        return (0..<3).map { _ in
            let dot = UIView()
            dot.backgroundColor = .systemGray3
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8)
            ])
            return dot
        }
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        startAnimating()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        contentView.addSubview(containerView)
        containerView.addSubview(dotsStackView)
        
        dots.forEach { dotsStackView.addArrangedSubview($0) }
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            containerView.widthAnchor.constraint(equalToConstant: 60),
            
            dotsStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            dotsStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    private func startAnimating() {
        dots.enumerated().forEach { index, dot in
            UIView.animate(
                withDuration: 0.4,
                delay: Double(index) * 0.1,
                options: [.repeat, .autoreverse],
                animations: {
                    dot.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                    dot.alpha = 0.6
                }
            )
        }
    }
}