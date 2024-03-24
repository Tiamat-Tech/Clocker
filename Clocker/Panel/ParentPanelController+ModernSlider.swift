// Copyright © 2015 Abhishek Banthia

import AppKit
import CoreLoggerKit
import Foundation

extension ParentPanelController: NSCollectionViewDataSource {
    func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int {
        let futureSliderDayPreference = DataStore.shared().retrieve(key: CLFutureSliderRange) as? NSNumber ?? 5
        let futureSliderDayRange = (futureSliderDayPreference.intValue + 1)
        return (PanelConstants.modernSliderPointsInADay * futureSliderDayRange * 2) + 1
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let item = collectionView.makeItem(withIdentifier: TimeMarkerViewItem.reuseIdentifier, for: indexPath) as? TimeMarkerViewItem else {
            return NSCollectionViewItem()
        }
        item.setup(with: indexPath.item)
        return item
    }
}

extension ParentPanelController {
    func setupModernSliderIfNeccessary() {
        if modernSlider != nil {
            if #available(OSX 11.0, *) {
                resetModernSliderButton.image = Themer.shared().resetModernSliderImage()
            } else {
                resetModernSliderButton.layer?.backgroundColor = NSColor.lightGray.cgColor
                resetModernSliderButton.layer?.masksToBounds = true
                resetModernSliderButton.layer?.cornerRadius = resetModernSliderButton.frame.width / 2
            }

            goBackwardsButton.image = Themer.shared().goBackwardsImage()
            goForwardButton.image = Themer.shared().goForwardsImage()

            goForwardButton.isContinuous = true
            goBackwardsButton.isContinuous = true

            goBackwardsButton.toolTip = "Navigate 15 mins back"
            goForwardButton.toolTip = "Navigate 15 mins forward"

            modernSlider.wantsLayer = true // Required for animating reset to center
            modernSlider.enclosingScrollView?.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            modernSlider.enclosingScrollView?.backgroundColor = NSColor.clear
            modernSlider.setAccessibility("ModernSlider")
            modernSlider.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(collectionViewDidScroll(_:)),
                                                   name: NSView.boundsDidChangeNotification,
                                                   object: modernSlider.superview)

            // Set the modern slider label!
            closestQuarterTimeRepresentation = findClosestQuarterTimeApproximation()
            if let unwrappedClosetQuarterTime = closestQuarterTimeRepresentation {
                modernSliderLabel.stringValue = timezoneFormattedStringRepresentation(unwrappedClosetQuarterTime)
            }

