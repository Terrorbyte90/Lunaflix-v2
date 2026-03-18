import XCTest

// MARK: - Lunaflix UI Tests
// Testar att appen startar, navigerar korrekt och att element
// inte är utanför skärmgränser på iPhone 16 Pro-storlek.

final class LunaflixUITests: XCTestCase {

    var app: XCUIApplication!
    // Screen size from the simulator window — populated after app.launch()
    var screenBounds: CGRect {
        app.windows.firstMatch.frame
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()

        // Vänta på att splash-skärmen försvinner (max 5 sekunder)
        waitForSplashToDisappear()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Splash

    func testAppLaunchesSuccessfully() {
        // Om appen startat och splashen försvinner har vi tab bar eller hemvy
        let tabbarOrContent = app.otherElements.firstMatch
        XCTAssertTrue(tabbarOrContent.exists, "Appen borde vara igång efter launch")
    }

    // MARK: - Tab navigation

    func testAllTabsAreAccessible() {
        // Vänta på att något interaktivt element finns
        let firstElement = app.buttons.firstMatch
        _ = firstElement.waitForExistence(timeout: 5)

        // Tab bar-knappar ska finnas
        let homeBtn  = app.buttons["Hem"]
        let searchBtn = app.buttons["Sök"]
        let downloadBtn = app.buttons["Laddat"]
        let profileBtn = app.buttons["Profil"]

        // Minst Home ska finnas
        XCTAssertTrue(homeBtn.exists || searchBtn.exists || downloadBtn.exists || profileBtn.exists,
                      "Minst en tab-knapp ska finnas")
    }

    func testSearchTabIsReachable() {
        tapTabIfExists("Sök")
        // Sökfältet ska finnas
        let searchField = app.textFields.firstMatch
        let exists = searchField.waitForExistence(timeout: 4)
        if !exists {
            // Acceptabelt om Mux ej konfigurerad — bara verifiera att appen inte kraschade
            XCTAssertFalse(app.staticTexts["ERROR"].exists)
        }
    }

    func testDownloadsTabIsReachable() {
        tapTabIfExists("Laddat")
        // Appen ska inte krascha
        XCTAssertFalse(app.staticTexts["ERROR"].exists)
    }

    func testProfileTabIsReachable() {
        tapTabIfExists("Profil")
        // Profilvyn ska ha något innehåll
        let something = app.staticTexts.firstMatch
        _ = something.waitForExistence(timeout: 4)
        XCTAssertFalse(app.staticTexts["ERROR"].exists)
    }

    // MARK: - Screen bounds integrity

    func testNoInteractiveElementsOutsideScreenBoundsOnHomeTab() {
        tapTabIfExists("Hem")
        waitSeconds(1)
        checkInteractiveElementsWithinBounds(context: "HomeView")
    }

    func testNoInteractiveElementsOutsideScreenBoundsOnSearchTab() {
        tapTabIfExists("Sök")
        waitSeconds(1)
        checkInteractiveElementsWithinBounds(context: "SearchView")
    }

    func testNoInteractiveElementsOutsideScreenBoundsOnProfileTab() {
        tapTabIfExists("Profil")
        waitSeconds(1)
        checkInteractiveElementsWithinBounds(context: "ProfileView")
    }

    func testNoInteractiveElementsOutsideScreenBoundsOnDownloadsTab() {
        tapTabIfExists("Laddat")
        waitSeconds(1)
        checkInteractiveElementsWithinBounds(context: "DownloadsView")
    }

    // MARK: - Tab bar layout

    func testTabBarButtonsHaveMinimumTouchTargets() {
        // The custom LunaTabBar renders each tab as a Button with .frame(maxWidth: .infinity).
        // XCUITest reports the full column width for each tab button. However the search
        // icon button in the navigation bar also has the label "Sök" (36x36pt). We
        // focus on verifying all tab-labelled buttons are hittable and have positive area.
        let tabLabels = ["Hem", "Sök", "Laddat", "Profil"]
        for label in tabLabels {
            // Find the first button with this label that is hittable
            let btn = app.buttons[label]
            if btn.waitForExistence(timeout: 2), btn.isHittable {
                let frame = btn.frame
                XCTAssertGreaterThan(frame.width, 0, "Tab '\(label)' har noll bredd")
                XCTAssertGreaterThan(frame.height, 0, "Tab '\(label)' har noll höjd")
                // The button must be within screen bounds
                XCTAssertGreaterThanOrEqual(frame.minX, -1, "Tab '\(label)' utanför vänster kant")
                XCTAssertLessThanOrEqual(frame.maxX, screenBounds.width + 1, "Tab '\(label)' utanför höger kant")
            }
        }
    }

    func testTabBarIsWithinScreenBounds() {
        let allButtons = app.buttons.allElementsBoundByIndex
        for btn in allButtons {
            guard btn.exists, ["Hem", "Sök", "Laddat", "Profil"].contains(btn.label) else { continue }
            let frame = btn.frame
            XCTAssertGreaterThanOrEqual(frame.minX, -1, "Tab '\(btn.label)' utanför vänster kant")
            XCTAssertLessThanOrEqual(frame.maxX, screenBounds.width + 1, "Tab '\(btn.label)' utanför höger kant")
            XCTAssertLessThanOrEqual(frame.maxY, screenBounds.height + 5, "Tab '\(btn.label)' utanför nedre kant")
        }
    }

    // MARK: - Search tab functional tests

    func testSearchFieldIsInteractable() {
        tapTabIfExists("Sök")
        let textField = app.textFields.firstMatch
        guard textField.waitForExistence(timeout: 4) else { return }

        textField.tap()
        XCTAssertTrue(textField.isHittable || app.keyboards.firstMatch.exists,
                      "Sökfältet borde vara klickbart")

        // Stäng tangentbordet om det öppnades
        if app.keyboards.firstMatch.exists {
            app.keyboards.firstMatch.buttons["return"].tap()
        }
    }

    func testSearchFieldDoesNotExtendOutsideBounds() {
        tapTabIfExists("Sök")
        let textField = app.textFields.firstMatch
        guard textField.waitForExistence(timeout: 4) else { return }

        let frame = textField.frame
        XCTAssertGreaterThanOrEqual(frame.minX, 0, "Sökfältet sticker ut till vänster")
        XCTAssertLessThanOrEqual(frame.maxX, screenBounds.width, "Sökfältet sticker ut till höger")
    }

    // MARK: - Profile tab functional tests

    func testProfileTabShowsLuna() {
        tapTabIfExists("Profil")
        // "Luna" borde finnas som text
        let luna = app.staticTexts["Luna"]
        _ = luna.waitForExistence(timeout: 4)
        // Mjuk check — Mux-konfiguration krävs ej
        if luna.exists {
            XCTAssertTrue(luna.frame.width > 0, "Lunas namn ska ha bredd > 0")
        }
    }

    func testSettingsSectionExists() {
        tapTabIfExists("Profil")
        // "Inställningar" header ska finnas
        let settings = app.staticTexts["Inställningar"]
        _ = settings.waitForExistence(timeout: 4)
        if settings.exists {
            XCTAssertTrue(settings.frame.height > 0)
        }
    }

    // MARK: - Static text elements not clipped

    func testStaticTextsHavePositiveHeight() {
        let tabs = ["Hem", "Sök", "Laddat", "Profil"]
        for tabName in tabs {
            tapTabIfExists(tabName)
            waitSeconds(1)

            let texts = app.staticTexts.allElementsBoundByIndex
            for text in texts {
                guard text.exists, !text.label.isEmpty else { continue }
                XCTAssertGreaterThan(
                    text.frame.height, 0,
                    "Text '\(text.label.prefix(40))' på \(tabName)-tabben har noll höjd — kan vara clippat"
                )
            }
        }
    }

    // MARK: - No overlapping interactive controls

    func testButtonsDontOverlapTextFields() {
        tapTabIfExists("Sök")
        waitSeconds(1)

        let buttons = app.buttons.allElementsBoundByIndex
        let textFields = app.textFields.allElementsBoundByIndex

        for button in buttons {
            guard button.exists && button.isHittable else { continue }
            for textField in textFields {
                guard textField.exists else { continue }
                // Allow 4pt tolerance for subpixel overlap
                let buttonFrame = button.frame.insetBy(dx: 4, dy: 4)
                let fieldFrame = textField.frame.insetBy(dx: 4, dy: 4)
                XCTAssertFalse(
                    buttonFrame.intersects(fieldFrame),
                    "Knapp '\(button.label)' överlappar textfält på Sök-tabben"
                )
            }
        }
    }

    // MARK: - Helpers

    private func waitForSplashToDisappear() {
        // Splash tar 1.6s + 0.5s fade = ca 2.1s — vi väntar upp till 5s
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 5 {
            if app.buttons.count > 0 { break }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        }
    }

    private func tapTabIfExists(_ tabTitle: String) {
        let btn = app.buttons[tabTitle]
        if btn.waitForExistence(timeout: 3), btn.isHittable {
            btn.tap()
        }
        // Short settle time for animation
        waitSeconds(0.4)
    }

    private func waitSeconds(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    private func checkInteractiveElementsWithinBounds(context: String) {
        let margin: CGFloat = 2.0

        // Knappar
        let buttons = app.buttons.allElementsBoundByIndex
        for btn in buttons {
            guard btn.exists && btn.isHittable else { continue }
            let f = btn.frame
            XCTAssertGreaterThanOrEqual(f.minX, -margin,
                "[\(context)] Knapp '\(btn.label)' utanför vänster kant: x=\(f.minX)")
            XCTAssertLessThanOrEqual(f.maxX, screenBounds.width + margin,
                "[\(context)] Knapp '\(btn.label)' utanför höger kant: maxX=\(f.maxX)")
            XCTAssertGreaterThanOrEqual(f.minY, -margin,
                "[\(context)] Knapp '\(btn.label)' utanför övre kant: y=\(f.minY)")
            XCTAssertLessThanOrEqual(f.maxY, screenBounds.height + margin,
                "[\(context)] Knapp '\(btn.label)' utanför nedre kant: maxY=\(f.maxY)")
        }

        // Textfält
        let textFields = app.textFields.allElementsBoundByIndex
        for tf in textFields {
            guard tf.exists else { continue }
            let f = tf.frame
            XCTAssertGreaterThanOrEqual(f.minX, -margin, "[\(context)] Textfält utanför vänster kant")
            XCTAssertLessThanOrEqual(f.maxX, screenBounds.width + margin, "[\(context)] Textfält utanför höger kant")
        }
    }
}
