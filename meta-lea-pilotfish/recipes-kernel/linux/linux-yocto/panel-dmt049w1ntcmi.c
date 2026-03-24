// SPDX-License-Identifier: GPL-2.0-only
/*
 * Densitron DMT049W1NTCMI-1A  4.9" 480x854 RGB panel driver
 *
 * The display IC (Sitronix ST7102) drives the RGB parallel bus for pixels
 * but requires a one-time SPI initialisation sequence (Mode 3, 8 MHz) before
 * the LCDC starts clocking data.  This driver implements a drm_panel that
 * fires that sequence in .prepare(), then lets tilcdc/panel-dpi take over.
 *
 * Connections (AM3352 Pilotfish board):
 *   SPI1 CS0  - MCASP0_AHCLKR / gpio3_17  (Mode 3, write-only)
 *   LCD_RSTn  - GPMC_A11      / gpio1_27  (active-low, driven by panel-dpi reset-gpios)
 *   BL_EN_20V - GPMC_AD10     / gpio0_26  (active-high, driven by gpio-backlight)
 *
 * Copyright (C) 2026 LEA GmbH
 */

#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/spi/spi.h>

#include <drm/drm_modes.h>
#include <drm/drm_panel.h>

/* -----------------------------------------------------------------------
 * SPI protocol helpers
 *
 * The ST7102 uses a 9-bit SPI word: bit[8] = D/CX (0=command, 1=data),
 * bits[7:0] = register or data byte.
 *
 * We use an explicit spi_transfer with bits_per_word=9 set per-transfer
 * (overriding the device default), passing the 9-bit value right-justified
 * in a u16. The AM335x McSPI controller sends bits [8:0] MSB-first.
 *
 *   Command: u16 = 0x0000 | reg   (bit8 = 0)
 *   Data:    u16 = 0x0100 | val   (bit8 = 1)
 * ----------------------------------------------------------------------- */

static int dmt_spi_write_word(struct spi_device *spi, u16 word)
{
	struct spi_transfer t = {
		.tx_buf        = &word,
		.len           = sizeof(word),
		.bits_per_word = 9,
	};
	struct spi_message m;

	spi_message_init(&m);
	spi_message_add_tail(&t, &m);
	return spi_sync(spi, &m);
}

static int dmt_spi_write_cmd(struct spi_device *spi, u8 reg)
{
	return dmt_spi_write_word(spi, (u16)reg);          /* bit8 = 0 → command */
}

static int dmt_spi_write_data(struct spi_device *spi, u8 val)
{
	return dmt_spi_write_word(spi, 0x0100 | (u16)val); /* bit8 = 1 → data */
}

/* Convenience macro used in the init table below */
#define CMD(r)   { .is_data = false, .val = (r) }
#define DATA(d)  { .is_data = true,  .val = (d) }
#define DELAY(ms) { .is_data = false, .val = 0xFF, .delay_ms = (ms) }

struct dmt_cmd {
	bool  is_data;
	u8    val;
	u16   delay_ms;
};

/* -----------------------------------------------------------------------
 * Full init sequence from DMT049W1NTCMI-1A initi code (2).txt
 * Reset and EN sequencing is handled in .prepare(); the table starts
 * after the reset has been released and the 120 ms wait has elapsed.
 * ----------------------------------------------------------------------- */
