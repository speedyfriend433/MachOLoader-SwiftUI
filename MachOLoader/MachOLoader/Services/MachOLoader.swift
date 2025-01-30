//
//  MachOLoader.swift
//  MachOLoader
//
//  Created by speedy on 1/30/25.
//

import Foundation
import MachO

class MachOLoader {
    private var fileData: Data?
    private var fileDescriptor: Int32 = -1
    private var segments: [MachOSegment] = []
    private var sections: [Any] = []
    private var symbolTable: SymbolTable?
    private var stringTable: [String]?
    private var is64Bit: Bool = false
    
    private struct MachMagic {
            static let magic32 = UInt32(0xfeedface)    // MH_MAGIC
            static let magic64 = UInt32(0xfeedfacf)    // MH_MAGIC_64
            static let cigam32 = UInt32(0xcefaedfe)    // MH_CIGAM
            static let cigam64 = UInt32(0xcffaedfe)    // MH_CIGAM_64
            static let fat = UInt32(0xcafebabe)        // FAT_MAGIC
            static let fatCigam = UInt32(0xbebafeca)   // FAT_CIGAM
        }
        
        enum MachOLoaderError: Error {
            case fileNotFound
            case invalidMachO
            case mappingError
            case unsupportedFormat
            case invalidMagic
            case invalidHeader
            case invalidSegment
            case invalidSection
            case invalidSymbol
            case fatBinaryNotSupported
            case wrongByteOrder
            
            var description: String {
                switch self {
                case .fileNotFound:
                    return "File not found"
                case .invalidMachO:
                    return "Invalid Mach-O file"
                case .mappingError:
                    return "Error mapping file to memory"
                case .unsupportedFormat:
                    return "Unsupported Mach-O format"
                case .invalidMagic:
                    return "Invalid magic number"
                case .invalidHeader:
                    return "Invalid Mach-O header"
                case .invalidSegment:
                    return "Invalid segment"
                case .invalidSection:
                    return "Invalid section"
                case .invalidSymbol:
                    return "Invalid symbol"
                case .fatBinaryNotSupported:
                    return "Fat (Universal) binary not yet supported"
                case .wrongByteOrder:
                    return "Binary has wrong byte order for this platform"
                }
            }
        }
    
    func load(path: String) throws {
        print("Attempting to load file at path: \(path)")
        
        fileDescriptor = open(path, O_RDONLY)
        guard fileDescriptor != -1 else {
            print("Failed to open file: \(errno)")
            throw MachOLoaderError.fileNotFound
        }

        var stat = stat()
        guard fstat(fileDescriptor, &stat) == 0 else {
            print("Failed to get file stats: \(errno)")
            throw MachOLoaderError.invalidMachO
        }
        let fileSize = stat.st_size
        
        print("File size: \(fileSize) bytes")
        
        guard let mapping = mmap(nil,
                               size_t(fileSize),
                               PROT_READ,
                               MAP_PRIVATE,
                               fileDescriptor,
                               0) else {
            print("Failed to map file: \(errno)")
            throw MachOLoaderError.mappingError
        }
        
        if mapping == MAP_FAILED {
            print("Memory mapping failed: \(errno)")
            throw MachOLoaderError.mappingError
        }
        
        fileData = Data(bytes: mapping, count: Int(fileSize))
        print("File successfully mapped to memory")
        
        try parseMachOHeader()
    }
    
