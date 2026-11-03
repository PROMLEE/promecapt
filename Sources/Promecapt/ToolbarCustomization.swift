import AppKit

/// Reorder and hide tools with native drag-and-drop or keyboard-accessible move buttons.
final class ToolbarCustomizationView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let table = NSTableView()
    private var items = ToolbarItem.order
    private var selectedItem: ToolbarItem = .region
    private let up = NSButton(title: "", target: nil, action: nil)
    private let down = NSButton(title: "", target: nil, action: nil)
    private var observer: NSObjectProtocol?
    private static let dragType = NSPasteboard.PasteboardType("com.promlee.promecapt.toolbar-item")

    override init(frame: NSRect) {
        super.init(frame: frame)
        let visible = NSTableColumn(identifier: .init("visible")); visible.width = 34; visible.minWidth = 34; visible.maxWidth = 34
        let name = NSTableColumn(identifier: .init("name")); name.width = 460
        table.addTableColumn(visible); table.addTableColumn(name)
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.headerView = nil; table.rowHeight = 24
        table.allowsMultipleSelection = false
        table.dataSource = self; table.delegate = self
        table.setAccessibilityLabel(L("도구 표시 및 순서"))
        table.registerForDraggedTypes([Self.dragType])
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        let scroll = NSScrollView()
        scroll.documentView = table; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        up.title = L("위로"); up.target = self; up.action = #selector(raiseTool)
        down.title = L("아래로"); down.target = self; down.action = #selector(lowerTool)
        up.setAccessibilityLabel(L("선택한 도구 앞으로"))
        down.setAccessibilityLabel(L("선택한 도구 뒤로"))
        let reset = NSButton(title: L("기본 도구 복원"), target: self, action: #selector(resetTools))
        for button in [up, down, reset] { button.bezelStyle = .regularSquare; button.controlSize = .small }
        let actions = NSStackView(views: [up, down, reset]); actions.spacing = 8
        actions.translatesAutoresizingMaskIntoConstraints = false; addSubview(actions)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor), scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor), scroll.bottomAnchor.constraint(equalTo: actions.topAnchor, constant: -8),
            actions.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6), actions.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            heightAnchor.constraint(equalToConstant: 260), widthAnchor.constraint(equalToConstant: 534)])
        observer = NotificationCenter.default.addObserver(forName: ToolbarItem.changed, object: nil, queue: .main) { [weak self] _ in self?.reload() }
        reload()
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    private func reload() {
        items = ToolbarItem.order
        table.reloadData()
        table.selectRowIndexes(IndexSet(integer: items.firstIndex(of: selectedItem) ?? 0), byExtendingSelection: false)
        updateButtons()
    }
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        if tableColumn?.identifier.rawValue == "visible" {
            let check = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleItem(_:)))
            check.tag = row; check.state = item.isVisible ? .on : .off
            check.setAccessibilityLabel(item.title)
            return check
        }
        return ToolbarTextField(labelWithString: item.title)
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        if items.indices.contains(table.selectedRow) { selectedItem = items[table.selectedRow] }
        updateButtons()
    }
    private func updateButtons() {
        up.isEnabled = table.selectedRow > 0
        down.isEnabled = table.selectedRow >= 0 && table.selectedRow < items.count - 1
    }
    @objc private func toggleItem(_ sender: NSButton) {
        guard items.indices.contains(sender.tag) else { return }
        items[sender.tag].setVisible(sender.state == .on)
    }
    @objc private func raiseTool() { moveSelection(by: -1) }
    @objc private func lowerTool() { moveSelection(by: 1) }
    func moveSelection(by delta: Int) {
        guard let index = items.firstIndex(of: selectedItem), items.indices.contains(index + delta) else { return }
        ToolbarItem.move(selectedItem, to: index + delta)
        table.scrollRowToVisible(table.selectedRow)
    }
    @objc private func resetTools() { ToolbarItem.reset() }
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let value = NSPasteboardItem(); value.setString(items[row].rawValue, forType: Self.dragType); return value
    }
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation {
        operation == .above && (info.draggingSource as? NSTableView) === tableView ? .move : []
    }
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation operation: NSTableView.DropOperation) -> Bool {
        guard operation == .above, (info.draggingSource as? NSTableView) === tableView,
              let raw = info.draggingPasteboard.string(forType: Self.dragType), let item = ToolbarItem(rawValue: raw),
              let source = items.firstIndex(of: item) else { return false }
        selectedItem = item
        ToolbarItem.move(item, to: row > source ? row - 1 : row)
        return true
    }
}
