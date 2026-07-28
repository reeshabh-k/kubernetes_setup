#!/bin/bash

../proxy.sh &

set -e

###########################################
# Versions
###########################################

HADOOP_VERSION="3.5.0"
FLINK_VERSION="2.3.0"

###########################################
# Download Directory
###########################################

DOWNLOAD_DIR="$PWD/downloads"

mkdir -p "$DOWNLOAD_DIR"

###########################################
# Download Function
###########################################

download_file() {

    NAME="$1"
    URL="$2"
    OUTPUT="$3"

    echo
    echo "========================================"
    echo "Downloading $NAME"
    echo "========================================"

    if [ -f "$OUTPUT" ]; then
        echo "$NAME already exists. Skipping."
        return
    fi

    wget -O "$OUTPUT" "$URL"

    echo "$NAME downloaded successfully."

}

###########################################
# Check Operating System
###########################################

echo
echo "========================================"
echo "Checking Operating System"
echo "========================================"

if ! grep -qi ubuntu /etc/os-release; then
    echo "ERROR: This script only supports Ubuntu."
    exit 1
fi

UBUNTU_VERSION=$(grep VERSION_ID /etc/os-release | cut -d '"' -f2)

echo "Ubuntu detected: $UBUNTU_VERSION"


###########################################
# Check Internet Connection
###########################################

echo
echo "========================================"
echo "Checking Internet Connection"
echo "========================================"

# Ping is intentionally not used.
# Many university networks block ICMP.
# HTTPS test is a better indicator.

if curl -fsSL --connect-timeout 10 https://downloads.apache.org/ >/dev/null; then
    echo "Internet connection OK."
else
    echo "ERROR: Cannot reach Apache download servers."

    echo
    echo "If you are using IITD proxy:"
    echo "  1. Start your proxy login script."
    echo "  2. Wait until login succeeds."
    echo "  3. Run this script again."

    exit 1
fi


###########################################
# Check Required Tools
###########################################

echo
echo "========================================"
echo "Checking Required Tools"
echo "========================================"

TOOLS=("curl" "wget" "tar" "gzip")

for TOOL in "${TOOLS[@]}"
do

    if command -v "$TOOL" >/dev/null 2>&1; then
        echo "$TOOL found."
    else
        echo "ERROR: $TOOL missing."
        exit 1
    fi

done


###########################################
# Check Java
###########################################

echo
echo "========================================"
echo "Checking Java"
echo "========================================"

if command -v java >/dev/null 2>&1; then

    JAVA_VERSION=$(java -version 2>&1 | head -n1)

    JAVA_MAJOR=$(java -version 2>&1 \
        | awk -F '"' '/version/ {split($2,v,"."); print v[1]}')

    echo "Java detected:"
    echo "$JAVA_VERSION"

    if [ "$JAVA_MAJOR" -ge 21 ]; then
        echo "Java version is compatible."
    else
        echo "WARNING: Java 21 or newer is recommended."
    fi

else

    echo "WARNING: Java is not installed."

    echo "Install later using:"
    echo
    echo "sudo apt install openjdk-21-jdk"

fi


###########################################
# Download Hadoop
###########################################

download_file \
"Hadoop $HADOOP_VERSION" \
"https://downloads.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz" \
"$DOWNLOAD_DIR/hadoop-$HADOOP_VERSION.tar.gz"


###########################################
# Download Flink
###########################################

download_file \
"Apache Flink $FLINK_VERSION" \
"https://dlcdn.apache.org/flink/flink-2.3.0/flink-2.3.0-bin-scala_2.12.tgz" \
"$DOWNLOAD_DIR/flink-$FLINK_VERSION-bin-scala_2.12.tgz"


###########################################
# Download MinIO Server
###########################################

download_file \
"MinIO Server" \
"https://dl.min.io/server/minio/release/linux-amd64/minio" \
"$DOWNLOAD_DIR/minio"


chmod +x "$DOWNLOAD_DIR/minio"


###########################################
# Download MinIO Client
###########################################

download_file \
"MinIO Client (mc)" \
"https://dl.min.io/client/mc/release/linux-amd64/mc" \
"$DOWNLOAD_DIR/mc"


chmod +x "$DOWNLOAD_DIR/mc"


###########################################
# Verify Downloads Exist
###########################################

echo
echo "========================================"
echo "Checking Download Results"
echo "========================================"


FILES=(
"hadoop-$HADOOP_VERSION.tar.gz"
"flink-$FLINK_VERSION-bin-scala_2.12.tgz"
"minio"
"mc"
)


for FILE in "${FILES[@]}"
do

    if [ -f "$DOWNLOAD_DIR/$FILE" ]; then
        echo "$FILE OK"
    else
        echo "ERROR: Missing $FILE"
        exit 1
    fi

done


###########################################
# Summary
###########################################

echo
echo "========================================"
echo "Phase 1 Complete"
echo "========================================"

echo
echo "Downloaded files:"

ls -lh "$DOWNLOAD_DIR"

echo
echo "No installation or configuration was performed."
echo "Files are ready for the next phase."