            // Make sure modern slider is centered horizontally!
            let indexPaths: Set<IndexPath> = Set([IndexPath(item: modernSlider.numberOfItems(inSection: 0) / 2, section: 0)])
            modernSlider.scrollToItems(at: indexPaths, scrollPosition: .centeredHorizontally)
        }
    }

    @IBAction func goForward(_: NSButton) {
        navigateModernSliderToSpecificIndex(1)
    }

    @IBAction func goBackward(_: NSButton) {
        navigateModernSliderToSpecificIndex(-1)
    }

    private func animateButton(_ hidden: Bool) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: hidden ? CAMediaTimingFunctionName.easeOut : CAMediaTimingFunctionName.easeIn)
            resetModernSliderButton.animator().alphaValue = hidden ? 0.0 : 1.0
        }, completionHandler: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.resetModernSliderButton.animator().isHidden = hidden
        })
    }

    @IBAction func resetModernSlider(_: NSButton) {
        closestQuarterTimeRepresentation = findClosestQuarterTimeApproximation()
        modernSliderLabel.stringValue = "Time Scroller"
        animateButton(true)
        if modernSlider != nil {
            let indexPaths: Set<IndexPath> = Set([IndexPath(item: modernSlider.numberOfItems(inSection: 0) / 2, section: 0)])
            modernSlider.scrollToItems(at: indexPaths, scrollPosition: .centeredHorizontally)
        }
    }

    private func navigateModernSliderToSpecificIndex(_ index: Int) {
        guard let contentView = modernSlider.superview as? NSClipView else {
            return
        }
        let changedOrigin = contentView.documentVisibleRect.origin
        let newPoint = NSPoint(x: changedOrigin.x + contentView.frame.width / 2, y: changedOrigin.y)
        if let indexPath = modernSlider.indexPathForItem(at: newPoint) {
            let previousIndexPath = IndexPath(item: indexPath.item + index, section: indexPath.section)
            modernSlider.scrollToItems(at: Set([previousIndexPath]), scrollPosition: .centeredHorizontally)
        }
    }

    @objc func collectionViewDidScroll(_ notification: NSNotification) {
        guard let contentView = notification.object as? NSClipView else {
            return
        }

        let changedOrigin = contentView.documentVisibleRect.origin
        let newPoint = NSPoint(x: changedOrigin.x + contentView.frame.width / 2, y: changedOrigin.y)
        let indexPath = modernSlider.indexPathForItem(at: newPoint)
        if let correctIndexPath = indexPath?.item, currentCenterIndexPath != correctIndexPath {
            currentCenterIndexPath = correctIndexPath
            let minutesToAdd = setDefaultDateLabel(correctIndexPath)
            setTimezoneDatasourceSlider(sliderValue: minutesToAdd)
            mainTableView.reloadData()
        }
    }

    public func findClosestQuarterTimeApproximation() -> Date {
        let defaultParameters = minuteFromCalendar()
        let hourQuarterDate = Calendar.current.nextDate(after: defaultParameters.0,
                                                        matching: DateComponents(minute: defaultParameters.1),
                                                        matchingPolicy: .strict,
                                                        repeatedTimePolicy: .first,
                                                        direction: .forward)!
        return hourQuarterDate
    }
    
    func minutesToHoursAndMinutes(_ minutes: Int) -> (hours: Int , leftMinutes: Int) {
        var minutesRemaining = (minutes % 60)
        if (minutesRemaining < 0) {
            minutesRemaining.negate()
        }
        return (minutes / 60, minutesRemaining)
    }

    public func setDefaultDateLabel(_ index: Int) -> Int {
        let futureSliderDayPreference = DataStore.shared().retrieve(key: CLFutureSliderRange) as? NSNumber ?? 5
        let futureSliderDayRange = (futureSliderDayPreference.intValue + 1)
        let totalCount = (PanelConstants.modernSliderPointsInADay * futureSliderDayRange * 2) + 1
        let centerPoint = Int(ceil(Double(totalCount / 2)))
        if index >= (centerPoint + 1) {
            let remainder = (index % (centerPoint + 1))
            let nextDate = Calendar.current.date(byAdding: .minute, value: remainder * 15, to: closestQuarterTimeRepresentation ?? Date())!
            let minutes = minutesToHoursAndMinutes(remainder * 15)
            modernSliderLabel.stringValue = "+\(minutes.hours):\(minutes.leftMinutes)h"
            if resetModernSliderButton.isHidden {
                animateButton(false)
            }

            return nextDate.minutes(from: Date()) + 1
        } else if index < centerPoint {
            let remainder = centerPoint - index + 1
            let previousDate = Calendar.current.date(byAdding: .minute, value: -1 * remainder * 15, to: closestQuarterTimeRepresentation ?? Date())!
            modernSliderLabel.stringValue = timezoneFormattedStringRepresentation(previousDate)
            let minutes = minutesToHoursAndMinutes(-1 * remainder * 15)
            modernSliderLabel.stringValue = "\(minutes.hours):\(minutes.leftMinutes)h"
            if resetModernSliderButton.isHidden {
                animateButton(false)
            }
            return previousDate.minutes(from: Date())
        } else {
            modernSliderLabel.stringValue = "Time Scroller"
            if !resetModernSliderButton.isHidden {
                animateButton(true)
            }
            return 0
        }
    }

    private func minuteFromCalendar() -> (Date, Int) {
        let currentDate = Date()
        var minute = Calendar.current.component(.minute, from: currentDate)
        if minute < 15 {
            minute = 15
        } else if minute < 30 {
            minute = 30
        } else if minute < 45 {
            minute = 45
        } else {
            minute = 0
        }

        return (currentDate, minute)
    }

    private func timezoneFormattedStringRepresentation(_ date: Date) -> String {
        let dateFormatter = DateFormatterManager.dateFormatterWithFormat(with: .none,
                                                                         format: "MMM d HH:mm",
                                                                         timezoneIdentifier: TimeZone.current.identifier,
                                                                         locale: Locale.autoupdatingCurrent)
        return dateFormatter.string(from: date)
    }
}
