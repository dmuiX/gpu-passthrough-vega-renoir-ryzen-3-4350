# GPU Passthrough Vega iGPU on a Ryzen 3 4350 with VEGA 6 Renoir Architecture or Any other Vega iGPU 5700G, 5600G

## Finally Figured Out how to make the iGPU run as a passthrough GPU!

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
  5.  I had to do this to make the install run under DEbian 12 with kernel 6.12
    	•	Edit `src/amd/amdgpu/atom.c`
	    •	Change line 32: From:
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

### Somtimes another stepp is necessary - was the case for the 5700G, the 4350G did work without it!

  1. adding a reset_gpu.bat script as logon
  2. and a disable_gpu.bat script on shutdown/restart

# AMD Ryzen 7 5700G Vega 8 (0x1638) Vendor-Reset Testing Documentation

---

## Test 1: amd_vega10_ops

### dmesg Output

[ 1283.704085] vfio-pci 0000:06:00.0: enabling device (0400 -> 0403)  
[ 1283.704186] vfio-pci 0000:06:00.0: AMD_VEGA10: version 1.0  
[ 1283.704189] vfio-pci 0000:06:00.0: AMD_VEGA10: performing pre-reset  
[ 1283.716081] vfio-pci 0000:06:00.0: AMD_VEGA10: performing reset  
[ 1283.717710] ATOM BIOS: 13-CEZANNE-019  
[ 1283.717720] vfio-pci 0000:06:00.0: AMD_VEGA10: SMU error 0xfe  
[ 1283.717733] vfio-pci 0000:06:00.0: AMD_VEGA10: failed to reset device  
[ 1283.728054] vfio-pci 0000:06:00.0: AMD_VEGA10: reset result = 0  

### Symptoms

- First VM boot post host reboot: Display output but Windows Device Manager shows Error 31.  
- Second VM boot: Black screen, VM unresponsive.

---

## Test 2: amd_polaris10_ops (Polaris12)

### dmesg Output

[  917.682022] vfio-pci 0000:06:00.0: enabling device (0400 -> 0403)  
[  917.682125] vfio-pci 0000:06:00.0: AMD_POLARIS12: version 1.1  
[  917.682128] vfio-pci 0000:06:00.0: AMD_POLARIS12: performing pre-reset  
[  917.694257] vfio-pci 0000:06:00.0: AMD_POLARIS12: performing reset  
[  917.718406] vfio-pci 0000:06:00.0: AMD_POLARIS12: reset result = 0  

### Symptoms

- First VM boot without host reboot: Black screen (dirty state).  
- First VM boot after host reboot: Display output, but Windows Error 31.  
- VM reboot: Display output, Error 31 persists.

---

## Test 3: amd_vega20_ops

### dmesg Output

[ 1050.564151] vfio-pci 0000:06:00.0: AMD_VEGA20: version 1.0  
[ 1051.088339] vfio-pci 0000:06:00.0: AMD_VEGA20: psp mode1 reset succeeded  
[ 1051.112500] vfio-pci 0000:06:00.0: AMD_VEGA20: reset result = 0  

### Symptoms

- VM boots immediately after VM shutdown (no host reboot).  
- Windows Error 31 persists.  
- AMD GPU driver installation causes system crashes/reboots.

---

## Test 4: amd_navi10_ops

### dmesg Output

[  472.195742] ATOM BIOS: 13-CEZANNE-019  
[  472.195751] vfio-pci 0000:06:00.0: AMD_NAVI10: bus reset disabled? yes  
[  472.195834] vfio-pci 0000:06:00.0: SMU error 0xff  
[  472.713307] vfio-pci 0000:06:00.0: AMD_NAVI10: mode1 reset succeeded  
[  472.737506] vfio-pci 0000:06:00.0: AMD_NAVI10: reset result = 0  

### Symptoms

- VM boots showing display output.  
- Error 31 initially cleared.  
- AMD driver install causes system freeze.  
- Subsequent boots black screen.

---

## IOMMU Page Faults

### dmesg Output

[ 1065.485081] amd_iommu_report_page_fault: 113 callbacks suppressed  
[ 1065.485086] vfio-pci 0000:06:00.0: AMD-Vi: Event logged [IO_PAGE_FAULT domain=0x0000 address=0x342230000 flags=0x0050]  
... (multiple IO_PAGE_FAULT events) ...  

