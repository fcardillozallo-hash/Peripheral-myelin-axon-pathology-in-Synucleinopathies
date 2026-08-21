var row, gAvgArea;   // row: shared results row index; gAvgArea: lets meanCTCF hand back avg area too

//open files from directory in loop and save
macro "Myelin_threshold_batch [a]" {
    inputDir = "/Users/Cesca/Desktop/RAw data/P726 split scenes/";
    outputDir = "/Users/Cesca/Desktop/Flourescence Data/MBP_NFL_NFH/P726/";   // <-- update per patient if needed
    File.makeDirectory(outputDir);

    fileList = getFileList(inputDir);

    for (f = 0; f < fileList.length; f++) {
        if (!endsWith(fileList[f], ".czi")) continue;   // skip anything that isn't a .czi file

        run("Bio-Formats Importer", "open=[" + inputDir + fileList[f] + "] color_mode=Composite view=Hyperstack stack_order=XYCZT");
        waitForUser("Draw your BACKGROUND (cell-free) selection on this image, then click OK");
        processImage(outputDir);

        close("*");
        roiManager("reset");
        run("Clear Results");
    }

    showMessage("Batch complete", "All files in the folder have been processed.");
}

function processImage(outputDir) {
    run("Set Measurements...", "area mean min max integrated");
    run("Clear Results");
    row = 0;

    if (selectionType() == -1)
        exit("Draw a background (cell-free) selection first, then run the macro.");
    roiManager("reset");
    roiManager("Add");
    roiManager("Select", 0);
    roiManager("Rename", "Background");
    bgIndex = 0;

    base = getTitle();
    getDimensions(w, h, channels, slices, frames);

    // ---- CALIBRATION CHECK: on the original, before any splitting/cropping ----
    getPixelSize(unit0, pw0, ph0);
    print("ORIGINAL image calibration: " + pw0 + " x " + ph0 + " " + unit0);

    // ---- pick the in-focus slice range ONCE, on the original composite stack ----
    run("Select None");
    Stack.setDisplayMode("composite");
    waitForUser("Scroll through the stack, note the first/last IN-FOCUS slice, then click OK");
    Dialog.create("Focus range");
    Dialog.addNumber("Start slice (first in-focus):", 1);
    Dialog.addNumber("Stop slice (last in-focus):", slices);
    Dialog.show();
    startSlice = Dialog.getNumber();
    stopSlice  = Dialog.getNumber();
    croppedSlices = stopSlice - startSlice + 1;

    run("Split Channels");
    selectWindow("C4-" + base);
    close();
    for (c = 1; c <= channels; c++) {
        if (c == 4) continue;
        orig = "C" + c + "-" + base;
        selectWindow(orig);

        // ---- CALIBRATION CHECK: right after split, before crop (only printed for C1) ----
        if (c == 1) {
            getPixelSize(unitA, pwA, phA);
            print("BEFORE crop - C1: " + pwA + " x " + phA + " " + unitA);
        }

        run("Duplicate...", "duplicate range=" + startSlice + "-" + stopSlice);
        rename("Cropped_" + orig);
        close(orig);
        selectWindow("Cropped_" + orig);
        rename(orig);

        // ---- CALIBRATION CHECK: right after crop/rename (only printed for C1) ----
        if (c == 1) {
            getPixelSize(unitB, pwB, phB);
            print("AFTER crop - C1: " + pwB + " x " + phB + " " + unitB);
        }

        run("Z Project...", "projection=[Max Intensity]");
    }

    // ---- build a composite of the Z-projected channels ONLY (no C4) to draw the AOI on ----
    selectWindow("MAX_C1-" + base); rename("MC1_temp");
    selectWindow("MAX_C2-" + base); rename("MC2_temp");
    selectWindow("MAX_C3-" + base); rename("MC3_temp");

    run("Merge Channels...", "c1=MC1_temp c2=MC2_temp c3=MC3_temp create keep");
    rename("AOI_composite");
    Stack.setDisplayMode("composite");
    waitForUser("Now draw your AREA OF INTEREST on the Z-projected composite, then click OK");
    roiManager("Add");
    aoiIndex = roiManager("count") - 1;
    roiManager("Select", aoiIndex);
    roiManager("Rename", "AreaOfInterest");
    close("AOI_composite");

    selectWindow("MC1_temp"); rename("MAX_C1-" + base);
    selectWindow("MC2_temp"); rename("MAX_C2-" + base);
    selectWindow("MC3_temp"); rename("MAX_C3-" + base);

    // ---- Channel 1 ----
    selectWindow("MAX_C1-" + base);
    run("Gaussian Blur...", "sigma=0.5");
    setAutoThreshold("Triangle dark no-reset");
    setOption("BlackBackground", true);
    run("Convert to Mask");
    run("Median...", "radius=0.1");

    roiManager("Select", aoiIndex);
    run("Clear Outside");
    run("Select None");

    run("Analyze Particles...", "size=5-Infinity pixel circularity=0.00-0.90 show=Masks");
    rename("FilteredMask_C1");
    run("Invert LUT");
    run("Create Selection");
    if (selectionType() == -1)
        exit("No particles passed the filter for C1 — mask is empty.");
    roiManager("Add");
    cell1 = roiManager("count") - 1;
    roiManager("Select", cell1);
    roiManager("Rename", "C1");
    selectWindow("MAX_C1-" + base);

    bg1 = addBackgroundCopy(bgIndex, "Background_C1");

    // ---- CALIBRATION CHECK: right at the point of measurement ----
    selectWindow("C1-" + base);
    getPixelSize(unitC, pwC, phC);
    print("AT MEASUREMENT - C1: " + pwC + " x " + phC + " " + unitC);

    ctcf1 = meanCTCF("C1-" + base, cell1, bg1, croppedSlices, "C1");
    area1 = gAvgArea;
    print("C1 CTCF (from Z-averaged values) = " + ctcf1);
    print("C1 average area = " + area1);

    // ---- Channel 2 ----
    selectWindow("MAX_C2-" + base);
    run("Gaussian Blur...", "sigma=0.5");
    setAutoThreshold("Li dark no-reset");
    setOption("BlackBackground", true);
    run("Convert to Mask");
    run("Median...", "radius=0.1");

    roiManager("Select", aoiIndex);
    run("Clear Outside");
    run("Select None");

    run("Analyze Particles...", "size=5-Infinity pixel circularity=0.00-0.80 show=Masks");
    rename("FilteredMask_C2");
    run("Invert LUT");
    run("Create Selection");
    if (selectionType() == -1)
        exit("No particles passed the filter for C2 — mask is empty.");
    roiManager("Add");
    cell2 = roiManager("count") - 1;
    roiManager("Select", cell2);
    roiManager("Rename", "C2");
    selectWindow("MAX_C2-" + base);

    bg2 = addBackgroundCopy(bgIndex, "Background_C2");
    ctcf2 = meanCTCF("C2-" + base, cell2, bg2, croppedSlices, "C2");
    area2 = gAvgArea;
    print("C2 CTCF (from Z-averaged values) = " + ctcf2);

    // ---- Channel 3 ----
    selectWindow("MAX_C3-" + base);
    run("Gaussian Blur...", "sigma=0.5");
    setAutoThreshold("Triangle dark no-reset");
    setOption("BlackBackground", true);
    run("Convert to Mask");
    run("Median...", "radius=0");

    roiManager("Select", aoiIndex);
    run("Clear Outside");
    run("Select None");

    run("Analyze Particles...", "size=2-Infinity pixel circularity=0.00-0.90 show=Masks");
    rename("FilteredMask_C3");
    run("Invert LUT");
    run("Create Selection");
    if (selectionType() == -1)
        exit("No particles passed the filter for C3 — mask is empty.");
    roiManager("Add");
    cell3 = roiManager("count") - 1;
    roiManager("Select", cell3);
    roiManager("Rename", "C3");
    selectWindow("MAX_C3-" + base);

    bg3 = addBackgroundCopy(bgIndex, "Background_C3");
    ctcf3 = meanCTCF("C3-" + base, cell3, bg3, croppedSlices, "C3");
    area3 = gAvgArea;
    print("C3 CTCF (from Z-averaged values) = " + ctcf3);

    // ---- append ONE summary row at the bottom with all six values as separate columns ----
    setResult("Channel",  row, "SUMMARY");
    setResult("C1 Area",  row, area1);
    setResult("C2 Area",  row, area2);
    setResult("C3 Area",  row, area3);
    setResult("C1 CTCF",  row, ctcf1);
    setResult("C2 CTCF",  row, ctcf2);
    setResult("C3 CTCF",  row, ctcf3);
    row++;
    updateResults();

    // ---- single check, after ALL channels are done, before anything closes ----
    waitForUser("Check FilteredMask_C1 / C2 / C3 (and MAX_C1/C2/C3) now, then click OK to save and continue");

    roiManager("Select", bgIndex);
    roiManager("Delete");

    saveAs("Results", outputDir + base + "_CTCF.csv");
}

