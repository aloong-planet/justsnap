import Foundation
import JustSnapCore

/// The two languages the landing page ships screenshots in. Each one renders the app in that UI language over
/// made-up content written in a matching language.
enum ShotLocale: String, CaseIterable {
    case zh
    case en

    var effectiveLanguage: EffectiveApplicationLanguage {
        switch self {
        case .zh: .simplifiedChinese
        case .en: .english
        }
    }

    var targetLanguageCode: String {
        switch self {
        case .zh: "zh-Hans"
        case .en: "en"
        }
    }

    var regionIdentifier: String {
        switch self {
        case .zh: "zh_CN"
        case .en: "en_US"
        }
    }

    var copy: ShotCopy {
        switch self {
        case .zh: .zh
        case .en: .en
        }
    }
}

/// A page of made-up text, drawn as a document and also given as the Markdown a model would return for it.
struct FixtureDocument {
    let heading: String
    let paragraphs: [String]
    let bullets: [String]
    let closing: [String]

    var markdown: String {
        var blocks = ["# \(heading)"]
        blocks += paragraphs
        if !bullets.isEmpty { blocks.append(bullets.map { "- \($0)" }.joined(separator: "\n")) }
        blocks += closing
        return blocks.joined(separator: "\n\n")
    }
}

/// One source paragraph and its translation, for the translate scenes.
struct FixtureSegment {
    let source: String
    let translation: String
}

struct HistoryFixture {
    enum Kind { case extract, translate }
    enum Status { case succeeded, failed, canceled }
    let kind: Kind
    let status: Status
    let source: String
    let snippet: String
    let translation: String?
    /// Minutes before the fixed "now" of the scene
    let minutesAgo: Int
    let pinned: Bool
}

/// Every made-up word the screenshots show, per language. No real person, company logo or user data is in here:
/// the names are roles, the documents are invented, and the provider key is an obvious placeholder.
struct ShotCopy {
    // Select / hero scenes
    let articleTitle: String
    let articleParagraphs: [String]
    let readerWindowTitle: String
    let sideWindowTitle: String
    let sideLines: [String]
    let dashboardWindowTitle: String
    let dashboardSidebar: [String]
    let dashboardCardTitle: String
    let dashboardTableHeader: [String]
    let dashboardRows: [[String]]

    // Extract scene
    let extractWindowTitle: String
    let extractDocument: FixtureDocument

    // Translate scene
    let translateWindowTitle: String
    let translateHeading: FixtureSegment
    let translateParagraphs: [FixtureSegment]

    // Paste scene
    let pasteRecent: [(title: String, detail: String)]
    let pasteSource: [String]
    let pasteTranslation: [String]

    // History scene
    let historyRows: [HistoryFixture]

    static let zh = ShotCopy(
        articleTitle: "为什么安静的界面很重要",
        articleParagraphs: [
            "好用的工具软件始终贴近当前任务：启动迅速，把一件事做好，然后让开。",
            "当每个控件都在争夺注意力，人们读得更少、点得更多。安静的版面，让内容自己说话。",
        ],
        readerWindowTitle: "阅读器",
        sideWindowTitle: "备忘",
        sideLines: ["周四前确认发布清单", "整理用户反馈", "预约设计评审"],
        dashboardWindowTitle: "季度计划",
        dashboardSidebar: ["概览", "路线图", "任务", "报告"],
        dashboardCardTitle: "各季度完成的任务数",
        dashboardTableHeader: ["事项", "负责组", "状态"],
        dashboardRows: [
            ["整理安装文档", "文档组", "进行中"],
            ["更新隐私说明", "法务组", "已完成"],
            ["发布 1.2 版本", "发布组", "待开始"],
            ["回访十位用户", "产品组", "进行中"],
        ],
        extractWindowTitle: "发布手册",
        extractDocument: FixtureDocument(
            heading: "发布前检查清单",
            paragraphs: ["本周五发布 1.2 版本，请在周四中午前确认以下事项："],
            bullets: [
                "完成安装包签名与公证",
                "更新发布说明与更新日志",
                "复核隐私声明里的数据说明",
                "在干净的系统上做一次全新安装测试",
                "确认自动更新的提示文字",
                "备份上一版的安装包",
            ],
            closing: ["全部确认后，请在发布群里回复“已确认”。"]
        ),
        translateWindowTitle: "Reader",
        translateHeading: FixtureSegment(
            source: "Why a calm interface matters",
            translation: "为什么安静的界面很重要"
        ),
        translateParagraphs: [
            FixtureSegment(
                source: "Good utility software stays close to the task. It opens quickly, does one thing well, and gets out of the way.",
                translation: "好用的工具软件始终贴近当前任务。它启动迅速，把一件事做好，然后让开。"
            ),
            FixtureSegment(
                source: "When every control competes for attention, people read less and click more. A quiet layout lets the content do the talking.",
                translation: "当每个控件都在争夺注意力，人们读得更少、点得更多。安静的版面，让内容自己说话。"
            ),
            FixtureSegment(
                source: "Small details add up. A steady shortcut, a clear result and a reliable retry make a tool feel calm.",
                translation: "细节会累积。稳定的快捷键、清晰的结果和可靠的重试，让工具用起来很安心。"
            ),
        ],
        pasteRecent: [
            ("发布前检查清单", "提取文字 · 3 分钟前"),
            ("为什么安静的界面很重要", "翻译 · 12 分钟前"),
            ("季度计划", "提取文字 · 1 小时前"),
        ],
        pasteSource: ["Hi team, the October invoice is attached. Please approve it before Friday so that the payment goes out on time.", "If anything looks off, reply to this message and I will fix it the same day. Thank you for the quick turnaround this month."],
        pasteTranslation: ["各位好，十月的发票已附上。请在周五前审批，以便按时付款。", "如有任何问题，请直接回复这封邮件，我会当天处理。感谢大家这个月的快速配合。"],
        historyRows: [
            HistoryFixture(kind: .translate, status: .succeeded, source: "Why a calm interface matters", snippet: "", translation: "为什么安静的界面很重要", minutesAgo: 4, pinned: true),
            HistoryFixture(kind: .extract, status: .succeeded, source: "发布前检查清单", snippet: "本周五发布 1.2 版本，请在周四中午前确认以下事项。", translation: nil, minutesAgo: 26, pinned: false),
            HistoryFixture(kind: .translate, status: .failed, source: "Quarterly planning notes", snippet: "", translation: nil, minutesAgo: 70, pinned: false),
            HistoryFixture(kind: .extract, status: .succeeded, source: "安装与升级说明", snippet: "把随译拖进“应用程序”文件夹，首次启动时授予屏幕录制权限。", translation: nil, minutesAgo: 190, pinned: false),
            HistoryFixture(kind: .translate, status: .succeeded, source: "Release notes, version 1.1", snippet: "", translation: "版本 1.1 发布说明", minutesAgo: 1_500, pinned: false),
        ]
    )

