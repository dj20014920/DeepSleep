import UIKit

/// 정책 모음집 허브 (리플릿(Leaflet)App 타겟 기본 경로)
/// - 개인정보처리방침/이용약관(앱 내 텍스트) / 구독 관리 딥링크 / 건강 면책 고지
final class PolicyHubViewController: UITableViewController {
    private enum PolicyItem: Int, CaseIterable {
        case privacy
        case terms
        case subscriptionManagement
        case medicalDisclaimer
        case dataRetentionPolicy
        case permissionsPolicy
        case aiUsagePolicy
        case securityPolicy
        case contactSupport
        
        var title: String {
            switch self {
            case .privacy: return "개인정보처리방침"
            case .terms: return "이용약관"
            case .subscriptionManagement: return "구독 관리 (iOS 설정으로 이동)"
            case .medicalDisclaimer: return "건강/의학적 조언 면책 고지"
            case .dataRetentionPolicy: return "데이터 보존·자동 정리 정책"
            case .permissionsPolicy: return "앱 권한 사용 정책"
            case .aiUsagePolicy: return "대나무숲 친구 AI 사용 정책"
            case .securityPolicy: return "보안 및 데이터 보호 정책"
            case .contactSupport: return "문의 및 지원"
            }
        }
        
        var subtitle: String {
            switch self {
            case .privacy: return "데이터 수집/이용/보관/제3자 제공 정책"
            case .terms: return "서비스 이용 조건 및 사용자 권리/의무"
            case .subscriptionManagement: return "App Store 구독 관리 화면으로 이동"
            case .medicalDisclaimer: return "본 앱은 의학적 진단/치료를 대체하지 않습니다"
            case .dataRetentionPolicy: return "30일 압축 / 60일 삭제 · 보호 요일 · 알림 옵트아웃"
            case .permissionsPolicy: return "캘린더, 알림 등 앱 권한 사용 목적"
            case .aiUsagePolicy: return "AI 모델 사용, 데이터 처리, 응답 품질 정책"
            case .securityPolicy: return "API 키 보호, 프록시 서버, 보안 검증 시스템"
            case .contactSupport: return "개발자 피드백, 문의, 버그 신고"
            }
        }
        
        var icon: String {
            switch self {
            case .privacy: return "🔒"
            case .terms: return "📄"
            case .subscriptionManagement: return "💳"
            case .medicalDisclaimer: return "⚕️"
            case .dataRetentionPolicy: return "🗂️"
            case .permissionsPolicy: return "🔐"
            case .aiUsagePolicy: return "🧠"
            case .securityPolicy: return "🛡️"
            case .contactSupport: return "📧"
            }
        }
    }
    
    // 앱 내 표시용 정책 텍스트 (초기 버전 — URL 없이 표기)
    private let privacyText: String = """
    [개인정보처리방침]
    
    리플릿(Leaflet)(이하 “앱”)은 개인정보 보호법 등 관련 법령을 준수하며, 서비스 제공에 필요한 최소한의 개인정보만을 처리합니다.
    
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
    
    제1조(목적) 이 약관은 리플릿(Leaflet)(이하 “앱”)이 제공하는 서비스의 이용 조건 및 절차, 권리·의무 등 기본 사항을 규정합니다.
    
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
    
    private let aiUsagePolicyText: String = """
    [대나무숲 친구 AI 사용 정책]
    
    리플릿(Leaflet)은 사용자에게 최고의 AI 경험을 제공하기 위해 다음과 같은 AI 정책을 운영합니다.
    
