# 1 - prepare eMMC on startup (assumes format-eMMC.sh in same directory as this script)
# 2 - clean sftp directory
# 3 - continously monitor SFTP directory for firmware update archive
#     when found:
#      - check for compatibility with the hw
#      - decrypt/extract archive into eMMC a/b partition
#      - toggle eMMC a/b partition
#      - reboot
# 4 - continously monitor SFTP directory for 802.1X certificate upload
#     when found, copy to /mnt/data/certs

SFTP_DIR=/var/tmp/sftp
mkdir -p $SFTP_DIR
rm -rf $SFTP_DIR/*

while [ 1 = 1 ] ; do
  unset IFS
  /usr/bin/inotifywait -m -e close_write $SFTP_DIR |
  while read DIR OP FILE ; do
    echo "dir is $DIR, op is $OP, file is $FILE"
    /bin/sleep 1s
    pushd $DIR


    # Get the amp hardware revision from kvs for use in the compatibility test
    REVERSE_COMPATIBLE_HW=$(ipcTool --port=1236 --url=/amp/deviceInfo --method=get --params='["reverseCompatibleHw"]' | jq -r '.result.reverseCompatibleHw')
    AMP_HW_REV=$(ipcTool --port=1236 --url=/amp/deviceInfo --method=get --params='["ampHardwareRevision"]' | jq -r '.result.ampHardwareRevision')
    if [[ $REVERSE_COMPATIBLE_HW == "false" ]]; then
        echo "Verify $FILE firmware supports hwRev [${AMP_HW_REV}]..."
        # Minimum firmware version needed for adcUpdate hw, older fw doesn't know about new hw changes.
        MIN_REQUIRED_VERSION="4.2.0"
        # Filename must start with DLS and have "-" seperated version numbers at the beginning, custom characters are allowed beyond that.
        if [[ $FILE =~ ^DLS-([0-9]+-[0-9]+-[0-9]+) ]]; then
            RAW_VER=${BASH_REMATCH[1]}
            FILE_VERSION=${RAW_VER//-/.}
            # check if FILE_VERSION is at least MIN_REQUIRED_VERSION
            if [ "$(printf '%s\n%s' "$MIN_REQUIRED_VERSION" "$FILE_VERSION" | sort -V | head -n1)" == "$MIN_REQUIRED_VERSION" ]; then
                echo "Yes! $FILE_VERSION passed version check (>= $MIN_REQUIRED_VERSION)."
                # Proceed with the update
            else
                echo "No! $FILE_VERSION is older than $MIN_REQUIRED_VERSION. Deleting."
                ipcTool --port=1236 --url=/misc --method=set --params='{"fwUpdateStatus":"HwNotSupportedInFw"}' || true
                rm $FILE
                sleep 5
                exit 1
            fi
        else
            echo "DEBUG: Captured NUM1=[${BASH_REMATCH[1]}] NUM2=[${BASH_REMATCH[2]}] NUM3=[${BASH_REMATCH[3]}]"
            echo "filename format is invalid, must start with DLS-x-x-x-x Deleting."
            rm $FILE
            exit 1
        fi
    else
        echo "The detected hwRev [${AMP_HW_REV}] supports all versions of firmware."
    fi
    # f/w updates require a tar.xz archive encrypted with openssl
    if [[ $FILE == *tar.xz.enc ]] ; then
      TARBALL=${FILE%.*}
      echo "decrypting"
      ipcTool --port=1236 --url=/misc --method=set --params='{"fwUpdateStatus":"Decrypting"}' || true
      openssl enc -aes-256-cbc -d -in $FILE -out $TARBALL -k DLS!
      # encrypt with: openssl enc -aes-256-cbc -salt -in $TARBALL -out $FILE -k DLS!
      if [[ $? = 0 ]] ; then
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
          ipcTool --port=1236 --url=/misc --method=set --params='{"fwUpdateStatus":"Extraction"}' || true
          umount /mnt/rootfs || true
          mkdir -p /mnt/rootfs
          mount $PART /mnt/rootfs
          export EXTRACT_UNSAFE_SYMLINKS=1
          rm -rf /mnt/rootfs/*
          tar xpf $TARBALL -C /mnt/rootfs
          sync
          echo 0 > /sys/block/mmcblk1boot1/force_ro # required to write u-boot env vars
          fw_setenv emmcpart $EMMCPART
          echo "extraction complete"
          ipcTool --port=1236 --url=/misc --method=set --params='{"fwUpdateStatus":"ExtractionComplete"}' || true
          sleep 2
          # Wait for hvRailSequencerState to become "Off" with a timeout of 20 seconds
          TIMEOUT=20
          SLEEP_INTERVAL=1
          ELAPSED=0
          RAIL_STATE=""

          while [[ $ELAPSED -lt $TIMEOUT ]]; do
            # Query hvRailSequencerState
            RAIL_STATE=$(ipcTool --port=1236 --url=/amp/powerSupply --method=get --params='["hvRailSequencerState"]' | jq -r '.results.hvRailSequencerState')

            if [[ $RAIL_STATE = "Off" ]]; then
              echo "hvRailSequencerState is Off, proceeding with rm, umount, and reboot"
              rm $TARBALL
              umount /mnt/rootfs
              sleep 1
              reboot
              break
            fi

            echo "Waiting for hvRailSequencerState to become Off, current state: $RAIL_STATE"
            sleep $SLEEP_INTERVAL
            ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
          done

          if [[ $RAIL_STATE != "Off" ]]; then
            echo "Timeout reached. hvRailSequencerState did not become Off, proceeding with rm, umount, and reboot"
            rm $TARBALL
            umount /mnt/rootfs
            sleep 1
            reboot
            break
          fi
        done
        set +e

      else
        echo "decrypt failed"
        ipcTool --port=1236 --url=/misc --method=set --params='{"fwUpdateStatus":"DecryptingFail"}' || true
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
      ipcTool --port=1236 --url=/misc --method=set --params='{"fwUpdateStatus":"ExtractionFail"}' || true
      sleep 5
    fi
    rm $FILE
    popd
  done
done

