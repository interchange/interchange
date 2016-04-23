/*global jQuery */
/*! 
* equalHeightColumns.js 1.2
* https://github.com/PaulSpr/jQuery-Equal-Height-Columns
*
* Copyright 2014, Paul Sprangers http://paulsprangers.com
* Released under the WTFPL license 
* http://www.wtfpl.net
*
* Date: Sat Dec 13 11:30:00 2014 +0100
*/

(function( $ ){

    $.fn.equalHeightColumns = function( options ) {

            defaults = { 
                minWidth: -1,               // Won't resize unless window is wider than this value
                maxWidth: 99999,            // Won't resize unless window is narrower than this value
                setHeightOn: 'min-height',   // The CSS attribute on which the equal height is set. Usually height or min-height
                defaultVal: 0,              // Default value (for resetting columns before calculation of the maximum height) for the CSS attribute defined via setHeightOn, e.g. 'auto' for 'height' or 0 for 'minHeight'
                equalizeRows: false,		// Give every column in indiviual rows even height. Every row can have a different height this way
				checkHeight: 'height'		// Which height to check, using box-sizing: border-box, innerHeight is probably more appropriate
            };

            var $this   = $(this); // store the object
            options     = $.extend( {}, defaults, options ); // merge options
            
            // Resize height of the columns
            var resizeHeight = function () {

                // Get window width
                var windowWidth = $(window).width();
				var currentElements = Array();

                // Check to see if the current browser width falls within the set minWidth and maxWidth
                if( options.minWidth < windowWidth  &&  options.maxWidth > windowWidth ){
                    var height = 0;
                    var highest = 0;
					var yPos = 0;

                    // Reset heights
                    $this.css( options.setHeightOn, options.defaultVal );

                    // Figure out the highest element
                    $this.each( function(){

						if( options.equalizeRows ){
							// Check if y position of the element is bigger, if so, it's on another row.
							// Make sure that the height is only set relative to elements in the same row.
							var elYPos = $(this).position().top;

							if( elYPos != yPos ){
								// new row, so set the height of the elements of the previous row
								if( currentElements.length > 0 ) {
									$(currentElements).css(options.setHeightOn, highest);
									// clear the array and reset values for the new row
									highest = 0;
									currentElements = [];
								}
								// get element elYPos again since it might have changed because of the resize
								yPos = $(this).position().top;

							}

							currentElements.push(this);
						}

						// do the height check and if it's the highest, set it as such
						height = $(this)[options.checkHeight]();

						if( height > highest ){
							highest = height;
						}

                    } );

					if( !options.equalizeRows ){
						// Set that height on the elements at once
						$this.css( options.setHeightOn, highest );
					}
					else{
						// set height on elements in last row
						$(currentElements).css( options.setHeightOn, highest );
					}

                }
                else{
                    // Add check so this doesn't have to happen everytime 
                    $this.css(options.setHeightOn, options.defaultVal);
                }
            };

            // Call once to set initially
            resizeHeight();

            // Call on resize. Opera debounces their resize by default. 
            $(window).resize(resizeHeight);
            
            // Also check if any images are present and recalculate when they load
            // there might be an optimization opportunity here
            $this.find('img').load( resizeHeight );
            
            // If afterLoading is defined, add a load event to the selector
            if ( typeof options.afterLoading !== 'undefined' ) {
            	$this.find(options.afterLoading).load( resizeHeight );
			}
			
			// If afterTimeout is defined use it a the timeout value
			if ( typeof options.afterTimeout !== 'undefined' ) {
            	setTimeout(function(){
	            	resizeHeight();
	            	
	            	// check afterLoading again, to make sure that dynamically added nodes are present
	            	if ( typeof options.afterLoading !== 'undefined' ) {
		            	$this.find(options.afterLoading).load( resizeHeight );
					}
            	}, options.afterTimeout);
			}

    };

})( jQuery );
