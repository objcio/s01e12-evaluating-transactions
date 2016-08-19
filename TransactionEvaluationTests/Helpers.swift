//
//  Equatable.swift
//  ExpressionEvaluation
//
//  Created by Florian Kugler on 20/07/16.
//  Copyright © 2016 objc.io. All rights reserved.
//

import Foundation


extension String: Error {}

func ==(lhs: Amount, rhs: Amount) -> Bool {
    return lhs.commodity == rhs.commodity && lhs.value == rhs.value
}

func ==(lhs: EvaluatedPosting, rhs: EvaluatedPosting) -> Bool {
    return lhs.account == rhs.account && lhs.amount == rhs.amount
}

func ==(lhs: EvaluatedTransaction, rhs: EvaluatedTransaction) -> Bool {
    return lhs.postings == rhs.postings
}



extension Int {
    var eur: Amount {
        return Amount(value: LedgerDouble(self), commodity: "EUR")
    }
    var usd: Amount {
        return Amount(value: LedgerDouble(self), commodity: "USD")
    }
}

extension Amount: ExpressibleByIntegerLiteral {
    init(integerLiteral value: LedgerDouble) {
        self.value = value
        self.commodity = ""
    }
}

extension Expression {
    func evaluate(context: [String: Amount]) throws -> Amount {
        switch self {
        case .amount(let amount):
            return amount
        case let .infix(op, lhs, rhs):
            let left = try lhs.evaluate(context: context)
            let right = try rhs.evaluate(context: context)
            let operators: [String: (LedgerDouble, LedgerDouble) -> LedgerDouble] = [
                "+": (+),
                "*": (*)
            ]
            guard let operatorFunction = operators[op] else {
                throw "Unknown operator: \(op)"
            }
            return try left.compute(operator: operatorFunction, other: right)
        case .identifier(let name):
            guard let value = context[name] else { throw "Unknown identifier: \(name)" }
            return value
        }
    }
}

extension Amount {
    func compute(operator f: (LedgerDouble, LedgerDouble) -> LedgerDouble, other: Amount) throws -> Amount {
        guard commodity == other.commodity else {
            throw "Commodities don't match"
        }
        
        return Amount(value: f(value, other.value), commodity: commodity)
    }
}
