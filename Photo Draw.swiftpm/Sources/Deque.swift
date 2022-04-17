//
//  Deque.swift
//  
//
//  Created by Vincent Spitale on 4/17/22.
//

import Foundation

class Deque<T> {
    private let header: Sentinel<T>
    
    init() {
        self.header = Sentinel()
    }
    
    func popFirst() -> T? {
        self.header.popFirst()
    }
    
    func popLast() -> T? {
        self.header.popLast()
    }
    
    func addAtTail(_ item: T) {
        self.header.addAtTail(item)
    }
    
    func addAtHead(_ item: T) {
        self.header.addAtHead(item)
    }
}

// Create a linked list structure of a generic type
fileprivate protocol NodeProtocol {
    associatedtype T
    associatedtype U: NodeProtocol where U.T == T
    var next: U? { get set }
    var prev: U? { get set }
    
    func removeNode() -> T?
}

fileprivate class ANode<T>: NodeProtocol {
    typealias T = T
    typealias U = ANode<T>
    
    var next: U? = nil
    var prev: U? = nil
    
    // By default removing a node does nothing
    func removeNode() -> T? {
        return nil
    }
}

// The sentinel stores the head and tail elements of the deque
fileprivate class Sentinel<T>: ANode<T> {
    
    func popFirst() -> T? {
        return self.next?.removeNode()
    }
    
    func popLast() -> T? {
        return self.prev?.removeNode()
    }
    
    func addAtHead(_ item: T) {
        let node = Node<T>(item, next: self.next, prev: self)
        self.next = node
    }
    
    func addAtTail(_ item: T) {
        let node = Node<T>(item, next: self, prev: self.prev)
        self.prev = node
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
    
    // Nodes can be removed from the linked list by deleting neighboring references
    override func removeNode() -> T? {
        prev?.next = next
        next?.prev = prev
        return data
    }
}
