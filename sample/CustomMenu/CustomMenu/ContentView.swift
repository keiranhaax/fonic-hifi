//
//  ContentView.swift
//  CustomMenu
//
//  Created by Balaji Venkatesh on 20/09/25.
//

import SwiftUI

struct ContentView: View {
    @State private var type: CustomMenuStyle = .glass
    @State private var interactiveDismiss: Bool = false
    var body: some View {
        /// Dummy UI
        ScrollView(.vertical) {
            VStack(spacing: 25) {
                RoundedRectangle(cornerRadius: 30)
                    .fill(.gray.opacity(0.15))
                    .frame(height: 180)
                    .overlay(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Usage:")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                                .underline()
                            
                            Text(
                                """
                                CustomMenuView(style) {
                                    
                                } content: {
                                    
                                }
                                """
                            )
                            .monospaced()
                        }
                        .padding(15)
                        .padding(.leading, 10)
                    }
                
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Transaction History")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("12 Jun 2025 - 20 Sep 2025")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    /// Custom Menu
                    CustomMenuView(style: type) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .frame(width: 40, height: 30)
                    } content: {
                        DateFilterView()
                            .interactiveDismissDisabled(interactiveDismiss)
                    }
                }
                
                Picker("", selection: $type) {
                    ForEach(CustomMenuStyle.allCases, id: \.self) {
                        Text($0.rawValue)
                            .tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                Toggle("Interactive Dismiss Disabled", isOn: $interactiveDismiss)
            }
            .padding(15)
            .padding(.bottom, 600)
        }
    }
}

/// A Custom Date Filter View Sample UI
struct DateFilterView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            Text("Filter Date Range")
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
            
            DatePicker("Start Date", selection: .constant(.now), displayedComponents: [.date])
                .datePickerStyle(.compact)
                .font(.caption)
            
            DatePicker("End Date", selection: .constant(.now), displayedComponents: [.date])
                .datePickerStyle(.compact)
                .font(.caption)
            
            VStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Text("Apply")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .tint(.blue)
                .buttonStyle(.glassProminent)

                Text("Maximum Range is 1 Year!")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .padding(.top, 15)
        }
        .padding(15)
        .frame(width: 250, height: 250)
    }
}

#Preview {
    ContentView()
}
