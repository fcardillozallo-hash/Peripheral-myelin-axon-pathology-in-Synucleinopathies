// Set the folder path
dir = "/Volumes/MSc project/P626/Labels/"; // Change this to your image folder path

// Get a list of all files in the folder
list = getFileList(dir);

// Set the path where the directory should be created
NewdirPath = "/Volumes/MSc project/P626/Labels/thickness/";

// Create the directory
File.makeDirectory(NewdirPath);
// Loop through the list and open each image file
for (i = 0; i < list.length; i++) {
    // Get the full path of the current image
    imagePath = dir + list[i];
    
    // Check if the file is an image (based on extension, e.g., .jpg, .png, .tif)
    if (endsWith(imagePath, ".jpg") || endsWith(imagePath, ".png") || endsWith(imagePath, ".tiff") || endsWith(imagePath, ".tif")) {
        open(imagePath);  // Open the image
        originalFileName = getTitle(); // Get the title of the currently open image (filename without path)
        
        // Capture calibration from the original image BEFORE running Local Thickness
        getVoxelSize(pw, ph, pd, unit);
        
        setThreshold(1, 1); // Take myelin area only
		run("Convert to Mask");
		run("8-bit");  // Local thickness requires 8-bit images
		run("Local Thickness (complete process)", "threshold=254");
		
		 // Local Thickness creates a new output image ("_LocThk") — reapply calibration to it
        setVoxelSize(pw, ph, pd, unit);
		
		newFileName = replace(originalFileName, ".tif", "_thickness.tif"); // Modify the filename (e.g., append "_processed")
		saveAs("Tiff", NewdirPath + newFileName); // Save the image with the new filename
		//newFileNameTxt = replace(originalFileName, ".txt", "_processed.txt");
		//saveAs("Text Image", NewdirPath + newFileNameTxt);
      	close();
      	close();
    }
}
