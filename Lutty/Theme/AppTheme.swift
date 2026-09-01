import SwiftUI

enum AppTheme {
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let editorBackground = Color(uiColor: .black)
    static let editorForeground = Color(uiColor: .white)
    static let secondaryEditorForeground = Color(uiColor: .lightGray)
    static let selectedEditorControl = Color(uiColor: .white).opacity(0.18)
    static let subduedEditorControl = Color(uiColor: .white).opacity(0.08)
    static let editorShadow = Color(uiColor: .black).opacity(0.28)

    static let pagePadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let controlSpacing: CGFloat = 12
    static let controlCornerRadius: CGFloat = 28
    static let cardCornerRadius: CGFloat = 24
}
