#!/bin/bash

KERNEL="next"

sudo rm -rf /lib/modules/*${KERNEL}* /lib/modules/*${KERNEL}*
sudo rm -rf /boot/*${KERNEL}* /boot/*${KERNEL}*
sudo make modules_install install
