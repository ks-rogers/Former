//
//  MultiSelectorPickerRowFormer.swift
//  Former
//
//  Created by 辻林大揮 on 2019/01/20.
//  Copyright © 2019 Ryo Aoyama. All rights reserved.
//

import UIKit

public protocol MultiSelectorPickerFormableRow: FormableRow {
    
    var selectorPickerView: UIPickerView? { get set } // Not need to set UIPickerView
    var selectorAccessoryView: UIView? { get set } // Not need to set UIView instance.
    
    
    func formTitleLabel() -> UILabel?
    func formDisplayLabel() -> UILabel?
    
    func formDefaultSelectedRows() -> [Int]
    func formDefaultDisplayLabelText() -> String?
}

// TODO:- enable displayTitle of SelectorPickerItem
open class MultiSelectorPickerRowFormer<T: UITableViewCell, S>
: BaseRowFormer<T>, Formable, UpdatableSelectorForm where T: MultiSelectorPickerFormableRow {
    
    // MARK: Public
    
    override open var canBecomeEditing: Bool {
        return enabled
    }
    
    open var pickerItems: [[SelectorPickerItem<S>]] = [[]] {
        didSet {
            if pickerItems.count != selectedRow.count {
                selectedRow = (0..<pickerItems.count).map { _ in nil }
            }
        }
    }
    open var delimiter: String = ","
    open var selectedRow: [Int?] = []
    open var inputAccessoryView: UIView?
    open var titleDisabledColor: UIColor? = .lightGray
    open var displayDisabledColor: UIColor? = .lightGray
    open var titleEditingColor: UIColor?
    open var displayEditingColor: UIColor?
    
    public private(set) final lazy var selectorView: UIPickerView = { [unowned self] in
        let picker = UIPickerView()
        picker.delegate = self.observer
        picker.dataSource = self.observer
        return picker
        }()
    
    public required init(instantiateType: Former.InstantiateType = .Class, cellSetup: ((T) -> Void)? = nil) {
        super.init(instantiateType: instantiateType, cellSetup: cellSetup)
    }
    
    @discardableResult
    public final func onValueChanged(_ handler: @escaping (([SelectorPickerItem<S>?]) -> Void)) -> Self {
        onValueChanged = handler
        return self
    }
    
    open override func update() {
        super.update()
        
        let titleLabel = cell.formTitleLabel()
        let displayLabel = cell.formDisplayLabel()
        if pickerItems.isEmpty {
            displayLabel?.text = ""
        } else if !selectedRow.compactMap({ $0 }).isEmpty {
            selectedRow
                .enumerated().forEach { selectorView.selectRow($0.element ?? 0, inComponent: $0.offset, animated: false) }
            displayLabel?.text = selectedRow.enumerated()
                .map { $0.element == nil ? "" : pickerItems[$0.element!][$0.offset].title }
                .joined(separator: delimiter)
        } else if !cell.formDefaultSelectedRows().isEmpty {
            self.selectedRow = cell.formDefaultSelectedRows()
            cell.formDefaultSelectedRows()
                .enumerated().forEach { selectorView.selectRow($0.element, inComponent: $0.offset, animated: false) }
            displayLabel?.text = cell.formDefaultSelectedRows().enumerated()
                .map { pickerItems[$0.element][$0.offset].title }
                .joined(separator: delimiter)
        } else {
            if let defaultText = cell.formDefaultDisplayLabelText() {
                displayLabel?.text = defaultText
            }
        }
        cell.selectorPickerView = selectorView
        cell.selectorAccessoryView = inputAccessoryView
        
        
        
        if enabled {
            if isEditing {
                if titleColor == nil { titleColor = titleLabel?.textColor ?? .black }
                _ = titleEditingColor.map { titleLabel?.textColor = $0 }
            } else {
                _ = titleColor.map { titleLabel?.textColor = $0 }
                _ = displayTextColor.map { displayLabel?.textColor = $0 }
                titleColor = nil
                displayTextColor = nil
            }
        } else {
            if titleColor == nil { titleColor = titleLabel?.textColor ?? .black }
            if displayTextColor == nil { displayTextColor = displayLabel?.textColor ?? .black }
            titleLabel?.textColor = titleDisabledColor
            displayLabel?.textColor = displayDisabledColor
        }
    }
    
    open override func cellSelected(indexPath: IndexPath) {
        former?.deselect(animated: true)
    }
    
    public func editingDidBegin() {
        if enabled {
            let titleLabel = cell.formTitleLabel()
            let displayLabel = cell.formDisplayLabel()
            
            if titleColor == nil { titleColor = titleLabel?.textColor ?? .black }
            _ = titleEditingColor.map { titleLabel?.textColor = $0 }
            
            if !selectedRow.isEmpty {
                if displayTextColor == nil { displayTextColor = displayLabel?.textColor ?? .black }
                _ = displayEditingColor.map { displayLabel?.textColor = $0 }
            }
            isEditing = true
        }
    }
    
    public func editingDidEnd() {
        isEditing = false
        let titleLabel = cell.formTitleLabel()
        let displayLabel = cell.formDisplayLabel()
        
        if !selectedRow.isEmpty && enabled {
            _ = titleColor.map { titleLabel?.textColor = $0 }
            titleColor = nil
            _ = displayTextColor.map { displayLabel?.textColor = $0 }
            displayTextColor = nil
        } else {
            if titleColor == nil { titleColor = titleLabel?.textColor ?? .black }
            if displayTextColor == nil { displayTextColor = displayLabel?.textColor ?? .black }
            titleLabel?.textColor = titleDisabledColor
            displayLabel?.textColor = displayDisabledColor
        }
    }
    
    // MARK: Private
    
    fileprivate final var onValueChanged: (([SelectorPickerItem<S>?]) -> Void)?
    fileprivate final var titleColor: UIColor?
    fileprivate final var displayTextColor: UIColor?
    fileprivate final lazy var observer: Observer<T, S> = Observer<T, S>(selectorPickerRowFormer: self)
}

