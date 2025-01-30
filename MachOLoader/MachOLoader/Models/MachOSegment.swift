//
//  MachOSegment.swift
//  MachOLoader
//
//  Created by speedy on 1/30/25.
//

import Foundation

struct MachOSegment {
    let segname: String
    let vmaddr: UInt64
    let vmsize: UInt64
    let fileoff: UInt64
    let filesize: UInt64
    let maxprot: Int32
    let initprot: Int32
    let nsects: UInt32
    let flags: UInt32
}