    1) 대나무숲 친구 모델 시스템
       - 통합 모델: Claude 3.5 Haiku, OpenAI GPT-4o Mini, Google Gemini 2.0 Flash-Lite, Naver HyperCLOVA X
       - 무료 사용자: Gemini 2.0 Flash-Lite 고정 + 일일 한도 적용
       - 프리미엄 사용자: 모든 대나무숲 친구 모델 선택 가능 + 상향 한도
    
    2) 데이터 처리 및 보안
       - 개인정보 필터링: 외부 AI로 전송 전 비식별 서술형 컨텍스트로 변환
       - 프록시 서버: Cloudflare Workers를 통한 API 키 보호 및 비용 정책 집행
       - HMAC 인증: 모든 요청에 대한 암호화 서명 및 인증
    
    3) AI 응답 품질 정책
       - 다중 모델 폴백: 모델 실패 시 자동으로 다른 모델로 전환
       - 비용 기반 우선순위: 무료 모델 티어 → Gemini → OpenAI → Naver → Claude
       - 프롬프트 캐싱: 3시간 TTL로 Claude 비용 90% 절감
    
    4) 사용량 한도 및 공정 이용
       - 사용량 모니터링: 실시간 비용 및 사용량 추적
       - 공정 이용 정책: 과도한 사용 방지를 위한 일일 한도 적용
       - 80%/100% 도달 시 사전 안내 및 업그레이드 안내
    
    5) 학습 비활성화
       - 모든 API 호출에서 '학습 비활성화(Opt-out)' 옵션 명시적 설정
       - 사용자 데이터는 모델 학습에 사용되지 않음
    
    대나무숲 친구 AI는 사용자의 개인정보를 보호하면서 최고 품질의 대화 경험을 제공하기 위해 지속적으로 개선되고 있습니다.
    """
    
    private let securityPolicyText: String = """
    [보안 및 데이터 보호 정책]
    
    리플릿(Leaflet)은 사용자의 데이터 보안과 개인정보 보호를 최우선으로 하여 다음과 같은 보안 시스템을 운영합니다.
    
    1) API 키 보호 시스템
       - 프록시 서버: Cloudflare Workers 기반 중계 서버로 API 키 완전 보호
       - 앱 내 키 저장 금지: 모든 API 키는 서버에만 저장되며 앱에는 포함되지 않음
       - HMAC 인증: SHA256 기반 요청 서명으로 무단 접근 차단
    
    2) 데이터 전송 보안
       - TLS/HTTPS: 모든 데이터 전송은 암호화된 연결을 통해서만 진행
       - 비식별화: 외부 AI로 전송되는 모든 데이터는 개인정보 제거 후 전송
       - 중간자 공격 방지: 인증서 핀닝 및 SSL/TLS 검증
    
    3) 개인정보 보호 조치
       - PII 필터링: 이름, 전화번호, 이메일 등 개인정보 자동 탐지 및 마스킹
       - 최소 수집 원칙: 서비스 제공에 필요한 최소한의 정보만 수집
       - 로컬 처리 우선: 가능한 모든 처리는 기기 내에서 수행
    
    4) 접근 통제 및 모니터링
       - 레이트 리미팅: API 호출 제한으로 남용 방지
       - 이상 행동 탐지: 비정상적인 사용 패턴 모니터링
       - 로그 최소화: 필요한 최소한의 로그만 기록하며 민감정보 제외
    
    5) 사고 대응 체계
       - 보안 사고 발생 시 즉시 서비스 차단 및 조사
       - 사용자 알림: 중대한 보안 사고 시 투명한 공지
       - 복구 계획: 신속한 서비스 복구 및 재발 방지 조치
    
    6) 정기 보안 검토
       - 코드 보안 감사: 정기적인 보안 취약점 점검
       - 인프라 보안: 서버 및 네트워크 보안 강화
       - 업데이트 정책: 보안 패치 신속 적용
    
    본 보안 정책은 최신 보안 위협에 대응하기 위해 지속적으로 개선되며, 중요한 변경사항은 사전 공지됩니다.
    """
    
    private let contactSupportText: String = """
    [문의 및 지원]
    
    리플릿(Leaflet) 사용 중 궁금한 점이나 문제가 있으시면 언제든 연락해 주세요.
    
    1) 앱 내 문의
       - 경로: 설정 > 개발자 피드백
       - 장점: 앱 버전, 기기 정보 자동 포함으로 빠른 문제 해결
       - 대응 시간: 1-2 영업일 내 답변
    
    2) 주요 문의 유형
       - 기능 사용법 및 설정 방법
       - 버그 신고 및 오류 보고
       - 구독 및 결제 관련 문의
       - 개인정보 및 데이터 관련 문의
       - 기능 개선 제안 및 피드백
    
    3) 구독 관리
       - App Store 구독 관리: iOS 설정 > Apple ID > 구독
       - 환불 문의: App Store 고객지원
       - 구독 복원: 앱 내 "구매 복원" 기능 이용
    
    4) 긴급 문의
       - 보안 관련 긴급 사안
       - 개인정보 침해 신고
       - 앱 내 문의를 통해 [긴급] 표시하여 문의
    
    5) 개발자 정보
       - 개발사: DJ (개인사업자)
       - 위치: 대한민국
       - 언어: 한국어, 영어 지원
    
    사용자의 소중한 의견은 리플릿(Leaflet)을 더 나은 앱으로 만드는 데 큰 도움이 됩니다. 
    언제든 편하게 문의해 주세요!
    """

    private let dataRetentionText: String = """
    [데이터 보존 및 자동 정리 정책]
    
    리플릿(Leaflet)은 사용자 경험과 성능 최적화를 위해 다음과 같은 보존 정책을 적용합니다.
    
    1) 보존/정리 주기
       - 30일이 지난 대화 세션: 요약 메시지 1건으로 압축합니다(핵심 맥락만 보존).
       - 60일이 지난 대화 세션: 완전 삭제합니다(복구 불가).
    
    2) 보호 요일(예외)
       - 선택된 보호 요일에 생성된 세션은 압축/삭제 대상에서 제외될 수 있습니다.
       - 보호 요일은 추후 설정에서 관리할 수 있도록 확장 예정입니다.
    
    3) 시간 기준
       - 기본적으로 기기 시간을 사용합니다. 서버 시간이 제공되는 경우 오프셋을 반영하여 왜곡을 방지합니다.
    
    4) 알림 사용 목적과 옵트아웃
       - 알림은 타이머 종료/할 일 리마인더처럼 목적이 분명한 경우에만 사용합니다.
       - 설정 > 알림 설정에서 전체/개별 알림을 끌 수 있으며, iOS 설정 앱으로 이동하여 권한을 변경할 수 있습니다.
    
    5) 개인정보 보호
       - 외부 공유/내보내기 시에는 이메일/전화/카드번호 등 PII를 마스킹하여 내보낼 수 있습니다.
    """
    
    private let permissionsPolicyText: String = """
    [앱 권한 사용 정책]
    
    리플릿(Leaflet)은 앱 기능 제공을 위해 최소한의 권한만을 요청하며, 사용자의 동의 하에만 사용합니다.
    
    1) 요력 권한
       - 사용 목적: 할 일을 시스템 얙륵에 동기화하여 다른 앱에서도 확인 및 알림 수신 가능
       - 데이터 범위: 사용자가 작성한 할 일 제목, 날짜, 메모만 저장
       - 선택사항: 사용자가 직접 동기화를 활성화한 경우에만 사용
    
    2) 알림 권한
       - 사용 목적: 타이머 종료, 할 일 리마인더 등 사용자가 설정한 알림 전송
       - 옵트아웃: 설정 > 알림 설정에서 전체/개별 알림을 끌 수 있으며, iOS 설정 앱으로 이동하여 권한을 변경할 수 있습니다.
    
    3) 건강 데이터 권한
       - 사용 목적: 수면 분석 및 마음챙김 데이터를 활용한 개인화 서비스 제공
       - 데이터 범위: 수면 데이터, 마음챙김 세션 (사용자 선택사항)
       - 보안: 모든 건강 데이터는 기기 내에서만 처리되며 외부로 전송되지 않습니다.
    
    4) 백그라운드 오디오 권한
       - 사용 목적: 수면 사운드 백그라운드 재생
       - 비고: 마이크 권한은 요청하지 않습니다.
    
    5) 권한 거부 시 영향
       - 알름 권한 거부 시 해당 기능을 사용할 수 없습니다.
       - 벘 언제든 설정에서 권한을 변경할 수 있습니다.
    
    권한 관리는 설정 > 권한 설정에서 이용할 수 있으며, 의문사항은 설정 > 개발자 피드백을 통해 접수 가능합니다.
    """
    
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
        case .dataRetentionPolicy:
            presentText(title: "데이터 보존/정리 정책", text: dataRetentionText)
        case .permissionsPolicy:
            presentText(title: "앱 권한 사용 정책", text: permissionsPolicyText)
        case .aiUsagePolicy:
            presentText(title: "대나무숲 친구 AI 사용 정책", text: aiUsagePolicyText)
        case .securityPolicy:
            presentText(title: "보안 및 데이터 보호 정책", text: securityPolicyText)
        case .contactSupport:
            showContactSupport()
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
    
    private func showContactSupport() {
        let alert = UIAlertController(
            title: "문의 및 지원",
            message: "리플릿(Leaflet) 사용 중 궁금한 점이나 문제가 있으시면 언제든 연락해 주세요.",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "앱 내 개발자 피드백", style: .default) { _ in
            // 설정 > 개발자 피드백으로 이동
            if let settingsVC = self.navigationController?.viewControllers.first(where: { $0 is SettingsViewController }) {
                self.navigationController?.popToViewController(settingsVC, animated: true)
                // 여기서 개발자 피드백 화면으로 이동하는 로직 추가 가능
            }
        })
        
        alert.addAction(UIAlertAction(title: "구독 관리 (iOS 설정)", style: .default) { _ in
            UIApplication.shared.open(self.subscriptionsURL, options: [:], completionHandler: nil)
        })
        
        alert.addAction(UIAlertAction(title: "자세한 문의 정보 보기", style: .default) { _ in
            self.presentText(title: "문의 및 지원", text: self.contactSupportText)
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
}
