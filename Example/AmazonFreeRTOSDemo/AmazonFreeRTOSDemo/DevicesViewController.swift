import Alertift
import AmazonFreeRTOS
import CoreBluetooth
import UIKit

/// This is the main controller used to list the nearby FreeRTOS devices that has the BLE capability.
class DevicesViewController: UITableViewController {

    var uuid: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        extendedLayoutIncludesOpaqueBars = true

        // Add observe for AmazonFreeRTOSManager NSNotifications
        NotificationCenter.default.addObserver(self, selector: #selector(centralManagerDidUpdateState), name: .afrCentralManagerDidUpdateState, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(centralManagerDidDisconnectDevice), name: .afrCentralManagerDidDisconnectDevice, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataWithoutAnimation), name: .afrCentralManagerDidDiscoverDevice, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataWithoutAnimation), name: .afrCentralManagerDidConnectDevice, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataWithoutAnimation), name: .afrCentralManagerDidFailToConnectDevice, object: nil)

        centralManagerDidUpdateState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    // Segue

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if segue.identifier == "toNetworkConfigViewController", let viewController = segue.destination as? NetworkConfigViewController {
            viewController.uuid = uuid
        }
    }
}

extension DevicesViewController {

    #warning("Scan forever when BLE is on, stop when off. However in production app there should be a timer to stop scan after some time.")
    @objc
    func centralManagerDidUpdateState() {
        if AmazonFreeRTOSManager.shared.central?.state == .poweredOn {
            AmazonFreeRTOSManager.shared.startScanForDevices()
            return
        }
        AmazonFreeRTOSManager.shared.stopScanForDevices()
    }

    @objc
    func centralManagerDidDisconnectDevice(_ notification: NSNotification) {
        reloadDataWithoutAnimation()
        if notification.userInfo?["identifier"] as? UUID == uuid {
            _ = navigationController?.popToRootViewController(animated: true)
        }
    }

    @objc
    func reloadDataWithoutAnimation() {
        UIView.performWithoutAnimation {
            self.tableView.reloadData()
        }
    }
}

// UITableView

extension DevicesViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection _: Int) -> Int {
        return AmazonFreeRTOSManager.shared.devices.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        guard let deviceCell = cell as? DeviceCell else {
            return cell
        }
        let device = Array(AmazonFreeRTOSManager.shared.devices.values)[indexPath.row]

        #warning("the GAP name (peripheral.name) is cached on iOS and refreshes on connect so we use advertisementData name to get the latest.")
        deviceCell.labDeviceName.text = device.advertisementData?["kCBAdvDataLocalName"] as? String ?? device.peripheral.name
        // iOS use generated identifier, it will be different on other devices.
        deviceCell.labDeviceIdentifier.text = device.peripheral.identifier.uuidString
        deviceCell.labDeviceRSSI.text = device.RSSI?.stringValue ?? NSLocalizedString("N/A", comment: String())
        if device.peripheral.state == .connected {
            deviceCell.viewDeviceStateIndicator.backgroundColor = UIColor(named: "seafoam_green_color")
        } else {
            deviceCell.viewDeviceStateIndicator.backgroundColor = UIColor.clear
        }
        return deviceCell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        uuid = Array(AmazonFreeRTOSManager.shared.devices.keys)[indexPath.row]
        let device = Array(AmazonFreeRTOSManager.shared.devices.values)[indexPath.row]
        if device.peripheral.state == .connected {
            device.getMtu()
            if device.mtu != nil {
                Alertift.actionSheet()
                    .popover(anchorView: cell)

                    // Network Config

                    .action(.default(NSLocalizedString("Network Config", comment: String()))) { _, _ in
                        self.performSegue(withIdentifier: "toNetworkConfigViewController", sender: self)
                        return
                    }

                    .action(.cancel(NSLocalizedString("Cancel", comment: String())))
                    .show(on: self)
            } else {
                if let deviceCell = cell as? DeviceCell {
                    deviceCell.viewDeviceStateIndicator.backgroundColor = UIColor(named: "orange_color")
                    Alertift.alert(title: NSLocalizedString("Error", comment: String()), message: "Unable to read secure values. You need to forget this device pair it again")
                        .action(.default(NSLocalizedString("OK", comment: String())))
                        .show(on: self)
                }
            }
        } else {
            device.connect(reconnect: true)
        }
    }

    override func tableView(_: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let device = Array(AmazonFreeRTOSManager.shared.devices.values)[indexPath.row]
        if device.peripheral.state == .connected {
            return true
        }
        return false
    }

    override func tableView(_: UITableView, titleForDeleteConfirmationButtonForRowAt _: IndexPath) -> String? {
        return NSLocalizedString("Disconnect", comment: String())
    }

    override func tableView(_: UITableView, commit _: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let device = Array(AmazonFreeRTOSManager.shared.devices.values)[indexPath.row]
        device.disconnect()
    }
}

extension DevicesViewController {

    @IBAction private func btnRescanPush(_: UIBarButtonItem) {
        AmazonFreeRTOSManager.shared.rescanForDevices()
        reloadDataWithoutAnimation()
    }
}
