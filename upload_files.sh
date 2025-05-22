#!/bin/bash
# Script to format NodeMCU and upload all Lua files

# Define color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== NodeMCU TT Scripts load =====${NC}"
echo -e "${BLUE}Restarting NodeMCU...${NC}"
nodemcu-tool reset
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Warning: Failed to restart NodeMCU.${NC}"
fi
echo

# Format the file system
echo -e "${BLUE}Formatting NodeMCU filesystem...${NC}"
nodemcu-tool mkfs --noninteractive
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to format NodeMCU filesystem. Is the device connected?${NC}"
    exit 1
fi
echo -e "${GREEN}NodeMCU filesystem formatted successfully.${NC}"
echo

# Upload all Lua files except init.lua (which should be uploaded last)
echo -e "${BLUE}Uploading Lua files...${NC}"
for file in *.lua; do
    # Skip init.lua for now
    if [ "$file" != "init.lua" ]; then
        echo -e "${BLUE}Uploading $file...${NC}"
        nodemcu-tool upload --minify --compile "$file"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to upload $file.${NC}"
            exit 1
        fi
        echo -e "${GREEN}Successfully uploaded $file${NC}"
    fi
done

# Ask for confirmation about uploading init.lua (default is no)
if [ -f "init.lua" ]; then
    echo -e "${YELLOW}An init.lua file exists. This will run automatically on startup.${NC}"
    echo -e "${YELLOW}WARNING: If init.lua has errors, it might put your device in a boot loop!${NC}"
    read -p "Do you want to upload init.lua? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Uploading init.lua...${NC}"
        nodemcu-tool upload init.lua
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to upload init.lua.${NC}"
            exit 1
        fi
        echo -e "${GREEN}Successfully uploaded init.lua${NC}"
    else
        echo -e "${YELLOW}Skipping init.lua upload per user request.${NC}"
    fi
fi

# Restart the device
echo -e "${BLUE}Restarting NodeMCU...${NC}"
nodemcu-tool reset
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Warning: Failed to restart NodeMCU.${NC}"
fi

# Show what files are on the board now
echo
echo -e "${BLUE}Files on the NodeMCU:${NC}"
nodemcu-tool fsinfo
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Warning: Failed to retrieve file system information.${NC}"
fi

echo
echo -e "${GREEN}All files uploaded successfully!${NC}"
echo -e "${BLUE}===== NodeMCU Upload Complete =====${NC}"