static const struct dmt_cmd dmt_init_sequence[] = {
	CMD(0x10),
	CMD(0x28),

	CMD(0x99), DATA(0x71), DATA(0x02), DATA(0xa2),
	CMD(0x99), DATA(0x71), DATA(0x02), DATA(0xa3),
	CMD(0x99), DATA(0x71), DATA(0x02), DATA(0xa4),

	CMD(0xB0),
		DATA(0x22), DATA(0x6B), DATA(0x1E), DATA(0x75),
		DATA(0x2F), DATA(0x39), DATA(0x43),

	CMD(0xB7), DATA(0x7D), DATA(0x7D),

	CMD(0xBF), DATA(0x95), DATA(0x95),   /* VCOM */

	CMD(0xBA),
		DATA(0x72), DATA(0x76), DATA(0x52), DATA(0xD6),
		DATA(0xC0), DATA(0x20), DATA(0x00), DATA(0x00),

	CMD(0xD7),
		DATA(0x00), DATA(0x0E), DATA(0xC6), DATA(0x19),
		DATA(0xAB), DATA(0xAB),

	CMD(0xA3),
		DATA(0x51), DATA(0x03), DATA(0x88), DATA(0x00),
		DATA(0x44), DATA(0x00), DATA(0x00), DATA(0x00),
		DATA(0x00), DATA(0x04), DATA(0x5C), DATA(0xCF),
		DATA(0x00), DATA(0x1A), DATA(0x00), DATA(0x45),
		DATA(0x05), DATA(0x00), DATA(0x00), DATA(0x00),
		DATA(0x00), DATA(0x46), DATA(0x00), DATA(0x00),
		DATA(0x02), DATA(0x20), DATA(0x52), DATA(0x00),
		DATA(0x00), DATA(0x00), DATA(0x00), DATA(0xFF),

	CMD(0xA7),
		DATA(0x19), DATA(0x19), DATA(0x00), DATA(0x64),
		DATA(0x40), DATA(0x05), DATA(0x14), DATA(0x40),
		DATA(0x00), DATA(0x04), DATA(0x03), DATA(0xCF),
		DATA(0xCF), DATA(0x00), DATA(0x64), DATA(0x40),
		DATA(0x23), DATA(0x67), DATA(0x01), DATA(0x00),
		DATA(0x02), DATA(0x00), DATA(0xCF), DATA(0xCF),
		DATA(0x00), DATA(0x64), DATA(0x40), DATA(0x4B),
		DATA(0x5A), DATA(0x00), DATA(0x00), DATA(0x02),
		DATA(0x01), DATA(0xCF), DATA(0xCF), DATA(0x00),
		DATA(0x24), DATA(0x40), DATA(0x69), DATA(0x78),
		DATA(0x00), DATA(0x00), DATA(0x00), DATA(0x00),
		DATA(0xCF), DATA(0xCF), DATA(0x00), DATA(0x44),

	CMD(0xA6),
		DATA(0x30), DATA(0x00), DATA(0x24), DATA(0x77),
		DATA(0x36), DATA(0x00), DATA(0x37), DATA(0x00),
		DATA(0x5C), DATA(0xCF), DATA(0x02), DATA(0xE4),
		DATA(0x99), DATA(0x00), DATA(0x0B), DATA(0x00),
		DATA(0x0B), DATA(0xCF), DATA(0x5C), DATA(0x02),
		DATA(0xA4), DATA(0x11), DATA(0x00), DATA(0x00),
		DATA(0x00), DATA(0x00), DATA(0x5C), DATA(0xCF),
		DATA(0x00), DATA(0xAC), DATA(0x11), DATA(0x00),
		DATA(0x00), DATA(0x00), DATA(0x00), DATA(0x5C),
		DATA(0xCF), DATA(0x00), DATA(0x00), DATA(0x06),
		DATA(0x00), DATA(0x00), DATA(0x00), DATA(0x00),

	CMD(0xA7),
		DATA(0x19), DATA(0x19), DATA(0x00), DATA(0x64),
		DATA(0x40), DATA(0x05), DATA(0x14), DATA(0x40),
		DATA(0x00), DATA(0x04), DATA(0x03), DATA(0x5C),
		DATA(0xCF), DATA(0x00), DATA(0x64), DATA(0x40),
		DATA(0x23), DATA(0x67), DATA(0x01), DATA(0x00),
		DATA(0x02), DATA(0x00), DATA(0x5C), DATA(0xCF),
		DATA(0x00), DATA(0x64), DATA(0x40), DATA(0x4B),
		DATA(0x5A), DATA(0x00), DATA(0x00), DATA(0x02),
		DATA(0x01), DATA(0x5C), DATA(0xCF), DATA(0x00),
		DATA(0x24), DATA(0x40), DATA(0x69), DATA(0x78),
		DATA(0x00), DATA(0x00), DATA(0x00), DATA(0x00),
		DATA(0x5C), DATA(0xCF), DATA(0x00), DATA(0x44),

	CMD(0xAC),
		DATA(0x13), DATA(0x10), DATA(0x01), DATA(0x00),
		DATA(0x1C), DATA(0x12), DATA(0x02), DATA(0x1B),
		DATA(0x18), DATA(0x09), DATA(0x19), DATA(0x1A),
		DATA(0x1B), DATA(0x1B), DATA(0x18), DATA(0x1B),
		DATA(0x0B), DATA(0x11), DATA(0x00), DATA(0x02),
		DATA(0x1C), DATA(0x0A), DATA(0x02), DATA(0x18),
		DATA(0x18), DATA(0x08), DATA(0x19), DATA(0x1A),
		DATA(0x1B), DATA(0x1B), DATA(0x18), DATA(0x1B),
		DATA(0xFF), DATA(0xFF), DATA(0xFF), DATA(0xFF),
		DATA(0x00),

	CMD(0xAD),
		DATA(0xCC), DATA(0x40), DATA(0x46), DATA(0x11),
		DATA(0x04), DATA(0x5C), DATA(0xCF),

	CMD(0xE8),
		DATA(0x30), DATA(0x07), DATA(0x00), DATA(0xEB),
		DATA(0xEB), DATA(0x9C), DATA(0x00), DATA(0xE2),
		DATA(0x04), DATA(0x00), DATA(0x00), DATA(0x00),
		DATA(0x00), DATA(0xEF),

	CMD(0xE9),
		DATA(0x3C), DATA(0x7F), DATA(0x08), DATA(0x0C),
		DATA(0x1A), DATA(0x7A), DATA(0x22), DATA(0x1A),
		DATA(0x33),

	CMD(0x75), DATA(0x03), DATA(0x04),

	CMD(0xE7),
		DATA(0x8B), DATA(0x3C), DATA(0x00), DATA(0x0C),
		DATA(0xF0), DATA(0x5D), DATA(0x00), DATA(0x5D),
		DATA(0x05), DATA(0x5D), DATA(0x00), DATA(0x5D),
		DATA(0x00), DATA(0xFF), DATA(0x00), DATA(0x08),
		DATA(0x7B), DATA(0x00), DATA(0x00), DATA(0xC8),
		DATA(0x6A), DATA(0x5A), DATA(0x08), DATA(0x1A),
		DATA(0x3C), DATA(0x00), DATA(0x91), DATA(0x01),
		DATA(0xCC), DATA(0x01), DATA(0x7F), DATA(0xF0),
		DATA(0x22),

	CMD(0xC8),
		DATA(0x00), DATA(0x00), DATA(0x28), DATA(0x43),
		DATA(0x66), DATA(0x00), DATA(0x9B), DATA(0x03),
		DATA(0xDD), DATA(0x06), DATA(0x11), DATA(0x37),
		DATA(0x06), DATA(0xA7), DATA(0x02), DATA(0x21),
		DATA(0xF4), DATA(0x02), DATA(0x33), DATA(0x01),
		DATA(0x22), DATA(0x6D), DATA(0x0D), DATA(0xAF),
		DATA(0x0A), DATA(0x33), DATA(0x08), DATA(0x0D),
		DATA(0x51), DATA(0x0C), DATA(0xF3), DATA(0x8F),
		DATA(0x0F), DATA(0xC0), DATA(0xE7), DATA(0x03),
		DATA(0xFF),

	CMD(0xC9),
		DATA(0x00), DATA(0x00), DATA(0x28), DATA(0x43),
		DATA(0x66), DATA(0x00), DATA(0x9B), DATA(0x03),
		DATA(0xDD), DATA(0x06), DATA(0x11), DATA(0x37),
		DATA(0x06), DATA(0xA7), DATA(0x02), DATA(0x21),
		DATA(0xF4), DATA(0x02), DATA(0x33), DATA(0x01),
		DATA(0x22), DATA(0x6D), DATA(0x0D), DATA(0xAF),
		DATA(0x0A), DATA(0x33), DATA(0x08), DATA(0x0D),
		DATA(0x51), DATA(0x0C), DATA(0xF3), DATA(0x8F),
		DATA(0x0F), DATA(0xC0), DATA(0xE7), DATA(0x03),
		DATA(0xFF),

	CMD(0x62), DATA(0x00),

	CMD(0x11),            /* Sleep Out */
	DELAY(200),

	CMD(0x29),            /* Display On */

	CMD(0x35), DATA(0x00), /* Tearing Effect Line On */

	/* BIST: fills screen with internal colour bars, independent of RGB input.
	 * Uncomment to verify SPI init is reaching the panel (blocks tilcdc pixel data). */
	// CMD(0xB5), DATA(0x85),
};