    static let en = ShotCopy(
        articleTitle: "Why a calm interface matters",
        articleParagraphs: [
            "Good utility software stays close to the task: it opens quickly, does one thing well, and gets out of the way.",
            "When every control competes for attention, people read less and click more. A quiet layout lets the content do the talking.",
        ],
        readerWindowTitle: "Reader",
        sideWindowTitle: "Notes",
        sideLines: ["Confirm the release list by Thursday", "Sort the user feedback", "Book the design review"],
        dashboardWindowTitle: "Quarterly plan",
        dashboardSidebar: ["Overview", "Roadmap", "Tasks", "Reports"],
        dashboardCardTitle: "Tasks completed per quarter",
        dashboardTableHeader: ["Item", "Owner", "Status"],
        dashboardRows: [
            ["Tidy the install guide", "Docs", "In progress"],
            ["Update the privacy notes", "Legal", "Done"],
            ["Ship version 1.2", "Release", "To do"],
            ["Call ten users back", "Product", "In progress"],
        ],
        extractWindowTitle: "Release handbook",
        extractDocument: FixtureDocument(
            heading: "Pre-release checklist",
            paragraphs: ["Version 1.2 ships on Friday. Please confirm the following by Thursday noon:"],
            bullets: [
                "Sign and notarize the installer",
                "Update the release notes and changelog",
                "Review the data notes in the privacy statement",
                "Test a fresh install on a clean system",
                "Check the wording of the update prompt",
                "Archive the previous installer",
            ],
            closing: ["Once everything is confirmed, reply \"Confirmed\" in the release channel."]
        ),
        translateWindowTitle: "Lecteur",
        translateHeading: FixtureSegment(
            source: "Pourquoi une interface calme compte",
            translation: "Why a calm interface matters"
        ),
        translateParagraphs: [
            FixtureSegment(
                source: "Un bon logiciel utilitaire reste proche de la tâche. Il s'ouvre vite, fait une chose et la fait bien, puis s'efface.",
                translation: "Good utility software stays close to the task. It opens quickly, does one thing well, and then gets out of the way."
            ),
            FixtureSegment(
                source: "Quand chaque commande se dispute l'attention, on lit moins et on clique plus. Une mise en page sobre laisse le contenu parler.",
                translation: "When every control competes for attention, people read less and click more. A quiet layout lets the content do the talking."
            ),
            FixtureSegment(
                source: "Les petits détails s'additionnent. Un raccourci stable, un résultat clair et un nouvel essai fiable rendent un outil serein.",
                translation: "Small details add up. A steady shortcut, a clear result and a reliable retry make a tool feel calm."
            ),
        ],
        pasteRecent: [
            ("Pre-release checklist", "Extract Text · 3 min ago"),
            ("Why a calm interface matters", "Translate · 12 min ago"),
            ("Quarterly plan", "Extract Text · 1 hr ago"),
        ],
        pasteSource: ["Bonjour à tous, la facture d'octobre est jointe. Merci de l'approuver avant vendredi afin que le paiement parte à temps.", "Si quelque chose vous semble anormal, répondez à ce message et je corrigerai le jour même. Merci pour votre réactivité ce mois-ci."],
        pasteTranslation: ["Hello everyone, the October invoice is attached. Please approve it before Friday so that the payment goes out on time.", "If anything looks off, reply to this message and I will fix it the same day. Thank you for your quick turnaround this month."],
        historyRows: [
            HistoryFixture(kind: .translate, status: .succeeded, source: "Pourquoi une interface calme compte", snippet: "", translation: "Why a calm interface matters", minutesAgo: 4, pinned: true),
            HistoryFixture(kind: .extract, status: .succeeded, source: "Pre-release checklist", snippet: "Version 1.2 ships on Friday. Please confirm the following by Thursday noon.", translation: nil, minutesAgo: 26, pinned: false),
            HistoryFixture(kind: .translate, status: .failed, source: "Notas de planificación trimestral", snippet: "", translation: nil, minutesAgo: 70, pinned: false),
            HistoryFixture(kind: .extract, status: .succeeded, source: "Install and upgrade guide", snippet: "Drag JustSnap into Applications and grant screen recording on first launch.", translation: nil, minutesAgo: 190, pinned: false),
            HistoryFixture(kind: .translate, status: .succeeded, source: "Notes de version 1.1", snippet: "", translation: "Release notes, version 1.1", minutesAgo: 1_500, pinned: false),
        ]
    )
}
