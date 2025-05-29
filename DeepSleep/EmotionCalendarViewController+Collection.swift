import UIKit

// MARK: - UICollectionView DataSource & Delegate
extension EmotionCalendarViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return calendarDates.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CalendarDayCell.identifier, for: indexPath) as! CalendarDayCell
        
        let date = calendarDates[indexPath.item]
        cell.configure(with: date, emotionData: emotionData)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width - 6) / 7
        return CGSize(width: width, height: 40)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let date = calendarDates[indexPath.item] else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        
        if let emotion = emotionData[dateKey] {
            showDiaryDetail(for: date, emotion: emotion)
        }
    }
}

// MARK: - CalendarDayCell
class CalendarDayCell: UICollectionViewCell {
    static let identifier = "CalendarDayCell"
    
    private let dayLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emotionLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(dayLabel)
        contentView.addSubview(emotionLabel)
        
        NSLayoutConstraint.activate([
            dayLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            dayLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dayLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dayLabel.heightAnchor.constraint(equalToConstant: 20),
            
            emotionLabel.topAnchor.constraint(equalTo: dayLabel.bottomAnchor),
            emotionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            emotionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            emotionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2)
        ])
        
        layer.cornerRadius = 8
    }
    
    func configure(with date: Date?, emotionData: [String: String]) {
        guard let date = date else {
            dayLabel.text = ""
            emotionLabel.text = ""
            backgroundColor = .clear
            return
        }
        
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        dayLabel.text = "\(day)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        
        if let emotion = emotionData[dateKey] {
            emotionLabel.text = emotion
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        } else {
            emotionLabel.text = ""
            backgroundColor = .clear
        }
        
        // 오늘 날짜 표시
        if calendar.isDateInToday(date) {
            layer.borderWidth = 2
            layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            layer.borderWidth = 0
        }
        
        // 주말 색상
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 {
            dayLabel.textColor = .systemRed
        } else if weekday == 7 {
            dayLabel.textColor = .systemBlue
        } else {
            dayLabel.textColor = .label
        }
    }
}
