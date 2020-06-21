//
//  HealthKitConfigViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/14/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit
import HealthKit
import UserNotifications
import SwiftyJSON

class HealthKitConfigViewController: UIViewController {
    
    var tableView = UITableView()
    var goals : [JSONGoal] = []
    let cellReuseIdentifier = "healthKitConfigTableViewCell"
    var syncRemindersSwitch = UISwitch()
    let margin = 12
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        self.title = "Health app integration"
        let backItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        self.navigationItem.backBarButtonItem = backItem
        
        let syncRemindersLabel = BSLabel()
        self.view.addSubview(syncRemindersLabel)
        syncRemindersLabel.text = "Sync Health data reminders"
        if #available(iOS 13.0, *) {
            syncRemindersLabel.backgroundColor = .secondarySystemBackground
        } else {
            syncRemindersLabel.backgroundColor = .clear
        }
        syncRemindersLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.margin)
            make.right.equalTo(0)
            make.top.equalTo(self.topLayoutGuide.snp.bottom)
            make.height.equalTo(Constants.defaultTextFieldHeight)
        }
        
        self.view.addSubview(self.syncRemindersSwitch)
        self.syncRemindersSwitch.isOn = UserDefaults.standard.bool(forKey: Constants.healthSyncRemindersPreferenceKey)
        self.syncRemindersSwitch.addTarget(self, action: #selector(self.syncRemindersSwitchValueChanged), for: .valueChanged)
        self.syncRemindersSwitch.snp.makeConstraints { (make) in
            make.centerY.equalTo(syncRemindersLabel)
            make.right.equalTo(-self.margin)
        }
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(syncRemindersLabel.snp.bottom)
            make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
        }
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.backgroundColor = UIColor.clear
        self.tableView.register(HealthKitConfigTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        self.goals = CurrentUserManager.sharedManager.goals
        self.sortGoals()
    }
    
    func sortGoals() {
        self.goals.sort { $0.slug < $1.slug }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.fetchGoals()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func syncRemindersSwitchValueChanged() {
        UserDefaults.standard.set(self.syncRemindersSwitch.isOn, forKey: Constants.healthSyncRemindersPreferenceKey)
        if self.syncRemindersSwitch.isOn == false {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    func fetchGoals() {
        MBProgressHUD.showAdded(to: self.view, animated: true)
        CurrentUserManager.sharedManager.fetchGoals(success: { (goals) in
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            self.goals = goals
            self.sortGoals()
            self.tableView.reloadData()
        }) { (error) in
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            if UIApplication.shared.applicationState == .active {
                if let errorString = error?.localizedDescription {
                    let alert = UIAlertController(title: "Error fetching goals", message: errorString, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
            self.tableView.reloadData()
        }
    }
    
    @objc func handleMetricRemovedNotification(notification: Notification) {
        self.fetchGoals()
    }
}

extension HealthKitConfigViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3 // manual, auto but apple (editable), auto
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { // first section, modifiable
            return self.manualSourced.count
        } else if section == 1 {
            return self.autoSourcedModifiable.count
        } else {
            return self.autoSourcedUnmodifiable.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as! HealthKitConfigTableViewCell!
        
        let goal = self.goalAt(indexPath)
        
        cell!.goal = goal
        
        return cell!
    }
    
    private func goalAt(_ indexPath: IndexPath) -> JSONGoal {
        if indexPath.section == 0 {
            return self.manualSourced[indexPath.row]
        } else if indexPath.section == 1 {
            return self.autoSourcedModifiable[indexPath.row]
        } else {
            return self.autoSourcedUnmodifiable[indexPath.row]
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let goal = self.goalAt(indexPath)

        if goal.autodata.count == 0 {
            let chooseHKMetricViewController = ChooseHKMetricViewController()
            chooseHKMetricViewController.goal = goal
            self.navigationController?.pushViewController(chooseHKMetricViewController, animated: true)
        } else if goal.autodata == "apple" {
            let controller = RemoveHKMetricViewController()
            controller.goal = goal
            self.navigationController?.pushViewController(controller, animated: true)
        } else {
            let alert: UIAlertController = {
                let alert = UIAlertController(title: "Auto-data Goal", message: "At the moment we don't have a way for you to swap data source here yourself for auto-data goals", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                return alert
            }()
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension HealthKitConfigViewController {
    var autoSourced: [JSONGoal] {
        return self.goals.filter { $0.isDataProvidedAutomatically }
    }
    
    var manualSourced: [JSONGoal] {
        return self.goals.filter { !$0.isDataProvidedAutomatically }
    }
    
    var autoSourcedModifiable: [JSONGoal] {
        return self.autoSourced.filter { goal -> Bool in
            return "Apple".localizedCaseInsensitiveCompare(goal.autodata) == ComparisonResult.orderedSame
        }
    }
    
    var autoSourcedUnmodifiable: [JSONGoal] {
        return self.autoSourced.filter { goal -> Bool in
            return "Apple".localizedCaseInsensitiveCompare(goal.autodata) != ComparisonResult.orderedSame
        }
    }
}
