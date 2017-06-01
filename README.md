kvm-boot
========

kvm-boot is for folks who work on Linux kernel development and want to test
kernel compiles fast with an extremely lightweight and very easy to read simple
test script. It is currently x86_64 biased, however some initial tests have
been done to make it work with other architectures.

Build
-----

There are not build requirements. Its all shell.

Install
-------

Just run:

	$ make install

Setup
-----

# Networking setup

When you decide you need to spawn guests just run this prior to spawning guests:

	$ sudo ~/bin/setup-switch

You may need to edit the file to replace WIRELESS_DEV variable for whatever
your actual networking interface is.

You should see:

	Setting up switch on tap0
	net.ipv4.ip_forward = 1

That should get your system setup for networking. It will allow your guests to
run using DHCP with full networking. Your hosts will have a functional access
to the network so long as your host does too. Although this does use dnsmasq we
prefer to specify all requirements on the command line instead of asking you to
have a custom configuraiton file or edit it. This strives for sensible defaults
that might work for most).

# KVM use for users

You will want to enable use of kvm for users. Typically this can be done
by letting the user be part of the kvm group. This will be important also
for networking purposes, in particular you will want the /var/run/qemu-vde.ctl
directory owned by kvm group, and files created as well. Using the sticky
bit should suffice.

Usage
-----

There are two main uses, direct kernel file boot:

	$ kvm-boot -k arch/x86/boot/bzImage

Raw image boot:

	$ kvm-boot -b

Additionally if you are working on qemu development you can always use:

	$ kvm-boot -d # use $HOME/devel/qemu/x86_64-softmmu/qemu-system-x86_64

Requirements
------------

You should have installed on your development system where you will
run guests from:

  * vde2
  * dnsmasq
  * iptables

Project goals
-------------

# What we strive for

  * We *want* a super easy-to-read simple script
  * We *want* a distribution-agnostic solution
  * We *want* _full_ solid network connectivity for the guest kernels
  * We *want* network connectivity to be *super easy* to setup
  * We *want* to allow for qemu-development in a simple way
  * We *want* to rely on screen(1) /usr/bin/screen
  * We *want* suspend to RAM / disk & resume to work on hypervisor host
  * We *want* to avoid having to copy over linux sources over and over again

# What we want to avoid

  * We *do not* want to deal with complex initramfs setup
  * We *do not* want to require root access for guest spawning
  * We *do not* want to deal with the complex network bridge setup
  * We *do not* want to deal with complex test infrastructure
  * We *do not* want to deal with fancy GUI crap

The two methods to boot guests
------------------------------

When working on kernel development you typically have two ways to use KVM.
They each have their pros and cons. We support both.

 * Direct file: Passing qemu -kernel and -initrd for direct boot use
 * Disk images: using qcow2 disk image

We document each case further below.

# Direct file

	$ kvm-boot -k arch/x86/boot/bzImage

This method allows you to compile kernel code on your local filesystem, and
just boot into those kernels. Typically this does require initramfs setup,
however, we provide initramfs inference support. Initramfs inferences support
relies on the *premise* that distributions have a proper /sbin/installkernel
script.

One of the tricky aspects of using this method is you need a kernel with
proper support for your KVM guest. You milleage may vary.

## The Linux kernel /sbin/installkernel

The Linux kernel gives you the option to have a scrip called /sbin/installkernel
which will be used on the 'make install' target of the Linux kernel. Typically
this is where distributions shove in their initramfs setup. Most distributions
rely on this script, and in fact is relied on by a slew of kernel developers to
install ther compiled Linux kernel and modules without *ever* having to deal
with local distribution shenanigans.

You should always be able to compile and install a kernel as follows on any
Linux distribution:

	$ make
	$ sudo make modules_install install

## Relying on /sbin/installkernel

We take advantage of how Linux distributions use /sbin/installkernel to ensure
proper initramfs setup for you for guest setup in a distribution agnostic way.
This does require you however to install a target kernel once.

## Enable your target development as built-in

Relying on /sbin/installkernel enables you to deploy an initramfs once, and
provided you do not need to rely on that initramfs for new code deltas
(re-compile modules) you are testing you can boot a second time by only
compiling code locally without re-generating the initramfs.

Since you might often be doing development with what typically is enabled as
modules you can can avoid the module catch-22 issue here by just enabling your
development target and its dependencies to be compiled as built-in.