/* -----------------------------------------------------------------------
 * Driver state
 * ----------------------------------------------------------------------- */
struct dmt_panel {
	struct drm_panel  panel;
	struct spi_device *spi;
	struct gpio_desc  *reset_gpio;  /* LCD_RSTn - optional, may be in DT */
	bool               prepared;
	bool               enabled;
};

static inline struct dmt_panel *to_dmt_panel(struct drm_panel *p)
{
	return container_of(p, struct dmt_panel, panel);
}

/* -----------------------------------------------------------------------
 * drm_panel ops
 * ----------------------------------------------------------------------- */
static int dmt_panel_prepare(struct drm_panel *panel)
{
	struct dmt_panel *ctx = to_dmt_panel(panel);
	struct spi_device *spi = ctx->spi;
	int i, ret;

	dev_info(&spi->dev, "DMT: prepare() called\n");

	if (ctx->prepared) {
		dev_info(&spi->dev, "DMT: already prepared, skipping\n");
		return 0;
	}

	/* Hard reset sequence using gpiod logical values (polarity handled by descriptor).
	 * reset_gpio is ACTIVE_LOW: gpiod_set_value(0) = deasserted = panel running,
	 *                           gpiod_set_value(1) = asserted   = panel in reset. */
	if (ctx->reset_gpio) {
		dev_info(&spi->dev, "DMT: pulsing reset GPIO\n");
		gpiod_set_value_cansleep(ctx->reset_gpio, 0); /* deassert - ensure not in reset */
		msleep(1);
		gpiod_set_value_cansleep(ctx->reset_gpio, 1); /* assert reset */
		msleep(10);
		gpiod_set_value_cansleep(ctx->reset_gpio, 0); /* deassert reset */
		msleep(120); /* wait for ST7102 to boot */
		dev_info(&spi->dev, "DMT: reset complete, ST7102 booted\n");
	} else {
		dev_warn(&spi->dev, "DMT: no reset GPIO - ST7102 may not be in known state\n");
	}

	/* Send the SPI init sequence */
	dev_info(&spi->dev, "DMT: sending SPI init sequence (%zu entries)\n",
		 ARRAY_SIZE(dmt_init_sequence));

	for (i = 0; i < ARRAY_SIZE(dmt_init_sequence); i++) {
		const struct dmt_cmd *c = &dmt_init_sequence[i];

		if (c->delay_ms) {
			msleep(c->delay_ms);
			continue;
		}

		if (c->is_data)
			ret = dmt_spi_write_data(spi, c->val);
		else
			ret = dmt_spi_write_cmd(spi, c->val);

		if (ret) {
			dev_err(&spi->dev,
				"DMT: SPI write failed at entry %d (val=0x%02x): %d\n",
				i, c->val, ret);
			return ret;
		}
	}

	dev_info(&spi->dev, "DMT: SPI init sequence complete\n");
	ctx->prepared = true;
	return 0;
}

