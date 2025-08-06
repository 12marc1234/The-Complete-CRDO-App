//
//  CityView.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//

import SwiftUI

struct CityView: View {
    @ObservedObject var cityManager = CityManager.shared
    @ObservedObject var gemsManager = GemsManager.shared
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var showingSaveAlert = false
    @State private var showingEditMode = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Enhanced background
                LinearGradient.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Building selection panel
                    BuildingSelectionPanel()
                    
                    // City grid
                    CityGrid()
                }
            }
            .navigationTitle("City")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button(action: {
                            cityManager.undo()
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundColor(.white)
                        }
                        .disabled(!cityManager.canUndo)
                        
                        Button(action: {
                            cityManager.redo()
                        }) {
                            Image(systemName: "arrow.uturn.forward")
                                .foregroundColor(.white)
                        }
                        .disabled(!cityManager.canRedo)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showingEditMode.toggle()
                        }) {
                            Image(systemName: showingEditMode ? "checkmark.circle.fill" : "pencil")
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            cityManager.saveCity()
                            showingSaveAlert = true
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .alert("City Saved!", isPresented: $showingSaveAlert) {
                Button("OK") { }
            }
        }
    }
}

struct BuildingSelectionPanel: View {
    @ObservedObject var cityManager = CityManager.shared
    @ObservedObject var gemsManager = GemsManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // Clean gems display
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    
                    Text("\(gemsManager.totalGems)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Compact building selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BuildingType.allCases, id: \.self) { buildingType in
                        CompactBuildingCard(buildingType: buildingType)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.4),
                    Color.clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct BuildingCard: View {
    @ObservedObject var cityManager = CityManager.shared
    @ObservedObject var gemsManager = GemsManager.shared
    let buildingType: BuildingType
    @State private var showingPurchaseAlert = false
    @State private var purchaseError = ""
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Enhanced 3D building preview
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                buildingType.color.opacity(0.9),
                                buildingType.color.opacity(0.7),
                                buildingType.color.opacity(0.5)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 2, y: 2)
                
                // Realistic building icon
                Image(buildingType.realisticIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                
                // Add depth effect
                RoundedRectangle(cornerRadius: 12)
                    .stroke(buildingType.color.opacity(0.8), lineWidth: 1)
                    .frame(width: 50, height: 50)
            }
            
            Text(buildingType.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "diamond.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                
                Text("\(buildingType.cost)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onTapGesture {
            if gemsManager.totalGems >= buildingType.cost {
                cityManager.selectedBuildingType = buildingType
                cityManager.isPlacingBuilding = true
            } else {
                purchaseError = "Not enough gems! You need \(buildingType.cost) gems but only have \(gemsManager.totalGems)."
                showingPurchaseAlert = true
            }
        }
        .scaleEffect(cityManager.selectedBuildingType == buildingType ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: cityManager.selectedBuildingType)
        .alert("Purchase Failed", isPresented: $showingPurchaseAlert) {
            Button("OK") { }
        } message: {
            Text(purchaseError)
        }
    }
}

struct CompactBuildingCard: View {
    @ObservedObject var cityManager = CityManager.shared
    @ObservedObject var gemsManager = GemsManager.shared
    let buildingType: BuildingType
    @State private var showingPurchaseAlert = false
    @State private var purchaseError = ""
    
