#!/usr/bin/env python3
import subprocess
import sys
import re
import xml.etree.ElementTree as ET

VMNAME = "Win11"
XMLFILE = "/etc/libvirt/qemu/Win11.xml"

subprocess.run(["virsh", "shutdown", VMNAME], stderr=subprocess.DEVNULL)
subprocess.run(["sleep", "5"])
subprocess.run(["virsh", "undefine", VMNAME])

# Parse XML to find used buses
tree = ET.parse(XMLFILE)
root = tree.getroot()

used_buses = set()
for address in root.findall(".//address[@type='pci']"):
    bus = address.get('bus')
    if bus:
        used_buses.add(bus)

print(f"Used buses: {used_buses}")

# Find first free bus (start from 0x06)
free_bus = None
for i in range(0x06, 0x20):
    bus_hex = f"0x{i:02x}"
    if bus_hex not in used_buses:
        free_bus = bus_hex
        break

if not free_bus:
    print("ERROR: No free PCI buses!")
    sys.exit(1)

print(f"Using bus {free_bus} for GPU audio")

with open(XMLFILE, 'r') as f:
    xml = f.read()

GPU_BLOCK = f'''    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
      </source>
      <rom file='/usr/share/vgabios/vbios_1638.dat'/>
      <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='0x0000' bus='0x06' slot='0x00' function='0x1'/>
      </source>
      <rom file='/usr/share/vgabios/ATIAudioDevice_AA01.rom'/>
      <address type='pci' domain='0x0000' bus='{free_bus}' slot='0x00' function='0x0'/>
    </hostdev>
    <hostdev mode='subsystem' type='usb' managed='yes'>
      <source>
        <vendor id='0x046d'/>
        <product id='0xc548'/>
        <address bus='3' device='2'/>
      </source>
      <address type='usb' bus='0' port='1'/>
    </hostdev>'''

VNC_BLOCK = '''    <graphics type='vnc' port='-1' autoport='yes'>
      <listen type='address'/>
    </graphics>
    <video>
      <model type='virtio' heads='1' primary='yes'/>
      <address type='pci' domain='0x0000' bus='0x10' slot='0x00' function='0x0'/>
    </video>'''

if "graphics type='vnc'" in xml:
    print("VNC+Virtio → GPU passthrough...")
    # Remove VNC + Video
    xml = re.sub(r"    <graphics type='vnc'.*?</graphics>\n", "", xml, flags=re.DOTALL)
    xml = re.sub(r"    <video>.*?</video>\n", "", xml, flags=re.DOTALL)
    # Add GPU
    xml = xml.replace("    <audio id='1' type='none'/>", f"    <audio id='1' type='none'/>\n{GPU_BLOCK}")
else:
    print("GPU passthrough → VNC+Virtio...")
    # Remove GPU blocks
    xml = re.sub(r"    <hostdev mode='subsystem' type='pci'.*?</hostdev>\n", "", xml, flags=re.DOTALL)
    xml = re.sub(r"    <hostdev mode='subsystem' type='usb'.*?</hostdev>\n", "", xml, flags=re.DOTALL)
    # Add VNC
    xml = xml.replace("    <audio id='1' type='none'/>", f"    <audio id='1' type='none'/>\n{VNC_BLOCK}")

# Write XML
with open(XMLFILE, 'w') as f:
    f.write(xml)

subprocess.run(["virsh", "define", XMLFILE])
subprocess.run(["virsh", "start", VMNAME])
print("Done!")
