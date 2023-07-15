// Copyright © 2015 Abhishek Banthia

import Cocoa
import CoreLoggerKit
import CoreModelKit

class NotesPopover: NSViewController {
    private enum OverrideType {
        case timezoneFormat
        case seconds
    }

    var dataObject: TimezoneData?

    var timezoneObjects: [Data]?

    var currentRow: Int = -1

    weak var popover: NSPopover?

    @IBOutlet var customLabel: NSTextField!

    @IBOutlet var reminderPicker: NSDatePicker!

    @IBOutlet var reminderView: NSView!

    @IBOutlet var timeFormatTweakingView: NSView!

    @IBOutlet var alertPopupButton: NSPopUpButton!

    @IBOutlet var scriptExecutionIndicator: NSProgressIndicator!

    @IBOutlet var saveButton: NSButton!

    @IBOutlet var setReminderCheckbox: NSButton!

    @IBOutlet var remindersButton: NSButton!

    @IBOutlet var timeFormatControl: NSPopUpButton!

    @IBOutlet var notesTextView: TextViewWithPlaceholder!

    private func convertOverrideFormatToPopupControlSelection() -> Int {
        var chosenFormat: Int = dataObject?.overrideFormat.rawValue ?? 0
        if chosenFormat == 3 {
            chosenFormat = 4
        } else if chosenFormat == 6 {
            chosenFormat = 7
        } else if chosenFormat == 9 {
            chosenFormat = 10
        }
        return chosenFormat
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAlarmTextField()
        setupUI()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(themeChanged),
                                               name: NSNotification.Name.themeDidChange,
                                               object: nil)

        let titles = [
            "None",
            "At time of the event",
            "5 minutes before",
            "10 minutes before",
            "15 minutes before",
            "30 minutes before",
            "1 hour before",
            "2 hour before",
            "1 day before",
            "2 days before",
        ]

        alertPopupButton.removeAllItems()
        alertPopupButton.addItems(withTitles: titles)
        alertPopupButton.selectItem(at: 1)

        // Set up time control
        let supportedTimeFormats = ["Respect Global Preference",
                                    "h:mm a (7:08 PM)",
                                    "HH:mm (19:08)",
                                    "-- With Seconds --",
                                    "h:mm:ss a (7:08:09 PM)",
                                    "HH:mm:ss (19:08:09)",
                                    "-- 12 Hour with Preceding 0 --",
                                    "hh:mm a (07:08 PM)",
                                    "hh:mm:ss a (07:08:09 PM)",
                                    "-- 12 Hour w/o AM/PM --",
                                    "hh:mm (07:08)",
                                    "hh:mm:ss (07:08:09)",
                                    "Epoch Time"]
        timeFormatControl.removeAllItems()
        timeFormatControl.addItems(withTitles: supportedTimeFormats)

        timeFormatControl.item(at: 3)?.isEnabled = false
        timeFormatControl.item(at: 6)?.isEnabled = false
        timeFormatControl.item(at: 9)?.isEnabled = false
        timeFormatControl.autoenablesItems = false
        timeFormatControl.selectItem(at: convertOverrideFormatToPopupControlSelection())

        // Set Accessibility Identifiers for UI tests
        customLabel.setAccessibilityIdentifier("CustomLabel")
        saveButton.setAccessibilityIdentifier("SaveButton")
        notesTextView.setAccessibilityIdentifier("NotesTextView")
        setReminderCheckbox.setAccessibilityIdentifier("ReminderCheckbox")
        alertPopupButton.setAccessibilityIdentifier("RemindersAlertPopup")
        reminderView.setAccessibilityIdentifier("RemindersView")

