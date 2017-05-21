import Cocoa
import Mocha
import MochaUI
import Hangouts
import ParrotServiceExtension

/* TODO: Re-enable link previews later when they're not terrible... */
/* TODO: Use the PlaceholderMessage for sending messages. */
/* TODO: When selecting text and typing a completion character, wrap the text. */

public struct EventStreamItemBundle {
    public let current: EventStreamItem
    public let previous: EventStreamItem?
    public let next: EventStreamItem?
}

/// This is instantly shown to the user when they send a message. It will
/// be updated automatically when the status of the message is known.
public struct PlaceholderMessage: Message {
    public var contentType: ContentType = .text
    public let sender: Person?
    public let timestamp: Date
    public let text: String
    public var failed: Bool = false
}

// states: nothing-loaded, loading, error, valid view

public class MessageListViewController: NSViewController, TextInputHost, ListViewDataDelegate, ListViewScrollbackDelegate {
    
    private lazy var moduleView: NSVisualEffectView = {
        self.view.prepare(NSVisualEffectView(frame: NSZeroRect)) { v in
            v.layerContentsRedrawPolicy = .onSetNeedsDisplay
            v.state = .active
            v.blendingMode = .withinWindow
            v.material = .appearanceBased
        }
    }()
    
    private lazy var listView: ListView = {
        self.view.prepare(ListView(frame: NSZeroRect)) { v in
            v.updateToBottom = true
            v.multipleSelect = false
            v.emptySelect = true
            v.delegate = self
        }
    }()
    
    private lazy var indicator: NSProgressIndicator = {
        self.view.prepare(NSProgressIndicator(frame: NSZeroRect)) { v in
            v.usesThreadedAnimation = true
            v.isIndeterminate = true
            v.style = .spinningStyle
        }
    }()
    
    private lazy var settingsPopover: NSPopover = {
        let popover = NSPopover()
        popover.contentViewController = self.settingsController
        popover.preferredEdge = .minY
        popover.relativePositioningView = self.view
        return popover
    }()
    
    private lazy var settingsController: ConversationDetailsViewController = {
        return ConversationDetailsViewController()
    }()
    
    private var typingHelper: TypingHelper? = nil
    private lazy var textInputCell: TextInputCell = {
        let t = TextInputCell()
        t.host = self
        _ = self.view.prepare(t.view) // prepare & attach
        return t
    }()
    
    private lazy var updateInterpolation: Interpolate = {
        let indicatorAnim = Interpolate(from: 0.0, to: 1.0, interpolator: EaseInOutInterpolator()) { [weak self] alpha in
            self?.listView.alphaValue = CGFloat(alpha)
            self?.indicator.alphaValue = CGFloat(1.0 - alpha)
        }
        indicatorAnim.add(at: 0.0) { [weak self] in
            DispatchQueue.main.async {
                self?.indicator.startAnimation(nil)
            }
        }
        indicatorAnim.add(at: 1.0) { [weak self] in
            DispatchQueue.main.async {
                self?.indicator.stopAnimation(nil)
            }
        }
        indicatorAnim.handlerRunPolicy = .always
        let scaleAnim = Interpolate(from: CGAffineTransform(scaleX: 1.5, y: 1.5), to: .identity, interpolator: EaseInOutInterpolator()) { [weak self] scale in
            self?.listView.layer!.setAffineTransform(scale)
        }
        let group = Interpolate.group(indicatorAnim, scaleAnim)
        return group
    }()
	
	// TODO: BEGONE!
    public var sendMessageHandler: (String, ParrotServiceExtension.Conversation) -> Void = {_ in}
    private var updateToken: Bool = false
    private var showingFocus: Bool = false
	
	var _previews = [String: [LinkPreviewType]]()
	var _note: NSObjectProtocol!
    
	private var dataSource: [EventStreamItem] = []
    public func numberOfItems(in: ListView) -> [UInt] {
        return [UInt(self.dataSource.count)]
    }
    
