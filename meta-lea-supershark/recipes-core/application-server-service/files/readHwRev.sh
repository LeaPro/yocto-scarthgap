# Read the (D)ARC hardware revision ADC input AIN0
# 12-bit ADC 1.8V max, 1-bit is 0.4mv
# See M:\Firmware\Info\HardwareVersionsAndRevisionsList.xlsx
# See C:\git\tools\info\HardwareVersionsAndRevisionsList.xlsx
#
#    0 is 0.00Volts is Rev 2  PWA 10006/7 Rev2 (DV Release-Purple Board)
#  455 is 0.20Volts is Rev 3  PWA 10006/7 Rev3 (Initial Production Release)
#  683 is 0.30Volts is Rev 4  PWA 10006/7 Rev4 (Dante Short Fix)
# 1024 is 0.45Volts is Rev 5  PWA 10006/7 Rev5 (eMMC changes for PCB mfg)
# 1251 is 0.55Volts is Rev 0  PWA 10029/30/31/32 Rev0 (AM SPI Fix)
# 1593 is 0.70Volts is Rev 6  PWA 10006/7 Rev6  Add POE load resistor
# 2503 is 1.10Volts is Rev 6  hw oops
# 
SYS_ADC_PATH=/sys/bus/iio/devices
HW_REV_STORAGE_PATH=/mnt/data/mfg/hwRev.txt

#echo "Read ARC hw revision id pin... "
cd $SYS_ADC_PATH
cd iio\:device0

count=$(cat in_voltage0_raw)

if (($count < 341)); then
    HWREV=2
elif (($count < 569)); then
    HWREV=3
elif (($count < 853)); then
    HWREV=4
elif (($count < 1138)); then
    HWREV=5
elif (($count < 1422)); then
    HWREV=0
elif (($count < 1764)); then
    HWREV=6
elif ((count > 2412) && ($count < 2617)); then
    HWREV=6
else
    HWREV=0;
fi

# create file if it doesn't exist
touch $HW_REV_STORAGE_PATH

# erase file contents
echo > $HW_REV_STORAGE_PATH

# write new hwRev to file
echo "hwRev:"$HWREV >> $HW_REV_STORAGE_PATH

echo $HWREV