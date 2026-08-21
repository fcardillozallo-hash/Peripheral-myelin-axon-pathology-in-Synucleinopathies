// ============================================================
// Fiji macro (IJM): starting from your ORIGINAL tile images,
// group by myelin section, prep the tiles (8-bit + contrast),
// then test several overlap % values per section automatically,
// saving each result separately for you to compare.
//
// HOW TO RUN: File > Open... this file in Fiji, then click Run.
// ============================================================

// ---- Which overlap percentages to try ----
// The script will attempt each of these values in turn for every
// myelin section, so you end up with one output file per value.
// Add or remove numbers here if you want to test a wider or
// narrower range.
overlapsToTest = newArray(10, 15, 20, 25, 30, 35);

// ---- Ask where your raw tiles are, and where to save results ----
// getDirectory() pops up a normal folder-picker window.
inputDir = getDirectory("Choose the folder containing ALL tile images (.tif)");
outputDir = getDirectory("Choose a folder to save the test results");

// This script creates a working folder called "_stitch_temp" next to
// your raw tiles, where it stores the renamed/prepped copies of each
// tile before stitching. It's created once and reused across runs.
tempRoot = inputDir + "_stitch_temp" + File.separator;
if (!File.exists(tempRoot)) File.makeDirectory(tempRoot);

// getFileList() returns the names of every file/folder in inputDir.
allFiles = getFileList(inputDir);

// ------------------------------------------------------------
// STEP 1: Scan every filename and work out which myelin section
// it belongs to, and its position in that section's tile sequence.
//
// Expected filename pattern: ..._M<number>_<tileindex>_....tif
// e.g. J9314_TB3gB12_M1_1_FCZ77269.tif -> group "..._M1", tile #1
//
// We use three parallel arrays (rather than a dictionary, which
// the macro language doesn't support) to record, for every matched
// file: which group it belongs to, its tile number, and its filename.
// ------------------------------------------------------------
allKeys = newArray(0);
allTileIdx = newArray(0);
allFnames = newArray(0);

for (i = 0; i < allFiles.length; i++) {
    fname = allFiles[i];
    if (!endsWith(toLowerCase(fname), ".tif")) continue; // skip non-tif files

    // Strip the ".tif" extension so we can split the rest by "_"
    dotIndex = lastIndexOf(fname, ".");
    base = substring(fname, 0, dotIndex);
    parts = split(base, "_");

    // Search the underscore-separated parts for a token that looks
    // like "M" followed by digits (e.g. "M1", "M12") - this marks
    // where the myelin number sits in the filename, regardless of
    // how many parts come before it.
    mIndex = -1;
    mNum = "";
    for (p = 0; p < parts.length; p++) {
        token = parts[p];
        if (startsWith(token, "M")) {
            rest = substring(token, 1);
            if (matches(rest, "[0-9]+")) {
                mIndex = p;
                mNum = rest;
                p = parts.length; // stop searching, we found it
            }
        }
    }
    if (mIndex == -1) continue;              // no "M<number>" token found - not a match
    if (mIndex + 1 >= parts.length) continue; // nothing after it - can't be a tile index

    // The part right after "M<number>" should be the tile index (e.g. "1", "2"...)
    tileToken = parts[mIndex + 1];
    if (!matches(tileToken, "[0-9]+")) continue;
    tileIdx = parseInt(tileToken);

    // Everything before the "M<number>" token is the shared prefix
    // for this specimen (e.g. "J9314_TB3gB12")
    prefix = "";
    for (p = 0; p < mIndex; p++) {
        if (p > 0) prefix = prefix + "_";
        prefix = prefix + parts[p];
    }
    key = prefix + "_M" + mNum; // unique identifier for this myelin section

    // Record this file's info in our three parallel arrays
    allKeys = Array.concat(allKeys, key);
    allTileIdx = Array.concat(allTileIdx, tileIdx);
    allFnames = Array.concat(allFnames, fname);
}

// If nothing matched the expected pattern, stop here rather than
// continuing with empty data.
if (allKeys.length == 0) {
    exit("No files matched the expected naming pattern (..._M<number>_<tileindex>_...). Check your filenames.");
}

// ------------------------------------------------------------
// STEP 2: Work out the list of unique myelin section names
// (e.g. "..._M1", "..._M2", "..._M3"...) from allKeys.
// ------------------------------------------------------------
groupKeys = newArray(0);
for (i = 0; i < allKeys.length; i++) {
    already = false;
    for (g = 0; g < groupKeys.length; g++) {
        if (groupKeys[g] == allKeys[i]) { already = true; g = groupKeys.length; } // already recorded, stop checking
    }
    if (!already) groupKeys = Array.concat(groupKeys, allKeys[i]);
}

print("Found " + groupKeys.length + " myelin section(s): " + String.join(groupKeys, ", "));

