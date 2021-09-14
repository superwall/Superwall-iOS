//
//  File.swift
//  
//
//  Created by Jake Mor on 9/13/21.
//

import UIKit
import Foundation
import StoreKit

internal class SWConsoleViewController: UIViewController {
    
    var products: [SKProduct] = []
    var tableViewCellData = [(String, String)]()
    
    lazy var productPicker: UIPickerView = {
        let picker: UIPickerView = UIPickerView()
        picker.delegate = self
        picker.dataSource = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.tintColor = PrimaryColor
        picker.backgroundColor = LightBackgroundColor
        return picker
    }()
    
    lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundView = nil
        tv.backgroundColor = .clear
        tv.delegate = self
        tv.dataSource = self
        tv.allowsSelection = false
        tv.allowsMultipleSelection = false
        return tv
        
    }()
    
    init(products: [SKProduct]) {
        super.init(nibName: nil, bundle: nil)
        self.products = products
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DarkBackgroundColor
        title = "Paywall Debugger"
        view.addSubview(tableView)
        view.addSubview(productPicker)
        
        NSLayoutConstraint.activate([
            productPicker.widthAnchor.constraint(equalTo: view.widthAnchor),
            productPicker.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.618),
            productPicker.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            productPicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            tableView.widthAnchor.constraint(equalTo: view.widthAnchor),
            tableView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: productPicker.topAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        productPicker.reloadAllComponents()
        reloadTableView()
    }
    
    func reloadTableView() {
        let index = productPicker.selectedRow(inComponent: 0)
        
        tableViewCellData = []
        let p = products[index]
        for i in p.eventData {
            tableViewCellData.append(i)
        }
        
        tableViewCellData.sort { first, second in
            let (a0, _) = first
            let (a1, _) = second
            return a0 < a1
        }
        
        tableView.reloadData()
    }
    
}

extension SWConsoleViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    internal func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    internal func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        products.count
    }
    
    internal func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let attributedString = NSAttributedString(string: products[row].productIdentifier, attributes: [NSAttributedString.Key.foregroundColor : PrimaryColor])
        return attributedString
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        reloadTableView()
    }
}

extension SWConsoleViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableViewCellData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        
        let (key, value) = tableViewCellData[indexPath.row]
        cell.textLabel?.text = value
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.text = "{{ \(key) }}"
        cell.detailTextLabel?.textColor = UIColor.white.withAlphaComponent(0.618)
        cell.backgroundView = nil
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        
        
        
        return cell
    }
    
    
    
    
}
