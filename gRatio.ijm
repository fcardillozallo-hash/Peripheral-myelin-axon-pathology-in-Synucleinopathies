// Set the folder path containing your final labeled images (1=myelin, 2=axon, 0=background)
dir = "/Volumes/MScproject/EM/P326/Labels/";
list = getFileList(dir);

// Prepare results table
run("Clear Results");
row = 0;

for (i = 0; i < list.length; i++) {
    if (endsWith(list[i], ".tif") || endsWith(list[i], ".tiff")) {
        open(dir + list[i]);
        originalFileName = getTitle();
        
        // Get histogram to count pixels by value
        getHistogram(values, counts, 256);
        
        // Count axon pixels (value == 2)
        pixel_count_axon = counts[2];
        
        // Count myelin pixels (value == 1)
        pixel_count_myelin = counts[1];
        
        // Total fiber area = axon + myelin
        pixel_count_axon_myelin = pixel_count_axon + pixel_count_myelin;
        
        // Calculate g-ratio
        g_ratio = sqrt(pixel_count_axon / pixel_count_axon_myelin);
        
     // Extract full sample ID, e.g. "J9314_TB3gB12_M4" from "labels_J9314_TB3gB12_M4_xxxxx.tif"
        parts = split(originalFileName, "_");
        sampleID = parts[1] + "_" + parts[2] + "_" + parts[3];

        // Add to results table
        setResult("Filename", row, originalFileName);
        setResult("ImageID", row, sampleID);
        setResult("g_ratio", row, g_ratio);
        row++;
        
        print(sampleID + " — g-ratio: " + g_ratio);
        
        close();
    }
}

updateResults();

// Save results as CSV
saveAs("Results", dir + "g_ratio_results.csv");