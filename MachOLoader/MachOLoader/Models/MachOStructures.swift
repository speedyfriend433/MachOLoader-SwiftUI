//
//  MachOStructures.swift
//  MachOLoader
//
//  Created by speedy on 1/30/25.
//

import Foundation
import MachO

struct FatHeader {
    var magic: UInt32
    var nfat_arch: UInt32
}

struct FatArch {
    var cputype: Int32
    var cpusubtype: Int32
    var offset: UInt32       // file offset to this object file
    var size: UInt32         // size of this object file
    var align: UInt32        // alignment as a power of 2
}

struct SymbolTable {
    let symbols: [Symbol]
    let stringTable: [String]?
}

struct Symbol {
    let name: String
    let type: UInt8
    let section: UInt8
    let desc: Int16
    let value: UInt64
    
    var typeString: String {
        switch type & 0x0e {
        case 0x0: return "Undefined"
        case 0x2: return "Absolute"
        case 0xe: return "Defined"
        case 0xc: return "Prebound"
        case 0xa: return "Indirect"
        default: return "Unknown"
        }
    }
    var isExternal: Bool {
        return (type & 0x01) != 0
    }
    
    var isPrivateExternal: Bool {
        return (type & 0x10) != 0 // N_PEXT
    }
}

struct Nlist32 {
        var n_strx: UInt32
        var n_type: UInt8
        var n_sect: UInt8
        var n_desc: Int16
        var n_value: UInt32
    }

struct Nlist64 {
        var n_strx: UInt32
        var n_type: UInt8
        var n_sect: UInt8
        var n_desc: Int16
        var n_value: UInt64
    }

struct NUnion {
        var n_strx: UInt32  // String table index
    }

struct NList32 {
        var n_un: NUnion    // String table index
        var n_type: UInt8   // Type flag
        var n_sect: UInt8   // Section number
        var n_desc: Int16   // Description field
        var n_value: UInt32 // Value/address of symbol
    }

struct NList64 {
        var n_un: NUnion
        var n_type: UInt8
        var n_sect: UInt8
        var n_desc: Int16
        var n_value: UInt64
    }

struct NList {
    var n_strx: UInt32
    var n_type: UInt8
    var n_sect: UInt8
    var n_desc: UInt16
    var n_value: UInt32
}

struct SymbolType {
    static let STAB: UInt8 = 0xe0  // Mask for stab bits
    static let PEXT: UInt8 = 0x10  // Private external symbol
    static let EXT:  UInt8 = 0x01  // External symbol
    static let TYPE: UInt8 = 0x0e  // Mask for type bits
    static let UNDF: UInt8 = 0x0   // Undefined
    static let ABS:  UInt8 = 0x2   // Absolute
    static let SECT: UInt8 = 0xe   // Defined in section
    static let PBUD: UInt8 = 0xc   // Prebound undefined
    static let INDR: UInt8 = 0xa   // Indirect
}

struct MachOLoadCommand {
    let cmd: UInt32
    let cmdsize: UInt32
}

struct MachSection64 {
    var sectname: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)
    var segname: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)
    var addr: UInt64
    var size: UInt64
    var offset: UInt32
    var align: UInt32
    var reloff: UInt32
    var nreloc: UInt32
    var flags: UInt32
    var reserved1: UInt32
    var reserved2: UInt32
    var reserved3: UInt32
}

struct MachSection32 {
    var sectname: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)
    var segname: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)
    var addr: UInt32
    var size: UInt32
    var offset: UInt32
    var align: UInt32
    var reloff: UInt32
    var nreloc: UInt32
    var flags: UInt32
    var reserved1: UInt32
    var reserved2: UInt32
}

struct Section64 {
    let sectname: String
    let segname: String
    let addr: UInt64
    let size: UInt64
    let offset: UInt32
    let align: UInt32
    let reloff: UInt32
    let nreloc: UInt32
    let flags: UInt32
}

struct Section32 {
    let sectname: String
    let segname: String
    let addr: UInt32
    let size: UInt32
    let offset: UInt32
    let align: UInt32
    let reloff: UInt32
    let nreloc: UInt32
    let flags: UInt32
}

enum LoadCommandType: UInt32 {
    case segment32 = 0x1
    case symtab = 0x2
    case dysymtab = 0xb
    case dylinker = 0xc
    case dylib = 0xd
    case segment64 = 0x19
}
