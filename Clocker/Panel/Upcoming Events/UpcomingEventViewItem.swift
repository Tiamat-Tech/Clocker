// Copyright © 2015 Abhishek Banthia

import AppKit
import Foundation

class UpcomingEventViewItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("UpcomingEventViewItem")

    @IBOutlet var calendarColorView: NSView!
    @IBOutlet var leadingConstraint: NSLayoutConstraint!
    @IBOutlet var eventTitleLabel: NSTextField!
    @IBOutlet var eventSubtitleButton: NSButton!
    @IBOutlet var supplementaryButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet var zoomButton: NSButton!

    private static let SupplementaryButtonWidth: CGFloat = 24.0
    private static let EventLeadingConstraint: CGFloat = 10.0
    private var meetingLink: URL?
    private weak var panelDelegate: UpcomingEventPanelDelegate?

    override func viewDidLoad() {
        zoomButton.target = self
        zoomButton.action = #selector(zoomButtonAction(_:))
    }

    override func prepareForReuse() {
        zoomButton.image = nil
        eventTitleLabel.stringValue = ""
        eventSubtitleButton.stringValue = ""
        meetingLink = nil
    }

    override var acceptsFirstResponder: Bool {
        return false
    }

    // MARK: Setup UI

    func setup(_ title: String,
               _ subtitle: String,
               _ color: NSColor,
               _ link: URL?,
               _ delegate: UpcomingEventPanelDelegate?,
               _ isCancelled: Bool)
    {
        if leadingConstraint.constant != UpcomingEventViewItem.EventLeadingConstraint / 2 {
            leadingConstraint.animator().constant = UpcomingEventViewItem.EventLeadingConstraint / 2
        }

        panelDelegate = delegate
        meetingLink = link

        setupLabels(title, isCancelled)
        setupSupplementaryButton(link, cancellationState: isCancelled)
        setCalendarButtonTitle(buttonTitle: subtitle, cancellationState: isCancelled)
        calendarColorView.layer?.backgroundColor = color.cgColor
    }

    private func setupLabels(_ title: String, _ cancellationState: Bool) {
        var sanitizedTitle = title
        if (cancellationState) {
            let offendingString = "Canceled: "
            sanitizedTitle = sanitizedTitle.replacingOccurrences(of: offendingString, with: "")
        }
        
        let attributes: [NSAttributedString.Key: Any] = cancellationState ? [NSAttributedString.Key.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                                                             NSAttributedString.Key.strikethroughColor: NSColor.gray] : [:]
        let attributedString = NSAttributedString(string: sanitizedTitle, attributes: attributes)
        eventTitleLabel.attributedStringValue = attributedString

        eventTitleLabel.toolTip = title
    }

    private func setupSupplementaryButton(_ meetingURL: URL?, cancellationState: Bool) {
        guard meetingURL != nil, cancellationState == false else {
            zoomButton.image = nil
            supplementaryButtonWidthConstraint.constant = 0.0
            return
        }

        zoomButton.isHidden = false
        zoomButton.image = Themer.shared().videoCallImage()

        if supplementaryButtonWidthConstraint.constant != UpcomingEventViewItem.SupplementaryButtonWidth {
            supplementaryButtonWidthConstraint.constant = UpcomingEventViewItem.SupplementaryButtonWidth
        }
    }

    func setupUndeterminedState(_ delegate: UpcomingEventPanelDelegate?) {
        panelDelegate = delegate
        setAlternateState(NSLocalizedString("See your next Calendar event here.", comment: "Next Event Label for no Calendar access"),
                          NSLocalizedString("Click here to start.", comment: "Button Title for no Calendar access"),
                          NSColor.systemBlue,
                          Themer.shared().removeImage())
    }

    func setupEmptyState() {
        let subtitle = NSCalendar.autoupdatingCurrent.isDateInWeekend(Date()) ? "Happy Weekend.".localized() : "Great going.".localized()

        setAlternateState(NSLocalizedString("No upcoming events for today!", comment: "Next Event Label with no upcoming event"),
                          subtitle,
                          NSColor.systemGreen,
                          nil)
    }

    private func setAlternateState(_ title: String, _ buttonTitle: String, _ color: NSColor, _ image: NSImage? = nil) {
        if leadingConstraint.constant != UpcomingEventViewItem.EventLeadingConstraint {
            leadingConstraint.animator().constant = UpcomingEventViewItem.EventLeadingConstraint
        }

        eventTitleLabel.stringValue = title
        setCalendarButtonTitle(buttonTitle: buttonTitle, cancellationState: false)
        calendarColorView.layer?.backgroundColor = color.cgColor
        zoomButton.image = image
    }

    private func setCalendarButtonTitle(buttonTitle: String, cancellationState: Bool) {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byTruncatingTail

        if let boldFont = NSFont(name: "Avenir", size: 11) {
            let sanitizedString = cancellationState ? "Canceled." : buttonTitle
            let attributes = [NSAttributedString.Key.foregroundColor: NSColor.gray, NSAttributedString.Key.paragraphStyle: style, NSAttributedString.Key.font: boldFont]
            let attributedString = NSAttributedString(string: sanitizedString, attributes: attributes)
            eventSubtitleButton.attributedTitle = attributedString
            eventSubtitleButton.toolTip =  buttonTitle
        }
    }

    // MARK: Button Actions

    @IBAction func calendarButtonAction(_ sender: NSButton) {
        panelDelegate?.didClickSupplementaryButton(sender)
    }

    @objc func zoomButtonAction(_ sender: NSButton) {
        guard sender.image != nil else { return }

        if let meetingURL = meetingLink {
            NSWorkspace.shared.open(meetingURL)
        } else {
            panelDelegate?.didRemoveCalendarView()
        }
    }
}
