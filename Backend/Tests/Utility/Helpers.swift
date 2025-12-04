//
//  Helpers.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/04.
//

func makeDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0
) -> Date {
    return Date.combine(date: .init(year: year, month: month, day: day), time: .init(hour: hour, minute: minute))
}