If you *really* want to be relying on modules you can consider the other method
of development work flow with kvm-boot using raw images. An alternative for
the future is to consider eventual integration of optionally kicking off
/sbin/installkernel as an option as a *regular user* during the Linux kernel
'make' target, which would build the initramfs locally within the Linux kernel
source tree.

## kvm-boot initramfs setup

kvm-boot assumes you have your initramfs correctly built and installed by
relying on you installing the development kernel locally to your system *once*.
Since kvm-boot is a distribution agnostic solution we assume the developer can
always (regardless of what distribution they are using) can simply always
install kernels and modules you have compiled with:

	$ make -j 4 # compile kernel and modules

And then install the kernel and initramfs as follows:

	$ sudo make modules_install install  # installs kernel and initramfs

Distribution packaging solutions (rpm, deb) use this target and should rely
on /sbin/installkernel anyway. Intalling kernel/modules using distribution
package solutions should therefore always work as well. If relying on this
does not work it should be considered a distribution bug.

## Initramfs inference support

Current initramfs inference is rather simple and relies on you specifying the
target kernel you want to use, refer for parse_passed_kernel() for details.

## Using the latest kernel

By default kvm-boot will look for the latest installed kernel / initramfs on
/boot/ and use that. Otherwise you should specify the target kernel using -k. 
If you want to be explicit about using the latest kernel found on /boot you
can always use:

	$ kvm-boot -l

# Disk images

Using disk images is convenient to do away with all the above required setup.
We suppot qcow2 disk image format by default. You will first need to setup a
basic qemu image you can use for development purposes. You actually will want
to setup at least two disk images eventually, one for the guest image, and
another for the Linux kernel sources which you can share accross images.

To start off with build a qcow2 disk image you can use to boot qemu from. We
start off with by using an ISO and a raw qcow2 file we will use as target
raw image. For now we supply an example guest script which folks can simply
customize as they see fit to enable them to install an ISO image of their
choice onto a qcow2 image.

## qcow2 image setup

You want to setup at least 2 qcow2 disk images. One for the guest, another for
the Linux kernel sources.

### qcow2 guest image setup

You will want to create a qcow2 image, 6 GiB typically works, as we will want
to deploy our Linux kernel sources in another larger image. This should be
enough to to also carry your /boot/, we'll practice to keep it small using
the script install-next-kernel.sh on the guest when installing kernels.
This assumes you are using linux-next.git for your development work flow.

	$ qemu-img create -f qcow2 /opt/qemu/some.img 6G

### qcow2 Linux kernel development image

You'll want a secondary image you can use with much larger size so you can use
it for stashing your linux kernel sources.

	$ qemu-img create -f qcow2 /opt/qemu/linux-next.qcow2 50G

To copy over the linux sources you can do from the host:

	$ sudo modprobe nbd max_part=16
	$ sudo qemu-nbd -c /dev/nbd0 /opt/qemu/linux-next.qcow2
	# Create primary parition and take up all the space
	$ sudo fdisk /dev/nbd0
		Command (m for help): n
		...
		Select (default p): p
		...
		Partition number (1-4, default 1): 1
		...
		First sector (2048-20971519, default 2048): 
		...
		Last sector, +sectors or +size{K,M,G,T,P} (2048-20971519, default 20971519): 
		...
		Command (m for help): t
		...
		Partition type (type L to list all types): 83
		...
		Command (m for help): w
	$ sudo partprobe /dev/nbd0
	$ sudo mkfs.ext4 /dev/nbd0p1
	$ sudo mkdir -p /mnt/linux-next
	$ sudo mount /dev/nbd0p1 /mnt/linux-next
	$ sudo cp -a ~/linux-next/ /mnt/linux-next
	$ sudo umount /mnt/linux-next
	$ sudo qemu-nbd -d /dev/nbd0
	# nbd has buggy suspend/resume, better remove it
	$ sudo modprobe -r nbd

This image is exposed to the kvm-boot guest kernel we boot later as a secondary
disk, using qemu -hdb parameter.

## guest-install

guest-install scripts can help you install an ISO image onto a target qcow2
image file, with a fully functionaly network in place, and exposing the
linux-next development target image as a secondary disk. Example use:

	$ ./guest-install -i /opt/isos/some.iso \
			  -t /opt/qemu/some.img \
			  -n /opt/qemu/linux-next.qcow2

