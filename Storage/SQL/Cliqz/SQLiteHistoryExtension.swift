//
//  SQLiteHistoryExtension.swift
//  Client
//
//  Created by Mahmoud Adam on 11/18/15.
//  Copyright © 2015 Cliqz. All rights reserved.
//

import Foundation
import Shared
import Deferred

extension SQLiteHistory: ExtendedBrowserHistory {
    
    public func count() -> Int {
        var count = 0
        self.getOldestVisitDate()
        let countSQL = "SELECT COUNT(\(TableHistory).id) AS rowCount FROM \(TableHistory) "
        
        let resultSet = db.runQuery(countSQL, args: nil, factory: SQLiteHistory.countFactory).value
        if let data = resultSet.successValue {
			if let d = data[0] {
				count = d
			}
        }
        return count
    }
    
    public func getOldestVisitDate() -> NSDate? {
        var oldestVisitDate: NSDate?

        let visitsSQL = "SELECT MIN(\(TableVisits).date) AS date FROM \(TableVisits) "
        
        let resultSet = db.runQuery(visitsSQL, args: nil, factory: SQLiteHistory.dateFactory).value
        if let data = resultSet.successValue {
            oldestVisitDate = data[0]
        }
        return oldestVisitDate
    }
    
    public func removeHistory(ids: [Int]) -> Success {
        let idsCommaSeparated = ids.map{String($0)}.joinWithSeparator(",")

        return self.db.run([
            ("DELETE FROM \(TableVisits) WHERE id in (\(idsCommaSeparated))", nil),
            ("DELETE FROM \(TableHistory) WHERE id NOT IN (SELECT distinct(siteID) FROM \(TableVisits))", nil),
            ("DELETE FROM \(TableDomains) WHERE id NOT IN (SELECT (domain_id) FROM \(TableHistory))", nil),
            self.favicons.getCleanupCommands(),
            ])
    }
	
	// TODO: check if possible to use FF's version of getHistory
    public func getHistoryVisits(offset:Int, limit: Int) -> Deferred<Maybe<Cursor<Site>>> {
        let args: Args?
        args = []
		
        let historySQL =
        "SELECT \(TableVisits).id, \(TableVisits).date, \(TableHistory).url, \(TableHistory).title " +
            "FROM \(TableHistory) " +
            "INNER JOIN \(TableVisits) ON \(TableVisits).siteID = \(TableHistory).id " +
            "ORDER BY \(TableVisits).id DESC " +
        "LIMIT \(limit) OFFSET \(offset)"
        
        // TODO countFactory
        return db.runQuery(historySQL, args: args, factory: SQLiteHistory.historyVisitsFactory)
    }
    
    public func getHistoryVisits(domain:String, timeStampLowerLimit:Int?, timeStampUpperLimit:Int?, limit: Int?) -> Deferred<Maybe<Cursor<Site>>> {
        
        func removeOptionalFromString(str:String) -> String {
            return "\(str)"
        }
        
        let args: Args?
        args = []
        
        let shouldAdd_WHERE = domain != "" || timeStampUpperLimit != nil || timeStampLowerLimit != nil
        
        var historySQL =
            "SELECT \(TableVisits).id, \(TableVisits).date, \(TableHistory).url, \(TableHistory).title " +
                "FROM \(TableDomains) " +
                "INNER JOIN \(TableHistory) ON \(TableDomains).id = \(TableHistory).domain_id " +
                "INNER JOIN \(TableVisits) ON \(TableHistory).id = \(TableVisits).siteID "
        
        if shouldAdd_WHERE {
        
            historySQL += "WHERE "
            
            var at_least_one_cond = false
            if domain != "" {
                historySQL += "\(TableDomains).domain = \"\(domain)\" "
                at_least_one_cond = true
            }
            if let min = timeStampLowerLimit {
                if at_least_one_cond {
                    historySQL += "AND \(TableVisits).date >= \(min) "
                }
                else {
                    historySQL += "\(TableVisits).date >= \(min) "
                    at_least_one_cond = true
                }
            }
            if let max = timeStampUpperLimit {
                if at_least_one_cond{
                    historySQL += "AND \(TableVisits).date <= \(max) "
                }
                else {
                    historySQL += "\(TableVisits).date <= \(max) "
                    at_least_one_cond = true
                }
            }
        }
        
        historySQL += "ORDER BY \(TableVisits).id DESC "
        
        if let l = limit {
            historySQL += "LIMIT \(l) OFFSET \(0)"
        }
        
        // TODO countFactory
        return db.runQuery(historySQL, args: args, factory: SQLiteHistory.historyVisitsFactory)
    }

	public func hideTopSite(url: String) -> Success {
		let insertSQL = "INSERT INTO \(TableHiddenTopSites) " +
			"(url) " +
			"VALUES (?)"
		let args: Args = [
			url
		]
		return db.run(insertSQL, withArgs: args)
	}

	public func deleteAllHiddenTopSites() -> Success {
		return self.db.run([
			"DELETE FROM \(TableHiddenTopSites)"])
	}

    //MARK: - Factories
    private class func countFactory(row: SDRow) -> Int {
        let cout = row["rowCount"] as! Int
        return cout
    }
    
    private class func dateFactory(row: SDRow) -> NSDate {

        let timeInMicroSeconds = row.getTimestamp("date")
        let timeIntervalSince1970 = Double(timeInMicroSeconds! / 1000000)
        
        let date = NSDate(timeIntervalSince1970:timeIntervalSince1970)
        return date
    }
	
    internal class func historyVisitsFactory(row: SDRow) -> Site {
        let id = row["id"] as! Int
        let url = row["url"] as! String
        let title = row["title"] as! String
		
        let site = Site(url: url, title: title)
        site.id = id
		
        let date = row.getTimestamp("date") ?? 0
        site.latestVisit = Visit(date: date, type: VisitType.Unknown)

        return site
    }
    

}
