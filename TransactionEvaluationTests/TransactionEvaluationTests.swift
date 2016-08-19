//
//  ExpressionEvaluationTests.swift
//  ExpressionEvaluationTests
//
//  Created by Florian Kugler on 20/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import XCTest


typealias LedgerDouble = Double
typealias Commodity = String

struct Amount: Equatable {
    var value: LedgerDouble
    var commodity: Commodity
    
    init(value: LedgerDouble, commodity: Commodity = "") {
        self.value = value
        self.commodity = commodity
    }
}

indirect enum Expression {
    case amount(Amount)
    case infix(String, Expression, Expression)
    case identifier(String)
}

struct Posting {
    var account: String
    var amount: Expression?
}

struct EvaluatedPosting: Equatable {
    var account: String
    var amount: Amount
}

typealias ExpressionContext = [String: Amount]

extension Posting {
    func evaluate(context: ExpressionContext) throws -> EvaluatedPosting {
        assert(amount != nil, "Cannot call evaluate on posting without amount")
        let evaluatedAmount = try amount!.evaluate(context: context)
        return EvaluatedPosting(account: account, amount: evaluatedAmount)
    }
}

struct Transaction {
//    var date: Date
//    var title: String
    var postings: [Posting]
}

struct EvaluatedTransaction: Equatable {
//    var date: Date
//    var title: String
    var postings: [EvaluatedPosting]
}

extension Dictionary {
    subscript(key: Key, or value: Value) -> Value {
        get {
            return self[key] ?? value
        }
        set {
            self[key] = newValue
        }
    }
}

extension EvaluatedTransaction {
    var balance: [Commodity: LedgerDouble] {
        var total: [Commodity: LedgerDouble] = [:]
        for posting in postings {
            total[posting.amount.commodity, or: 0] += posting.amount.value
        }
        return total
    }
    
    func verify() throws {
        for (_, value) in balance {
            guard value == 0 else { throw "Transaction does not balance" }
        }
    }
}

extension Transaction {
    func evaluate(context: ExpressionContext) throws -> EvaluatedTransaction {
        let postingsWithAmount = postings.filter { $0.amount != nil }
        let postingsWithoutAmount = postings.filter { $0.amount == nil }
        guard postingsWithoutAmount.count <= 1 else { throw "Transaction can only contain one posting without amount" }
        
        let evaluatedPostings = try postingsWithAmount.map { try $0.evaluate(context: context) }
        var evaluatedTransaction = EvaluatedTransaction(postings: evaluatedPostings)
        
        if let posting = postingsWithoutAmount.first {
            for (commodity, value) in evaluatedTransaction.balance {
                evaluatedTransaction.postings.append(EvaluatedPosting(account: posting.account, amount: Amount(value: -value, commodity: commodity)))
            }
        }
        
        try evaluatedTransaction.verify()
        return evaluatedTransaction
    }
}

class TransactionEvaluationTests: XCTestCase {

    let checkingMinus10 = Posting(account: "Assets:Checking", amount: .amount((-10).eur))
    let food10 = Posting(account: "Expenses:Food", amount: .amount(10.eur))
    let checkingMinus20USD = Posting(account: "Assets:Checking", amount: .amount((-20).usd))
    let food20USD = Posting(account: "Expenses:Food", amount: .amount(20.usd))

    let evaluatedCheckingMinus10 = EvaluatedPosting(account: "Assets:Checking", amount: (-10).eur)
    let evaluatedFood10 = EvaluatedPosting(account: "Expenses:Food", amount: 10.eur)
    let evaluatedCheckingMinus20USD = EvaluatedPosting(account: "Assets:Checking", amount: (-20).usd)
    let evaluatedFood20USD = EvaluatedPosting(account: "Expenses:Food", amount: (20).usd)
    
    
    // 2016/07/25 Lunch
    //    Expenses:Food  10 EUR
    //    Assets:Checking  -10 EUR
    func testTransaction() {
        let transaction = Transaction(postings: [food10, checkingMinus10])
        XCTAssertEqual(try! transaction.evaluate(context: [:]), EvaluatedTransaction(postings: [evaluatedFood10, evaluatedCheckingMinus10]))
    }
    
    // 2016/07/26 Non-balanced lunch ; throws an error!
    //    Expenses:Food  5 EUR
    //    Assets:Checking  -10 EUR
    func testUnbalancedTransaction() {
        let transaction = Transaction(postings: [Posting(account: "Expenses:Food", amount: .amount(5.eur)), checkingMinus10])
        XCTAssertNil(try? transaction.evaluate(context: [:]))
    }
    
    // 2016/07/27 International lunch
    //    Expenses:Food  10 EUR
    //    Expenses:Food  20 USD
    //    Assets:Checking  -10 EUR
    //    Assets:Checking  -20 USD
    func testMultiCommodityTransaction() {
        let transaction = Transaction(postings: [food10, food20USD, checkingMinus10, checkingMinus20USD])
        XCTAssertEqual(try! transaction.evaluate(context: [:]), EvaluatedTransaction(postings: [evaluatedFood10, evaluatedFood20USD, evaluatedCheckingMinus10, evaluatedCheckingMinus20USD]))

    }
    
    // 2016/07/25 Implicit lunch
    //    Expenses:Food  10 EUR
    //    Assets:Checking
    func testImplicitTransaction() {
        let transaction = Transaction(postings: [food10, Posting(account: "Assets:Checking", amount: nil)])
        XCTAssertEqual(try! transaction.evaluate(context: [:]), EvaluatedTransaction(postings: [evaluatedFood10, evaluatedCheckingMinus10]))
    }
}