static int dmt_panel_unprepare(struct drm_panel *panel)
{
	struct dmt_panel *ctx = to_dmt_panel(panel);
	struct spi_device *spi = ctx->spi;

	dev_info(&spi->dev, "DMT: unprepare() called\n");

	if (!ctx->prepared)
		return 0;

	/* Enter standby: display off → sleep in → power off */
	dmt_spi_write_cmd(spi, 0x28); /* display off */
	msleep(10);
	dmt_spi_write_cmd(spi, 0x10); /* sleep in */
	msleep(120);

	if (ctx->reset_gpio)
		gpiod_set_value_cansleep(ctx->reset_gpio, 1); /* assert reset = panel off */

	ctx->prepared = false;
	return 0;
}

static int dmt_panel_enable(struct drm_panel *panel)
{
	struct dmt_panel *ctx = to_dmt_panel(panel);

	dev_info(&ctx->spi->dev, "DMT: enable() called\n");
	ctx->enabled = true;
	return 0;
}

static int dmt_panel_disable(struct drm_panel *panel)
{
	struct dmt_panel *ctx = to_dmt_panel(panel);

	dev_info(&ctx->spi->dev, "DMT: disable() called\n");
	ctx->enabled = false;
	return 0;
}

static int dmt_panel_get_modes(struct drm_panel *panel,
			       struct drm_connector *connector)
{
	struct dmt_panel *ctx = to_dmt_panel(panel);
	struct drm_display_mode *mode;

	dev_info(&ctx->spi->dev, "DMT: get_modes() called\n");

	mode = drm_mode_create(connector->dev);
	if (!mode)
		return -ENOMEM;

	/* From DMT049W1NTCMI-1A init code:
	 *   480x854, 36 MHz pclk
	 *   HSA=2  HBP=40  HFP=40
	 *   VSA=2  VBP=12  VFP=193
	 */
	drm_mode_set_name(mode);
	mode->clock     = 36000; /* kHz */
	mode->hdisplay  = 480;
	mode->hsync_start = 480 + 40;           /* hdisplay + HFP */
	mode->hsync_end   = 480 + 40 + 2;       /* + HSA */
	mode->htotal      = 480 + 40 + 2 + 40;  /* + HBP */
	mode->vdisplay  = 854;
	mode->vsync_start = 854 + 193;           /* vdisplay + VFP */
	mode->vsync_end   = 854 + 193 + 2;       /* + VSA */
	mode->vtotal      = 854 + 193 + 2 + 12;  /* + VBP */
	mode->flags     = DRM_MODE_FLAG_NVSYNC | DRM_MODE_FLAG_NHSYNC;
	mode->type      = DRM_MODE_TYPE_DRIVER | DRM_MODE_TYPE_PREFERRED;