    public func object(in: ListView, at: ListView.Index) -> Any? {
        let row = Int(at.item)
        if let f = self.dataSource[row] as? Focus {
            return f
        }
        
        let prev = (row - 1) > 0 && (row - 1) < self.dataSource.count
        let next = (row + 1) < self.dataSource.count && (row + 1) < 0
        return EventStreamItemBundle(current: self.dataSource[row],
                                     previous: prev ? self.dataSource[row - 1] : nil,
                                     next: next ? self.dataSource[row + 1] : nil) as Any
    }
    
    public func itemClass(in: ListView, at: ListView.Index) -> NSView.Type {
        let row = Int(at.item)
        if let _ = self.dataSource[row] as? Focus {
            return WatermarkCell.self
        }
        return MessageCell.self
    }
    
    public func cellHeight(in view: ListView, at: ListView.Index) -> Double {
        let row = Int(at.item)
        if let _ = self.dataSource[row] as? Focus {
            return 32.0
        } else if let m = self.dataSource[row] as? Message {
            return MessageCell.measure(m.text, view.frame.width)
        }
        return 0.0
    }
    
    public func reachedEdge(in: ListView, edge: NSRectEdge) {
        func scrollback() {
            guard self.updateToken == false else { return }
            let first = self.dataSource[0] as? IChatMessageEvent
            log.debug("SCROLLBACK \(first?.event.eventId)")
            self.conversation?.getEvents(event_id: first?.event.eventId, max_events: 50) { events in
                let count = self.dataSource.count
                self.dataSource.insert(contentsOf: events.flatMap { $0 as? IChatMessageEvent }, at: 0)
                DispatchQueue.main.async {
                    self.listView.tableView.insertRows(at: IndexSet(integersIn: 0..<(self.dataSource.count - count)),
                                                       withAnimation: .slideDown)
                    self.updateToken = false
                }
            }
            self.updateToken = true
        }
        
        // Driver/filter here:
        switch edge {
        case .maxY: scrollback()
        default: break
        }
    }
    
    public override func loadView() {
        self.view = NSView()
        
        self.view.centerX == self.indicator.centerX
        self.view.centerY == self.indicator.centerY
        self.view.centerX == self.listView.centerX
        self.view.centerY == self.listView.centerY
        self.view.width == self.listView.width
        self.view.height == self.listView.height
        self.moduleView.left == self.view.left
        self.moduleView.right == self.view.right
        self.moduleView.bottom == self.view.bottom
        self.moduleView.height <= 250
        self.textInputCell.view.left == self.moduleView.left
        self.textInputCell.view.right == self.moduleView.right
        self.textInputCell.view.top == self.moduleView.top
        self.textInputCell.view.bottom == self.moduleView.bottom
    }
    
    public override func viewDidLoad() {
        /*
		self.window?.appearance = ParrotAppearance.interfaceStyle().appearance()
		self.window?.enableRealTitlebarVibrancy(.withinWindow)
		self.window?.titleVisibility = .hidden
        self.window?.contentView?.superview?.wantsLayer = true
        */
        
		ParrotAppearance.registerVibrancyStyleListener(observer: self, invokeImmediately: true) { style in
			guard let vev = self.view.window?.contentView as? NSVisualEffectView else { return }
			vev.state = style.visualEffectState()
			//guard let vev2 = self.drawer.contentView as? NSVisualEffectView else { return }
			//vev2.state = style.visualEffectState()
		}
        
        //let nib = NSNib(nibNamed: "MessageCell", bundle: nil)!
        //let nib2 = NSNib(nibNamed: "WatermarkCell", bundle: nil)!
        //self.listView.register(nib: nib, forClass: MessageCell.self)
        //self.listView.register(nib: nib2, forClass: WatermarkCell.self)
		
        self.token = AutoSubscription(kind: Notification.Name("com.avaidyam.Parrot.UpdateColors")) { _ in
            self.setBackground()
        }
        setBackground()
        if let s = self.view.window?.standardWindowButton(.closeButton)?.superview as? NSVisualEffectView {
            s.state = .active
        }
        
        self.typingHelper = TypingHelper {
            switch $0 {
            case .started:
                self.conversation?.setTyping(typing: TypingType.Started)
            case .paused:
                self.conversation?.setTyping(typing: TypingType.Paused)
            case .stopped:
                self.conversation?.setTyping(typing: TypingType.Stopped)
            }
        }
    }
    
