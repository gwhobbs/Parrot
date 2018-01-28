import AppKit
import Mocha

@objc public protocol PreferencePane: NSObjectProtocol {
    var image: NSImage? { get }
    var title: String? { get }
}

public class PreferencesViewController: NSTabViewController {
    private var _sizes = [String : NSSize]()
    
    public override func loadView() {
        super.loadView()
        self.tabStyle = .toolbar
        self.transitionOptions = [.allowUserInteraction, .crossfade]
    }
    
    public override func viewWillAppear() {
        self.view.window?.center()
    }
    
    public override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, willSelect: tabViewItem)
        self._sizes[tabViewItem!.label] = tabViewItem!.view!.frame.size
    }
    
    public override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        DispatchQueue.main.async {
            if let window = self.view.window {
                let size = (self._sizes[tabViewItem!.label])!
                window.setFrame(self.normalizedFrame(for: window, from: size),
                                display: false, animate: true)
            }
        }
    }
    
    public override func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        let a = super.toolbarAllowedItemIdentifiers(toolbar)
        return [.flexibleSpace] + a + [.flexibleSpace]
    }
    
    public override func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        let a = super.toolbarDefaultItemIdentifiers(toolbar)
        return [.flexibleSpace] + a + [.flexibleSpace]
    }
    
    public override func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return super.toolbarSelectableItemIdentifiers(toolbar)
    }
    
    private func normalizedFrame(for window: NSWindow, from size: NSSize) -> NSRect {
        let contentFrame = window.frameRect(forContentRect: NSMakeRect(0.0, 0.0, size.width, size.height))
        var frame = window.frame
        frame.origin.y = frame.origin.y + (frame.size.height - contentFrame.size.height)
        frame.size.height = contentFrame.size.height
        frame.size.width = contentFrame.size.width
        return frame
    }
    
    /// Use this to append preference panes.
    public func add<T: NSViewController & PreferencePane>(pane p: T) {
        let tab = NSTabViewItem(viewController: p)
        tab.image = p.image
        self.addTabViewItem(tab)
    }
}
