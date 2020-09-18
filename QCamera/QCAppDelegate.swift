//
//  AppDelegate.swift
//  Quick Camera
//
//  Created by Simon Guest on 1/22/17.
//  Copyright © 2013-2019 Simon Guest. All rights reserved.
//

import Cocoa
import AVKit
import AVFoundation

@available(OSX 10.15, *)
@NSApplicationMain
class QCAppDelegate: NSObject, NSApplicationDelegate, QCUsbWatcherDelegate {
    
    func deviceCountChanged() {
        self.detectVideoDevices()
        self.updateSourceResolutionsMenu(forDeviceAtIndex:selectedDeviceIndex)
        self.startCaptureWithVideoDevice(defaultDevice: selectedDeviceIndex)
    }
    
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var selectSourceMenu: NSMenuItem!
    @IBOutlet weak var selectSourceResolution: NSMenuItem!
    @IBOutlet weak var playerView: AVPlayerView!
    
    var isMirrored: Bool = false;
    var isUpsideDown: Bool = false;
    
    // 0 = normal, 1 = 90' top to right, 2 = 180' top to bottom, 3 = 270' top to left
    var position = 0;
    
    var isBorderless: Bool = false;
    var defaultBorderStyle: NSWindow.StyleMask = NSWindow.StyleMask.closable;
    var windowTitle = "Quick Camera";
    let defaultDeviceIndex: Int = 0;
    var selectedDeviceIndex: Int = 0
    var selectedSourceResolution: Int = -1
    
    var devices: [AVCaptureDevice]!;
    var captureSession: AVCaptureSession!;
    var captureLayer: AVCaptureVideoPreviewLayer!;
    