    public override func viewWillAppear() {
        
        // Center by default, but load a saved frame if available, and set the autosave.
        self.view.window?.center()
        self.view.window?.setFrameUsingName("Messages")
        self.view.window?.setFrameAutosaveName("Messages")
        
        
        self.indicator.startAnimation(nil)
        self.listView.alphaValue = 0.0
        //self.animatedUpdate(true)
        self.listView.insets = EdgeInsets(top: 36.0, left: 0, bottom: 40.0, right: 0)
        
        if self.conversation != nil {
            self.settingsController.conversation = self.conversation
        }
        
        /*
         if self.window?.isKeyWindow ?? false {
         self.windowDidBecomeKey(Notification(name: "" as Notification.Name))
         }
         */
        self.tokenOcclusion = AutoSubscription(from: self.view.window!, kind: .NSWindowDidChangeOcclusionState) { [weak self] _ in
            
            // NSWindowOcclusionState: 8194 is Visible, 8192 is Occluded
            self?.conversation?.setFocus((self?.view.window?.occlusionState.rawValue ?? 0) == 8194)
        }
        self.conversation?.setFocus((self.view.window?.occlusionState.rawValue ?? 0) == 8194)
        
        // Set up dark/light notifications.
        ParrotAppearance.registerInterfaceStyleListener(observer: self, invokeImmediately: true) { interface in
            self.view.window?.appearance = interface.appearance()
            self.settingsPopover.appearance = interface.appearance()
        }
        
        /*
         runSelectionPanel(for: self.window!, fileTypes: ["mp3", "caf", "aiff", "wav"]) {
         log.debug("received \($0)")
         }*/
    }
    
    public override func viewWillDisappear() {
        self.tokenOcclusion = nil
    }
    
    private var token: Any? = nil
    private var tokenOcclusion: Any? = nil
    public func setBackground() {
        if  let dat = Settings["Parrot.ConversationBackground"] as? NSData,
            let img = NSImage(data: dat as Data) {
            self.moduleView.superview?.layer?.contents = img
        } else {
            self.moduleView.superview?.layer?.contents = nil
        }
    }
    deinit {
        self.token = nil
        self.tokenOcclusion = nil
    }
    
    @IBAction func colorChanged(_ sender: AnyObject?) {
        /*if let well = sender as? NSColorWell, well.identifier == "MyBubbleColor" {
            
        } else if let well = sender as? NSColorWell, well.identifier == "TheirBubbleColor" {
            
        } else if let img = sender as? NSImageView, img.identifier == "BackgroundImage" {
            
        }*/
        
        Subscription.Event(name: Notification.Name(rawValue: "com.avaidyam.Parrot.UpdateColors"), object: self).post()
    }
    
