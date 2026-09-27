// SPDX-License-Identifier: GPL-2.0
/*
 * Steam Machine (Fremont): power off instead of booting up again.
 *
 * Since Linux 7.2 ("pinctrl-amd: Don't clear S4 wake bits at probe") the
 * S4/S5 wake bit the firmware leaves set on GPIO pin 18 (_SB.PCI0.GPP6)
 * stays set, and the machine starts again right after powering off.
 * Valve's kernel clears that bit at probe on Fremont (not for upstream);
 * this does the same right before power-off, for kernels without it.
 */
#include <linux/acpi.h>
#include <linux/bits.h>
#include <linux/dmi.h>
#include <linux/io.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/reboot.h>

#define FREMONT_GPP6_PIN	18
#define WAKE_CNTRL_OFF_S4	15

static void __iomem *pin_reg;
static struct sys_off_handler *handler;

static int fremont_poweroff_prepare(struct sys_off_data *data)
{
	u32 v = readl(pin_reg);

	if (v & BIT(WAKE_CNTRL_OFF_S4))
		writel(v & ~BIT(WAKE_CNTRL_OFF_S4), pin_reg);
	return NOTIFY_DONE;
}

static int __init fremont_poweroff_init(void)
{
	struct acpi_device *adev;
	struct device *dev;
	struct resource *res;
	u32 v;

	if (!dmi_match(DMI_BOARD_NAME, "Fremont"))
		return -ENODEV;
	adev = acpi_dev_get_first_match_dev("AMDI0030", NULL, -1);
	if (!adev)
		return -ENODEV;
	dev = bus_find_device_by_acpi_dev(&platform_bus_type, adev);
	acpi_dev_put(adev);
	if (!dev)
		return -ENODEV;
	res = platform_get_resource(to_platform_device(dev), IORESOURCE_MEM, 0);
	put_device(dev);
	if (!res || resource_size(res) < (FREMONT_GPP6_PIN + 1) * 4)
		return -ENODEV;
	/* pinctrl-amd owns the region; only this one register is touched. */
	pin_reg = ioremap(res->start + FREMONT_GPP6_PIN * 4, 4);
	if (!pin_reg)
		return -ENOMEM;
	v = readl(pin_reg);
	pr_info("GPIO %d register 0x%08x, S4/S5 wake %s\n", FREMONT_GPP6_PIN, v,
		v & BIT(WAKE_CNTRL_OFF_S4) ? "set (cleared at power-off)" : "clear");
	handler = register_sys_off_handler(SYS_OFF_MODE_POWER_OFF_PREPARE,
					   SYS_OFF_PRIO_DEFAULT, fremont_poweroff_prepare, NULL);
	if (IS_ERR(handler)) {
		iounmap(pin_reg);
		return PTR_ERR(handler);
	}
	return 0;
}

static void __exit fremont_poweroff_exit(void)
{
	unregister_sys_off_handler(handler);
	iounmap(pin_reg);
}

module_init(fremont_poweroff_init);
module_exit(fremont_poweroff_exit);
MODULE_DESCRIPTION("Steam Machine: clear GPIO 18's S4 wake bit before power-off");
MODULE_LICENSE("GPL");
MODULE_ALIAS("dmi:*:rnFremont:*");
