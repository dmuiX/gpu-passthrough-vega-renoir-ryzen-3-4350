#!/usr/bin/env python3
import subprocess, sys, time
import xml.etree.ElementTree as ET

# List VMs and select
vms = [l.split()[1] for l in subprocess.getoutput("virsh list --all").splitlines()[2:] if l.strip()]
if not vms:
    print("No VMs found"); sys.exit(1)
print("VMs:", *[f"[{i}] {v}" for i,v in enumerate(vms)])
while True:
    choice = input("Select VM (name or #): ").strip()
    if choice.isdigit() and int(choice) < len(vms):
        VM = vms[int(choice)]; break
    elif choice in vms:
        VM = choice; break
    print("Invalid choice, try again")

def virsh(args, output=True):
    cmd = ["virsh"] + args.split()
    return subprocess.run(cmd, capture_output=True, text=True).stdout.strip() if output else subprocess.run(cmd)

# 1. Ensure VM is off
if virsh(f"domstate {VM}") != "shut off":
    print("Shutting down...")
    virsh(f"shutdown {VM}", output=False)
    while virsh(f"domstate {VM}") != "shut off": time.sleep(1)

# 2. Get XML and Parse
xml = ET.fromstring(virsh(f"dumpxml {VM} --security-info --inactive"))
devices = xml.find("devices")

# 3. Detect Mode (Check for GPU at host 06:00.0)
gpu = next((d for d in devices.findall("hostdev")
            if d.find("source/address") is not None
            and d.find("source/address").get("bus") == "0x06"
            and d.find("source/address").get("function") == "0x0"), None)

# Helper to find a free bus (avoiding collisions)
_claimed = set()
def get_bus():
    used = {int(a.get("bus"), 16) for a in xml.findall(".//address[@type='pci']") if a.get("bus")}
    used |= _claimed
    bus = 6
    while bus in used: bus += 1
    _claimed.add(bus)
    return f"0x{bus:02x}"

if gpu:
    print("GPUPass -> VNC")
    # Remove GPU, Audio (06:00.1), and USB (046d:c548)
    for d in list(devices):
        src = d.find("source")
        if d == gpu: devices.remove(d) # GPU
        elif d.tag == "hostdev" and not src: print(f"Warning: hostdev without source: {ET.tostring(d, encoding='unicode')[:80]}")
        elif d.tag == "hostdev" and src.find("address") is not None and src.find("address").get("function") == "0x1": devices.remove(d) # Audio
        elif d.tag == "hostdev" and src.find("vendor") is not None and src.find("vendor").get("id") == "0x046d": devices.remove(d) # USB

    # Add VNC & Video
    ET.SubElement(devices, "graphics", type="vnc", port="-1", autoport="yes").append(ET.Element("listen", type="address"))

    vid = ET.SubElement(devices, "video")
    ET.SubElement(vid, "model", type="virtio", heads="1", primary="yes")
    ET.SubElement(vid, "address", type="pci", domain="0x0000", bus=get_bus(), slot="0x00", function="0x0")

else:
    print("VNC -> GPUPass")
    # Remove VNC & Video
    for d in list(devices):
        if d.tag in ["graphics", "video"]: devices.remove(d)

    # Add GPU, Audio, USB
    def add_pci(bus, func, rom, dest_bus):
        dev = ET.SubElement(devices, "hostdev", mode="subsystem", type="pci", managed="yes")
        ET.SubElement(dev, "driver", name="vfio")
        ET.SubElement(ET.SubElement(dev, "source"), "address", domain="0x0000", bus=bus, slot="0x00", function=func)
        ET.SubElement(dev, "rom", file=rom)
        ET.SubElement(dev, "address", type="pci", domain="0x0000", bus=dest_bus, slot="0x00", function="0x0")

    add_pci("0x06", "0x0", "/usr/share/vgabios/vbios_1638.dat", get_bus())
    add_pci("0x06", "0x1", "/usr/share/vgabios/ATIAudioDevice_AA01.rom", get_bus())

    usb = ET.SubElement(devices, "hostdev", mode="subsystem", type="usb", managed="yes")
    src = ET.SubElement(usb, "source")
    ET.SubElement(src, "vendor", id="0x046d"); ET.SubElement(src, "product", id="0xc548")

# 4. Apply
subprocess.run(["virsh", "define", "/dev/stdin"], input=ET.tostring(xml, encoding="unicode"), text=True, check=True)
virsh(f"start {VM}", output=False)
