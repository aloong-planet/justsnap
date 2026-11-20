import AppKit

@MainActor
public enum JustSnapApplicationMenuBuilder {
    public static func makeMainMenu(
        applicationName: String,
        pasteboard: NSPasteboard = .general,
        activeResponder: @escaping @MainActor () -> NSResponder? = { NSApp.keyWindow?.firstResponder }
    ) -> NSMenu {
        let mainMenu = ProviderPasteMenu(title: applicationName, pasteboard: pasteboard, activeResponder: activeResponder)
        mainMenu.addItem(topLevelItem(title: applicationName, submenu: applicationMenu(applicationName)))
        mainMenu.addItem(topLevelItem(title: JustSnapStrings.menuFile, submenu: fileMenu()))
        let edit = editMenu()
        mainMenu.routePaste(in: edit)
        mainMenu.addItem(topLevelItem(title: JustSnapStrings.menuEdit, submenu: edit))
        mainMenu.addItem(topLevelItem(title: JustSnapStrings.menuWindow, submenu: windowMenu()))
        mainMenu.addItem(topLevelItem(title: JustSnapStrings.menuHelp, submenu: helpMenu()))
        return mainMenu
    }

    private static func applicationMenu(_ applicationName: String) -> NSMenu {
        let menu = NSMenu(title: applicationName)
        menu.addItem(item(
            title: String(format: JustSnapStrings.menuAboutFormat, applicationName),
            action: "orderFrontStandardAboutPanel:"
        ))
        menu.addItem(.separator())
        menu.addItem(item(
            title: String(format: JustSnapStrings.menuHideFormat, applicationName),
            action: "hide:",
            key: "h"
        ))
        menu.addItem(item(
            title: JustSnapStrings.menuHideOthers,
            action: "hideOtherApplications:",
            key: "h",
            modifiers: [.command, .option]
        ))
        menu.addItem(item(title: JustSnapStrings.menuShowAll, action: "unhideAllApplications:"))
        menu.addItem(.separator())
        menu.addItem(item(
            title: JustSnapStrings.menuQuit,
            action: "terminate:",
            key: "q"
        ))
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: JustSnapStrings.menuFile)
        menu.addItem(item(title: JustSnapStrings.menuCloseWindow, action: "performClose:", key: "w"))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: JustSnapStrings.menuEdit)
        menu.addItem(item(title: JustSnapStrings.editUndo, action: "undo:", key: "z"))
        menu.addItem(item(
            title: JustSnapStrings.editRedo,
            action: "redo:",
            key: "z",
            modifiers: [.command, .shift]
        ))
        menu.addItem(.separator())
        menu.addItem(item(title: JustSnapStrings.editCut, action: "cut:", key: "x"))
        menu.addItem(item(title: JustSnapStrings.editCopy, action: "copy:", key: "c"))
        menu.addItem(item(title: JustSnapStrings.editPaste, action: "paste:", key: "v"))
        menu.addItem(item(
            title: JustSnapStrings.editPasteAndMatchStyle,
            action: "pasteAsPlainText:",
            key: "v",
            modifiers: [.command, .option, .shift]
        ))
        menu.addItem(item(title: JustSnapStrings.editDelete, action: "delete:"))
        menu.addItem(item(title: JustSnapStrings.editSelectAll, action: "selectAll:", key: "a"))
        menu.addItem(.separator())
        menu.addItem(submenuItem(title: JustSnapStrings.editFind, submenu: findMenu()))
        menu.addItem(submenuItem(
            title: JustSnapStrings.editSpellingAndGrammar,
            submenu: spellingMenu()
        ))
        menu.addItem(submenuItem(title: JustSnapStrings.editSubstitutions, submenu: substitutionsMenu()))
        menu.addItem(submenuItem(title: JustSnapStrings.editTransformations, submenu: transformationsMenu()))
        menu.addItem(submenuItem(title: JustSnapStrings.editSpeech, submenu: speechMenu()))
        menu.addItem(.separator())
        menu.addItem(item(title: JustSnapStrings.editStartDictation, action: "startDictation:"))
        menu.addItem(item(
            title: JustSnapStrings.editEmojiAndSymbols,
            action: "orderFrontCharacterPalette:",
            key: " ",
            modifiers: [.command, .control]
        ))
        return menu
    }

    private static func findMenu() -> NSMenu {
        let menu = NSMenu(title: JustSnapStrings.editFind)
        menu.addItem(textFinderItem(
            title: JustSnapStrings.editFindPanel,
            action: .showFindInterface,
            key: "f"
        ))
        menu.addItem(textFinderItem(
            title: JustSnapStrings.editFindNext,
            action: .nextMatch,
            key: "g"
        ))
        menu.addItem(textFinderItem(
            title: JustSnapStrings.editFindPrevious,
            action: .previousMatch,
            key: "g",
            modifiers: [.command, .shift]
        ))
        menu.addItem(textFinderItem(
            title: JustSnapStrings.editUseSelectionForFind,
            action: .setSearchString,
            key: "e"
        ))
        menu.addItem(item(
            title: JustSnapStrings.editJumpToSelection,
            action: "centerSelectionInVisibleArea:",
            key: "j"
        ))
        return menu
    }

    private static func spellingMenu() -> NSMenu {
        let menu = NSMenu(title: JustSnapStrings.editSpellingAndGrammar)
        menu.addItem(item(
            title: JustSnapStrings.editShowSpellingAndGrammar,
            action: "showGuessPanel:",
            key: ":"
        ))
        menu.addItem(item(
            title: JustSnapStrings.editCheckDocumentNow,
            action: "checkSpelling:",
            key: ";"
        ))
        menu.addItem(.separator())
        menu.addItem(item(
            title: JustSnapStrings.editCheckSpellingWhileTyping,
            action: "toggleContinuousSpellChecking:"
        ))
        menu.addItem(item(
            title: JustSnapStrings.editCheckGrammarWithSpelling,
            action: "toggleGrammarChecking:"
        ))
        menu.addItem(item(
            title: JustSnapStrings.editCorrectSpellingAutomatically,
            action: "toggleAutomaticSpellingCorrection:"
        ))
        return menu
    }

    private static func substitutionsMenu() -> NSMenu {
        let menu = NSMenu(title: JustSnapStrings.editSubstitutions)
        menu.addItem(item(
            title: JustSnapStrings.editShowSubstitutions,
            action: "orderFrontSubstitutionsPanel:"
        ))
        menu.addItem(.separator())
        menu.addItem(item(title: JustSnapStrings.editSmartCopyPaste, action: "toggleSmartInsertDelete:"))
        menu.addItem(item(title: JustSnapStrings.editSmartQuotes, action: "toggleAutomaticQuoteSubstitution:"))
        menu.addItem(item(title: JustSnapStrings.editSmartDashes, action: "toggleAutomaticDashSubstitution:"))
        menu.addItem(item(title: JustSnapStrings.editSmartLinks, action: "toggleAutomaticLinkDetection:"))
        menu.addItem(item(title: JustSnapStrings.editDataDetectors, action: "toggleAutomaticDataDetection:"))
        menu.addItem(item(title: JustSnapStrings.editTextReplacement, action: "toggleAutomaticTextReplacement:"))
        return menu
    }

    private static func transformationsMenu() -> NSMenu {
        let menu = NSMenu(title: JustSnapStrings.editTransformations)
        menu.addItem(item(title: JustSnapStrings.editMakeUpperCase, action: "uppercaseWord:"))
        menu.addItem(item(title: JustSnapStrings.editMakeLowerCase, action: "lowercaseWord:"))
        menu.addItem(item(title: JustSnapStrings.editCapitalize, action: "capitalizeWord:"))
        return menu
    }

    private static func speechMenu() -> NSMenu {
        let menu = NSMenu(title: JustSnapStrings.editSpeech)
        menu.addItem(item(title: JustSnapStrings.editStartSpeaking, action: "startSpeaking:"))
        menu.addItem(item(title: JustSnapStrings.editStopSpeaking, action: "stopSpeaking:"))
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: JustSnapStrings.menuWindow)
        menu.addItem(item(title: JustSnapStrings.menuMinimize, action: "performMiniaturize:", key: "m"))
        menu.addItem(item(title: JustSnapStrings.menuZoom, action: "performZoom:"))
        menu.addItem(.separator())
        menu.addItem(item(title: JustSnapStrings.menuBringAllToFront, action: "arrangeInFront:"))
        return menu
    }

    private static func helpMenu() -> NSMenu {
        NSMenu(title: JustSnapStrings.menuHelp)
    }

    private static func topLevelItem(title: String, submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private static func submenuItem(title: String, submenu: NSMenu) -> NSMenuItem {
        topLevelItem(title: title, submenu: submenu)
    }

    private static func item(
        title: String,
        action: String,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: Selector(action), keyEquivalent: key)
        item.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
        item.target = nil
        return item
    }

    private static func textFinderItem(
        title: String,
        action: NSTextFinder.Action,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = self.item(
            title: title,
            action: "performTextFinderAction:",
            key: key,
            modifiers: modifiers
        )
        item.tag = action.rawValue
        return item
    }
}
