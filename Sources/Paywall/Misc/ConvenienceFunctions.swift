//
//  File 2.swift
//  
//
//  Created by Brian Anglin on 8/4/21.
//
import Foundation

func onMain(_ execute: @escaping () -> Void) {
	DispatchQueue.main.async(execute: execute)
}

func onMain(after: TimeInterval, _ execute: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: execute)
}
