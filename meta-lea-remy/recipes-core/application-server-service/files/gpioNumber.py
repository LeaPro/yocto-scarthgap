#!/usr/bin/env python3
import os
import sys
import argparse

def get_gpio_number(port: str, pin: int) -> int:
    """
    Maps an AM62x GPIO port or I2C expander and pin to the /sys/class/gpio
    global number.
    """
    gpio_mapping = {
        "GPIO0": "600000.gpio",
        "GPIO1": "601000.gpio",
        "MCU_GPIO0": "4201000.gpio",
        "PCA9534": "1-0038",
    }
    
    port_name = port.upper()
    target_label = gpio_mapping.get(port_name)
    if not target_label:
        print(f"Error: Unknown port '{port}'. Valid choices are: {', '.join(gpio_mapping.keys())}", file=sys.stderr)
        sys.exit(1)

    if port_name == "PCA9534" and not 0 <= pin < 8:
        print("Error: PCA9534 pin must be between 0 and 7", file=sys.stderr)
        sys.exit(1)
        
    gpio_path = "/sys/class/gpio"
    if not os.path.exists(gpio_path):
        print("Error: Sysfs GPIO interface (/sys/class/gpio) not found.", file=sys.stderr)
        print("Ensure CONFIG_GPIO_SYSFS is enabled in your Yocto kernel.", file=sys.stderr)
        sys.exit(1)

    # Search for the matching gpiochip base
    for entry in os.listdir(gpio_path):
        if entry.startswith("gpiochip"):
            chip_dir = os.path.join(gpio_path, entry)
            try:
                with open(os.path.join(chip_dir, "label"), "r") as f:
                    label = f.read().strip()
                
                if label == target_label:
                    with open(os.path.join(chip_dir, "base"), "r") as f:
                        base = int(f.read().strip())
                    return base + pin
            except IOError:
                continue

    print(f"Error: Could not find a live gpiochip matching {port} ({target_label})", file=sys.stderr)
    sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description="Map AM62x or I2C expander GPIO & Pin to Sysfs GPIO number."
    )
    parser.add_argument(
        "port", 
        type=str, 
        help="The GPIO port name (e.g., GPIO0, GPIO1, MCU_GPIO0, PCA9534)"
    )
    parser.add_argument(
        "pin", 
        type=int, 
        help="The pin number offset (typically 0-31)"
    )
    parser.add_argument(
        "--export", 
        action="store_true", 
        help="Output just the raw number (useful for shell scripting: `export $(python3 gpio_map.py GPIO1 12 --export)`)"
    )

    args = parser.parse_args()

    gpio_num = get_gpio_number(args.port, args.pin)

    if args.export:
        print(gpio_num)
    else:
        print(f"--- AM62x GPIO Mapping ---")
        print(f"Input:        {args.port.upper()}_{args.pin}")
        print(f"Sysfs Number: {gpio_num}")
        print(f"Export Path:  /sys/class/gpio/gpio{gpio_num}/")
        print(f"Command:      echo {gpio_num} > /sys/class/gpio/export")

if __name__ == "__main__":
    main()

