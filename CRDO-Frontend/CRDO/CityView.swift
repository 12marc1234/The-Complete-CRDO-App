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
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.black.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
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
        }
    }
}

struct BuildingSelectionPanel: View {
    @ObservedObject var cityManager = CityManager.shared
    @ObservedObject var gemsManager = GemsManager.shared
    
    var body: some View {
        VStack(spacing: 15) {
            // Gems display
            HStack {
                Image(systemName: "diamond.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                Text("\(gemsManager.totalGems)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Building types
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(BuildingType.allCases, id: \.self) { buildingType in
                        BuildingCard(buildingType: buildingType)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color.black.opacity(0.5))
    }
}

struct BuildingCard: View {
    @ObservedObject var cityManager = CityManager.shared
    @ObservedObject var gemsManager = GemsManager.shared
    let buildingType: BuildingType
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // 3D building preview
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
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                
                Image(systemName: buildingType.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
            
            Text(buildingType.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "diamond.fill")
                    .foregroundColor(.yellow)
                    .font(.caption2)
                
                Text("\(buildingType.cost)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            cityManager.canPurchaseBuilding(buildingType) ? Color.black.opacity(0.4) : Color.red.opacity(0.4),
                            cityManager.canPurchaseBuilding(buildingType) ? Color.black.opacity(0.2) : Color.red.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(buildingType.color.opacity(0.6), lineWidth: 1.5)
                        .shadow(color: buildingType.color.opacity(0.3), radius: 2, x: 0, y: 0)
                )
        )
        .onTapGesture {
            if cityManager.canPurchaseBuilding(buildingType) {
                cityManager.selectedBuildingType = buildingType
                cityManager.isPlacingBuilding = true
            }
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
        VStack(spacing: 2) {
            ZStack {
                // 3D building base
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                building.type.color.opacity(0.8),
                                building.type.color.opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: building.type.size.width, height: building.type.size.height)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                
                // Building icon
                Image(systemName: building.type.icon)
                    .font(.system(size: building.type.size.width * 0.5))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
            
            // Building name with better styling
            Text(building.type.rawValue)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
        }
        .frame(width: building.type.size.width, height: building.type.size.height + 20)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(building.type.color.opacity(0.8), lineWidth: 2)
                        .shadow(color: building.type.color.opacity(0.3), radius: 2, x: 0, y: 0)
                )
        )
    }
}

#Preview {
    CityView()
} 