    /*@IBAction public func colorWellSelected(_ sender: AnyObject?) {
        guard let sender = sender as? NSColorWell else { return }
        publish(Notification(name: Notification.Name("_ColorChanged")))
    }*/
	
    
    /*
    public func windowShouldClose(_ sender: AnyObject) -> Bool {
        guard let w = self.window else { return false }
        
        let old_rect = w.frame
        var rect = w.frame
        rect.origin.y = -(rect.height)
        
        let scale = Interpolate(from: 1.0, to: 0.5, interpolator: EaseInOutInterpolator()) { scale in
            w.scale(to: scale, by: CGPoint(x: 0.5, y: 0.5))
        }
        let alpha = Interpolate(from: 1.0, to: 0.0, interpolator: EaseInInterpolator()) { alpha in
            w.alphaValue = alpha
        }
        let frame = Interpolate(from: old_rect, to: rect, interpolator: EaseInInterpolator()) { frame in
            w.setFrame(frame, display: false)
        }
        
        let group = Interpolate.group(scale, alpha, frame)
        group.add {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
                w.setFrame(old_rect, display: false)
                w.alphaValue = 1.0
                w.scale()
                w.close()
            }
        }
        
        group.animate(duration: 0.25)
        return false
    }
    */
    
	
	public func windowWillClose(_ notification: Notification) {
		ParrotAppearance.unregisterInterfaceStyleListener(observer: self)
	}
	
	var conversation: IConversation? {
		didSet {
			//DispatchQueue.main.sync {
				self.title = self.conversation?.name ?? ""
				self.view.window?.setFrameAutosaveName("\(self.conversation?.identifier)")
			//}
			
			/*
			if let oldConversation = oldValue {
				oldConversation.delegate = nil
			}
			self.conversation?.delegate = self
			*/
			
			self.conversation?.getEvents(event_id: nil, max_events: 50) { events in
				for chat in (events.flatMap { $0 as? IChatMessageEvent }) {
					self.dataSource.append(chat)
					//linkQ.async {
						/*
						let d = try! NSDataDetector(types: TextCheckingResult.CheckingType.link.rawValue)
						let t = chat.text
						d.enumerateMatches(in: t, options: RegularExpression.MatchingOptions(rawValue: UInt(0)),
						                   range: NSMakeRange(0, t.unicodeScalars.count)) { (res, flag, stop) in
							let key = res!.url!.absoluteString!
							guard let meta = try? _getLinkCached(key) else { return }
							
							if let arr = self._previews[chat.id] {
								self._previews[chat.id] = arr + [meta]
							} else {
								self._previews[chat.id] = [meta]
							}
						}
						*/
					//}
				}
                
                let group = self.updateInterpolation
                DispatchQueue.main.async {
                    self.listView.update(animated: false) {
                        group.animate(duration: 0.5)
                        //self.window?.makeFirstResponder(self.entryView)
                    }
                }
			}
            
            self.settingsController.conversation = self.conversation
			
			/*
			self.conversation!.messages.map {
				if let prev = self._previews[($0 as! IChatMessageEvent).id] {
					let ret = [$0 as Any] + prev.map { $0 as Any }
					return ret
				} else { return [$0 as Any] }
			}.reduce([], combine: +)
			*/
			//self.listView?.update()
		}
	}
	
	public func conversation(_ conversation: IConversation, didReceiveEvent event: IEvent) {
		guard let e = event as? IChatMessageEvent else { return }
        DispatchQueue.main.async {
            self.dataSource.append(e)
            log.debug("section 0: \(self.dataSource.count)")
            self.listView.insert(at: [(section: 0, item: UInt(self.dataSource.count - 1))])
            //self.listView.scroll(toRow: self.dataSource.count - 1)
		}
    }
    
    // FIXME: Watermark!!
    private var lastWatermarkIdx = -1
    public func watermarkEvent(_ focus: Focus) {
        guard let s = focus.sender, !s.me else { return }
        DispatchQueue.main.async {
            let oldWatermarkIdx = self.lastWatermarkIdx
            if oldWatermarkIdx > 0 {
                self.dataSource.remove(at: oldWatermarkIdx)
            }
            self.dataSource.append(focus)
            self.lastWatermarkIdx = self.dataSource.count - 1
            
            if oldWatermarkIdx > 0 && self.lastWatermarkIdx > 0 {
                log.debug("MOVE WATERMARK")
                //self.listView.remove(at: [(section: 0, item: UInt(oldWatermarkIdx))])
                //self.listView.insert(at: [(section: 0, item: UInt(self.lastWatermarkIdx))])
                self.listView.move(from: [(section: 0, item: UInt(oldWatermarkIdx))],
                                   to: [(section: 0, item: UInt(self.lastWatermarkIdx))])
            } else if self.lastWatermarkIdx > 0 {
                log.debug("ADD WATERMARK")
                self.listView.insert(at: [(section: 0, item: UInt(self.lastWatermarkIdx))])
            }
        }
    }
    
