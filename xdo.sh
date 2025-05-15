#!/bin/bash

# --- Configuration: Define your desired crop region ---
# Top-left corner of your desired region (X1, Y1)
X1=30
# Y1=35 # Springboot
Y1=05 # IPTM

# Bottom-right corner of your desired region (X2, Y2)
X2=1360
# Y2=700 # Springboot
Y2=740 # IPTM
# --- End Configuration ---

# Calculate crop geometry for ImageMagick (WidthxHeight+X_offset+Y_offset)
CROP_WIDTH=$(($X2 - $X1))
CROP_HEIGHT=$(($Y2 - $Y1))
CROP_GEOMETRY="${CROP_WIDTH}x${CROP_HEIGHT}+${X1}+${Y1}"

# Create a temporary DIRECTORY inside your home directory
# The XXXXXX will be replaced by mktemp to ensure a unique directory name
# Using a dot prefix to make it a "hidden" directory by default listing
TMP_CAPTURE_DIR=$(mktemp -d "$HOME/Dev/flameshot_capture_XXXXXX")

# Check if mktemp succeeded in creating the directory
if [ ! -d "$TMP_CAPTURE_DIR" ]; then
    echo "Error: Failed to create temporary directory in $HOME."
    exit 1
fi

# Define a path for the CROPPED image (can be in the same temp dir)
TMP_CROPPED_FILE="${TMP_CAPTURE_DIR}/cropped_image_$(date +%s).png"

# Ensure cleanup of the entire temporary directory on exit
trap 'echo "Cleaning up temporary directory: $TMP_CAPTURE_DIR"; rm -rf "$TMP_CAPTURE_DIR"' EXIT

echo "--- Script Start ---"
echo "Desired crop region: Top-Left(X1,Y1)=($X1,$Y1), Bottom-Right(X2,Y2)=($X2,$Y2)"
echo "Calculated crop settings: Width=$CROP_WIDTH, Height=$CROP_HEIGHT, OffsetX=$X1, OffsetY=$Y1"
echo "ImageMagick crop geometry: $CROP_GEOMETRY"
echo "Using temporary directory for Flameshot output: $TMP_CAPTURE_DIR"
echo "--------------------------------------------------"

echo "Step 1: Capturing full screen with Flameshot, saving into directory $TMP_CAPTURE_DIR..."
# Pass the DIRECTORY path (now in your home folder) to flameshot.
if flameshot full --path "$TMP_CAPTURE_DIR"; then
    echo "Flameshot capture command executed. Check Flameshot's output above for any specific messages."
else
    echo "Error: Flameshot command failed to execute properly."
    # List contents for debugging even on failure
    if [ -d "$TMP_CAPTURE_DIR" ]; then
        echo "Contents of $TMP_CAPTURE_DIR after failed flameshot command:"
        ls -la "$TMP_CAPTURE_DIR"
    fi
    exit 1
fi

# Add a small delay for the filesystem to fully write the file(s).
sleep 0.5 # Adjust if needed

ACTUAL_FLAMESHOT_SAVED_FILE=$(find "$TMP_CAPTURE_DIR" -maxdepth 1 -type f -name "*.png" -print -quit)

if [ -z "$ACTUAL_FLAMESHOT_SAVED_FILE" ]; then
    echo "Error: Could not find any .png screenshot file saved by Flameshot in $TMP_CAPTURE_DIR."
    echo "Contents of $TMP_CAPTURE_DIR:"
    ls -la "$TMP_CAPTURE_DIR"
    exit 1
fi

if [ ! -s "$ACTUAL_FLAMESHOT_SAVED_FILE" ]; then
    echo "Error: Found screenshot file ($ACTUAL_FLAMESHOT_SAVED_FILE) but it is empty or unreadable."
    echo "Contents of $TMP_CAPTURE_DIR:"
    ls -la "$TMP_CAPTURE_DIR"
    exit 1
fi
echo "Successfully found screenshot saved by Flameshot: $ACTUAL_FLAMESHOT_SAVED_FILE"

FULL_SCREEN_DIMS=$(identify -format "%wx%h" "$ACTUAL_FLAMESHOT_SAVED_FILE")
echo "LOG: Full screenshot dimensions (WxH): $FULL_SCREEN_DIMS"
echo "--------------------------------------------------"

echo "Step 2: Cropping the screenshot to $CROP_GEOMETRY..."
if convert "$ACTUAL_FLAMESHOT_SAVED_FILE" -crop "$CROP_GEOMETRY" "$TMP_CROPPED_FILE"; then
    echo "Screenshot cropped and saved to $TMP_CROPPED_FILE"
else
    echo "Error: ImageMagick (convert) failed to crop the image."
    exit 1
fi

if [ ! -f "$TMP_CROPPED_FILE" ] || [ ! -s "$TMP_CROPPED_FILE" ]; then
    echo "Error: Cropped screenshot file is missing or empty."
    exit 1
fi

CROPPED_DIMS=$(identify -format "%wx%h" "$TMP_CROPPED_FILE")
echo "LOG: Cropped image actual dimensions (WxH): $CROPPED_DIMS"
echo "LOG: Cropped image expected dimensions (WxH): ${CROP_WIDTH}x${CROP_HEIGHT}"
if [ "$CROPPED_DIMS" != "${CROP_WIDTH}x${CROP_HEIGHT}" ]; then
    echo "WARNING: Actual cropped dimensions ($CROPPED_DIMS) do not match expected dimensions (${CROP_WIDTH}x${CROP_HEIGHT})."
    echo "         This might happen if the crop region (X1,Y1,X2,Y2) extends beyond the full screenshot boundaries."
    echo "         Full screenshot dimensions were: $FULL_SCREEN_DIMS"
fi
echo "--------------------------------------------------"

echo "Step 3: Copying cropped image to clipboard..."
if xclip -selection clipboard -t image/png -i "$TMP_CROPPED_FILE"; then
    echo "Cropped image copied to clipboard!"
else
    echo "Error: xclip failed to copy image to clipboard."
    exit 1
fi

echo "--- Script End ---"
# Temporary directory (and all its contents) will be cleaned up by the 'trap' command.


xdotool key "Ctrl+Alt+Left"

xdotool mousemove 866 444
xdotool click 1
xdotool key "Control_L+End"
sleep 0.5
xdotool click 1
sleep 0.05
xdotool key "Return"
sleep 0.05
xdotool key "Ctrl+v"