	drm_mode_probed_add(connector, mode);
	connector->display_info.width_mm  = 62;  /* ~4.9" panel */
	connector->display_info.height_mm = 110;

	return 1; /* number of modes added */
}

static const struct drm_panel_funcs dmt_panel_funcs = {
	.prepare   = dmt_panel_prepare,
	.unprepare = dmt_panel_unprepare,
	.enable    = dmt_panel_enable,
	.disable   = dmt_panel_disable,
	.get_modes = dmt_panel_get_modes,
};

/* -----------------------------------------------------------------------
 * SPI driver probe / remove
 * ----------------------------------------------------------------------- */
static int dmt_panel_probe(struct spi_device *spi)
{
	struct dmt_panel *ctx;
	int ret;

	ctx = devm_kzalloc(&spi->dev, sizeof(*ctx), GFP_KERNEL);
	if (!ctx)
		return -ENOMEM;

	ctx->spi = spi;
	spi_set_drvdata(spi, ctx);

	/* SPI Mode 3, 8 MHz, 9-bit words (ST7102 uses bit[8] as D/CX flag).
	 * Set bits_per_word=9 on the device so spi_setup() validates it against
	 * the controller's SPI_BPW_RANGE_MASK(4,32), and each per-transfer
	 * override of bits_per_word=9 is consistent with the device default. */
	spi->mode = SPI_MODE_3;
	spi->bits_per_word = 9;
	ret = spi_setup(spi);
	if (ret) {
		dev_err(&spi->dev, "spi_setup failed: %d\n", ret);
		return ret;
	}

	/* Reset GPIO: held asserted (GPIOD_OUT_HIGH = logically active = physically LOW)
	 * until .prepare() pulses it to bring the ST7102 out of reset. */
	ctx->reset_gpio = devm_gpiod_get_optional(&spi->dev, "reset",
						  GPIOD_OUT_HIGH);
	if (IS_ERR(ctx->reset_gpio))
		return PTR_ERR(ctx->reset_gpio);

	dev_info(&spi->dev, "DMT: reset_gpio %s\n",
		 ctx->reset_gpio ? "acquired" : "not found");

	drm_panel_init(&ctx->panel, &spi->dev, &dmt_panel_funcs,
		       DRM_MODE_CONNECTOR_DPI);

	ret = drm_panel_of_backlight(&ctx->panel);
	if (ret) {
		dev_err(&spi->dev, "DMT: drm_panel_of_backlight failed: %d\n", ret);
		return ret;
	}

	drm_panel_add(&ctx->panel);

	dev_info(&spi->dev, "DMT049W1NTCMI-1A panel driver registered, waiting for tilcdc\n");
	return 0;
}

static int dmt_panel_remove(struct spi_device *spi)
{
	struct dmt_panel *ctx = spi_get_drvdata(spi);

	drm_panel_remove(&ctx->panel);
	drm_panel_disable(&ctx->panel);
	drm_panel_unprepare(&ctx->panel);
	return 0;
}

static const struct of_device_id dmt_panel_of_match[] = {
	{ .compatible = "densitron,dmt049w1ntcmi" },
	{ }
};
MODULE_DEVICE_TABLE(of, dmt_panel_of_match);

static const struct spi_device_id dmt_panel_spi_ids[] = {
	{ "dmt049w1ntcmi", 0 },
	{ }
};
MODULE_DEVICE_TABLE(spi, dmt_panel_spi_ids);

static struct spi_driver dmt_panel_driver = {
	.driver = {
		.name           = "panel-dmt049w1ntcmi",
		.of_match_table = dmt_panel_of_match,
	},
	.id_table = dmt_panel_spi_ids,
	.probe    = dmt_panel_probe,
	.remove   = dmt_panel_remove,
};
module_spi_driver(dmt_panel_driver);

MODULE_AUTHOR("LEA GmbH");
MODULE_DESCRIPTION("Densitron DMT049W1NTCMI-1A RGB panel driver (ST7102 TDDI)");
MODULE_LICENSE("GPL v2");
