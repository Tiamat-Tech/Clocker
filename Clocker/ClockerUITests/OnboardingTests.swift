// Copyright © 2015 Abhishek Banthia

import XCTest

class OnboardingTests: XCTestCase {
    var app: XCUIApplication!
    
    static let kOnboardingTestsLaunchArgument = "isTestingTheOnboardingFlow"

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append(Self.kOnboardingTestsLaunchArgument)
        app.launch()
    }

    // We test a couple of things in the Onboarding Process
    // 1. The flow (forward button and back button take the user to the correct screen)
    // 2. Static texts and button title's are appropriate
    func testForwardButton() {
        welcomeControllerTests()

        // Let's go to the Permissions View
        moveForward()
        permissionsControllerTests()

        // Time to test the launchAtLoginView
        moveForward()
        startupControllerTests()

        // Let's go to OnboardingSearchController
        moveForward()
        searchControllerTests()

        // Let's go to the FinalOnboardingController
        moveForward()
        finalOnboardingControllerTests()

        backButtonTests()
    }

    func backButtonTests() {
        moveBackward()
        searchControllerTests()

        moveBackward()
        startupControllerTests()

        moveBackward()
        permissionsControllerTests()

        moveBackward()
        welcomeControllerTests()

        alternateStartupFlowTests()
    }

    func alternateStartupFlowTests() {
        // Let's go to the Permissions View
        moveForward()
        permissionsControllerTests()

        // Time to test the launchAtLoginView
        moveForward()
        startupControllerTests()

        // Let's go to OnboardingSearchController
        alternateMoveForward()
        searchControllerTests()

        // Let's go to the FinalOnboardingController
        moveForward()
        finalOnboardingControllerTests()

        moveForward()
        XCTAssertTrue(app.statusItems.count > 0, "Status item was not installed in the menubar")
    }

    private func moveForward() {
        let onboardingWindow = app.windows["OnboardingWindow"]
        onboardingWindow.buttons["Forward"].click()
        sleep(1)
    }

    private func alternateMoveForward() {
        let onboardingWindow = app.windows["OnboardingWindow"]
        onboardingWindow.buttons["Alternate"].click()
        sleep(1)
    }

    private func moveBackward() {
        let onboardingWindow = app.windows["OnboardingWindow"]
        onboardingWindow.buttons["Backward"].click()
        sleep(1)
    }

    private func welcomeControllerTests() {
        let onboardingWindow = app.windows["OnboardingWindow"]

        // Tests static texts
        XCTAssertTrue(onboardingWindow.staticTexts["CFBundleDisplayName".localizedString()].exists, "Static text Clocker was unexpectedly missing")
        XCTAssertTrue(onboardingWindow.staticTexts["It only takes 3 steps to set up Clocker.".localizedString()].exists, "Accessory label's static text was unexpectedly wrong.")

        let button = onboardingWindow.buttons["Forward"]

        // Test the button title
        XCTAssertTrue(button.exists, "Button title was unexpectedly wrong. Expected \"Get Started\", Actual: \"\(onboardingWindow.buttons.firstMatch.title)\" ")

        XCTAssertTrue(onboardingWindow.buttons.count == 1, "More than 1 button on Welcome screen!")
    }

    private func permissionsControllerTests() {
        let onboardingWindow = app.windows["OnboardingWindow"]

        XCTAssertTrue(onboardingWindow.staticTexts["Permissions".localizedString()].exists, "Header label's static text was unexpectedly wrong.")
        XCTAssertTrue(onboardingWindow.staticTexts["Your data doesn't leave your device 🔐"].exists, "Onboarding Info label's static text was unexpectedly wrong.")

        XCTAssertTrue(onboardingWindow.buttons["Forward"].title == "Continue".localizedString(), "Forward button title's was unexpectedly wrong")
        XCTAssertTrue(onboardingWindow.buttons["Backward"].exists, "Back button was unexpectedly missing")
        XCTAssertFalse(onboardingWindow.buttons["Alternate"].exists, "Alternate button was unexpectedly present.")
    }

    private func startupControllerTests() {
        let onboardingWindow = app.windows["OnboardingWindow"]

        XCTAssertTrue(onboardingWindow.buttons["Forward"].title == "Open Clocker At Login".localizedString(), "Forward button title's was unexpectedly wrong")
        XCTAssertTrue(onboardingWindow.buttons["Alternate"].title == "Don't Open".localizedString(), "Alternate button title's was unexpectedly wrong")

        XCTAssertTrue(onboardingWindow.staticTexts["Launch at Login".localizedString()].exists, "Header label's static text was unexpectedly wrong.")
        XCTAssertTrue(onboardingWindow.staticTexts["Should Clocker open automatically on startup?".localizedString()].exists, "Accessory label's static text was unexpectedly wrong.")
    }

    private func searchControllerTests() {
        let onboardingWindow = app.windows["OnboardingWindow"]

        XCTAssertFalse(onboardingWindow.buttons["Alternate"].exists, "Alternate button was unexpectedly present.")
        XCTAssertTrue(onboardingWindow.buttons["Forward"].title == "Continue".localizedString(), "Forward button title's was unexpectedly wrong")

        XCTAssertTrue(onboardingWindow.staticTexts["Quick Add Locations".localizedString()].exists, "Header label's static text was unexpectedly wrong.")
        XCTAssertTrue(onboardingWindow.staticTexts["More search options in Clocker Preferences.".localizedString()].exists, "Accessory label's static text was unexpectedly wrong.")
    }

    private func finalOnboardingControllerTests() {
        let onboardingWindow = app.windows["OnboardingWindow"]

        // Let's test the buttons
        XCTAssertTrue(onboardingWindow.staticTexts["You're all set!".localizedString()].exists, "Header label's static text was unexpectedly wrong.")
        XCTAssertTrue(onboardingWindow.staticTexts["Thank you for the details.".localizedString()].exists, "Accessory label's static text was unexpectedly wrong.")

        XCTAssertFalse(onboardingWindow.buttons["Alternate".localizedString()].exists, "Alternate button was unexpectedly present.")
        XCTAssertTrue(onboardingWindow.buttons["Forward".localizedString()].title == "Launch Clocker".localizedString(), "Forward button's title was unexpectedly wrong.")
    }
}
