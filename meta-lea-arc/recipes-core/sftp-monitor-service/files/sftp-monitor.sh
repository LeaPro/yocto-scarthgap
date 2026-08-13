# 1 - prepare eMMC on startup (assumes format-eMMC.sh in same directory as this script)
# 2 - clean sftp directory
# 3 - continously monitor SFTP directory for firmware update archive
#     when found:
#      - decrypt/extract archive into eMMC a/b partition
#      - toggle eMMC a/b partition
#      - reboot
# 4 - continously monitor SFTP directory for 802.1X certificate upload
#     when found, copy to /mnt/data/certs

SFTP_DIR=/var/tmp/sftp
mkdir -p $SFTP_DIR
rm -rf $SFTP_DIR/*
FW_KEY="${FW_KEY:-DTSB}"
FILE_PREFIX="${FILE_PREFIX:-ASBT}"

while [ 1 = 1 ] ; do
  unset IFS
  /usr/bin/inotifywait -m -e close_write $SFTP_DIR |
  while read DIR OP FILE ; do
    echo "dir is $DIR, op is $OP, file is $FILE"
    /bin/sleep 1s
    pushd $DIR
    # f/w updates require a tar.xz archive encrypted with openssl
    if [[ $FILE == *tar.xz.enc ]] ; then
      if [[ ${FILE:0:4} != "$FILE_PREFIX" ]] ; then
        echo "filename prefix mismatch for $FILE"
        touch /usr/sbin/decryptFailed
        rm $FILE
        sleep 5
        continue
      fi
      TARBALL=${FILE%.*}
      echo "decrypting"
      touch /usr/sbin/decrypting
      openssl enc -aes-256-cbc -d -in $FILE -out $TARBALL -k "$FW_KEY"
      # encrypt with: openssl enc -aes-256-cbc -salt -in $TARBALL -out $FILE -k "$FW_KEY"
      if [[ $? = 0 ]] ; then
        # Block firmware updates when running on PoE
        POWER_SOURCE=""
        POWER_SOURCE=$(ipcTool --port=1236 --url=/amp/powerSupply --method=get --params='["powerSource"]' | jq -r '.result.powerSource')
        if [[ $POWER_SOURCE == "POE" ]]; then
          echo "Firmware update is not allowed when running on PoE. Deleting $FILE."
          rm $FILE
          sleep 5
          continue
        fi
        # Get the ampUpdateHw flag from kvs for use in the compatibility test (true = requires newer fw, false = compatible with all fw versions)
        REVERSE_COMPATIBLE_HW=$(ipcTool --port=1236 --url=/amp/deviceInfo --method=get --params='["reverseCompatibleHw"]' | jq -r '.result.reverseCompatibleHw')
        AMP_HW_REV=$(ipcTool --port=1236 --url=/amp/deviceInfo --method=get --params='["hardwareID"]' | jq -r '.result.hardwareID')
        if [[ $REVERSE_COMPATIBLE_HW == "false" ]]; then
            echo "Verify $FILE firmware supports hwRev [${AMP_HW_REV}]..."
            # Minimum firmware version needed for ASBT adcUpdate hw, older fw doesn't know about new hw changes.
            MIN_REQUIRED_VERSION="4.2.0"
            # Extract version from filename using regex
            if [[ $FILE =~ ([0-9]+-[0-9]+-[0-9]+-[0-9]+) ]]; then
                FILE_VERSION="${BASH_REMATCH[1]//-/.}"
                # check if FILE_VERSION is at least MIN_REQUIRED_VERSION
                if [ "$(printf '%s\n%s' "$MIN_REQUIRED_VERSION" "$FILE_VERSION" | sort -V | head -n1)" == "$MIN_REQUIRED_VERSION" ]; then
                    echo "Yes! $FILE_VERSION passed version check (>= $MIN_REQUIRED_VERSION)."
                    # Proceed with the update
                else
                    echo "No! $FILE_VERSION is older than $MIN_REQUIRED_VERSION. Deleting."
                    ipcTool --port=1236 --url=/misc --method=set --params='{"fwUpdateStatus":"HwNotSupportedInFw"}' || true
                    touch /usr/sbin/HwNotSupportedInFw
                    rm $FILE
                    sleep 5
                    continue
                fi
            else
                echo "filename is invalid $FILE, can't be evaluated"
                rm $FILE
                continue
            fi
        else
            echo "The detected hwRev [${AMP_HW_REV}] supports all versions of firmware."
        fi
        rm $FILE
        # format eMMC if we're not running from it
        mount | grep -e "mmcblk1.* on /"
        if [[ $? != 0 ]] ; then
          /bin/sh -c "$(dirname "$0")/format-eMMC.sh"
        fi
        set -e # exit on error
        IFS='='
        fw_printenv emmcpart |
        while read FOO EMMCPART ; do
          if [[ $EMMCPART = 1 ]] ; then
            EMMCPART=2
          else
            EMMCPART=1
          fi
          PART="/dev/mmcblk1p$EMMCPART"
          echo "extracting $TARBALL into $PART"
          touch /usr/sbin/extracting
          mkdir -p /mnt/rootfs
          mount $PART /mnt/rootfs
          export EXTRACT_UNSAFE_SYMLINKS=1
          rm -rf /mnt/rootfs/*
          tar xpf $TARBALL -C /mnt/rootfs
          sync
          echo 0 > /sys/block/mmcblk1boot1/force_ro # required to write u-boot env vars
          fw_setenv emmcpart $EMMCPART
          echo "extraction complete"
          touch /usr/sbin/extractionComplete
          WAITFILE=/usr/sbin/fwUpdateDontWait.txt
          if [[ -e "$WAITFILE" ]]; then
            cp -f /usr/sbin/fwUpdateDontWait.txt /mnt/rootfs/usr/sbin/lastFwUpdateDontWait.txt
            echo "fwUpdateDontWait file found"
          else
            echo "fwUpdateDontWait not found! wait for HV rails to discharge in fwUpdate"
          fi
          sleep 2
          rm $TARBALL
          set +e # don't exit on non-zero return code
          systemctl stop application-server
          while [[ true ]] ; do
            systemctl is-active application-server
            if [[ $? = 0 ]] ; then
              echo "still active"
              sleep 1
            else
              echo "is NOT active, break out"
              break 1
            fi 
            echo "try again"
            systemctl stop application-server
          done
          set -e # exit on error
          cd ~
          umount /mnt/rootfs
          sleep 1
          reboot
        done
        rm $TARBALL
        set +e
      else
        echo "decrypt failed"
        touch /usr/sbin/decryptFailed
        sleep 5
      fi
    # copy 802.1x certificates to /mnt/data/uploaded-certs
    elif [[ $FILE == *.pem || $FILE == *.key ]] ; then
      COUNT=($(wc ${FILE}))
      BYTES=${COUNT[2]}
      if [[ ${BYTES} -le 65536 ]] ; then
        mkdir -p /mnt/data/uploaded-certs
        cp ${FILE} /mnt/data/uploaded-certs
      else
        echo "ignoring ${FILE} due to excessive size (${BYTES} B)"
      fi
    else
      echo "unsupported file type"
        touch /usr/sbin/badFile
        sleep 5
    fi
    rm $FILE
    popd
  done
done