    private func parseMachOHeader() throws {
            guard let data = fileData else {
                print("No file data available")
                throw MachOLoaderError.invalidMachO
            }
            
            guard data.count >= 4 else {
                print("File too small to contain magic number")
                throw MachOLoaderError.invalidMachO
            }
            
            let magic = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self) }
            print("Magic number: 0x\(String(format: "%x", magic))")
            
            switch magic {
            case MachMagic.magic64:
                print("Detected 64-bit Mach-O")
                is64Bit = true
                try parse64BitMachO()
                
            case MachMagic.magic32:
                print("Detected 32-bit Mach-O")
                is64Bit = false
                try parse32BitMachO()
                
            case MachMagic.cigam64:
                print("Detected 64-bit Mach-O (wrong byte order)")
                throw MachOLoaderError.wrongByteOrder
                
            case MachMagic.cigam32:
                print("Detected 32-bit Mach-O (wrong byte order)")
                throw MachOLoaderError.wrongByteOrder
                
            case MachMagic.fat, MachMagic.fatCigam:
                print("Detected Fat (Universal) binary")
                try parseFatBinary(magic: magic)
                
            default:
                print("Unsupported magic number: 0x\(String(format: "%x", magic))")
                throw MachOLoaderError.unsupportedFormat
            }
        }
    
    private func parseFatBinary(magic: UInt32) throws {
        guard let data = fileData else {
            throw MachOLoaderError.invalidMachO
        }
        
        let fatHeader = data.withUnsafeBytes { ptr -> FatHeader in
            ptr.load(as: FatHeader.self)
        }
        
        let needsSwap = magic == MachMagic.fatCigam
        let narch = needsSwap ? fatHeader.nfat_arch.byteSwapped : fatHeader.nfat_arch
        
        print("Fat binary contains \(narch) architectures")
        
        guard let currentArch = getCurrentArchitecture() else {
            throw MachOLoaderError.unsupportedFormat
        }
        
        var offset = MemoryLayout<FatHeader>.size
        
        for _ in 0..<narch {
            let arch = data.advanced(by: offset).withUnsafeBytes { ptr -> FatArch in
                ptr.load(as: FatArch.self)
            }
            
            let cputype = needsSwap ? Int32(bigEndian: arch.cputype) : arch.cputype
            let cpusubtype = needsSwap ? Int32(bigEndian: arch.cpusubtype) : arch.cpusubtype
            
            if cputype == currentArch.cpu && cpusubtype == currentArch.subcpu {

                let archOffset = needsSwap ? UInt32(bigEndian: arch.offset) : arch.offset
                let archSize = needsSwap ? UInt32(bigEndian: arch.size) : arch.size
                let sliceData = data.subdata(in: Int(archOffset)..<Int(archOffset + archSize))
                fileData = sliceData
                try parseMachOHeader()
                return
            }
            
            offset += MemoryLayout<FatArch>.size
        }
        
        throw MachOLoaderError.unsupportedFormat
    }
        
