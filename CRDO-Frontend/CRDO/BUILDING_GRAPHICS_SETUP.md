# Building Graphics Setup Guide

## Overview
This guide explains how to add custom graphics for each building type in the CRDO city builder.

## Image Requirements

### File Format
- **Format**: PNG or JPEG
- **Transparency**: PNG with transparent background recommended
- **Resolution**: At least 60x60 pixels (will be scaled down)

### Image Sizes Needed
For each building type, you need 3 versions:
- **1x**: 30x30 pixels (for standard displays)
- **2x**: 60x60 pixels (for Retina displays)
- **3x**: 90x90 pixels (for high-DPI displays)

## Building Types and Image Names

### 1. House (BuildingHouse)
- **File**: `BuildingHouse.png`
- **Description**: Cozy residential house
- **Style**: Single-family home with roof, windows, door
- **Color**: Warm, inviting colors

### 2. Park (BuildingPark)
- **File**: `BuildingPark.png`
- **Description**: Green space with trees and benches
- **Style**: Park with trees, grass, maybe a fountain
- **Color**: Green and natural tones

### 3. Office (BuildingOffice)
- **File**: `BuildingOffice.png`
- **Description**: Modern office building
- **Style**: Corporate building with windows, maybe a logo
- **Color**: Blue/gray professional colors

### 4. Mall (BuildingMall)
- **File**: `BuildingMall.png`
- **Description**: Shopping center
- **Style**: Large building with storefronts, parking
- **Color**: Bright, commercial colors

### 5. Skyscraper (BuildingSkyscraper)
- **File**: `BuildingSkyscraper.png`
- **Description**: Tall office tower
- **Style**: Modern glass tower reaching high
- **Color**: Silver/blue modern colors

### 6. Monument (BuildingMonument)
- **File**: `BuildingMonument.png`
- **Description**: Landmark structure
- **Style**: Iconic monument or statue
- **Color**: Gold/bronze or distinctive colors

## How to Add Images

### Option 1: Using Xcode
1. Open the project in Xcode
2. Navigate to `CRDO/Assets.xcassets`
3. For each building type:
   - Click on the building's imageset folder
   - Drag and drop your image files into the appropriate scale slots
   - Make sure the image names match exactly (e.g., `BuildingHouse.png`)

### Option 2: Manual File Addition
1. Navigate to the appropriate imageset folder:
   ```
   CRDO-Frontend/CRDO/Assets.xcassets/BuildingHouse.imageset/
   CRDO-Frontend/CRDO/Assets.xcassets/BuildingPark.imageset/
   CRDO-Frontend/CRDO/Assets.xcassets/BuildingOffice.imageset/
   CRDO-Frontend/CRDO/Assets.xcassets/BuildingMall.imageset/
   CRDO-Frontend/CRDO/Assets.xcassets/BuildingSkyscraper.imageset/
   CRDO-Frontend/CRDO/Assets.xcassets/BuildingMonument.imageset/
   ```

2. Add your image files to each folder
3. Update the `Contents.json` file to reference your images

## Design Tips

### Style Guidelines
- **Consistent Style**: All buildings should have a similar art style
- **Simple but Detailed**: Clear enough to recognize at small sizes
- **Color Coding**: Each building type should have distinct colors
- **Transparent Background**: PNG with transparency works best

### Recommended Tools
- **Adobe Illustrator**: For vector graphics
- **Photoshop**: For detailed raster graphics
- **Figma/Sketch**: For modern design
- **Free Alternatives**: GIMP, Inkscape, Canva

### Color Palette Suggestions
- **House**: Warm browns, beige, red roofs
- **Park**: Greens, browns, natural colors
- **Office**: Blues, grays, professional tones
- **Mall**: Bright colors, commercial feel
- **Skyscraper**: Silver, blue, modern grays
- **Monument**: Gold, bronze, distinctive colors

## Testing Your Graphics

1. Add your images to the appropriate folders
2. Build and run the app
3. Go to the City tab
4. Check that the building cards show your custom graphics
5. Place buildings and verify they display correctly in the city grid

## Troubleshooting

### Images Not Showing
- Check file names match exactly (case-sensitive)
- Verify images are in the correct folders
- Ensure `Contents.json` files are properly formatted
- Clean and rebuild the project

### Poor Quality
- Use higher resolution source images
- Ensure proper scaling for different screen densities
- Test on actual devices, not just simulator

### Performance Issues
- Optimize image file sizes
- Use appropriate compression
- Consider using vector graphics where possible

## Next Steps

Once you've added your custom graphics:
1. Test on different devices and screen sizes
2. Adjust image sizes if needed
3. Consider adding animations or effects
4. Maybe add different building variations for variety

## Example Image Specifications

### BuildingHouse.png
- **Size**: 60x60 pixels
- **Style**: Isometric house with roof, door, windows
- **Colors**: Brown roof, beige walls, green lawn
- **Details**: Chimney, front door, 2-3 windows

### BuildingPark.png
- **Size**: 60x60 pixels
- **Style**: Top-down park view
- **Colors**: Green grass, brown trees, blue water
- **Details**: Trees, benches, maybe a fountain

This setup will give you a much more professional and visually appealing city builder experience! 