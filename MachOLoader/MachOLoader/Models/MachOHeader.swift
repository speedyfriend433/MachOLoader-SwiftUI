//
//  MachOHeader.swift
//  MachOLoader
//
//  Created by speedy on 1/30/25.
//

import Foundation

struct MachOHeader {
    let magic: UInt32
    let cpuType: Int32
    let cpuSubtype: Int32
    let fileType: UInt32
    let ncmds: UInt32
    let sizeofcmds: UInt32
    let flags: UInt32
}

enum MachOMagic: UInt32 {
    case magic32 = 0xfeedface
    case magic64 = 0xfeedfacf
    case cigam32 = 0xcefaedfe
    case cigam64 = 0xcffaedfe
}