function addBackgroundCopy(bgSource, newName) {
    roiManager("Select", bgSource);
    roiManager("Add");
    idx = roiManager("count") - 1;
    roiManager("Select", idx);
    roiManager("Rename", newName);
    return idx;
}

function meanCTCF(imgName, cellROI, bgROI, slices, label) {
    sumArea = 0;
    sumIntDen = 0;
    sumBgMean = 0;

    for (s = 1; s <= slices; s++) {
        selectWindow(imgName);
        setSlice(s);

        roiManager("Select", cellROI);
        area   = getValue("Area");
        intden = getValue("IntDen");

        roiManager("Select", bgROI);
        bgMean = getValue("Mean");

        sumArea   += area;
        sumIntDen += intden;
        sumBgMean += bgMean;

        setResult("Channel", row, label);
        setResult("Slice",   row, s);
        setResult("Area",    row, area);
        setResult("IntDen",  row, intden);
        setResult("BgMean",  row, bgMean);
        row++;

        print(label + " slice " + s + ": Area = " + area + ", IntDen = " + intden + ", bgMean = " + bgMean);
    }

    avgArea   = sumArea / slices;
    avgIntDen = sumIntDen / slices;
    avgBgMean = sumBgMean / slices;

    gAvgArea = avgArea;
    return avgIntDen - (avgArea * avgBgMean);
}