//**************************************************************************************
//
//    Filename: MainTableViewController.swift
//     Project: HealthKitTest
//
//      Author: Robert Kerr 
//   Copyright: Copyright © 2016 Marvel Apps, LLC. All rights reserved.
//
// Description: This is just a test app to validate the approach to reading/writing
//              Healthkit sample data in Swift 3 / iOS 10
//
//  Maintenance History
//          9/17/16      File Created
//
//**************************************************************************************

import UIKit
import HealthKit

struct StepCountRecord {
    var date : Date?
    var source : String?
    var stepCount : Double?
}

class MainTableViewController: UITableViewController {

    var listItems = [StepCountRecord]()
    let df = DateFormatter()
    

    
    let myHealth = HKHealthStore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        df.dateFormat = "MM/dd h:mm:ss a"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        doRefresh()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func refreshQuery(_ sender: AnyObject) {
        createDuplicates()
        deleteDuplicateHealthkitRows()
    }
    
    //**************************************************************************************
    //
    //      Function: createDuplicates
    //   Description: Create some duplicate records, so we can test purging them later
    //
    //**************************************************************************************
    func createDuplicates() {
        let stepCount = Double(arc4random_uniform(2000))
        let stepQty = HKQuantity(unit: HKUnit.count(), doubleValue: stepCount)
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-5)
        
        if let quantityType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let sample = HKQuantitySample(type: quantityType, quantity: stepQty, start: startDate, end: endDate)
            let sample2 = HKQuantitySample(type: quantityType, quantity: stepQty, start: startDate, end: endDate)
            let sample3 = HKQuantitySample(type: quantityType, quantity: stepQty, start: startDate, end: endDate)
            