        if #available(OSX 11.0, *) {
            alertPopupButton.controlSize = .large
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        scriptExecutionIndicator.stopAnimation(nil)
        updateContent()
    }

    private func setupUI() {
        if let saveCell = saveButton.cell as? NSButtonCell {
            setCellState(buttonCell: saveCell)
        }

        if let remindersCell = remindersButton.cell as? NSButtonCell {
            setCellState(buttonCell: remindersCell)
        }

        notesTextView.font = NSFont(name: "Avenir", size: 14)
        notesTextView.enclosingScrollView?.hasVerticalScroller = false

        themeChanged()
    }

    private func setCellState(buttonCell: NSButtonCell) {
        buttonCell.highlightsBy = .contentsCellMask
        buttonCell.showsStateBy = .pushInCellMask
    }

    private func setupAlarmTextField() {
        reminderPicker.datePickerStyle = .textField
        reminderPicker.isBezeled = false
        reminderPicker.isBordered = false
        reminderPicker.drawsBackground = false
        reminderPicker.datePickerElements = [.yearMonthDay, .hourMinute]
        reminderPicker.target = self
    }

    private func setInitialReminderTime() {
        // If self.calSelectedDate is today, the initialStart is set to
        // the next whole hour. Otherwise, 8am of self.calselectedDate.

        getCurrentTimezoneDate { finalDate in
            let currentDate = finalDate ?? Date()
            self.continueProcess(with: currentDate)
        }
    }

    private func continueProcess(with currentDate: Date) {
        let calendar = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)
        var hour = 0
        calendar?.getHour(&hour,
                          minute: nil,
                          second: nil,
                          nanosecond: nil,
                          from: currentDate)

        hour = (hour == 23) ? 0 : hour + 1

        guard let initialStart = calendar?.nextDate(after: currentDate,
                                                    matching: NSCalendar.Unit.hour,
                                                    value: hour,
                                                    options: NSCalendar.Options.matchPreviousTimePreservingSmallerUnits)
        else {
            assertionFailure("Initial Date object was unexepectedly nil")
            return
        }

        reminderPicker.minDate = currentDate
        reminderPicker.dateValue = initialStart
    }

    private func getCurrentTimezoneDate(completionHandler: @escaping (_ response: Date?) -> Void) {
        guard let timezoneID = dataObject?.timezone() else {
            assertionFailure("Unable to retrieve timezoneID from the model")
            completionHandler(nil)
            return
        }

        let currentCalendar = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)

        guard let newDate = currentCalendar?.date(byAdding: NSCalendar.Unit.minute,
                                                  value: 0,
                                                  to: Date(),
                                                  options: NSCalendar.Options.matchLast)
        else {
            assertionFailure("Initial Date object was unexepectedly nil")
            completionHandler(nil)
            return
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: timezoneID)

        let dateStyle = formatter.string(from: newDate)
        let type: NSTextCheckingResult.CheckingType = .date

        do {
            let detector = try NSDataDetector(types: type.rawValue)
            detector.enumerateMatches(in: dateStyle,
                                      options: NSRegularExpression.MatchingOptions.reportCompletion,
                                      range: NSRange(location: 0, length: dateStyle.count),
                                      using: { result, _, _ in
                                          guard let completedDate = result?.date else {
                                              return
                                          }
                                          completionHandler(completedDate)

                                      })
        } catch {
            assertionFailure("Failed to successfully initialize DataDetector")
            completionHandler(nil)
        }
    }

    private func setAttributedTitle(title: String, for button: NSButton) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        guard let font = NSFont(name: "Avenir-Book", size: 13) else { return }

        let attributesDictionary = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: Themer.shared().mainTextColor(),
            NSAttributedString.Key.paragraphStyle: style,
        ]

        button.attributedTitle = NSAttributedString(string: title,
                                                    attributes: attributesDictionary)
    }

    @IBAction func saveAction(_: Any) {
        updateLabel()

        dataObject?.note = notesTextView.string
        dataObject?.setShouldOverrideGlobalTimeFormat(timeFormatControl.indexOfSelectedItem)
        insertTimezoneInDefaultPreferences()

        if setReminderCheckbox.state == .on {
            setReminderAlarm()
            Logger.log(object: nil, for: "Reminder Set")
        }

        refreshMainTableView()

        NotificationCenter.default.post(name: NSNotification.Name.customLabelChanged, object: nil)

        popover?.close()
    }

    @IBAction func seeReminders(_: Any) {
        OperationQueue.main.addOperation {
            self.scriptExecutionIndicator.startAnimation(nil)

            let source = """
            tell application \"Reminders\"
            tell default account
            show (first list where name is \"Clocker Reminders\")
            activate application
            end tell
            end tell
            """

            var scriptExecutionErrors: NSDictionary? = .none
            let remindersScript = NSAppleScript(source: source)
            let eventDescriptor = remindersScript?.executeAndReturnError(&scriptExecutionErrors)

            if let errors = scriptExecutionErrors, errors.allKeys.isEmpty == false {
                if let convertedType = errors as? [String: Any] {
                    Logger.log(object: convertedType, for: "Script Execution Errors")
                }
                NSWorkspace.shared.launchApplication("Reminders")
            } else if eventDescriptor == nil {
                Logger.log(object: nil, for: "Event Description is unexpectedly nil")
                NSWorkspace.shared.launchApplication("Reminders")
            } else {
                Logger.log(object: ["Successfully Executed Apple Script": "YES"], for: "Successfully Executed Apple Script")
            }

            self.scriptExecutionIndicator.stopAnimation(nil)
        }
    }

    @IBAction func checkboxAction(_: Any) {
        enableReminderView(!alertPopupButton.isEnabled)
    }

    @IBAction func customizeTimeFormat(_ sender: NSSegmentedControl) {
        updateTimezoneInDefaultPreferences(with: sender.selectedSegment, .timezoneFormat)
        refreshMainTableView()

        // Update the display if the chosen menubar mode is compact!
        if let delegate = NSApplication.shared.delegate as? AppDelegate {
            let handler = delegate.statusItemForPanel()
            handler.setupStatusItem()
        }
    }

    private func insertTimezoneInDefaultPreferences() {
        guard let model = dataObject, var timezones = timezoneObjects,
        let encodedObject = NSKeyedArchiver.clocker_archive(with:model) else { return }
        
        timezones[currentRow] = encodedObject
        DataStore.shared().setTimezones(timezones)
    }

    private func updateTimezoneInDefaultPreferences(with override: Int,
                                                    _: OverrideType)
    {
        let timezones = DataStore.shared().timezones()

        var timezoneObjects: [TimezoneData] = []

        for timezone in timezones {
            if let model = TimezoneData.customObject(from: timezone) {
                timezoneObjects.append(model)
            }
        }

        for timezoneObject in timezoneObjects where timezoneObject.isEqual(dataObject) {
            timezoneObject.setShouldOverrideGlobalTimeFormat(override)
        }

        var datas: [Data] = []

        for updatedObject in timezoneObjects {
            guard let dataObject = NSKeyedArchiver.clocker_archive(with: updatedObject) else {
                continue
            }
            datas.append(dataObject)
        }

        DataStore.shared().setTimezones(datas)
    }

    private func setReminderAlarm() {
        let eventCenter = EventCenter.sharedCenter()

        if eventCenter.reminderAccessNotDetermined() {
            eventCenter.requestAccess(to: .reminder, completionHandler: { granted in
                if granted {
                    OperationQueue.main.addOperation {
                        self.createReminder()
                    }
                } else {
                    Logger.log(object: ["Reminder Access Not Granted": "YES"], for: "Reminder Access Not Granted")
                }
            })

        } else if eventCenter.reminderAccessGranted() {
            createReminder()
        } else {
            showAlertForPermissionNotGiven()
        }
    }

    private func refreshMainTableView() {
        OperationQueue.main.addOperation {
            if DataStore.shared().shouldDisplay(ViewType.showAppInForeground) {
                let currentInstance = FloatingWindowController.shared()
                currentInstance.updateDefaultPreferences()
            } else {
                guard let panelController = PanelController.panel() else { return }
                panelController.updateDefaultPreferences()
                panelController.updateTableContent()
            }
        }
    }

    private func createReminder() {
        guard let model = dataObject else { return }
        if setReminderCheckbox.state == .on {
            let eventCenter = EventCenter.sharedCenter()
            let alertIndex = alertPopupButton.indexOfSelectedItem

            if eventCenter.createReminder(with: model.customLabel!,
                                          timezone: model.timezone(),
                                          alertIndex: alertIndex,
                                          reminderDate: reminderPicker.dateValue,
                                          additionalNotes: model.note)
            {
                showSuccessMessage()
            }
        }
    }

    private func showAlertForPermissionNotGiven() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Clocker needs access to Reminders 😅"
        alert.informativeText = "Please go to System Preferences -> Security & Privacy -> Privacy -> Reminders to allow Clocker to set reminders."
        alert.addButton(withTitle: "Okay")

        let alertResponse = alert.runModal()

        if alertResponse == .stop {
            OperationQueue.main.addOperation {
                self.popover?.close()
            }
        }
    }

    private func showSuccessMessage() {
        let reminderNotification = NSUserNotification()
        reminderNotification.title = "Reminder Set".localized()
        reminderNotification.subtitle = "Successfully set.".localized()

        NSUserNotificationCenter.default.scheduleNotification(reminderNotification)
    }

    func setDataSource(data: TimezoneData) {
        dataObject = data

        if isViewLoaded {
            updateContent()
        }
    }
}

