//
//  Deque.swift
//
//
//  Created by Vincent Spitale on 4/17/22.
//

import Foundation

// Normally I would use Swift Collections, but since loading
// dependencies requires a network connection, I opted to implement
// my own double-ended queue
class Deque<T> {
    private let header: Sentinel<T>
    
    init() {
        self.header = Sentinel()
    }
    
    /// Get and remove the value at the head of the deque
    func popFirst() -> T? {
        self.header.popFirst()
    }
    
    /// Get and remove the value at the tail of the deque
    func popLast() -> T? {
        self.header.popLast()
    }
    
    /// Add a new item to the end of the deque
    func addAtTail(_ item: T) {
        self.header.addAtTail(item)
    }
    
}

// Create a doubly linked list structure of a generic type
fileprivate protocol NodeProtocol {
    associatedtype T
    associatedtype U: NodeProtocol where U.T == T
    var next: U? { get set }
    var prev: U? { get set }
}

// This class should not be created directly, only its subclasses
// should be used in a linked list
fileprivate class ANode<T>: NodeProtocol {
    typealias T = T
    typealias U = ANode<T>
    
    weak var next: U? = nil
    var prev: U? = nil
    
    /// Return any data stored in this node
    func getData() -> T? {
        return nil
    }
}

// The sentinel stores the head and tail elements of the deque
fileprivate class Sentinel<T>: ANode<T> {
    
    func popFirst() -> T? {
        let prev = self.prev
        self.prev = prev?.next
        return prev?.getData()
    }
    
    func popLast() -> T? {
        let next = self.next
        self.next = next?.prev
        return next?.getData()
    }
    
    func addAtTail(_ item: T) {
        guard let next = self.next else {
            let node = Node<T>(item, next: self, prev: self)
            self.prev = node
            self.next = node
            return
        }
        let node = Node<T>(item, next: self, prev: self.next)
        next.next = node
        self.next = node
    }
    
}

fileprivate class Node<T>: ANode<T> {
    var data: T
    
    init(_ data: T, next: ANode<T>?, prev: ANode<T>?) {
        self.data = data
        super.init()
        self.next = next
        self.prev = prev
    }
    
    override func getData() -> T? {
        return data
    }
}