// ------------------------------------------------------------
// STEP 3: Process each myelin section one at a time.
// ------------------------------------------------------------
for (k = 0; k < groupKeys.length; k++) {
    key = groupKeys[k];

    // Collect every tile index + filename that belongs to this
    // particular section, by scanning back through allKeys.
    tileIdxArr = newArray(0);
    fileArr = newArray(0);
    for (i = 0; i < allKeys.length; i++) {
        if (allKeys[i] == key) {
            tileIdxArr = Array.concat(tileIdxArr, allTileIdx[i]);
            fileArr = Array.concat(fileArr, allFnames[i]);
        }
    }
    n = fileArr.length; // total number of tiles in this section

    // Sort the files into tile-number order (1, 2, 3...) rather than
    // whatever order the file system happened to list them in.
    // Array.rankPositions gives the sorted order as a list of indices.
    ranks = Array.rankPositions(tileIdxArr);
    sortedFiles = newArray(n);
    for (e = 0; e < n; e++) sortedFiles[e] = fileArr[ranks[e]];

    print("==== " + key + " (" + n + " tiles) ====");

    // Ask the user how many columns wide this section's grid is.
    // We can't work this out automatically - only you know how the
    // grid was captured - so this pauses for input once per section.
    Dialog.create("Grid size for " + key);
    Dialog.addMessage(key + " has " + n + " tiles total.\nHow many COLUMNS wide is this grid?");
    Dialog.addNumber("Columns:", n);
    Dialog.show();
    gridX = Dialog.getNumber();

    // Sanity check: the tile count must divide evenly into the
    // column count, or the grid shape doesn't make sense.
    if (gridX <= 0 || (n % gridX) != 0) {
        print("WARNING: " + n + " is not evenly divisible by " + gridX + ". Skipping " + key + ".");
        continue;
    }
    gridY = n / gridX; // number of rows, worked out from columns + tile count

    // ---- Prep tiles: rename sequentially + convert to 8-bit with contrast stretch ----
    // The stitching plugin needs simple, predictable filenames
    // (tile_001.tif, tile_002.tif...) rather than your original
    // naming. We also convert from 16-bit to 8-bit here, which:
    //   1) roughly halves file size and speeds up stitching
    //   2) "Enhance Contrast" stretches the pixel value range first,
    //      giving the matching algorithm more visible detail to work
    //      with on low-contrast EM images.
    subDir = tempRoot + key + File.separator;
    if (!File.exists(subDir)) File.makeDirectory(subDir);

    for (e = 0; e < n; e++) {
        src = inputDir + sortedFiles[e];
        dst = subDir + "tile_" + IJ.pad(e + 1, 3) + ".tif"; // e.g. tile_001.tif

        open(src);
        run("Enhance Contrast", "saturated=0.35"); // stretch contrast (sets display range)
        run("8-bit");                               // convert down from 16-bit using that range
        saveAs("Tiff", dst);
        close();
    }

    // ---- Test each overlap % on this section ----
    // For every value in overlapsToTest, run the actual Fiji
    // "Grid/Collection Stitching" plugin with that overlap guess,
    // and save the result under a name that records which overlap
    // % produced it - so you can open them side by side afterwards
    // and pick whichever looks the most correctly aligned.
    for (o = 0; o < overlapsToTest.length; o++) {
        ov = overlapsToTest[o];
        print("  -- trying overlap=" + ov + "% --");

        nBefore = nImages; // how many images are open before we try stitching

        // Build the parameter string for the stitching plugin.
        //   type/order       -> matches your row-by-row, left-to-right,
        //                        top-to-bottom acquisition pattern
        //   grid_size_x/y    -> the grid shape you entered above
        //   tile_overlap     -> the % being tested this loop
        //   compute_overlap  -> tells Fiji to refine the real overlap
        //                        via pixel correlation rather than
        //                        blindly trusting the % above
        //   regression / displacement thresholds -> control how
        //                        strict Fiji is about rejecting a
        //                        tile-to-tile match that doesn't fit
        //                        the overall pattern (helps avoid
        //                        false matches on repetitive texture)
        params = "type=[Grid: row-by-row] order=[Right & Down                ]"
            + " grid_size_x=" + gridX + " grid_size_y=" + gridY
            + " tile_overlap=" + ov + " first_file_index_i=1"
            + " directory=[" + subDir + "]"
            + " file_names=tile_{iii}.tif"
            + " output_textfile_name=TileConfiguration_ov" + ov + ".txt"
            + " fusion_method=[Linear Blending]"
            + " regression_threshold=0.30"
            + " max/avg_displacement_threshold=1.50"
            + " absolute_displacement_threshold=2.00"
            + " compute_overlap"
            + " computation_parameters=[Save memory (but be slower)]"
            + " image_output=[Fuse and display]";

        run("Grid/Collection stitching", params);

        // If stitching failed (e.g. couldn't find good matches), no
        // new image window will have opened - skip saving in that case.
        if (nImages == nBefore) {
            print("     WARNING: no image produced at overlap=" + ov + "%.");
            continue;
        }

        // Save this attempt with a filename that records which
        // overlap % was used, then close it before trying the next one.
        savePath = outputDir + key + "_overlap" + ov + ".tif";
        saveAs("Tiff", savePath);
        close();
        print("     Saved: " + savePath);
    }
}

print("DONE. Open the saved files per section and pick whichever overlap % looks cleanest.");