### Symptoms

- Page faults logged during VM activity, especially after driver installs.  
- VM freezes and loses display output.

---

## Navi10 VM Reboot Dmesg & Symptoms

### dmesg Output

[  841.752278] ATOM BIOS: 13-CEZANNE-019  
...  
[  842.295713] vfio-pci 0000:06:00.0: AMD_NAVI10: reset result = 0  

### Symptoms

- Correct resolution shown.  
- Error 31 gone.  
- AMD driver install freezes system.  
- Virsh shutdown succeeds despite freeze.

---

## Navi10 VM Startup with IOMMU Faults

### dmesg Output

[ 1065.485081] amd_iommu_report_page_fault: 113 callbacks suppressed  
[ 1067.353925] vfio-pci 0000:06:00.0: AMD_NAVI10: performing post-reset  
[  991.271365] vfio-pci 0000:06:00.0: SMU error 0xff  
[ 1067.377927] vfio-pci 0000:06:00.0: AMD_NAVI10: reset result = 0  
[ 1070.486600] vfio-pci 0000:06:00.0: AMD-Vi: Event logged [IO_PAGE_FAULT domain=0x000c address=...]  

### Symptoms

- GPU dirty after VM reboot.  
- No display output on some boots.  
- System instability while installing drivers.

---

You can copy this Markdown content as is into any editor or converter for PDF or other documentation formats. If you want me to help with conversion steps, please let me know!

# Conclusion and Comparison of AMD Ryzen 7 5700G Vendor-Reset Methods

## Overview

Based on extensive testing of various reset methods with the AMD Ryzen 7 5700G integrated Vega 8 GPU, the reset methods vary significantly in effectiveness, kernel reset quality, Windows driver acceptance, and VM stability.

---

## Reset Methods Tested

| Reset Method    | Kernel Reset Stability          | Windows Error 31 Presence | VM Usability & Stability                     |
|-----------------|--------------------------------|---------------------------|----------------------------------------------|
| **amd_vega10**  | Poor: SMU errors, reset fails   | Yes                       | VM unusable after reboot, black screen       |
| **amd_polaris10** | Better, clean reset logs       | Yes                       | Usable but persistent Error 31                |
| **amd_vega20**   | Good, PSP reset success         | Yes                       | Works with Error 31, driver install crashes  |
| **amd_navi10**   | Good, some SMU errors tolerated | No initially              | Best Windows usability; freezes on driver install |

---

## Detailed Remarks

- **Worst was `amd_vega10_ops`.** It produced SMU errors and failed to reset properly, resulting in unstable VMs and Windows reporting Error 31 consistently.

- **`amd_polaris10_ops` and `amd_vega20_ops` showed improvements** at the kernel level with cleaner reset logs and successful PSP firmware resets, but Windows guest OS still experienced Error 31, and driver installation caused system crashes or reboots.

- **`amd_navi10_ops` was the best method tested.** It resulted in a VM boot with correct resolution and no Error 31 initially. However, attempts to install official AMD drivers led to system freezes and black screens on subsequent boots, indicating remaining issues with driver and hardware state management.

---

## Additional Observations

- IO_PAGE_FAULT events logged in kernel dmesg suggest IOMMU/memory mapping complications affecting GPU stability during VM lifecycle events.

- Windows drivers are fragile regarding GPU passthrough on Ryzen APUs and often require guest-side reset utilities or complete host reboots to maintain functionality.

- The perfect “clean reset” for integrated AMD GPUs in passthrough scenarios remains a challenging problem, with ongoing active development in vendor-reset and related projects.

---

## Recommendations

- Focus on the `amd_navi10_ops` reset method for best initial VM experience.

- Consider using guest-side tools like RadeonResetBugFix to mitigate driver issues.

- Maintain workflows with host reboot before VM launch to ensure hardware clean states.

- Keep track of BIOS and kernel updates for better IOMMU and GPU reset support.

---

This summary reflects your detailed testing journey and analysis on AMD vendor-reset methods for Ryzen 7 5700G iGPU passthrough.

