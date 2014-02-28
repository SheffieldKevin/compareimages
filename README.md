compareimages
=========

A CIDifferenceBlend and a CIAreaMaximum (Core Image filters CIFilter) used in a command line tool to compare image files.

### Uses

Objective-C, Cocoa, OS X, CoreImage.

### Produced

A command line tool "compareimages".

### Requirements

10.9, Xcode 5.0.1.

The following is a print usage output produced if you call the command line tool without any parameters.

	Compare image files.
	
	Find maximum pixel value difference between two images. Compare this difference against distance parameter.
	If image files have different dimensions then return "DIFFERENT".
	If comparison of any pixel between images is greater than -distance return "DIFFERENT" otherwise return "SAME".
	
	compareimages - usage:
	    ./compareimages [-parameter <value> ...]
	    parameters are all preceded by a -<parameterName>.  The order of the parameters is unimportant.
	    Required parameters are -file1 <File1URL> -file2 <File1URL>.
	    Required parameters:
	        -file1 <File1URL> The first image file for comparison.
	        -file2 <File2URL> The second image file for comparison.
	    Optional parameter:
	        -distance <X> The chromatic difference in any color component for comparison. Default 10. Range 0 to 255.
	
	    Examples of compareimages usage:
	        A fairly loose idea of what constitutes as two images being the same.
	            ./compareimages -file1 "~/Pictures/file1.png" -file2 "~/Desktop/file2.png" -distance 30
	        The pixel values in image 1 have to be exactly the same as image 2 to report images as the same.
	            ./compareimages -file1 "~/Pictures/file1.png" -file2 "~/Desktop/file2.png" -distance 0
