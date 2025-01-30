//
//  LoaderView.swift
//  MachOLoader
//
//  Created by speedy on 1/30/25.
//

import SwiftUI

struct LoaderView: View {
    let loader: MachOLoader
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Segments")
                    .font(.headline)
                    .padding(.vertical)
                
                ForEach(loader.getSegments(), id: \.segname) { segment in
                    SegmentView(segment: segment)
                        .padding(.bottom)
                }
                
                Text("Sections")
                    .font(.headline)
                    .padding(.vertical)
                
                ForEach(0..<loader.getSections().count, id: \.self) { index in
                    if let section64 = loader.getSections()[index] as? Section64 {
                        Section64View(section: section64)
                            .padding(.bottom)
                    } else if let section32 = loader.getSections()[index] as? Section32 {
                        Section32View(section: section32)
                            .padding(.bottom)
                    }
                }
            }
            .padding()
        }
    }
}

struct SegmentView: View {
    let segment: MachOSegment
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Segment: \(segment.segname)")
                .font(.subheadline)
            Text("VM Address: 0x\(String(format: "%llx", segment.vmaddr))")
            Text("VM Size: \(segment.vmsize)")
            Text("File Offset: \(segment.fileoff)")
            Text("File Size: \(segment.filesize)")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct Section64View: View {
    let section: Section64
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Section: \(section.sectname)")
                .font(.subheadline)
            Text("Segment: \(section.segname)")
            Text("Address: 0x\(String(format: "%llx", section.addr))")
            Text("Size: \(section.size)")
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct Section32View: View {
    let section: Section32
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Section: \(section.sectname)")
                .font(.subheadline)
            Text("Segment: \(section.segname)")
            Text("Address: 0x\(String(format: "%x", section.addr))")
            Text("Size: \(section.size)")
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}
