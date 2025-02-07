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

while [ 1 = 1 ] ; do
  unset IFS
  /usr/bin/inotifywait -m -e close_write $SFTP_DIR |
  while read DIR OP FILE ; do
    echo "dir is $DIR, op is $OP, file is $FILE"
    /bin/sleep 1s
    pushd $DIR
    # f/w updates require a tar.xz archive encrypted with openssl
    if [[ $FILE == *tar.xz.enc ]] ; then
      TARBALL=${FILE%.*}
      echo "decrypting"
      ipcTool --url=/misc --method=set --params='{"fwUpdateStatus":"Decrypting"}' || true
      openssl enc -aes-256-cbc -d -in $FILE -out $TARBALL -k SDBS
      # encrypt with: openssl enc -aes-256-cbc -salt -in $TARBALL -out $FILE -k SDBS
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
          ipcTool --url=/misc --method=set --params='{"fwUpdateStatus":"Extraction"}' || true
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
          ipcTool --url=/misc --method=set --params='{"fwUpdateStatus":"ExtractionComplete"}' || true
          sleep 2
          rm $TARBALL
          umount /mnt/rootfs
          sleep 1
          reboot
        done
        set +e
      else
        echo "decrypt failed"
        ipcTool --url=/misc --method=set --params='{"fwUpdateStatus":"DecryptingFail"}' || true
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
      ipcTool --url=/misc --method=set --params='{"fwUpdateStatus":"ExtractionFail"}' || true
      sleep 5
    fi
    rm $FILE
    popd
  done
done

