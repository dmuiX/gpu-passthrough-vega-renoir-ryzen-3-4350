# GPU Passthrough Vega iGPU on a Ryzen 3 4350 with VEGA 6 Renoir Architecture or Any other Vega iGPU 5700G, 5600G

## Finally Figured Out how to make the iGPU run as a passthrough GPU!

### Best way

is definetly to add the igpu to vendor_reset: https://github.com/gnif/vendor-reset src file like that: {PCI_VENDOR_ID_ATI, 0x1636, op, DEVICE_INFO(AMD_NAVI10)}, \
and then add a manage-gpu script in Windows wich resets the gpu on startup and disables it on shutdown

## Some Instructions
here some one has describe what he had done to make it work:

https://forum.proxmox.com/threads/amd-ryzen-5600g-igpu-code-43-error.138665/

kind of followed these steps as well!

### vendor-reset
  1. clone this repo: https://github.com/gnif/vendor-reset
  2. find out the vendor id: lspci -nkk
  3. add your one (renoir is 1636, cezanne is 1638) to the src/device-db.h file in the vendor-reset folder under AMD_NAVI10:
      85 #define _AMD_NAVI10(op) \
      86     {PCI_VENDOR_ID_ATI, 0x1636, op, DEVICE_INFO(AMD_NAVI10)}, \
      87     {PCI_VENDOR_ID_ATI, 0x7310, op, DEVICE_INFO(AMD_NAVI10)}, \
      88     {PCI_VENDOR_ID_ATI, 0x7312, op, DEVICE_INFO(AMD_NAVI10)}, \
  4. install it with dkms install .
  5.  I had to do this to make the install run under Debian 12/13 with kernel 6.12
    	•	Edit `src/amd/amdgpu/atom.c`
	    •	Change line 32:From:
       #include <asm/unaligned.h>
        to
       #include <linux/unaligned.h>
  6. then add the module (its actually called vendor_reset not with -!) to the /etc/module
  7. Restart
### IOMMU and grub
1. Luckily my mainboard has my gpu already on a separate iommu group, otherwise you would have to separate your iommu group with sth. like asm google it and you will find what I mean
2. For me no further grub options were necesssary as my system - a headless debian 12 server with omv installed - seems to diasble the gpu on the host automatically.
### vga-bios:
   1. Find out how to extract your vbios rom and the hdmi audio rom from either the GPU or an UEFI update File.
      
   If you have the same cpu as me - 4350g or a 5700g - you can use the dat files from here.
   vbios_1636.dat is the vega 6 of the 4350G
   vbios_1638.dat is the vega 8 of the 5700G.
   ATIAudioDevice_AA01.rom file for the HDMI audio device can be used for both!
     
   IMPORTANT: You must include the audio device otherwise the passthrough will end as the famous error 43.

   To extract my files from the bios update file: 
   I did use this one here: https://winraid.level1techs.com/t/tool-guide-news-uefi-bios-updater-ubu/3035 called UBU-1.80 and a UEFI File
   Actually just extracted it and then used UBU.cmd which asked for my UEFI Update file.
   then you need to convert it as well:
	
 	https://github.com/isc30/ryzen-gpu-passthrough-proxmox?tab=readme-ov-file#configuring-the-gpu-in-the-windows-vm
	https://github.com/isc30/ryzen-gpu-passthrough-proxmox/discussions/18#discussioncomment-8627679

  2. Add the vbios to the folder /usr/share/vgabios nothing else works for kvm under Debian!
  3. Add the PCIe Devices to your domain.xml and define the rom file:
     ```xml
	     <hostdev mode="subsystem" type="pci" managed="yes">
	      <source>
	        <address domain="0x0000" bus="0x06" slot="0x00" function="0x0"/>
	      </source>
	      <rom file="/usr/share/vgabios/vbios_1636.dat"/>
	      <address type="pci" domain="0x0000" bus="0x06" slot="0x00" function="0x0"/>
	    </hostdev>
	    <hostdev mode="subsystem" type="pci" managed="yes">
	      <driver name="vfio"/>
	      <source>
	        <address domain="0x0000" bus="0x06" slot="0x00" function="0x1"/>
	      </source>
	      <rom file="/usr/share/vgabios/ATIAudioDevice_AA01.rom"/>
	      <address type="pci" domain="0x0000" bus="0x09" slot="0x00" function="0x0"/>
	    </hostdev>
    ```
### other options in the xml file

1. UEFI is Necessary! So you need to configure the vm to use uefi and secure boot as well.
   Although I suppose when you create a Win11 VM with virt-manager it will activate this stuff automatically.
   
   ```xml
   <os firmware='efi'>
    <type arch='x86_64' machine='pc-q35-10.0'>hvm</type>
    <firmware>
      <feature enabled='yes' name='enrolled-keys'/>
      <feature enabled='yes' name='secure-boot'/>
    </firmware>
    <loader readonly='yes' secure='yes' type='pflash' format='raw'>/usr/share/OVMF/OVMF_CODE_4M.ms.fd</loader>
    <nvram template='/usr/share/OVMF/OVMF_VARS_4M.ms.fd' templateFormat='raw' format='raw'>/var/lib/libvirt/qemu/nvram/Win11_VARS.fd</nvram>
    <bootmenu enable='no'/>
   </os>
   ```

2. Actually have activated a ton of other options of kvm unsure which ones are really necessary for windows to work.
   dont want to test anymore so I will laeve it like that for now:
	
   ```xml
	   <features>
	    <acpi/>
	    <apic/>
	    <hyperv mode='custom'>
	      <relaxed state='on'/>
	      <vapic state='on'/>
	      <spinlocks state='on' retries='8191'/>
	      <vpindex state='on'/>
	      <synic state='on'/>
	      <stimer state='on'/>
	      <reset state='on'/>
	      <vendor_id state='on' value='1756857dhai7'/>
	      <frequencies state='on'/>
	      <reenlightenment state='on'/>
	      <tlbflush state='on'/>
	      <ipi state='on'/>
	    </hyperv>
	    <kvm>
	      <hidden state='on'/>
	    </kvm>
	    <vmport state='off'/>
	    <smm state='on'/>
	    <ioapic driver='qemu'/>
	  </features>
   ```
### boot into windows
When you have booted to windows install the amd drivers. actually for me the official ones from amd work! have downloaded them manually but I suppso the automatic detection of windows myght work es well

### Celebrate
You have sucessfully implemented a working igpu passthrough, which many say is immpossible :D. 

### Somtimes another stepp is necessary - was the case for the 5700G, the 4350G did work without it

I have created a manage-gpu.bat script which can enable disable and reset a GPU and a AUDIO device.

1. find out the corresponding IDs in the device manager under Details/Device instance path
   looks like this: PCI\VEN_1002&DEV_1638&SUBSYS_D0001458&REV_C8\4&3B1E1872&0&000D
   you can omit this part "\4&3B1E1872&0&000D" and then set it to the GPU_ID and AUDIO_ID in the script
2. import disable_gpu.xml and reset_gpu.xml to the task scheduler
3. save it


Have added a swap-gpu script which swaps my passthrough gpu to the virtio gpu + vnc

# Did not work
qemu hook with just /sys/bus/pci/devices/0000:06:00.0/remove 2>/dev/null
vendor_reset is doing more than that.