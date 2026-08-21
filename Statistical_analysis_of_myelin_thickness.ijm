// Set the folder path containing your Local Thickness output images
dir = "/Volumes/MSc project/P626/Labels/thickness/";
list = getFileList(dir);

// Set up measurements: mean and std dev, limited to thresholded (non-zero) pixels
run("Set Measurements...", "mean standard limit redirect=None decimal=3");

// Clear any old results
run("Clear Results");

for (i = 0; i < list.length; i++) {
    if (endsWith(list[i], ".tif") || endsWith(list[i], ".tiff")) {
        open(dir + list[i]);
        
        // Read the calibrated pixel size from the image itself
        getVoxelSize(pw, ph, pd, unit);
        
        // Threshold to exclude background (value 0) — measures only "damaged"/thickness pixels
        setThreshold(1, 65535);
        
        // Measure mean and std dev of thresholded pixels only
        run("Measure");
        
        // Convert results from pixel units to calibrated real-world units
        row = nResults - 1;
        meanVal = getResult("Mean", row) * pw;
        stdVal = getResult("StdDev", row) * pw;
        setResult("Mean", row, meanVal);
        setResult("StdDev", row, stdVal);
        setResult("Unit", row, unit);
        
         // Save the full filename in its own column
        setResult("Filename", row, list[i]);
        
        // Extract short filename (part before first "_"), matching your MATLAB "shortfileName" logic
        parts = split(list[i], "_");
        setResult("Label", row, parts[0]);
        
        close();
    }
}

// Save results table as CSV — ready to open directly in Prism
saveAs("Results", dir + "thickness_results.csv");