That will by defalut use SDL to kick off your installation. Follow the steps to
install the guest, be sure to install and enable SSH, some distros disable this
by default.

You can configure the install as you wish, just be sure to dedicate the larger
disk for your say, $HOME/$USER/data/ partition.

Some installers are rather pesky and assume the larger disk is where the target
install should be, and sometimes they make it rather difficult through the GUI
to modify the fact that you just want the larger disk to be used for a home
subdirectory for you. So you may want to just skip the -n option and use: -n
none:

	$ ./guest-install -i /opt/isos/some.iso \
			  -t /opt/qemu/some.img \
			  -n none

If you do this can later expose the disk on a second boot and configure it to
be mounted on $HOME/$USER/data as follows on /etc/fstab:

	/dev/sdb1	/home/mcgrof/data	ext4    errors=remount-ro 0       1

Once done with the install you can use the *same exact command* to boot off the
hard drive provided the ISO gives you that option (most distros do this). You
want to do a first boot to configure the guest a bit for the last touches so
you can start hacking away in a nice development environment.

Be sure to expose the development disk so you can configure a mount point for
it as recommended above, so *make sure* to use the -n option with the respective
linux-next.qcow2 file.

## Preparing for first kvm-boot use on guest

Once you are done with the installation of the guest there are a few more things
you will want to set up to be a happy camper Linux developer using kvm-boot,
you can set these up using the same guest-install script as described above
and booting from the hard disk.

You will want to do the following:

  * console access - useful for early crashes or in case networking dies
  * grub tty setup - lets you select your kernels on the boot prompt
  * write down the guest IP address - these should be static after first DHCP

### Setting up console and grub

Edit /etc/securetty and ensure you have the entries:

	ttyS0
	ttyS1
	ttyS2

You will also need to setup the getty to spawn. This will vary depending
on what init system you are using. If you are using old init you will
need to add the entries on /etc/inittab:

	T0:23:respawn:/sbin/getty -L ttyS0 115200 vt100
	T1:23:respawn:/sbin/getty -L ttyS1 115200 vt100
	T1:23:respawn:/sbin/getty -L ttyS2 115200 vt100

On systemd this is done as follows:

	systemctl enable console-getty.service getty@ttyS0.service
	systemctl enable console-getty.service getty@ttyS1.service
	systemctl enable console-getty.service getty@ttyS2.service

Edit the guest /etc/default/grub and ensure you have these entries:

	GRUB_CMDLINE_LINUX="console=ttyS1,115200 console=ttyS1"
	GRUB_TERMINAL=serial

The last line mentioned above enables you to select a kernel through the
grub prompt through serial.

After this you will need to run the boot loader refresh script for your
distribution so that the grub configuration files get updated.

  * Debian: update-grub
  * OpenSUSE: update-bootloader --refresh

## Booting development guest for the first time

Provided you could setup all the above correctly you should be ready to go.
Try now:

	$ kvm-boot -t /opt/qemu/some.img -n /opt/qemu/linux-next2.qcow2

You should see something like this on stdout:

	Going to boot directly onto image disk
	qemu-system-x86_64: -monitor pty: char device redirected to /dev/pts/9 (label compat_monitor0)
	qemu-system-x86_64: -chardev pty,id=ttyS1: char device redirected to /dev/pts/11 (label ttyS1)
	qemu-system-x86_64: -chardev pty,id=ttyS2: char device redirected to /dev/pts/12 (label ttyS2)

We purposely redirect two ttys to a PTS so you can then use screen to attach
to them (root should not be required). You can also get access to the qemu
control interface using screen as well:

	$ screen /dev/pts/9
	$ screen /dev/pts/11
	$ screen /dev/pts/12

## Sshing into your guest image

Make sure to write down the IP address of the guest before using kvm-boot, you
should then be able to ssh into it. There is a slew of issues which can occur
when using console (see the WTF note on kvm-boot), for this reason the author
has relied mostly on ssh for access to the system.

## Keeping your /boot small

When using qcow2 images you may often find /boot can fill up quickly when
doing a lot of development. If you are working with a linux-next development
work flow you can consier copying over the file install-next-kernel.sh and
using that when installing your kernels, it will make sure to always remove
old linux-next instances, while keeping your distribution kernels.

TODO
----

  * Document how to get direct raw access to disk for filesystem benchmarking and
    testing.
  * Make sure the above intructions work for most distributions and adjust as
    needed