    func detectVideoDevices() {
        NSLog("Detecting video devices...");
        self.devices = AVCaptureDevice.devices(for: AVMediaType.video);
        
        if (devices?.count == 0) {
            let popup = NSAlert();
            popup.messageText = "Unfortunately, you don't appear to have any cameras connected. Goodbye for now!";
            popup.runModal();
            NSApp.terminate(nil);
        } else {
            NSLog("%d devices found", devices?.count ?? 0);
        }
        
        let deviceMenu = NSMenu();
        var deviceIndex = 0;
        
        var currentdevice = self.devices[defaultDeviceIndex]
        
        if(self.captureSession != nil) {
            currentdevice = (self.captureSession.inputs[0] as! AVCaptureDeviceInput).device
        }
        
        self.selectedDeviceIndex = defaultDeviceIndex
        
        for device in self.devices {
            let deviceMenuItem = NSMenuItem(title: device.localizedName, action: #selector(deviceMenuChanged), keyEquivalent: "")
            deviceMenuItem.target = self;
            deviceMenuItem.representedObject = deviceIndex;
            if (device == currentdevice) {
                deviceMenuItem.state = NSControl.StateValue.on;
                self.selectedDeviceIndex = deviceIndex
            }
            if (deviceIndex < 9) {
                deviceMenuItem.keyEquivalent = String(deviceIndex + 1);
            }
            deviceMenu.addItem(deviceMenuItem);
            deviceIndex += 1;
        }
        selectSourceMenu.submenu = deviceMenu;
        
    }
    
    func startCaptureWithVideoDevice(defaultDevice: Int) {
        NSLog("Starting capture with device index %d", defaultDevice);
        
        let device: AVCaptureDevice = self.devices[defaultDevice];
        
        if (captureSession != nil) {
            let currentdevice = (self.captureSession.inputs[0] as! AVCaptureDeviceInput).device
            guard currentdevice != device else { return }
            captureSession.stopRunning();
        }
        
        captureSession = AVCaptureSession()
        
        do {
            let input = try AVCaptureDeviceInput(device: device);
            
            self.captureSession.addInput(input);
            self.captureSession.startRunning();
            self.captureLayer = AVCaptureVideoPreviewLayer(session: self.captureSession);
            
            self.applyResolutionToDevice()
            
            self.captureLayer.connection?.automaticallyAdjustsVideoMirroring = false;
            self.captureLayer.connection?.isVideoMirrored = false;
            self.playerView.layer = self.captureLayer;
            self.playerView.controlsStyle = AVPlayerViewControlsStyle.none;
            self.playerView.layer?.backgroundColor = CGColor.black;
            self.windowTitle = String(format: "Quick Camera: [%@]", device.localizedName);
            self.window.title = self.windowTitle;

        } catch {
            NSLog("Error while opening device");
            let popup = NSAlert();
            popup.messageText = "Unfortunately, there was an error when trying to access the camera. Try again or select a different one.";
            popup.runModal();
        }
    }
    
    @IBAction func mirrorHorizontally(_ sender: NSMenuItem) {
        NSLog("Mirror image menu item selected");
        isMirrored = !isMirrored;
        self.captureLayer.connection?.isVideoMirrored = isMirrored;
    }
    
    func setRotation(_ position: Int){
        switch (position){
        case 1: if (!isUpsideDown){
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft;
        } else {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight;
        }
        break;
        case 2: if (!isUpsideDown){
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown;
        } else {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait;
        }
        break;
        case 3: if (!isUpsideDown) {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight;
        } else {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft;
        }
        break;
        case 0: if (!isUpsideDown) {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait;
        } else {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown;
        }
        break;
        default: break;
        }
    }
    
    @IBAction func mirrorVertically(_ sender: NSMenuItem) {
        NSLog("Mirror image vertically menu item selected");
        isUpsideDown = !isUpsideDown;
        setRotation(position);
        isMirrored = !isMirrored;
        self.captureLayer.connection?.isVideoMirrored = isMirrored;
    }
    
    @IBAction func rotateLeft(_ sender: NSMenuItem) {
        NSLog("Rotate Left menu item selected with position %d", position);
        position = position - 1;
        if (position == -1) { position = 3;}
        setRotation(position);
    }
    
    @IBAction func rotateRight(_ sender: NSMenuItem) {
        NSLog("Rotate Right menu item selected with position %d", position);
        position = position + 1;
        if (position == 4) { position = 0;}
        setRotation(position);
    }
    
    @IBAction func borderless(_ sender: NSMenuItem) {
        NSLog("Borderless menu item selected");
        isBorderless = !isBorderless;
        sender.state = convertToNSControlStateValue((isBorderless ? NSControl.StateValue.on.rawValue : NSControl.StateValue.off.rawValue));
        
        if (isBorderless) {
            // remove border and affix window on top
            defaultBorderStyle = window.styleMask;
            self.window.styleMask = NSWindow.StyleMask.borderless;
            self.window.level = convertToNSWindowLevel(Int(CGWindowLevelForKey(.maximumWindow)));
            window.isMovableByWindowBackground = true;
        } else {
            window.styleMask = defaultBorderStyle;
            window.title = self.windowTitle;
            self.window.level = convertToNSWindowLevel(Int(CGWindowLevelForKey(.normalWindow)));
            window.isMovableByWindowBackground = false;
        }
    }
    
    @objc func deviceMenuChanged(_ sender: NSMenuItem) {
        NSLog("Device Menu changed");
        if (sender.state == NSControl.StateValue.on) {
            // selected the active device, so nothing to do here
            return;
        }
        
        // set the checkbox on the currently selected device
        for menuItem: NSMenuItem in selectSourceMenu.submenu!.items {
            menuItem.state = NSControl.StateValue.off;
        }
        sender.state = NSControl.StateValue.on;
        
        let selectedDeviceIndex = sender.representedObject as! Int
        
        self.updateSourceResolutionsMenu(forDeviceAtIndex: selectedDeviceIndex)
        
        self.startCaptureWithVideoDevice(defaultDevice: selectedDeviceIndex)
    }
    
    var usb : QCUsbWatcher!
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        detectVideoDevices();
        updateSourceResolutionsMenu(forDeviceAtIndex:selectedDeviceIndex)
        startCaptureWithVideoDevice(defaultDevice: selectedDeviceIndex);
        usb = QCUsbWatcher()
        usb.delegate = self
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true;
    }
    
    
    // MARK - source resolutions
    func updateSourceResolutionsMenu(forDeviceAtIndex:Int) {
        
        let selectedDevice = self.devices[forDeviceAtIndex]
        let deviceMenu = NSMenu();
        
        var resIndex = 0;
        for res in selectedDevice.formats {
            
            let menuTitle = "\(res.formatDescription.dimensions.width)x\(res.formatDescription.dimensions.height)      [\(res.formatDescription.mediaType.description)/\(res.formatDescription.mediaSubType.description)]"
            
            let deviceMenuItem = NSMenuItem(title: menuTitle, action: #selector(sourceResolutionsMenuChanged), keyEquivalent: "")
            deviceMenuItem.target = self;
            deviceMenuItem.representedObject = resIndex;
            
            if(selectedDevice.activeFormat == res) {
                deviceMenuItem.state = NSControl.StateValue.on;
                self.selectedSourceResolution = resIndex
            }
            
            deviceMenu.addItem(deviceMenuItem);
            
            resIndex += 1;

            selectSourceResolution.submenu = deviceMenu;
        }
    }
        
    @objc func sourceResolutionsMenuChanged(_ sender: NSMenuItem)
    {
        if (sender.state == NSControl.StateValue.on) {
            return;
        }
        
        for menuItem: NSMenuItem in sender.parent!.submenu!.items {
            menuItem.state = NSControl.StateValue.off;
        }
        sender.state = NSControl.StateValue.on;
        
        self.selectedSourceResolution = sender.representedObject as! Int
        
        self.applyResolutionToDevice()
    }
    
    func applyResolutionToDevice()
    {
        let device = (self.captureSession.inputs[0] as! AVCaptureDeviceInput).device
        try! device.lockForConfiguration()
        
        let format = device.formats[selectedSourceResolution]
        device.activeFormat = format
        
        let maxFrameRateDuration = format.videoSupportedFrameRateRanges.reduce(CMTime.positiveInfinity) { (res, e) -> CMTime in
            CMTimeMinimum(res, e.minFrameDuration)
        }
        device.activeVideoMinFrameDuration = maxFrameRateDuration
        device.unlockForConfiguration()
    }
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSControlStateValue(_ input: Int) -> NSControl.StateValue {
    return NSControl.StateValue(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSWindowLevel(_ input: Int) -> NSWindow.Level {
    return NSWindow.Level(rawValue: input)
}