    var body: some View {
        HStack(spacing: 8) {
            // Compact building icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                buildingType.color.opacity(0.8),
                                buildingType.color.opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                
                Image(buildingType.realisticIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0.5)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(buildingType.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                HStack(spacing: 3) {
                    Image(systemName: "diamond.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    
                    Text("\(buildingType.cost)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            cityManager.selectedBuildingType == buildingType ? 
                            buildingType.color.opacity(0.6) : Color.white.opacity(0.15),
                            lineWidth: cityManager.selectedBuildingType == buildingType ? 2 : 1
                        )
                )
        )
        .onTapGesture {
            if gemsManager.totalGems >= buildingType.cost {
                cityManager.selectedBuildingType = buildingType
                cityManager.isPlacingBuilding = true
            } else {
                purchaseError = "Not enough gems! You need \(buildingType.cost) gems but only have \(gemsManager.totalGems)."
                showingPurchaseAlert = true
            }
        }
        .scaleEffect(cityManager.selectedBuildingType == buildingType ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: cityManager.selectedBuildingType)
        .alert("Purchase Failed", isPresented: $showingPurchaseAlert) {
            Button("OK") { }
        } message: {
            Text(purchaseError)
        }
    }
}

struct CityGrid: View {
    @ObservedObject var cityManager = CityManager.shared
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var selectedBuilding: Building?
    
    var body: some View {
        GeometryReader { geometry in
            CityGridContent(
                geometry: geometry,
                dragLocation: $dragLocation,
                isDragging: $isDragging,
                selectedBuilding: $selectedBuilding
            )
        }
    }
}

struct CityGridContent: View {
    @ObservedObject var cityManager = CityManager.shared
    let geometry: GeometryProxy
    @Binding var dragLocation: CGPoint
    @Binding var isDragging: Bool
    @Binding var selectedBuilding: Building?
    
    var body: some View {
        ZStack {
            // Grid background
            GridBackground()
            
            // Placed buildings
            ForEach(cityManager.buildings) { building in
                BuildingView(building: building)
                    .position(building.position)
                    .onTapGesture {
                        // Select building for moving
                        selectedBuilding = building
                        cityManager.isPlacingBuilding = true
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if selectedBuilding?.id == building.id {
                                    dragLocation = value.location
                                    isDragging = true
                                }
                            }
                            .onEnded { value in
                                if selectedBuilding?.id == building.id {
                                    let position = value.location
                                    
                                    // Ensure position is within bounds
                                    let clampedPosition = CGPoint(
                                        x: max(building.type.size.width/2, min(geometry.size.width - building.type.size.width/2, position.x)),
                                        y: max(building.type.size.height/2, min(geometry.size.height - building.type.size.height/2, position.y))
                                    )
                                    
                                    // Update building position
                                    if let index = cityManager.buildings.firstIndex(where: { $0.id == building.id }) {
                                        cityManager.buildings[index].position = clampedPosition
                                        cityManager.saveCityData()
                                    }
                                    
                                    selectedBuilding = nil
                                    cityManager.isPlacingBuilding = false
                                    isDragging = false
                                }
                            }
                    )
            }
            
            // Dragging preview for new buildings
            if cityManager.isPlacingBuilding, let selectedType = cityManager.selectedBuildingType, selectedBuilding == nil {
                BuildingView(building: Building(type: selectedType, position: dragLocation))
                    .position(dragLocation)
                    .opacity(0.7)
            }
            
            // Dragging preview for existing buildings
            if let selectedBuilding = selectedBuilding, isDragging {
                BuildingView(building: selectedBuilding)
                    .position(dragLocation)
                    .opacity(0.7)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if cityManager.isPlacingBuilding && selectedBuilding == nil {
                        dragLocation = value.location
                        isDragging = true
                    }
                }
                .onEnded { value in
                    if cityManager.isPlacingBuilding, let selectedType = cityManager.selectedBuildingType, selectedBuilding == nil {
                        let position = value.location
                        
                        // Ensure position is within bounds
                        let clampedPosition = CGPoint(
                            x: max(selectedType.size.width/2, min(geometry.size.width - selectedType.size.width/2, position.x)),
                            y: max(selectedType.size.height/2, min(geometry.size.height - selectedType.size.height/2, position.y))
                        )
                        
                        if cityManager.purchaseBuilding(selectedType, at: clampedPosition) {
                            print("🏗️ Building purchased: \(selectedType.rawValue) at \(clampedPosition)")
                        }
                        
                        cityManager.isPlacingBuilding = false
                        cityManager.selectedBuildingType = nil
                        isDragging = false
                    }
                }
        )
        .onTapGesture {
            if cityManager.isPlacingBuilding && selectedBuilding == nil {
                cityManager.isPlacingBuilding = false
                cityManager.selectedBuildingType = nil
            }
            selectedBuilding = nil
        }
    }
}

struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 50
            
            // Draw grid lines
            for x in stride(from: 0, through: size.width, by: gridSize) {
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 0.5)
            }
            
            for y in stride(from: 0, through: size.height, by: gridSize) {
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 0.5)
            }
        }
        .background(Color.black.opacity(0.2))
    }
}

struct BuildingView: View {
    let building: Building
    
    var body: some View {
        // Just the building image, clean and simple
        Image(building.type.realisticIcon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: building.type.size.width * 0.8, height: building.type.size.height * 0.8)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
    }
}

#Preview {
    CityView()
} 