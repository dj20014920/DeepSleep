import UIKit

/// 정책 모음집 허브 (DeepSleepApp 타겟 기본 경로)
/// - 개인정보처리방침/이용약관(앱 내 텍스트) / 구독 관리 딥링크 / 건강 면책 고지
final class PolicyHubViewController: UITableViewController {
    private enum PolicyItem: Int, CaseIterable {
        case privacy
        case terms
        case subscriptionManagement
        case medicalDisclaimer
        
        var title: String {
            switch self {
            case .privacy: return "개인정보처리방침"
            case .terms: return "이용약관"
            case .subscriptionManagement: return "구독 관리 (iOS 설정으로 이동)"
            case .medicalDisclaimer: return "건강/의학적 조언 면책 고지"
            }
        }
        
        var subtitle: String {
            switch self {
            case .privacy: return "데이터 수집/이용/보관/제3자 제공 정책"
            case .terms: return "서비스 이용 조건 및 사용자 권리/의무"
            case .subscriptionManagement: return "App Store 구독 관리 화면으로 이동"
            case .medicalDisclaimer: return "본 앱은 의학적 진단/치료를 대체하지 않습니다"
            }
        }
    }
    
    // 앱 내 표시용 정책 텍스트 (초기 버전 — URL 없이 표기)
    private let privacyText: String = """
    [개인정보처리방침]
    
    DeepSleep(이하 “앱”)은 개인정보 보호법 등 관련 법령을 준수하며, 서비스 제공에 필요한 최소한의 개인정보만을 처리합니다.
    
    1) 수집 및 처리 항목
       - 필수: 앱 사용 기록(요청/응답 시각, 기능별 사용 횟수 등 비식별 통계)
       - 선택: 사용자가 자발적으로 입력한 닉네임/기본 선호 설정(기기 내 저장)
       - 대화/일기 내용: 외부 AI로 전송 전 비식별 서술형 컨텍스트로 변환되며, 민감정보는 필터링됩니다.
    
    2) 이용 목적
       - 서비스 제공(대화, 추천, 통계), 품질 향상, 과금/한도 관리, 보안 모니터링
    
    3) 보관 및 파기
       - 목적 달성 또는 보관 기간 경과 시 지체 없이 파기합니다. 법령상 의무 보관이 있는 경우 해당 기간 동안 보관 후 파기합니다.
    
    4) 제3자 제공 및 처리위탁
       - 원칙적으로 제3자에게 제공하지 않습니다. 다만 법령에 근거한 요청이 있는 경우에 한해 제공될 수 있습니다.
       - 외부 AI API 호출은 프록시/보안 경로를 통해 중계되며, 개인을 직접 식별할 수 있는 데이터는 전송하지 않습니다.
    
    5) 이용자의 권리
       - 열람/정정/삭제/처리정지 요청이 가능하며, 앱 내 문의(설정 > 개발자 피드백)를 통해 접수 가능합니다.
    
    6) 안전성 확보 조치
       - 최소 수집/암호화/접근통제, 로깅 최소화, 민감정보 필터링(AISecurityManager) 적용
    
    7) 개인정보 보호책임자
       - 문의 경로: 설정 > 개발자 피드백(이메일/이슈 트래커 안내)
    
    본 방침은 앱 내 공지를 통해 개정될 수 있으며, 중요한 변경 시 사전 고지합니다.
    """
    
    private let termsText: String = """
    [이용약관]
    
    제1조(목적) 이 약관은 DeepSleep(이하 “앱”)이 제공하는 서비스의 이용 조건 및 절차, 권리·의무 등 기본 사항을 규정합니다.
    
    제2조(용어 정의) 주요 용어의 정의는 앱 내 안내에 따르며, 별도 정의가 없는 경우 관련 법령 및 일반 관례에 따릅니다.
    
    제3조(약관의 효력 및 변경) 본 약관은 앱 내 고지 시 효력이 발생하며, 필요한 경우 개정될 수 있습니다. 중요한 변경은 사전 고지합니다.
    
    제4조(서비스의 제공) 앱은 AI 기반 조언, 수면 사운드 추천, 사용 패턴 분석 등을 제공합니다. 일부 기능은 유료 구독이 필요할 수 있습니다.
    
    제5조(구독 및 결제) 월간/연간 자동갱신 구독을 제공하며, 동일 구독 그룹 내 1회 7일 무료체험이 제공됩니다. 결제/환불/해지는 App Store 정책을 따릅니다.
    
    제6조(해지) 사용자는 iOS 설정의 “구독 관리”에서 언제든 해지가 가능하며, 해지 시 기간 종료까지 권리가 유지됩니다.
    
    제7조(환불 및 권리 유지) 환불 시 앱 정책에 따라 결제일로부터 30일간 프리미엄 권리를 유지할 수 있으며, 이후 무료로 전환됩니다(내부 정책 고지 참조).
    
    제8조(사용자 의무) 불법/악의적 사용, 시스템 오남용, 타인의 권리 침해를 금지합니다. 위반 시 서비스 이용이 제한될 수 있습니다.
    
    제9조(면책) 앱의 정보와 조언은 일반적 웰니스 목적이며 의료적 진단/치료를 대체하지 않습니다. 의학적 판단은 전문가 상담에 따르십시오.
    
    제10조(개인정보 보호) 개인정보 처리에 관한 사항은 앱의 개인정보처리방침을 따릅니다.
    
    제11조(분쟁 해결) 분쟁이 발생한 경우 성실히 협의하며, 협의가 되지 않을 경우 관련 법령 및 관할 법원을 따릅니다.
    
    부칙: 이 약관은 앱 내 공지한 날로부터 시행합니다.
    """
    
    private let subscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "정책 모음집"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.tableFooterView = UIView()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        PolicyItem.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard let item = PolicyItem(rawValue: indexPath.row) else { return cell }
        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.secondaryText = item.subtitle
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = PolicyItem(rawValue: indexPath.row) else { return }
        switch item {
        case .privacy:
            presentText(title: "개인정보처리방침", text: privacyText)
        case .terms:
            presentText(title: "이용약관", text: termsText)
        case .subscriptionManagement:
            UIApplication.shared.open(subscriptionsURL, options: [:], completionHandler: nil)
        case .medicalDisclaimer:
            showMedicalDisclaimer()
        }
    }
    
    private func presentText(title: String, text: String) {
        let vc = UIViewController()
        vc.title = title
        vc.view.backgroundColor = .systemBackground
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = text
        textView.isEditable = false
        textView.font = .systemFont(ofSize: 15)
        vc.view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -16),
            textView.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor, constant: -16)
        ])
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func showMedicalDisclaimer() {
        let vc = UIViewController()
        vc.title = "건강/의학적 조언 면책"
        vc.view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "본 앱의 정보와 조언은 일반적 웰니스 목적이며, 의학적 진단/치료를 대체하지 않습니다. 건강 문제가 의심되면 전문가의 상담을 받으십시오."
        label.numberOfLines = 0
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
        navigationController?.pushViewController(vc, animated: true)
    }
}
