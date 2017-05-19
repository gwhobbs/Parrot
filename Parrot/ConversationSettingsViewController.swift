import Cocoa
import MochaUI
import ParrotServiceExtension

/* TODO: Requires Observables & EventBus built on NotificationCenter...? */

public class ConversationDetailsViewController: NSViewController {
    
    // Internally used to identify different controls on action sent.
    private enum Tags: Int {
        case mute, block, archive, delete
    }
    
    public var conversation: Conversation? {
        get { return representedObject as? Conversation }
        set { self.representedObject = newValue }
    }
    
    private lazy var muteButton: NSButton = {
        let b = NSButton(title: "Mute", image: #imageLiteral(resourceName: "NSImageNameVolumeMute"), target: self,
                         action: #selector(ConversationDetailsViewController.buttonAction(_:)))
        
        return NSView.prepare(b) { (v: NSButton) in
            v.alternateTitle = "Unmute"
            v.alternateImage = #imageLiteral(resourceName: "NSImageNameVolumeMute")
            v.bezelStyle = .texturedRounded
            
            v.setButtonType(.pushOnPushOff)
            v.state = 0
            v.tag = Tags.mute.rawValue
        }
    }()
    
    private lazy var blockButton: NSButton = {
        let b = NSButton(title: "Block", image: #imageLiteral(resourceName: "NSImageNameVolumeMute"), target: self,
                         action: #selector(ConversationDetailsViewController.buttonAction(_:)))
        return NSView.prepare(b) { (v: NSButton) in
            v.alternateTitle = "Unblock"
            v.alternateImage = #imageLiteral(resourceName: "NSImageNameVolumeMute")
            v.bezelStyle = .texturedRounded
            
            v.setButtonType(.pushOnPushOff)
            v.state = 0
            v.tag = Tags.block.rawValue
        }
    }()
    
    private lazy var archiveButton: NSButton = {
        let b = NSButton(title: "Archive", image: #imageLiteral(resourceName: "NSImageNameVolumeMute"), target: self,
                         action: #selector(ConversationDetailsViewController.buttonAction(_:)))
        return NSView.prepare(b) { (v: NSButton) in
            v.alternateTitle = "Unarchive"
            v.alternateImage = #imageLiteral(resourceName: "NSImageNameVolumeMute")
            v.bezelStyle = .texturedRounded
            
            v.setButtonType(.pushOnPushOff)
            v.state = 0
            v.tag = Tags.archive.rawValue
        }
    }()
    
    private lazy var deleteButton: NSButton = {
        let b = NSButton(title: "Delete", image: #imageLiteral(resourceName: "NSImageNameVolumeMute"), target: self,
                         action: #selector(ConversationDetailsViewController.buttonAction(_:)))
        return NSView.prepare(b) { (v: NSButton) in
            v.alternateTitle = "Undelete"
            v.alternateImage = #imageLiteral(resourceName: "NSImageNameVolumeMute")
            v.bezelStyle = .texturedRounded
            
            v.setButtonType(.pushOnPushOff)
            v.state = 0
            v.tag = Tags.delete.rawValue
        }
    }()
    
    public override func loadView() {
        let stack: NSStackView = NSView.prepare(NSStackView(views: [
            self.muteButton,
            self.blockButton,
            self.archiveButton,
            self.deleteButton
        ]))
        
        stack.edgeInsets = EdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
        stack.spacing = 8.0
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.distribution = .fill
        
        stack.width == 128.0
        self.view = stack
    }
    
    @objc
    private func buttonAction(_ sender: Any?) {
        guard   let _ = self.conversation,
                let button = sender as? NSButton,
                let tag = Tags(rawValue: button.tag)
        else { return }
        
        switch tag {
        case .mute:
            print("MUTE TOGGLE")
        case .block:
            print("BLOCK TOGGLE")
        case .archive:
            print("ARCHIVE TOGGLE")
        case .delete:
            print("DELETE TOGGLE")
        }
    }
    
    // TODO:
    //
    // notification: ?
    // sound: ?
    // vibrate: ?
    //
    // outcolor: com.avaidyam.Parrot.ConversationOutgoingColor
    // incolor: com.avaidyam.Parrot.ConversationIncomingColor
    // bgimage: Parrot.ConversationBackground
}