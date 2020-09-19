
import UIKit
import CoreBluetooth
import CoreLocation

class ViewController: UIViewController, CBPeripheralManagerDelegate, CBCentralManagerDelegate {
    var peripheralManager : CBPeripheralManager? //let uuid = UUID(uuidString: "086704EE-9611-4ACC-91DB-F983ABAC9153")
    var centralManager: CBCentralManager!   // CoreBluetooth Central Manager
    var peripherals = [CBPeripheral]()      // All peripherals in Central Manager
    let uuid = UUID(uuidString: "6F3934B7-B904-0001-AFFA-11200E011907")
    // 07 19 01 0E 20 11 FA AF 01 00 04 B9 B7 34 39 6F
    // 07, 19: Length, 01, 0E20: Device Model, 11: UTP, FA: Battery Indication1, AF: Battery Indication 2, 01: Lid Open Count, 00: Device Color, 04, Encrypted Payload(16-byte)
    let identifier = "ident"
    let major: CLBeaconMajorValue = 1
    let minor: CLBeaconMinorValue = 0
    
    var isCentralActive = false
    
    var msg = ""
    var index = 0
    var isSentLoopRequired = false

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state{
        case .poweredOn:
                let serviceUUID = CBUUID(string: "6F3934B7-B904-0001-AFFA-11200E011907")
                let service=CBMutableService(type: serviceUUID, primary: true)
                self.peripheralManager?.add(service)
            
            default:
            break
    }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if error == nil {
            
            if(isSentLoopRequired){
                var slicedEncoded=""
                if msg.count>=(index+1)*8-1{
                    let range = index*8...(index+1)*8-1
                    slicedEncoded = msg[range]
                    if msg.count-1<(index+1)*8{
                        // Initialize
                        isSentLoopRequired = false
                        index = 0
                    }else{
                        // Update index
                        index = index+1
                    }
                }else{
                    let range = index*8...msg.count-1
                    slicedEncoded = msg[range]
                    // Initialize
                    isSentLoopRequired = false
                    index = 0
                }
                sendMessage(message: slicedEncoded)
                
            }else{
                print("Successfully started advertising our beacon data.")
                let message = "Successfully set up your beacon. " +
                "The unique identifier of our service is: \(String(describing: uuid?.uuidString)), and the sent data is: \(String(describing: inputText.text))"
                let controller = UIAlertController(title: "Airpods Friend", message: message,
                                                   preferredStyle: .alert)
                controller.addAction(UIAlertAction(title: "OK",
                                                   style: .default,
                                                   handler: nil))
                present(controller, animated: true, completion: nil)

                if isSentLoopRequired==false{
                    // Terminate Advertising Automatically
                    sleep(1)
                    peripheralManager?.stopAdvertising()
                }
            }
        } else {
            print("Failed to advertise our beacon. Error = \(String(describing: error))")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        centralManager = CBCentralManager(delegate:self, queue: nil)        // This will trigger centralManagerDidUpdateState
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        centralManager.stopScan()   // Stop scan to save battery when entering  background
        
        peripherals.removeAll(keepingCapacity: false)   // Remove all peripherals from the array
    }
    
    // MARK: CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central Manager did update state \n")
        var message = String()
        if central.state == .poweredOn {
            print("Bluetooth is powered on \n")
            let serviceUUID = CBUUID(string: "6F3934B7-B904-0001-AFFA-11200E011907")
            let options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            self.centralManager.scanForPeripherals(withServices: [serviceUUID], options: options)
        }else{
        switch central.state{
            case .unsupported:
                message = "Bluetooth is unsupported \n"
            case .unknown:
                message = "Bluetooth state is unknown \n"
            case .unauthorized:
                message = "Bluetooth is unauthorized \n"
            case .poweredOff:
                message = "Bluetooth is powered off \n"
            default:
                break
            }
            let controller = UIAlertController(title: "Bluetooth unavailable", message: message, preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "OK",
                                               style: .default,
                                               handler: nil))
            present(controller, animated: true, completion: nil)
        }
        
    }
    
    public func centralManager(central:CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData:[NSObject : AnyObject]!,RSSI:NSNumber!){
        print("Peripheral discovered: \(String(describing: peripheral)) \n")
        
        peripherals.append(peripheral)  // Add the peripheral to the array to keep reference, otherwise the system will release it and further delegate methods won't be triggered (didConnect, didFail....)
        showMessage()
    }
    
    func showMessage(){
        let p = peripherals[0]
        outputText.text = p.identifier.uuidString
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    @IBOutlet weak var inputText: UITextField!
    @IBOutlet weak var sentText: UILabel!
    @IBOutlet weak var outputText: UILabel!

    // MARK: Broadcasting
    @IBAction func btnStopTouchUpInside(_ sender: Any) {
        sentText.text="";
        peripheralManager!.stopAdvertising()
    }
    
    func sendMessage(message: String){
        if peripheralManager!.isAdvertising{
            sleep(1)
            peripheralManager?.stopAdvertising()
        }
        print("message is \(String(describing: message)) \n")
        let region = CLBeaconRegion(proximityUUID: self.uuid!,
                                    major: self.major,
                                    minor: self.minor,
                                    identifier: self.identifier)
        let peripheralData = region.peripheralData(withMeasuredPower: nil)
        
        peripheralManager!.startAdvertising( [CBAdvertisementDataLocalNameKey: message, CBAdvertisementDataServiceUUIDsKey:[CBUUID(string: "6F3934B7-B904-0001-AFFA-11200E011907")],])
    }
    
    @IBAction func btnStartTouchUpInside(_ sender: Any) {
        sentText.text = inputText.text

        let encoded=inputText.text
        var slicedEncoded = String()
        if encoded!.count < 8 {
            if peripheralManager!.state == .poweredOn {
                sendMessage(message: encoded!)
            }
        }
        else{
            // 8글자씩 index update하기
            isSentLoopRequired = true
            msg = encoded!
            index = 1
            if peripheralManager!.state == .poweredOn {
                sendMessage(message: encoded![0...7])
            }
            }
    }
    
    @IBAction func Startlistening(_ sender: Any) {
        listen()
    }
    @IBAction func Stoplistening(_ sender: Any) {
        stopListening()
    }
    
    // MARK: Listening
    
    public func listen()->Bool{
        guard self.isCentralActive else{
            NSLog("[WARNING] Peer is not active. Skip listening")
            return false
        }
        if centralManager.state == .poweredOn{
            print("centralManager is successfully powered on \n")
            let serviceUUID = CBUUID(string: "6F3934B7-B904-0001-AFFA-11200E011907")
            let options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            self.centralManager.scanForPeripherals(withServices: [serviceUUID], options: options)
            print("centralManager successfully scans peripherals")
        }
        return true
    }
    
    public func stopListening(){
        self.centralManager.stopScan()
        // peripherals.removeAll()
    }
    
}


extension String {
    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }

    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }
}