    public func focusModeChanged(_ focus: Focus) {
        guard let s = focus.sender, !s.me else { return }
        DispatchQueue.main.async {
            switch focus.mode {
            case .typing: fallthrough
            case .enteredText:
                log.debug("typing start")
                guard !self.showingFocus else { return }
                self.showingFocus = true
                //self.listView.insert(at: [(section: 1, item: 0)])
                //self.listView.scroll(toRow: self.dataSource.count)
            case .here: fallthrough
            case .away:
                log.debug("typing stop")
                guard self.showingFocus else { return }
                self.showingFocus = false
                //self.listView.remove(at: [(section: 1, item: 0)])
            }
        }
    }
    
	@IBAction public func toggleMute(_ sender: AnyObject?) {
		guard let button = sender as? NSButton else { return }
		
		// Swap button images on toggle.
		let altI = button.alternateImage
		button.alternateImage = button.image
		button.image = altI
		
		// Swap button titles on toggle.
		let altT = button.alternateTitle
		button.alternateTitle = button.title
		button.title = altT
		
		// Mute or unmute the conversation.
		var cv = self.conversation as! ParrotServiceExtension.Conversation
		cv.muted = (button.state == NSOnState ? true : false)
	}
	
    // MARK: Window notifications
	
	public func windowDidBecomeKey(_ notification: Notification) {
        if let conversation = conversation {
			NSUserNotification.notifications()
				.filter { $0.identifier == conversation.id }
				.forEach { $0.remove() }
        }
		
        // Delay here to ensure that small context switches don't send focus messages.
		DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            if let window = self.view.window, window.isKeyWindow {
				self.conversation?.setFocus(true) // set it here too just in case.
            }
			self.conversation?.updateReadTimestamp()
			
			// Get current states
			for state in self.conversation!.readStates {
				let person = self.conversation!.client.directory.people[state.participantId!.gaiaId!]!
				let timestamp = Date.from(UTC: Double(state.latestReadTimestamp!))
				//log.debug("conv => { conv: \(self.conversation!.conversation) }")
				log.debug("state => { person: \(person.nameComponents), timestamp: \(timestamp) }")
			}
        }
    }
	
    /*
	// Bind the drawer state to the button that toggles it.
	public func drawerWillOpen(_ notification: Notification) {
		self.drawerButton.state = NSOnState
		self.drawer.drawerWindow?.animator().alphaValue = 1.0
        
        publish(on: .system, Notification(name: Notification.Name("com.avaidyam.Parrot.Service.getConversations")))
	}
	public func drawerWillClose(_ notification: Notification) {
		self.drawerButton.state = NSOffState
		self.drawer.drawerWindow?.animator().alphaValue = 0.0
	}
    */
    
    public var image: NSImage? {
        if let me = self.conversation?.client.userList.me {
            return fetchImage(user: me as! User, monogram: true)
        }
        return nil
    }
    
    public func resized(to: Double) {
        self.listView.insets = EdgeInsets(top: 36.0, left: 0, bottom: CGFloat(to), right: 0)
        self.moduleView.needsLayout = true
        self.moduleView.layoutSubtreeIfNeeded()
    }
    
    public func typing() {
        self.typingHelper?.typing()
    }
    
    public func send(message: String) {
        self.sendMessageHandler(message, self.conversation!)
    }
}
