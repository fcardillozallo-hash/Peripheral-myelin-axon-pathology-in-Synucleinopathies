// Get the title of the current image to be labeled
originalTitle = getTitle();

// Manually set the correct calibration on the original image
pw = 0.575;   // pixel width in nm
ph = 0.575;   // pixel height in nm
pd = 1;      // pixel depth (1 for 2D images)
unit = "nm";

setVoxelSize(pw, ph, pd, unit);

// Set the path where the labels directory should be created
NewdirPath = "/Volumes/MScproject/EM/P326/Labels/";

// Create the directory if it doesn't already exist, and confirm
if (!File.exists(NewdirPath)) {
    File.makeDirectory(NewdirPath);
    print("Created directory: " + NewdirPath);
} else {
    print("Directory already exists: " + NewdirPath);
}

// Create an 8-bit black image the same size as the original
newImage(originalTitle, "8-bit black", getWidth(), getHeight(), 1);

// Apply the calibration to the new labeled image
setVoxelSize(pw, ph, pd, unit);

// Add all the ROIs to the black image by grouping them in triplets
// Fills from largest area to smallest area: Outside Myelin -> Inside Myelin -> Outside Axon
for (i = 0; i < roiManager("count"); i += 3) {
    
    // 1. Draw Outside Myelin (Largest - Base Layer)
    roiManager("select", i);       // Your 1st manual drawing
    setColor(i + 1); 
    fill();
    
    // 2. Draw Inside Myelin (Middle Layer - Paints over the base)
    if (i + 2 < roiManager("count")) {
        roiManager("select", i + 2);   // Your 3rd manual drawing
        setColor(i + 3); 
        fill();
    }
    
    // 3. Draw Outside Axon (Smallest Layer - Paints safely on top of everything)
    if (i + 1 < roiManager("count")) {
        roiManager("select", i + 1);   // Your 2nd manual drawing
        setColor(i + 2); 
        fill();
    }
}

// Stretch display range to actual label range
setMinAndMax(0, roiManager("count"));

// Get rid of ROI selection on image
run("Select None");

// Scale the image down by a factor of 10 (nearest-neighbor to preserve label values)
run("Scale...", "x=0.1 y=0.1 width=" + (getWidth()/10) + " height=" + (getHeight()/10) + " interpolation=None create title=" + originalTitle + "_scaled.tif");

// Update calibration to reflect the new pixel size (each pixel covers 10x linear distance)
setVoxelSize(pw*10, ph*10, pd, unit);

// Save into the labels folder, prefixed with "labels_"
saveAs("Tiff", NewdirPath + "labels_" + originalTitle);