            self.myHealth.save(sample, withCompletion: { (success : Bool, error : Error?) in
                print("Insert to HealthKit, stepQty=\(stepQty), success=\(success), error=\(error?.localizedDescription)")
            })
            self.myHealth.save(sample2, withCompletion: { (success : Bool, error : Error?) in
                print("Insert to HealthKit, stepQty=\(stepQty), success=\(success), error=\(error?.localizedDescription)")
            })
            self.myHealth.save(sample3, withCompletion: { (success : Bool, error : Error?) in
                print("Insert to HealthKit, stepQty=\(stepQty), success=\(success), error=\(error?.localizedDescription)")
            })
        }
        
    }
    
    
    //**************************************************************************************
    //
    //      Function: deleteDuplicateHealthkitRows
    //   Description: Evaluate a set of HealthKit rows, detect duplicate entries and purge them
    //
    //**************************************************************************************
    func deleteDuplicateHealthkitRows() {
        
        var myRecords = [HKQuantitySample]()
        var recsToPurge = [HKQuantitySample]()
        
        let beginDate = Date().addingTimeInterval(60 * 60 * 24 * 4 * -1)
        let endDate = Date().addingTimeInterval(60 * 60 * 24 * 3)
        
        print("Building predicate")
        print("   beginDate=\(self.df.string(from: beginDate)), endDate=\(self.df.string(from: endDate))")
        
        let predicate = HKQuery.predicateForSamples(withStart: beginDate, end: endDate, options: .strictStartDate)

        guard let sampleType = HKSampleType.quantityType(forIdentifier: .stepCount) else {
            fatalError("*** This method should never fail ***")
        }
    
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: nil) { query, results, error in
        
            guard let samples = results as? [HKQuantitySample] else {
                fatalError("An error occured fetching healthkit rows. The error was: \(error?.localizedDescription)");
            }
        
            for sample in samples {
                let source = sample.sourceRevision.source.name
                
                if source == "HealthKitTest" {
                //if source == "CARROT" {
                    myRecords.append(sample)
                }
            }
            
            // Sort our samples by date
            myRecords.sort {
                $0.startDate.timeIntervalSince1970 < $1.startDate.timeIntervalSince1970
            }
            
            var lastRec : HKQuantitySample?
            
            print("**************  EVALUATING  ********************")
            
            for rec in myRecords {
                
                print("source=\(rec.sourceRevision.source.name), date=\(rec.startDate), steps=\(rec.quantity.doubleValue(for: HKUnit.count()))")
                
                if let last = lastRec {
                    if self.isSameDateAs(dt1: rec.startDate, dt2: last.startDate) {
                        recsToPurge.append(rec)
                    }
                }
                
                lastRec = rec
            }
            
            print("**************  PURGING  ********************")
            
            for r in recsToPurge {
                print("source=\(r.sourceRevision.source.name), date=\(r.startDate), steps=\(r.quantity.doubleValue(for: HKUnit.count()))")
            }
            
            if recsToPurge.count > 0 {
                self.myHealth.delete(recsToPurge, withCompletion: { (success: Bool, error: Error?) in
                    print("Puging duplicate records: \(success)")
                    
                    if let err = error {
                        print("\(err.localizedDescription)")
                    }
                })
            }
        }
        
        self.myHealth.execute(query)
    }
    
    //**************************************************************************************
    //
    //      Function: isSameDateAs
    //   Description: A small routine to evaluate whether the year/month/day of to Dates are the same
    //
    //**************************************************************************************
    func isSameDateAs(dt1 : Date, dt2 : Date) -> Bool {
        let calendar = NSCalendar.current
        let dc1 = calendar.dateComponents([.year, .month, .day], from: dt1)
        let dc2 = calendar.dateComponents([.year, .month, .day], from: dt2)

        if dc1.year == dc2.year && dc1.month == dc2.month && dc1.day == dc2.day {
            return true
        }
        
        return false
    }
    
    //**************************************************************************************
    //
    //      Function: doRefresh
    //   Description: Refresh the UITableView with HealthKit sample data
    //
    //**************************************************************************************
    func doRefresh() {
        
        self.listItems.removeAll()
        DispatchQueue.main.async { [unowned self] in
            self.tableView.reloadData()
        }
        
        if HKHealthStore.isHealthDataAvailable() {
            
            let readTypes = [HKObjectType.quantityType(forIdentifier: .stepCount)]
            let mySet = NSSet(array: readTypes)
            let stepType = NSSet(object: HKObjectType.quantityType(forIdentifier: .stepCount))
            myHealth.requestAuthorization(toShare: stepType as? Set<HKSampleType>, read: mySet as? Set<HKObjectType>, completion: { (authorized : Bool, error : Error?) in
                
                print("authorized=\(authorized), error=\(error?.localizedDescription)")
                
                if error == nil {
                    
                    let beginDate = Date().addingTimeInterval(60 * 60 * 24 * 4 * -1)
                    let endDate = Date().addingTimeInterval(60 * 60 * 24 * 3)
                    
                    let options : HKStatisticsOptions = [HKStatisticsOptions.separateBySource, HKStatisticsOptions.cumulativeSum]
                    var interval = DateComponents()
                    interval.hour = 1

                    if let quantityType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
                        
                        print("Building predicate")
                        print("   beginDate=\(self.df.string(from: beginDate)), endDate=\(self.df.string(from: endDate))")
                        
                        let predicate = HKQuery.predicateForSamples(withStart: beginDate, end: endDate, options: .strictStartDate)
                        
                        let query = HKStatisticsCollectionQuery(
                            quantityType: quantityType,
                            quantitySamplePredicate: predicate,
                            options: options,
                            anchorDate: endDate,
                            intervalComponents: interval)
                        
                        query.initialResultsHandler = {
                            query, results, error in
                            
                            guard let stats = results else {
                                print("Fatal error calculating statistics: \(error?.localizedDescription)")
                                return
                            }
                            

                            for dayStats in stats.statistics() {
                                
                                let total = dayStats.sumQuantity()?.doubleValue(for: HKUnit.count())
                                print("Total=\(total)")
                                
                                if let sources = dayStats.sources {
                                    
                                    print("*********** \(sources.count) Sources  ********************")
                                    print(sources)
                                    print("******************************************")
                                    
                                    for source in sources {
                                        
                                        
                                        let stat = dayStats.sumQuantity(for: source)
                                        let stepCount = stat?.doubleValue(for: HKUnit.count())

                                        let strStartDate = self.df.string(from: dayStats.startDate)
                                        let strEndDate = self.df.string(from: dayStats.startDate)

                                        print("source: \(source.name), stepCount=\(stepCount), startDate: \(strStartDate), endDate: \(strEndDate)")
                                        
                                        let rec = StepCountRecord(date: dayStats.startDate, source: source.name, stepCount: stepCount)
                                        
                                        print(rec)

                                        self.listItems.append(rec)
                                    }
                                }
                            }
                            
                            DispatchQueue.main.async { [unowned self] in
                                self.tableView.reloadData()
                            }
                            
                        }
                        self.myHealth.execute(query)
                        
                    } else {
                        print("wasn't able to construct quantitytype")
                    }
                } else {
                    print("didn't execute query because error != nil")
                }
            })
        }
    }
    
    
    //**************************************************************************************
    //
    //      Function: addNewItem
    //   Description: Add a new single item to the HealthKit database
    //
    //**************************************************************************************
    @IBAction func addNewItem(_ sender: AnyObject) {
        
        let stepCount = Double(arc4random_uniform(2000))
        let stepQty = HKQuantity(unit: HKUnit.count(), doubleValue: stepCount)
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-5)
        
        if let quantityType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let sample = HKQuantitySample(type: quantityType, quantity: stepQty, start: startDate, end: endDate)
            
            self.myHealth.save(sample, withCompletion: { (success : Bool, error : Error?) in
                print("Insert to HealthKit, stepQty=\(stepQty), success=\(success), error=\(error?.localizedDescription)")
            })
        }
        
    }
    

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1 // self.days.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.listItems.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = self.listItems[indexPath.row]
        
        let lblDate = cell.viewWithTag(1) as! UILabel
        let lblSource = cell.viewWithTag(2) as! UILabel
        let lblSteps = cell.viewWithTag(3) as! UILabel
        
        if let dt = item.date {
            let df = DateFormatter()
            df.dateFormat = "MM/dd h:mm:ss a"
            lblDate.text = df.string(from: dt)
        } else {
            lblDate.text = "nil"
        }

        lblSource.text = item.source
        
        if let steps = item.stepCount {
            let nf = NumberFormatter()
            nf.usesGroupingSeparator = true
            nf.groupingSeparator = ","
            nf.maximumFractionDigits = 0
            lblSteps.text = nf.string(from: NSNumber(value: steps))
        } else {
            lblSteps.text = "nil"
        }
        
        return cell
    }
}
