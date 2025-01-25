#!/bin/bash

# Navigate to the iOS directory
cd ios

# Archive the app
xcodebuild -workspace Runner.xcworkspace \
           -scheme Runner \
           -configuration Release \
           -archivePath build/Runner.xcarchive \
           -allowProvisioningUpdates \
           archive

# Export the archive
xcodebuild -exportArchive \
           -archivePath build/Runner.xcarchive \
           -exportPath build/Runner \
           -exportOptionsPlist ExportOptions.plist \
           -allowProvisioningUpdates

# Navigate back to the project root
cd ..