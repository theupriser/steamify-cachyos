# Build only modules that the target kernel does not already provide. DKMS
# applies the matching BUILD_EXCLUSIVE_CONFIG rules when it collects and
# installs the results; these Kbuild checks also avoid compiling an excluded
# module during the shared make invocation.
ifeq ($(filter y m,$(CONFIG_MFD_STEAMDECK)),)
obj-m += steamdeck.o
endif

ifeq ($(filter y m,$(CONFIG_SENSORS_STEAMDECK)),)
obj-m += steamdeck_hwmon.o
endif
