/*
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import UIKit

import CocoaLumberjackSwift

enum SettingsViewKey {
    case StartDelay
    case PerRow
    case RowCount
    case NadirCount
    case MaxPitchEnabled
    case MetricSelected
    case GimbalYaw
}

class SettingsViewController: UIViewController, Analytics, SystemUtils, ModelSettings, ModelUtils {

    var model: String = ""
    var type: ProductType = .Aircraft

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var yawAngleLabel: UILabel!
    @IBOutlet weak var pitchAngleLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var helpView: UIView!
    @IBOutlet weak var helpTitle: UILabel!
    @IBOutlet weak var helpText: UILabel!

    var startDelay = 0
    var perRow = 0
    var rowCount = 0
    var nadirCount = 0
    var maxPitchEnabled = true
    var maxPitch = 0
    var metricSelected = true
    var acGimbalYaw = false

    override func viewDidLoad() {
        super.viewDidLoad()

        helpView.alpha = 0
        
        if let version = buildVersion() {
            self.versionLabel.hidden = false
            self.versionLabel.text = "Version \(version)"

            DDLogDebug("Settings VC showing version \(version)")
        } else {
            self.versionLabel.hidden = true

            DDLogWarn("Settings VC unknown version")
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        initSettings()

        DDLogInfo("Showing settings window")
        trackScreenView("SettingsViewController")
    }

    override func viewDidAppear(animated: Bool) {
        DDLogInfo("Settings VC Showing settings view")
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    func stringForAngle(angle: Double, color: UIColor = UIColor.whiteColor()) -> NSAttributedString {
        let roundedString = String(format: "%.2f", angle)
        
        let angleString = NSMutableAttributedString(string: "\(roundedString)", attributes: [
            NSFontAttributeName: UIFont.boldSystemFontOfSize(14),
            NSForegroundColorAttributeName: color
            ])
        
        
        angleString.appendAttributedString(NSAttributedString(string: "˚", attributes: [
            NSFontAttributeName: UIFont.systemFontOfSize(14),
            NSForegroundColorAttributeName: color
            ]))
        
        return angleString
    }
    
    func setYawAngle(angle: Double) {
        self.yawAngleLabel.attributedText = stringForAngle(angle)
    }
    
    func setPitchAngle(angle: Double) {
        if angle > 30 {
            self.pitchAngleLabel.attributedText = stringForAngle(angle, color: UIColor(red: 1, green: 0.5, blue: 0.5, alpha: 1))
        } else {
            self.pitchAngleLabel.attributedText = stringForAngle(angle)
        }
    }

    func setCount(count: Int) {
        self.countLabel.text = "\(count)"
    }
    
    func updateCounts() {
        if self.rowCount > 0 && self.perRow > 0 {
            self.setYawAngle(360.0 / Double(self.perRow))

            let maxP = self.maxPitchEnabled ? Double(self.maxPitch) : Double(0)

            self.setPitchAngle((maxP + 90.0) / Double(self.rowCount))

            self.setCount((self.rowCount * self.perRow) + self.nadirCount)
        }
    }
    
    func initSettings() {
        if (self.model == "") {
            titleLabel.text = "Disconnected"
        } else {
            titleLabel.text = "\(model) Settings"
        }

        setYawAngle(0)
        setPitchAngle(0)
        setCount(0)

        self.startDelay = startDelay(model)
        self.perRow = photosPerRow(model)
        self.rowCount = numberOfRows(model)
        self.nadirCount = nadirCount(model)
        self.maxPitchEnabled = maxPitchEnabled(model)
        self.maxPitch = maxPitch(model)
        self.metricSelected = metricUnits()
        self.acGimbalYaw = acGimbalYaw(model)

        updateCounts()
    }

    @IBAction func copyLogToClipboard(sender: UIButton) {
        if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate {
            if (appDelegate.copyLogToClipboard()) {
                showAlert("Log copied", body: "Log copied to clipboard")
            } else {
                showAlert("Failed", body: "Failed to copy log to clipboard")
            }
        }
    }

    private func showAlert(title: String, body: String) {
        let alert = UIAlertController(title: title, message: body, preferredStyle: .Alert)

        let ok = UIAlertAction(title: "OK", style: .Default, handler: nil)

        alert.addAction(ok)

        self.presentViewController(alert, animated: true, completion: nil)
    }

    func displayMessage(title: String, message: String) {
        helpTitle.text = title
        helpText.text = message

        UIView.animateWithDuration(0.5, animations: {
            self.helpView.alpha = 1
        })
    }
    
    @IBAction func clearHelpWindow(sender: UIButton) {
        UIView.animateWithDuration(0.5, animations: {
            self.helpView.alpha = 0
        })
    }
}

extension SettingsViewController : UITableViewDelegate {
    
}

extension SettingsViewController : UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (self.type) {
        case .Handheld:
            return 6
        case .Aircraft:
            var rowCount = 7
            
            if maxPitch <= 0 {
                rowCount -= 1
            }
            
            if !isInspire(model) {
                rowCount -= 1
            }
            
            return rowCount
        default:
            return 0
        }
    }
    
    func unitsCell(tableView: UITableView, indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SegmentViewCell", forIndexPath: indexPath) as! SegmentTableViewCell
        
        cell.delegate = self
        
        cell.title = "Units:"
        cell.values = ["Metric", "Imperial"]
        cell.helpText = "Distances (distance of aircraft from you and altitude) can be shown in metres or feet"
        cell.key = .MetricSelected

        cell.prepareForDisplay(self.metricSelected ? "Metric" : "Imperial")
        
        return cell
    }
    
    func startDelayCell(tableView: UITableView, indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SliderViewCell", forIndexPath: indexPath) as! SliderTableViewCell

        cell.delegate = self
        
        cell.title = "Start Delay (seconds):"
        cell.min = 0
        cell.max = 30
        cell.step = 5
        cell.helpText = "The Osmo will wait this many seconds after you start the panorama before it starts the sequence. This is your chance to get out of shot"
        cell.key = .StartDelay
        
        cell.prepareForDisplay(self.startDelay)

        return cell
    }

    func photosPerRowCell(tableView: UITableView, indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SliderViewCell", forIndexPath: indexPath) as! SliderTableViewCell
        
        cell.delegate = self
        
        cell.title = "Number of photos per row:"
        cell.min = 6
        cell.max = 20
        cell.step = 1
        cell.helpText = "How many photos do you want in one row? X3/Phantom should be good with 6-8, X5 will need more - depending on what lens they are using"
        cell.key = .PerRow
        
        cell.prepareForDisplay(self.perRow)
        
        return cell
    }
    
    func rowCountCell(tableView: UITableView, indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SliderViewCell", forIndexPath: indexPath) as! SliderTableViewCell
        
        cell.delegate = self
        
        cell.title = "Number of rows:"
        cell.min = 3
        cell.max = 10
        cell.step = 1
        cell.helpText = "How many rows to take? X3/Phantom should be fairly good with 3-5 (3 is not enough if you set max pitch so that a column crosses the horizontal). This does not include the nadir/zenith shot (straight down/straight up)"
        cell.key = .RowCount
        
        cell.prepareForDisplay(self.rowCount)
        
        return cell
    }
    
    func nadirCountCell(tableView: UITableView, indexPath: NSIndexPath, nadir: Bool = true) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SliderViewCell", forIndexPath: indexPath) as! SliderTableViewCell

        cell.delegate = self
        
        if (nadir) {
            cell.title = "Number of nadir shots:"
            cell.helpText = "How many nadir (straight down) photos to take at the end of the sequence. X3/Phantom users should be good with 1 - X5 may need more"
        } else {
            cell.title = "Number of zenith shots:"
            cell.helpText = "How many zenith (straight up) photos to take at the end of the sequence. X3/Phantom users should be good with 1 - X5 may need more"
        }
        
        cell.min = 1
        cell.max = 4
        cell.step = 1
        cell.key = .NadirCount
        
        cell.prepareForDisplay(self.nadirCount)

        return cell
    }
    
    func pitchMaxCell(tableView: UITableView, indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SegmentViewCell", forIndexPath: indexPath) as! SegmentTableViewCell

        cell.delegate = self
        
        let max = "\(self.maxPitch)˚"
        
        cell.title = "Maximum Upward Pitch:"
        cell.values = [max, "Horizon"]
        cell.helpText = "You can choose to take from the horizon (0˚) to nadir (90˚ down) or from \(self.maxPitch)˚ above the horizon to nadir. Rows will be evenly spaced across this range"
        cell.key = .MaxPitchEnabled


        cell.prepareForDisplay(self.maxPitchEnabled ? max : "Horizon")
        
        return cell
    }

    func gimbalYawCell(tableView: UITableView, indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SegmentViewCell", forIndexPath: indexPath) as! SegmentTableViewCell
        
        cell.delegate = self
        
        cell.title = "Aircraft or Gimbal Yaw:"
        cell.values = ["Aircraft", "Gimbal"]
        cell.helpText = "You can choose to yaw the entire aircraft or the gimbal only"
        cell.key = .GimbalYaw
        
        cell.prepareForDisplay(self.acGimbalYaw ? "Gimbal" : "Aircraft")
        
        return cell
    }
    
    func buttonCell(tableView: UITableView, indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("ButtonViewCell", forIndexPath: indexPath) as! ButtonViewCell
        
        cell.delegate = self
        
        return cell
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell : UITableViewCell
        
        switch (self.type) {
        case .Handheld:
            switch (indexPath.row) {
            case 0:
                cell = startDelayCell(tableView, indexPath: indexPath)
            case 1:
                cell = photosPerRowCell(tableView, indexPath: indexPath)
            case 2:
                cell = rowCountCell(tableView, indexPath: indexPath)
            case 3:
                cell = nadirCountCell(tableView, indexPath: indexPath, nadir: false)
            case 4:
                cell = unitsCell(tableView, indexPath: indexPath)
            default:
                cell = buttonCell(tableView, indexPath: indexPath)
            }
        case .Aircraft:
            var row = indexPath.row
            
            if row > 2 {
                if maxPitch == 0 {
                    // Need to skip if no max pitch
                    row = row + 1
                }
            }
            
            if row > 3 {
                if !isInspire(model) {
                    // Need to skip if no gimbal yaw
                    row = row + 1
                }
            }
            
            switch (row) {
            case 0:
                cell = photosPerRowCell(tableView, indexPath: indexPath)
            case 1:
                cell = rowCountCell(tableView, indexPath: indexPath)
            case 2:
                cell = nadirCountCell(tableView, indexPath: indexPath)
            case 3:
                cell = pitchMaxCell(tableView, indexPath: indexPath)
            case 4:
                cell = gimbalYawCell(tableView, indexPath: indexPath)
            case 5:
                cell = unitsCell(tableView, indexPath: indexPath)
            default:
                cell = buttonCell(tableView, indexPath: indexPath)
            }
        default:
            cell = unitsCell(tableView, indexPath: indexPath)
        }
        
        // Workaround for iPad ignoring IB clear color
        cell.backgroundColor = cell.contentView.backgroundColor
        
        return cell
    }
}

extension SettingsViewController : SegmentTableViewCellDelegate {
    func newValueForKey(key: SettingsViewKey, value: String) {
        switch key {
        case .MaxPitchEnabled:
            self.maxPitchEnabled = value != "Horizon"
        case .MetricSelected:
            self.metricSelected = value == "Metric"
        case .GimbalYaw:
            self.acGimbalYaw = value == "Gimbal"
        default:
            DDLogWarn("Segment control tríed to update a non-segment setting \(key)")
        }
        
        updateCounts()
    }
}

extension SettingsViewController : SliderTableViewCellDelegate {
    func newValueForKey(key: SettingsViewKey, value: Int) {
        switch key {
        case .StartDelay:
            self.startDelay = value
        case .PerRow:
            self.perRow = value
        case .RowCount:
            self.rowCount = value
        case .NadirCount:
            self.nadirCount = value
        default:
            DDLogWarn("Slider control tríed to update a non-slider setting \(key)")
        }
        
        updateCounts()
    }
}

extension SettingsViewController : ButtonViewCellDelegate {
    func buttonClicked(save: Bool) {
        if (save) {
            setMetricUnits(self.metricSelected)

            let settings : [SettingsKeys:AnyObject] = [
                .StartDelay: self.startDelay,
                .PhotosPerRow: self.perRow,
                .NumberOfRows: self.rowCount,
                .NadirCount: self.nadirCount,
                .MaxPitchEnabled: self.maxPitchEnabled,
                .ACGimbalYaw: self.acGimbalYaw
            ]

            updateSettings(model, settings: settings)
        }
        
        self.dismissViewControllerAnimated(true, completion: {})
    }
}