extension NotesPopover {
    func setRow(row: Int) {
        currentRow = row
    }

    func set(timezones: [Data]) {
        timezoneObjects = timezones
    }

    func set(with popover: NSPopover) {
        self.popover = popover
    }

    @objc func themeChanged() {
        notesTextView.textColor = Themer.shared().mainTextColor()
        customLabel.textColor = Themer.shared().mainTextColor()
        reminderPicker.textColor = Themer.shared().mainTextColor()
        popover?.appearance = Themer.shared().popoverAppearance()
        setAttributedTitle(title: saveButton.title, for: saveButton)
        setAttributedTitle(title: remindersButton.title, for: remindersButton)
    }

    func updateContent() {
        guard let model = dataObject else {
            assertionFailure("Model object was unexepectedly nil")
            return
        }

        enableReminderView(false)
        setReminderCheckbox.state = .off

        if let label = model.customLabel, !label.isEmpty {
            customLabel.stringValue = label
        } else {
            customLabel.stringValue = model.formattedTimezoneLabel()
        }

        if let note = model.note, !note.isEmpty {
            notesTextView.string = note
        } else {
            notesTextView.string = CLEmptyString
        }

        setInitialReminderTime()
        updateTimeFormat()
    }

    private func updateTimeFormat() {
        timeFormatControl.selectItem(at: convertOverrideFormatToPopupControlSelection())
    }

    private func enableReminderView(_ shouldEnable: Bool) {
        reminderPicker.isEnabled = shouldEnable
        alertPopupButton.isEnabled = shouldEnable
        reminderPicker.alphaValue = shouldEnable ? 1.0 : 0.25
    }
}

extension NotesPopover: NSTextFieldDelegate {
    func controlTextDidChange(_: Notification) {
        updateLabel()
    }

    private func updateLabel() {
        // We need to do a couple of things if the customLabel is updated
        // 1. Update the userDefaults
        // 2. Check if the timezone is displayed in the menubar; if so, update the model
        guard let model = dataObject else { return }
        model.setLabel(customLabel.stringValue)

        insertTimezoneInDefaultPreferences()

        NotificationCenter.default.post(name: NSNotification.Name.customLabelChanged,
                                        object: nil)
    }
}
