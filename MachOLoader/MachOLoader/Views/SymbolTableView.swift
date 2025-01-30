//
//  SymbolTableView.swift
//  MachOLoader
//
//  Created by speedy on 1/30/25.
//

import SwiftUI

struct SymbolTableView: View {
    let symbolTable: SymbolTable
    @State private var searchText = ""
    
    var filteredSymbols: [Symbol] {
        if searchText.isEmpty {
            return symbolTable.symbols
        } else {
            return symbolTable.symbols.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                searchBar
                
                List(filteredSymbols, id: \.name) { symbol in
                    SymbolRowView(symbol: symbol)
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Symbol Table")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textSecondary)
            
            TextField("Search symbols", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(Theme.cardBackground)
    }
}

struct SymbolRowView: View {
    let symbol: Symbol
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(symbol.name)
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
            
            HStack {
                Label(
                    "Type: 0x\(String(format: "%02x", symbol.type))",
                    systemImage: "tag.fill"
                )
                
                Spacer()
                
                Label(
                    "0x\(String(format: "%llx", symbol.value))",
                    systemImage: "number.circle.fill"
                )
            }
            .font(.system(.subheadline, design: .monospaced))
            .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 8)
        .listRowBackground(Theme.cardBackground)
    }
}