//herlper
        private func getCurrentArchitecture() -> (cpu: Int32, subcpu: Int32)? {
            #if arch(x86_64)
            return (CPU_TYPE_X86_64, CPU_SUBTYPE_X86_64_ALL)
            #elseif arch(arm64)
            return (CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64_ALL)
            #else
            return nil
            #endif
        }
    
    private func parse64BitMachO() throws {
        guard let data = fileData else {
            throw MachOLoaderError.invalidMachO
        }
        
        guard data.count >= MemoryLayout<mach_header_64>.size else {
            print("File too small to contain 64-bit header")
            throw MachOLoaderError.invalidHeader
        }
        
        let header = data.withUnsafeBytes { ptr -> mach_header_64 in
            ptr.load(as: mach_header_64.self)
        }
        
        print("Number of load commands: \(header.ncmds)")
        print("Size of load commands: \(header.sizeofcmds)")
        
        var offset = MemoryLayout<mach_header_64>.size
        
        for i in 0..<header.ncmds {
            guard offset + MemoryLayout<load_command>.size <= data.count else {
                print("Load command \(i) extends beyond file size")
                throw MachOLoaderError.invalidHeader
            }
            
            let loadCommand = data.advanced(by: offset).withUnsafeBytes { ptr -> load_command in
                ptr.load(as: load_command.self)
            }
            
            print("Processing load command \(i): type 0x\(String(format: "%x", loadCommand.cmd))")
            
            switch loadCommand.cmd {
            case UInt32(LC_SEGMENT_64):
                try parseSegment64Command(data: data, offset: offset)
            case UInt32(LC_SYMTAB):
                print("Found symbol table command")
                try parseSymtabCommand(data: data, offset: offset)
            default:
                print("Skipping load command type: 0x\(String(format: "%x", loadCommand.cmd))")
            }

            
            offset += Int(loadCommand.cmdsize)
        }
    }
    
    private func parse32BitMachO() throws {
        guard let data = fileData else {
            throw MachOLoaderError.invalidMachO
        }
        
        let header = data.withUnsafeBytes { ptr -> mach_header in
            ptr.load(as: mach_header.self)
        }
        
        var offset = MemoryLayout<mach_header>.size
        
        for _ in 0..<header.ncmds {
            let loadCommand = data.advanced(by: offset).withUnsafeBytes { ptr -> load_command in
                ptr.load(as: load_command.self)
            }
            
            switch LoadCommandType(rawValue: loadCommand.cmd) {
            case .segment32:
                try parseSegment32Command(data: data, offset: offset)
            case .symtab:
                try parseSymtabCommand(data: data, offset: offset)
            case .dysymtab:
                try parseDysymtabCommand(data: data, offset: offset)
            default:
                break
            }
            
            offset += Int(loadCommand.cmdsize)
        }
    }
    
    private func parseSegment64Command(data: Data, offset: Int) throws {
        let segmentCommand = data.advanced(by: offset).withUnsafeBytes { ptr -> segment_command_64 in
            ptr.load(as: segment_command_64.self)
        }
        
        let segname = withUnsafeBytes(of: segmentCommand.segname) { ptr -> String in
            String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
        
        let segment = MachOSegment(
            segname: segname,
            vmaddr: segmentCommand.vmaddr,
            vmsize: segmentCommand.vmsize,
            fileoff: segmentCommand.fileoff,
            filesize: segmentCommand.filesize,
            maxprot: segmentCommand.maxprot,
            initprot: segmentCommand.initprot,
            nsects: segmentCommand.nsects,
            flags: segmentCommand.flags
        )
        
        segments.append(segment)
        
        var sectionOffset = offset + MemoryLayout<segment_command_64>.size
        
        for _ in 0..<segmentCommand.nsects {
            let section = data.advanced(by: sectionOffset).withUnsafeBytes { ptr -> section_64 in
                ptr.load(as: section_64.self)
            }
            
            let sectname = withUnsafeBytes(of: section.sectname) { ptr -> String in
                String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
            
            let segname = withUnsafeBytes(of: section.segname) { ptr -> String in
                String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
            
            let section64 = Section64(
                sectname: sectname,
                segname: segname,
                addr: section.addr,
                size: section.size,
                offset: section.offset,
                align: section.align,
                reloff: section.reloff,
                nreloc: section.nreloc,
                flags: section.flags
            )
            
            sections.append(section64)
            sectionOffset += MemoryLayout<section_64>.size
        }
    }

    private func parseSegment32Command(data: Data, offset: Int) throws {
        let segmentCommand = data.advanced(by: offset).withUnsafeBytes { ptr -> segment_command in
            ptr.load(as: segment_command.self)
        }
        
        let segname = withUnsafeBytes(of: segmentCommand.segname) { ptr -> String in
            String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
        
        let segment = MachOSegment(
            segname: segname,
            vmaddr: UInt64(segmentCommand.vmaddr),
            vmsize: UInt64(segmentCommand.vmsize),
            fileoff: UInt64(segmentCommand.fileoff),
            filesize: UInt64(segmentCommand.filesize),
            maxprot: segmentCommand.maxprot,
            initprot: segmentCommand.initprot,
            nsects: segmentCommand.nsects,
            flags: segmentCommand.flags
        )
        
        segments.append(segment)
        
        var sectionOffset = offset + MemoryLayout<segment_command>.size
            
            for _ in 0..<segmentCommand.nsects {
                let section = data.advanced(by: sectionOffset).withUnsafeBytes { ptr -> MachSection32 in
                    ptr.load(as: MachSection32.self)
                }
                
                let sectname = withUnsafeBytes(of: section.sectname) { ptr -> String in
                    String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
                }
                
                let segname = withUnsafeBytes(of: section.segname) { ptr -> String in
                    String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
                }
                
                let section32 = Section32(
                    sectname: sectname,
                    segname: segname,
                    addr: section.addr,
                    size: section.size,
                    offset: section.offset,
                    align: section.align,
                    reloff: section.reloff,
                    nreloc: section.nreloc,
                    flags: section.flags
                )
                
                sections.append(section32)
                sectionOffset += MemoryLayout<MachSection32>.size
            }
        }

    
    private func parseSymtabCommand(data: Data, offset: Int) throws {
            print("Starting symbol table parsing at offset: \(offset)")
            
            let symtabCommand = data.advanced(by: offset).withUnsafeBytes { ptr -> symtab_command in
                ptr.load(as: symtab_command.self)
            }
            
            print("Symbol table info:")
            print("- Number of symbols: \(symtabCommand.nsyms)")
            print("- Symbol table offset: \(symtabCommand.symoff)")
            print("- String table offset: \(symtabCommand.stroff)")
            print("- String table size: \(symtabCommand.strsize)")
            
            guard symtabCommand.stroff + symtabCommand.strsize <= data.count,
                  symtabCommand.symoff + (symtabCommand.nsyms * UInt32(is64Bit ? MemoryLayout<Nlist64>.size : MemoryLayout<Nlist32>.size)) <= data.count else {
                print("Invalid symbol table or string table offsets")
                throw MachOLoaderError.invalidSymbol
            }
            
            stringTable = try parseStringTable(data: data,
                                             offset: Int(symtabCommand.stroff),
                                             size: Int(symtabCommand.strsize))
            
            let symbols = try is64Bit ?
                parseSymbols64(data: data, offset: Int(symtabCommand.symoff), count: Int(symtabCommand.nsyms)) :
                parseSymbols32(data: data, offset: Int(symtabCommand.symoff), count: Int(symtabCommand.nsyms))
            
            symbolTable = SymbolTable(symbols: symbols, stringTable: stringTable)
            print("Symbol table parsing completed successfully with \(symbols.count) symbols")
        }
        
        private func parseStringTable(data: Data, offset: Int, size: Int) throws -> [String] {
            print("Parsing string table at offset: \(offset), size: \(size)")
            
            guard offset + size <= data.count else {
                print("String table extends beyond file size")
                throw MachOLoaderError.invalidSymbol
            }
            
            var strings: [String] = []
            var currentOffset = offset
            var currentString = ""
            
            while currentOffset < offset + size {
                if currentOffset >= data.count {
                    break
                }
                
                let byte = data[currentOffset]
                
                if byte == 0 {
                    if !currentString.isEmpty {
                        strings.append(currentString)
                        currentString = ""
                    }
                } else {
                    if let char = String(bytes: [byte], encoding: .utf8) {
                        currentString.append(char)
                    }
                }
                
                currentOffset += 1
            }
            
            print("Parsed \(strings.count) strings from string table")
            return strings
        }
    
    private struct SymbolEntry {
            let strx: UInt32
            let type: UInt8
            let sect: UInt8
            let desc: Int16
            let value: UInt64
        }
    
    private struct SymbolEntry64 {
            let strx: UInt32
            let type: UInt8
            let sect: UInt8
            let desc: UInt16
            let value: UInt64
        }

        private struct SymbolEntry32 {
            let strx: UInt32
            let type: UInt8
            let sect: UInt8
            let desc: UInt16
            let value: UInt32
        }
        
    private func loadSymbolEntry(from data: Data, at offset: Int, is64Bit: Bool) throws -> SymbolEntry {
            return try data.advanced(by: offset).withUnsafeBytes { ptr -> SymbolEntry in
                guard ptr.count >= (is64Bit ? 16 : 12) else {
                    throw MachOLoaderError.invalidSymbol
                }
                
                let strx = ptr.load(fromByteOffset: 0, as: UInt32.self)
                let type = ptr.load(fromByteOffset: 4, as: UInt8.self)
                let sect = ptr.load(fromByteOffset: 5, as: UInt8.self)
                let desc = ptr.load(fromByteOffset: 6, as: Int16.self)
                let value: UInt64
                
                if is64Bit {
                    value = ptr.load(fromByteOffset: 8, as: UInt64.self)
                } else {
                    value = UInt64(ptr.load(fromByteOffset: 8, as: UInt32.self))
                }
                
                return SymbolEntry(strx: strx, type: type, sect: sect, desc: desc, value: value)
            }
        }

        private func parseSymbols64(data: Data, offset: Int, count: Int) throws -> [Symbol] {
            print("Parsing \(count) 64-bit symbols at offset: \(offset)")
            
            var symbols: [Symbol] = []
            var currentOffset = offset
            
            for i in 0..<count {
                guard currentOffset + 16 <= data.count else {
                    print("Symbol \(i) extends beyond file size")
                    throw MachOLoaderError.invalidSymbol
                }
                
                let entry = try loadSymbolEntry(from: data, at: currentOffset, is64Bit: true)
                
                if let stringTable = stringTable,
                   Int(entry.strx) < stringTable.count {
                    let name = stringTable[Int(entry.strx)]
                    let symbol = Symbol(
                        name: name,
                        type: entry.type,
                        section: entry.sect,
                        desc: entry.desc,
                        value: entry.value
                    )
                    symbols.append(symbol)
                }
                
                currentOffset += 16
            }
            
            print("Successfully parsed \(symbols.count) 64-bit symbols")
            return symbols
        }
        
        private func parseSymbols32(data: Data, offset: Int, count: Int) throws -> [Symbol] {
            print("Parsing \(count) 32-bit symbols at offset: \(offset)")
            
            var symbols: [Symbol] = []
            var currentOffset = offset
            
            for i in 0..<count {
                guard currentOffset + 12 <= data.count else {
                    print("Symbol \(i) extends beyond file size")
                    throw MachOLoaderError.invalidSymbol
                }
                
                let entry = try loadSymbolEntry(from: data, at: currentOffset, is64Bit: false)
                
                if let stringTable = stringTable,
                   Int(entry.strx) < stringTable.count {
                    let name = stringTable[Int(entry.strx)]
                    let symbol = Symbol(
                        name: name,
                        type: entry.type,
                        section: entry.sect,
                        desc: entry.desc,
                        value: entry.value
                    )
                    symbols.append(symbol)
                }
                
                currentOffset += 12
            }
            
            print("Successfully parsed \(symbols.count) 32-bit symbols")
            return symbols
        }
        
        func getSymbolTable() -> SymbolTable? {
            if let table = symbolTable, !table.symbols.isEmpty {
                print("Returning symbol table with \(table.symbols.count) symbols")
                return table
            }
            print("No valid symbol table available")
            return nil
        }
        
    private func parseSymbols(data: Data, offset: Int, count: Int) throws -> [Symbol] {
        print("Parsing \(count) symbols at offset: \(offset)")
        
        var symbols: [Symbol] = []
        var currentOffset = offset
        
        for i in 0..<count {
            if is64Bit {
                guard currentOffset + MemoryLayout<nlist_64>.size <= data.count else {
                    print("Symbol \(i) extends beyond file size")
                    throw MachOLoaderError.invalidSymbol
                }
                
                let nlist = data.advanced(by: currentOffset).withUnsafeBytes { ptr -> nlist_64 in
                    ptr.load(as: nlist_64.self)
                }
                
                if nlist.n_un.n_strx < stringTable?.count ?? 0 {
                    let name = stringTable?[Int(nlist.n_un.n_strx)] ?? "unknown"
                    let symbol = Symbol(
                        name: name,
                        type: nlist.n_type,
                        section: nlist.n_sect,
                        desc: Int16(nlist.n_desc),
                        value: nlist.n_value
                    )
                    symbols.append(symbol)
                }
                
                currentOffset += MemoryLayout<nlist_64>.size
            } else {
                guard currentOffset + MemoryLayout<nlist>.size <= data.count else {
                    print("Symbol \(i) extends beyond file size")
                    throw MachOLoaderError.invalidSymbol
                }
                
                let nlist = data.advanced(by: currentOffset).withUnsafeBytes { ptr -> nlist.Type in
                    ptr.load(as: nlist.self)
                }
                
                if nlist.n_un.n_strx < stringTable?.count ?? 0 {
                    let name = stringTable?[Int(nlist.n_un.n_strx)] ?? "unknown"
                    let symbol = Symbol(
                        name: name,
                        type: nlist.n_type,
                        section: nlist.n_sect,
                        desc: nlist.n_desc,
                        value: UInt64(nlist.n_value)
                    )
                    symbols.append(symbol)
                }
                
                currentOffset += MemoryLayout<nlist>.size
            }
        }
        
        print("Successfully parsed \(symbols.count) symbols")
        return symbols
    }
        
        func hasValidSymbols() -> Bool {
            if let table = symbolTable, !table.symbols.isEmpty {
                return true
            }
            return false
        }
        
    private func parseStringTable(data: Data, offset: Int, size: Int) throws {
            print("Parsing string table at offset: \(offset), size: \(size)")
            
            guard offset + size <= data.count else {
                print("String table extends beyond file size")
                throw MachOLoaderError.invalidHeader
            }
            
            var strings: [String] = []
            var currentOffset = offset
            var currentString = ""
            
            while currentOffset < offset + size {
                let byte = data[currentOffset]
                
                if byte == 0 {
                    if !currentString.isEmpty {
                        strings.append(currentString)
                        currentString = ""
                    }
                } else {
                    if let char = String(bytes: [byte], encoding: .utf8) {
                        currentString.append(char)
                    }
                }
                
                currentOffset += 1
            }
            
            self.stringTable = strings
            print("Parsed \(strings.count) strings from string table")
        }
        
        
        
    private func parseSymbols(data: Data, offset: Int, count: Int) throws {
        print("Parsing \(count) symbols at offset: \(offset)")
        
        var symbols: [Symbol] = []
        var currentOffset = offset
        
        for i in 0..<count {
            if is64Bit {
                guard currentOffset + MemoryLayout<NList64>.size <= data.count else {
                    print("Symbol \(i) extends beyond file size")
                    throw MachOLoaderError.invalidHeader
                }
                
                let nlist = data.advanced(by: currentOffset).withUnsafeBytes { ptr -> NList64 in
                    ptr.load(as: NList64.self)
                }
                
                let symbol = try createSymbol(from: nlist)
                symbols.append(symbol)
                
                currentOffset += MemoryLayout<NList64>.size
            } else {
                guard currentOffset + MemoryLayout<NList>.size <= data.count else {
                    print("Symbol \(i) extends beyond file size")
                    throw MachOLoaderError.invalidHeader
                }
                
                let nlist = data.advanced(by: currentOffset).withUnsafeBytes { ptr -> NList in
                    ptr.load(as: NList.self)
                }
                
                let symbol = try createSymbol(from: nlist)
                symbols.append(symbol)
                
                currentOffset += MemoryLayout<NList>.size
            }
        }
        
        symbolTable = SymbolTable(symbols: symbols, stringTable: stringTable)
        print("Successfully parsed \(symbols.count) symbols")
    }

        
    private func createSymbol(from nlist64: NList64) throws -> Symbol {
        guard let stringTable = self.stringTable,
              Int(nlist64.n_un.n_strx) < stringTable.count else {
            throw MachOLoaderError.invalidSymbol
        }
        
        return Symbol(
            name: stringTable[Int(nlist64.n_un.n_strx)],
            type: nlist64.n_type,
            section: nlist64.n_sect,
            desc: Int16(nlist64.n_desc),
            value: nlist64.n_value
        )
    }
    
    private func createSymbol(from nlist: NList) throws -> Symbol {
        guard let stringTable = self.stringTable,
              Int(nlist.n_strx) < stringTable.count else {
            throw MachOLoaderError.invalidSymbol
        }
        
        return Symbol(
            name: stringTable[Int(nlist.n_strx)],
            type: nlist.n_type,
            section: nlist.n_sect,
            desc: Int16(nlist.n_desc),
            value: UInt64(nlist.n_value)
        )
    }
        
        func getSymbolInfo(symbol: Symbol) -> String {
            var info = "Symbol: \(symbol.name)\n"
            info += "Type: \(getSymbolTypeDescription(type: symbol.type))\n"
            info += "Section: \(symbol.section)\n"
            info += "Value: 0x\(String(format: "%llx", symbol.value))"
            return info
        }
        
        private func getSymbolTypeDescription(type: UInt8) -> String {
            var description = ""
            
            if (type & SymbolType.STAB) != 0 {
                description += "STAB "
            }
            if (type & SymbolType.PEXT) != 0 {
                description += "PEXT "
            }
            if (type & SymbolType.EXT) != 0 {
                description += "EXT "
            }
            
            let basicType = type & SymbolType.TYPE
            switch basicType {
            case SymbolType.UNDF:
                description += "UNDF"
            case SymbolType.ABS:
                description += "ABS"
            case SymbolType.SECT:
                description += "SECT"
            case SymbolType.PBUD:
                description += "PBUD"
            case SymbolType.INDR:
                description += "INDR"
            default:
                description += "UNKNOWN"
            }
            
            return description
        }
    
    
private func parseDysymtabCommand(data: Data, offset: Int) throws {
    // Implementation for dynamic symbol table parsing later
}
    func getSegments() -> [MachOSegment] {
        return segments
    }
    
    func getSections() -> [Any] {
        return sections
    }
    
    func cleanup() {
            print("Cleaning up resources")
            if fileDescriptor != -1 {
                close(fileDescriptor)
                fileDescriptor = -1
            }
            
            if let data = fileData {
                munmap(UnsafeMutableRawPointer(mutating: (data as NSData).bytes), data.count)
                fileData = nil
            }
        }
        
        deinit {
            cleanup()
        }
    }
