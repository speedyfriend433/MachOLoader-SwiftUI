//
//  ContentView.swift
//  MachOLoader
//
//  Created by speedy on 1/30/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isShowingFilePicker = false
    @State private var selectedFile: URL?
    @State private var loader = MachOLoader()
    @State private var errorMessage: String?
    @State private var status: String = "Ready"
    @State private var isLoading = false
    @State private var analysisComplete = false
    
    private var hasSymbols: Bool {
        if let symbolTable = loader.getSymbolTable(),
           !symbolTable.symbols.isEmpty {
            print("Valid symbol table found with \(symbolTable.symbols.count) symbols")
            return true
        }
        print("No valid symbols available")
        return false
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        if let selectedFile = selectedFile {
                            fileInfoCard(file: selectedFile)
                        } else {
                            emptyStateView
                        }
                        
                        if let errorMessage = errorMessage {
                            errorCard(message: errorMessage)
                        }
                        
                        if analysisComplete {
                            Text("Analysis Status: Complete")
                                .foregroundColor(.green)
                            
                            if hasSymbols {
                                NavigationLink(destination: SymbolTableView(symbolTable: loader.getSymbolTable()!)) {
                                    symbolTableButton
                                }
                                
                                if let symbolTable = loader.getSymbolTable() {
                                    analysisSummaryCard(symbolCount: symbolTable.symbols.count)
                                }
                            } else {
                                Text("No symbols found in the file")
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.data, .executable]
        ) { result in
            handleFileImport(result)
        }
        .overlay(
            LoadingView(isLoading: $isLoading)
        )
    }
    
    private func analysisSummaryCard(symbolCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Summary")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Symbols Found")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(symbolCount)")
                        .font(.title2)
                        .foregroundColor(Theme.accent)
                }
                
                if let fileSize = selectedFile?.fileSizeString {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("File Size")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        Text(fileSize)
                            .font(.title2)
                            .foregroundColor(Theme.accent)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var symbolTableButton: some View {
        HStack {
            Image(systemName: "list.bullet.rectangle")
            Text("View Symbol Table")
            Spacer()
            Image(systemName: "chevron.right")
        }
        .font(.headline)
        .foregroundColor(Theme.accent)
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.cardBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Mach-O Loader")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            
            Text(status)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(Theme.secondary)
            
            Text("No File Selected")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            
            selectFileButton
        }
        .padding(.vertical, 40)
    }
    
    private func fileInfoCard(file: URL) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.fill")
                    .font(.title2)
                    .foregroundColor(Theme.accent)
                
                Text(file.lastPathComponent)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            Button(action: { loadFile() }) {
                Text("Analyze File")
                    .font(.headline)
            }
            .buttonStyle(ModernButtonStyle(
                backgroundColor: Theme.accent,
                foregroundColor: .white
            ))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.error)
                Text("Error")
                    .font(.headline)
                    .foregroundColor(Theme.error)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.error.opacity(0.1))
        )
    }
    
    private var selectFileButton: some View {
        Button(action: { isShowingFilePicker = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Select Mach-O File")
            }
            .font(.headline)
        }
        .buttonStyle(ModernButtonStyle(
            backgroundColor: Theme.primary,
            foregroundColor: .white
        ))
    }
    
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let file):
            selectedFile = file
            status = "File selected: \(file.lastPathComponent)"
            errorMessage = nil
        case .failure(let error):
            errorMessage = "Error selecting file: \(error.localizedDescription)"
            status = "Error selecting file"
        }
    }
    
    private func loadFile() {
        guard let path = selectedFile?.path else {
            errorMessage = "No file selected"
            return
        }
        
        isLoading = true
        status = "Analyzing file..."
        analysisComplete = false
        
        print("Starting file analysis: \(path)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try loader.load(path: path)
                
                DispatchQueue.main.async {
                    if loader.getSymbolTable() != nil {
                        print("Analysis complete with symbols")
                        status = "File analyzed successfully with symbols"
                    } else {
                        print("Analysis complete but no symbols found")
                        status = "File analyzed successfully but no symbols found"
                    }
                    errorMessage = nil
                    isLoading = false
                    analysisComplete = true
                }
            } catch let error as MachOLoader.MachOLoaderError {
                DispatchQueue.main.async {
                    print("Analysis failed with error: \(error.description)")
                    errorMessage = "Error analyzing file: \(error.description)"
                    status = "Analysis failed"
                    isLoading = false
                    analysisComplete = false
                }
            } catch {
                DispatchQueue.main.async {
                    print("Unexpected error during analysis: \(error)")
                    errorMessage = "Unexpected error: \(error.localizedDescription)"
                    status = "Analysis failed"
                    isLoading = false
                    analysisComplete = false
                }
            }
        }
    }
}

extension URL {
    var fileSizeString: String? {
        guard let resources = try? resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = resources.fileSize else {
            return nil
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


#Preview {
    ContentView()
}