private class Observer<T: UITableViewCell, S>
: NSObject, UIPickerViewDelegate, UIPickerViewDataSource where T: MultiSelectorPickerFormableRow {
    
    fileprivate weak var selectorPickerRowFormer: MultiSelectorPickerRowFormer<T, S>?
    
    init(selectorPickerRowFormer: MultiSelectorPickerRowFormer<T, S>?) {
        self.selectorPickerRowFormer = selectorPickerRowFormer
    }
    
    fileprivate dynamic func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let selectorPickerRowFormer = selectorPickerRowFormer else { return }
        if selectorPickerRowFormer.enabled {
            selectorPickerRowFormer.selectedRow[component] = row
            
            let pickerItems = selectorPickerRowFormer.pickerItems.enumerated().map {
                selectorPickerRowFormer.selectedRow[$0.offset] == nil ? nil : $0.element[selectorPickerRowFormer.selectedRow[$0.offset]!]
            }
            
            let cell = selectorPickerRowFormer.cell
            let displayLabel = cell.formDisplayLabel()
            displayLabel?.text = pickerItems.map { $0?.title ?? "" }.joined(separator: selectorPickerRowFormer.delimiter)
            selectorPickerRowFormer.onValueChanged?(pickerItems)
        }
    }
    
    fileprivate dynamic func numberOfComponents(in pickerView: UIPickerView) -> Int {
        guard let selectorPickerRowFormer = selectorPickerRowFormer else { return 0 }
        return selectorPickerRowFormer.pickerItems.count
    }
    
    fileprivate dynamic func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        guard let selectorPickerRowFormer = selectorPickerRowFormer else { return 0 }
        return selectorPickerRowFormer.pickerItems[component].count
    }
    
    fileprivate dynamic func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard let selectorPickerRowFormer = selectorPickerRowFormer else { return nil }
        return selectorPickerRowFormer.pickerItems[component][row].title
    }
}
