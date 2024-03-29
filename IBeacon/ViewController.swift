
import UIKit
import CoreBluetooth
import CoreLocation

@available(iOS 13, *)
class ViewController: UIViewController, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        print("viewDidLoad\n")
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        centralManager = CBCentralManager(delegate:self, queue: nil)        // This will trigger centralManagerDidUpdateState
        // let filePath = Bundle.main.path(forResource: "TheLittlePrince", ofType: "txt");
        let filePath = Bundle.main.path(forResource: "TheLittlePrince_4KB", ofType: "txt");
        let URL = NSURL.fileURL(withPath: filePath!)
        do {
            let string = try String.init(contentsOf: URL)
            fileContents = string
            // print("read: " + string)
        } catch  {
            print(error);
        }
        
    }
    
    
    var peripheralManager = CBPeripheralManager()
    var centralManager =  CBCentralManager()   // CoreBluetooth Central Manager
    // var peripherals = [CBPeripheral]()      // All peripherals in Central Manager
    var discoveredPeripheral:CBPeripheral?
    let uuid = UUID(uuidString: "6F3934B7-B904-0001-AFFA-11200E011907")
    // 07 19 01 0E 20 11 FA AF 01 00 04 B9 B7 34 39 6F
    // 07, 19: Length, 01, 0E20: Device Model, 11: UTP, FA: Battery Indication1, AF: Battery Indication 2, 01: Lid Open Count, 00: Device Color, 04, Encrypted Payload(16-byte)
    let identifier = "ident"
    let major: CLBeaconMajorValue = 1
    let minor: CLBeaconMinorValue = 0
    
    var startTime = DispatchTime.now()
    var endTime = DispatchTime.now()
    
    private(set) var isRunning = false
    
    var isCentralActive = false
    
    var msg = ""
    var prevMsg = ""
    var sentmsg = ""
    
    var index = 0
    var isSentLoopRequired = false
    
    var fileContents = ""
    var lostPacketNum = 0
    var ber = 0
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central Manager did update state")
        var message = String()
        var isPoweredOn = false
        switch  (central.state){
        case .poweredOn:
            print("Bluetooth is powered on \n")
            let serviceUUID = CBUUID(string: "6F3934B7-B904-0001-AFFA-11200E011907")
            let options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            //self.centralManager.scanForPeripherals(withServices: [serviceUUID], options: options)
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: options)
            isPoweredOn = true
            break
        case .unknown:
            message = "Bluetooth state is unknown \n"
            break
        case .resetting:
            break
        case .unsupported:
            message = "Bluetooth is unsupported \n"
            break
        case .unauthorized:
            message = "Bluetooth is unauthorized \n"
            break
        case .poweredOff:
            message = "Bluetooth is powered off \n"
            break
        default:
            break
        }
        if isPoweredOn == false{
            let controller = UIAlertController(title: "Bluetooth unavailable", message: message, preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "OK",
                                               style: .default,
                                               handler: nil))
            present(controller, animated: true, completion: nil)
        }
    }
    
    
    func centralManager(_ central:CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData:[String : Any],rssi RSSI:NSNumber){
        // print("centralManager")
        //print("...receiving")
        let name = peripheral.name ?? "NONE"
        if name != "NONE"{
            print(name);
        }
        if peripheral.name != prevMsg && name != "NONE"{
            msg = msg + name
            outputText.text = msg
            prevMsg = name
            //print("msg: \(msg)")
        }
            
        /*
        if(peripheral.identifier.uuidString == "6F3934B7-B904-0001-AFFA-11200E011907"){
            outputText.text = peripheral.name
            print("PERIPHERAL NAME: \(peripheral.name ?? "NONE")\n")
            print("UUID DESCRIPTION: \(peripheral.identifier.uuidString)\n")
            print("IDENTIFIER: \(peripheral.identifier)\n")
        }
        */
    }
    
    
    func startScanningForPeripherals(){
        if centralManager.state != CBManagerState.poweredOn {
            print("here")
            return
        }
        let serviceUUID = CBUUID(string: "6F3934B7-B904-0001-AFFA-11200E011907")
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        print("is scanning: \(centralManager.isScanning)")
    }
    
    func startListening() {
        if isRunning {
            print("already listening")
            return
        }
        isRunning = true
        print("listening started.")
        startScanningForPeripherals()
    }
    
    func stopListening() {
        if !isRunning{
            print("already stopped listening")
            return
        }
        isRunning = false
        centralManager.stopScan()
        PacketLoss()
        BER()
        let message = "The number of lost packets is: \(String(describing: lostPacketNum)), and BER is: \(String(describing: ber)), and the length of recieved msg is \(String(describing: msg.count))"
        let controller = UIAlertController(title: "Packet Loss and BER", message: message,
                                           preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "OK",
                                           style: .default,
                                           handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
    func PacketLoss(){
        var indexM = 0
        var indexC = 0
        lostPacketNum = 0
        while(indexM < msg.count){
            var lastOffset = 0
            if (indexM+8>msg.count){
                lastOffset = msg.count - indexM
            }else{
                lastOffset = 8
            }
            
            var rChunk = msg[msg.index(msg.startIndex, offsetBy: indexM)..<msg.index(msg.startIndex, offsetBy: indexM+lastOffset)]
            var cChunk = fileContents[fileContents.index(fileContents.startIndex, offsetBy: indexC)..<fileContents.index(fileContents.startIndex, offsetBy: indexC+lastOffset)]
            let isEqual = (rChunk == cChunk)
            if (isEqual){
                indexM += 8;
                indexC += 8;
                /*
                print(rChunk)
                print(cChunk)
                print("=====================")
                */
            }else{
                if (indexC + 8 < fileContents.count){
                    indexC += 8;
                }
                lostPacketNum+=1
            }
        }
        print("Packet Loss: ")
        print(lostPacketNum)
    }
    
    func BER(){
        let difference = msg.difference(from: fileContents)
        print("BER")
        print(difference)   // 504-2047
        print("========")
        print(msg)
        print("========")
        print(fileContents)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("peripheralManagerDidUpdateState\n")
        switch peripheral.state{
        case .poweredOn:
                let serviceUUID = CBUUID(string: "6F3934B7-B904-0001-AFFA-11200E011907")
                let service=CBMutableService(type: serviceUUID, primary: true)
            self.peripheralManager.add(service)
            
            default:
            break
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("peripheralManagerDidStartAdversiting")
        print(DispatchTime.now());
        if error == nil {
            if(isSentLoopRequired){
                var slicedEncoded=""
                if msg.count>(index+1)*8-1{
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
                sentmsg += slicedEncoded
                sendMessage(message: slicedEncoded)
                
            }else{
                endTime = DispatchTime.now()
                print("Successfully started advertising our beacon data.")
                //let message = "Successfully set up your beacon. " +
                //"The unique identifier of our service is: \(String(describing: uuid?.uuidString)), and the sent data is: \(String(describing: inputText.text))"
                let message = "Sent data length is : \(String(describing: sentmsg.count)), elapsed time is : \(String(describing: (Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds))/1_000_000_000))"
                
                let controller = UIAlertController(title: "Send message successfully", message: message,
                                                   preferredStyle: .alert)
                controller.addAction(UIAlertAction(title: "OK",
                                                   style: .default,
                                                   handler: nil))
                present(controller, animated: true, completion: nil)

                if isSentLoopRequired==false{
                    // Terminate Advertising Automatically
                    //sleep(1)
                    //usleep(500000) // 0.5 seconds
                    //usleep(200000) // 0.2 seconds
                    //usleep(100000) // 0.1 seconds
                    usleep(50000) // 0.05 seconds
                    
                    peripheralManager.stopAdvertising()
                }
            }
        } else {
            print("Failed to advertise our beacon. Error = \(String(describing: error))")
        }
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        print("viewWillDisappear\n")
        
        centralManager.stopScan()   // Stop scan to save battery when entering  background
        
        //peripheral.removeAll(keepingCapacity: false)   // Remove all peripherals from the array
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
        inputText.text = "";
        peripheralManager.stopAdvertising()
    }
    
    func sendMessage(message: String){
        if peripheralManager.isAdvertising{
            // sleep(1)
            //usleep(500000) // 0.5 seconds
            //usleep(200000) // 0.2 seconds
            //usleep(100000) // 0.1 seconds
            usleep(50000) // 0.05 seconds
            peripheralManager.stopAdvertising()
        }
        // print("message is \(String(describing: message)) \n")
        let region = CLBeaconRegion(proximityUUID: self.uuid!,
                                    major: self.major,
                                    minor: self.minor,
                                    identifier: self.identifier)
        let peripheralData = region.peripheralData(withMeasuredPower: nil)
        
        peripheralManager.startAdvertising( [CBAdvertisementDataLocalNameKey: message, CBAdvertisementDataServiceUUIDsKey:[CBUUID(string: "6F3934B7-B904-0001-AFFA-11200E011907")],])
    }
    
    @IBAction func btnStartTouchUpInside(_ sender: Any) {
        sentText.text = inputText.text
        startTime = DispatchTime.now()
        
        // let encoded=inputText.text
        let encoded = fileContents
        var slicedEncoded = String()
        if encoded.count < 8 {
            if peripheralManager.state == .poweredOn {
                sendMessage(message: encoded)
            }
        }
        else{
            // 8글자씩 index update하기
            isSentLoopRequired = true
            msg = encoded
            index = 1
            if peripheralManager.state == .poweredOn {
                sendMessage(message: encoded[0...7])
                sentmsg += encoded[0...7]
            }
            }
    }
    
    @IBAction func Startlistening(_ sender: Any) {
        outputText.text = ""
        msg = ""
        lostPacketNum = 0
        ber = 0
        startListening()
    }
    
    @IBAction func Stoplistening(_ sender: Any) {
        stopListening()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            if error != nil {
                if let error = error {
                    print("Scan service error, error reason:\(error)")
                }
            } else {
                for service in peripheral.services ?? [] {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    
    private func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!,
           error: NSError!) {
        print("peripheral 1")
               
        print("\nCharacteristic \(characteristic.description) isNotifying: \(characteristic.isNotifying)\n")
               
       }
    func peripheral(peripheral: CBPeripheral!, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        print("peripheral 2")
            if( characteristic.isNotifying )
            {
                peripheral.readValue(for: characteristic)
            }
        }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
         self.view.endEditing(true)
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

extension Array where Element: Hashable {
    func difference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }
}
