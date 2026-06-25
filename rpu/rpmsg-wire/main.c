typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long u64;

#define VRING_NUM 256U
#define VRING_MASK (VRING_NUM - 1U)
#define VRING_ALIGN 0x1000U
#define VRING_DESC_F_WRITE 2U

#ifndef RPU_VRING0_BASE
#define RPU_VRING0_BASE 0x3ED40000U
#endif

#ifndef RPU_VRING1_BASE
#define RPU_VRING1_BASE 0x3ED44000U
#endif

#ifndef RPU_IPI_BASE
#define RPU_IPI_BASE 0xFF310000U
#endif

#ifndef RPU_IPI_TARGET_MASK
#define RPU_IPI_TARGET_MASK 0x00000001U
#endif

#ifndef RPU_ENDPOINT_ADDR
#define RPU_ENDPOINT_ADDR 1024U
#endif

#define RPMSG_HDR_LEN 16U
#define RPU_WIRE_MAGIC 0x52505344U
#define RPU_WIRE_ABI 2U
#define RPU_WIRE_FRAME_LEN 64U
#define RPU_WIRE_STATUS_ACCEPTED 0U
#define RPU_WIRE_STATUS_APPLIED 1U
#define RPU_WIRE_STATUS_REJECTED 2U
#define RPU_WIRE_STATUS_INTERLOCKED 3U
#define RPU_WIRE_STATUS_FAULT 4U
#define RPU_WIRE_STATUS_TIMEOUT 5U

#define RPU_WIRE_OP_STATUS 0U
#define RPU_WIRE_OP_READ_REGISTER 1U
#define RPU_WIRE_OP_WRITE_REGISTER 2U
#define RPU_WIRE_OP_READ_ATTENUATION 3U
#define RPU_WIRE_OP_SET_ATTENUATION 4U
#define RPU_WIRE_OP_READ_BIAS 5U
#define RPU_WIRE_OP_SET_BIAS 6U
#define RPU_WIRE_OP_READ_TRIM 7U
#define RPU_WIRE_OP_SET_TRIM 8U
#define RPU_WIRE_OP_READ_OFFSET 9U
#define RPU_WIRE_OP_SET_OFFSET 10U
#define RPU_WIRE_OP_READ_VBIAS_CONTROL 11U
#define RPU_WIRE_OP_SET_VBIAS_CONTROL 12U
#define RPU_WIRE_OP_SET_RESET 13U
#define RPU_WIRE_OP_DO_RESET 14U
#define RPU_WIRE_OP_SET_POWER_STATE 15U
#define RPU_WIRE_OP_ALIGN 16U
#define RPU_WIRE_OP_BEGIN_CONFIGURE_FRONTEND 17U
#define RPU_WIRE_OP_CONFIGURE_AFE 18U
#define RPU_WIRE_OP_CONFIGURE_CHANNEL 19U
#define RPU_WIRE_OP_APPLY_CONFIGURE_FRONTEND 20U
#define RPU_WIRE_OP_WRITE_FUNCTION 21U

#define RPU_WIRE_TARGET_NONE 0U
#define RPU_WIRE_TARGET_AFE 1U
#define RPU_WIRE_TARGET_CHANNEL 2U
#define RPU_WIRE_TARGET_ALL 3U

#define AFE_COUNT 5U
#define CHANNELS_PER_AFE 8U
#define CHANNEL_COUNT (AFE_COUNT * CHANNELS_PER_AFE)
#define DAC_12BIT_MAX 0x0FFFU
#define DEFAULT_SPIN_LIMIT 100000U

#ifndef FPGA_REGISTER_BASE
#define FPGA_REGISTER_BASE 0x80000000U
#endif

#define AFE_GLOBAL_CONTROL_OFFSET 0x00000000U
#define AFE_CONTROL_BASE_OFFSET 0x00000004U
#define AFE_DAC_TRIM_BASE_OFFSET 0x00000008U
#define AFE_DAC_OFFSET_BASE_OFFSET 0x0000000CU
#define AFE_REGISTER_STRIDE 0x0000000CU
#define DAC_GAIN_BIAS_CONTROL_OFFSET 0x0C000000U
#define DAC_GAIN_BIAS_U50_OFFSET 0x0C000004U
#define DAC_GAIN_BIAS_U53_OFFSET 0x0C000008U
#define DAC_GAIN_BIAS_U5_OFFSET 0x0C00000CU
#define BIAS_ENABLE_OFFSET 0x1400000CU
#define FRONTEND_CONTROL_OFFSET 0x08000000U
#define FRONTEND_STATUS_OFFSET 0x08000004U
#define FRONTEND_TRIGGER_OFFSET 0x08000008U
#define FRONTEND_DELAY_BASE_OFFSET 0x0800000CU
#define FRONTEND_BITSLIP_BASE_OFFSET 0x08000020U
#define FRONTEND_AFE_STRIDE 0x00000004U
#define SPY_BUFFER_BASE_OFFSET 0x10000000U
#define SPY_BUFFER_AFE_STRIDE 0x00009000U
#define SPY_BUFFER_CHANNEL_STRIDE 0x00001000U
#define SPY_BUFFER_FRAME_CLOCK_CHANNEL 8U

#define AFE_GLOBAL_RESET_BIT 0U
#define AFE_GLOBAL_POWERSTATE_BIT 1U
#define AFE_GLOBAL_BUSY_START 2U
#define AFE_GLOBAL_BUSY_END 4U
#define AFE_SPI_TRIGGER_WORD 0x00000002U
#define AFE_SPI_IDLE_WORD 0x00000000U
#define DAC_GO_BIT 1U
#define DAC_BUSY_BIT 0U

#define FRONTEND_DELAYCTRL_RESET_BIT 0U
#define FRONTEND_SERDES_RESET_BIT 1U
#define FRONTEND_DELAY_EN_VTC_BIT 2U
#define FRONTEND_DELAYCTRL_READY_BIT 0U
#define FRONTEND_TRIGGER_WORD 0x0000BABAU
#define FRONTEND_DELAY_TAPS 512U
#define FRONTEND_BITSLIP_TAPS 16U
#define FRONTEND_VERIFY_READS 4U
#define FRONTEND_EXPECTED_FCLK_WORD 0x00FF00FFU

#define RPU_FAULT_TIMEOUT 1U
#define RPU_FAULT_MMIO 2U
#define RPU_INTERLOCK_ALIGN_UNVALIDATED 1U

struct vring_desc {
	u32 addr_lo;
	u32 addr_hi;
	u32 len;
	u16 flags;
	u16 next;
} __attribute__((packed));

struct vring_used_elem {
	u32 id;
	u32 len;
} __attribute__((packed));

struct rpmsg_hdr {
	u32 src;
	u32 dst;
	u32 reserved;
	u16 len;
	u16 flags;
} __attribute__((packed));

struct vring_state {
	u32 base;
	u16 last_avail;
};

struct wire_command {
	u16 op;
	u8 target;
	u8 afe_board;
	u8 afe_pl;
	u8 channel;
	u8 afe_channel;
	u16 reg;
	u32 value;
	u32 flags;
	const u8 *payload;
};

struct command_result {
	u16 status;
	u32 readback;
	u32 readback_valid;
	u32 fault_code;
	u32 interlock_code;
};

struct dac_route {
	u8 chip;
	u8 channel;
	u8 gain;
	u8 buffer;
};

struct afe_config {
	u8 present;
	u8 afe_board;
	u8 afe_pl;
	u16 attenuation;
	u16 bias;
	u8 adc_flags;
	u8 pga_lpf;
	u8 pga_flags;
	u8 lna_clamp;
	u8 lna_gain;
	u8 lna_flags;
};

struct channel_config {
	u8 present;
	u8 channel;
	u8 afe_board;
	u8 afe_pl;
	u8 afe_channel;
	u16 trim;
	u16 offset;
	u16 gain;
};

struct staged_config {
	u8 active;
	u16 afe_count;
	u16 channel_count;
	u16 bias_control;
	struct afe_config afes[AFE_COUNT];
	struct channel_config channels[CHANNEL_COUNT];
};

struct afe_function_spec {
	const char *name;
	u16 reg;
	u8 msb;
	u8 lsb;
	u16 min;
	u16 max;
	u16 options[6];
	u8 option_count;
};

static struct vring_state tx_to_host = { RPU_VRING0_BASE, 0 };
static struct vring_state rx_from_host = { RPU_VRING1_BASE, 0 };
static u64 heartbeat;
static u16 attenuation[AFE_COUNT];
static u16 bias_setting[AFE_COUNT];
static u16 trim_halves[AFE_COUNT][CHANNELS_PER_AFE];
static u16 offset_halves[AFE_COUNT][CHANNELS_PER_AFE];
static u16 vbias_control;
static u8 vbias_enabled;
static struct staged_config staged;

static const struct dac_route afe_gain_routes[AFE_COUNT] = {
	{ 0U, 0U, 0U, 0U },
	{ 0U, 1U, 0U, 0U },
	{ 0U, 2U, 0U, 0U },
	{ 0U, 3U, 0U, 0U },
	{ 2U, 1U, 0U, 0U },
};

static const struct dac_route afe_bias_routes[AFE_COUNT] = {
	{ 1U, 0U, 0U, 0U },
	{ 1U, 1U, 0U, 0U },
	{ 1U, 2U, 0U, 0U },
	{ 1U, 3U, 0U, 0U },
	{ 2U, 0U, 0U, 0U },
};

static const struct dac_route vbias_route = { 2U, 2U, 0U, 0U };

#define FUNC_RANGE(name_, reg_, msb_, lsb_, min_, max_) \
	{ name_, reg_, msb_, lsb_, min_, max_, { 0U, 0U, 0U, 0U, 0U, 0U }, 0U }
#define FUNC_OPTIONS2(name_, reg_, msb_, lsb_, a_, b_) \
	{ name_, reg_, msb_, lsb_, 0U, 0U, { a_, b_, 0U, 0U, 0U, 0U }, 2U }
#define FUNC_OPTIONS4(name_, reg_, msb_, lsb_, a_, b_, c_, d_) \
	{ name_, reg_, msb_, lsb_, 0U, 0U, { a_, b_, c_, d_, 0U, 0U }, 4U }
#define FUNC_OPTIONS6(name_, reg_, msb_, lsb_, a_, b_, c_, d_, e_, f_) \
	{ name_, reg_, msb_, lsb_, 0U, 0U, { a_, b_, c_, d_, e_, f_ }, 6U }

static const struct afe_function_spec afe_functions[] = {
	FUNC_RANGE("SOFTWARE_RESET", 0U, 0U, 0U, 0U, 1U),
	FUNC_RANGE("REGISTER_READOUT_ENABLE", 0U, 1U, 1U, 0U, 1U),
	FUNC_RANGE("ADC_COMPLETE_PDN", 1U, 0U, 0U, 0U, 1U),
	FUNC_RANGE("LVDS_OUTPUT_DISABLE", 1U, 1U, 1U, 0U, 1U),
	FUNC_RANGE("ADC_PDN_CH", 1U, 9U, 2U, 0U, 0xFFU),
	FUNC_RANGE("PARTIAL_PDN", 1U, 10U, 10U, 0U, 1U),
	FUNC_RANGE("LOW_FREQUENCY_NOISE_SUPPRESSION", 1U, 11U, 11U, 0U, 1U),
	FUNC_RANGE("EXT_REF", 1U, 13U, 13U, 0U, 1U),
	FUNC_RANGE("LVDS_OUTPUT_RATE_2X", 1U, 12U, 14U, 0U, 1U),
	FUNC_RANGE("SINGLE-ENDED_CLK_MODE", 1U, 15U, 15U, 0U, 1U),
	FUNC_RANGE("POWER-DOWN_LVDS", 2U, 10U, 3U, 0U, 1U),
	FUNC_RANGE("AVERAGING_ENABLE", 2U, 11U, 11U, 0U, 1U),
	FUNC_RANGE("LOW_LATENCY", 2U, 12U, 12U, 0U, 1U),
	FUNC_RANGE("TEST_PATTERN_MODES", 2U, 15U, 13U, 0U, 0x7U),
	FUNC_RANGE("INVERT_CHANNELS", 3U, 7U, 0U, 0U, 0xFFU),
	FUNC_RANGE("CHANNEL_OFFSET_SUBSTRACTION_ENABLE", 3U, 8U, 8U, 0U, 1U),
	FUNC_RANGE("DIGITAL_GAIN_ENABLE", 3U, 12U, 12U, 0U, 1U),
	FUNC_RANGE("SERIALIZED_DATA_RATE", 3U, 14U, 13U, 0U, 0x3U),
	FUNC_RANGE("ENABLE_EXTERNAL_REFERENCE_MODE", 3U, 15U, 15U, 0U, 1U),
	FUNC_RANGE("ADC_RESOLUTION_RESET", 4U, 1U, 1U, 0U, 1U),
	FUNC_RANGE("ADC_OUTPUT_FORMAT", 4U, 3U, 3U, 0U, 1U),
	FUNC_RANGE("LSB_MSB_FIRST", 4U, 4U, 4U, 0U, 1U),
	FUNC_RANGE("CUSTOM_PATTERN", 5U, 13U, 0U, 0U, 0x3FFFU),
	FUNC_RANGE("SYNC_PATTERN", 10U, 8U, 8U, 0U, 1U),
	FUNC_RANGE("OFFSET_CH1", 13U, 9U, 0U, 0U, 0x3FFU),
	FUNC_RANGE("DIGITAL_GAIN_CH1", 13U, 15U, 11U, 0U, 0x1FU),
	FUNC_RANGE("OFFSET_CH2", 15U, 9U, 0U, 0U, 0x3FFU),
	FUNC_RANGE("DIGITAL_GAIN_CH2", 15U, 15U, 11U, 0U, 0x1FU),
	FUNC_RANGE("OFFSET_CH3", 17U, 9U, 0U, 0U, 0x3FFU),
	FUNC_RANGE("DIGITAL_GAIN_CH3", 17U, 15U, 11U, 0U, 0x1FU),
	FUNC_RANGE("OFFSET_CH4", 19U, 9U, 0U, 0U, 0x3FFU),
	FUNC_RANGE("DIGITAL_GAIN_CH4", 19U, 15U, 11U, 0U, 0x1FU),
	FUNC_RANGE("DIGITAL_HPF_FILTER_ENABLE_CH1-4", 21U, 0U, 0U, 0U, 1U),
	FUNC_RANGE("DIGITAL_HPF_FILTER_K_CH1-4", 21U, 4U, 1U, 2U, 10U),
	FUNC_RANGE("OFFSET_CH8", 25U, 9U, 0U, 0U, 0x3FFU),
	FUNC_RANGE("DIGITAL_GAIN_CH8", 25U, 15U, 11U, 0U, 0x1FU),
	FUNC_RANGE("OFFSET_CH7", 27U, 9U, 0U, 0U, 0x3FFU),
	FUNC_RANGE("DIGITAL_GAIN_CH7", 27U, 15U, 11U, 0U, 0x1FU),
	FUNC_RANGE("OFFSET_CH6", 29U, 9U, 0U, 0U, 0x3FFU),
	FUNC_RANGE("DIGITAL_GAIN_CH6", 29U, 15U, 11U, 0U, 0x1FU),
	FUNC_RANGE("OFFSET_CH5", 31U, 9U, 0U, 0U, 0x3FFU),
	FUNC_RANGE("DIGITAL_GAIN_CH5", 31U, 15U, 11U, 0U, 0x1FU),
	FUNC_RANGE("DIGITAL_HPF_FILTER_ENABLE_CH5-8", 33U, 0U, 0U, 0U, 1U),
	FUNC_RANGE("DIGITAL_HPF_FILTER_K_CH5-8", 33U, 4U, 1U, 2U, 10U),
	FUNC_RANGE("DITHER", 66U, 15U, 15U, 0U, 1U),
	FUNC_RANGE("PGA_CLAMP_-6dB", 50U, 10U, 10U, 0U, 1U),
	FUNC_OPTIONS4("LPF_PROGRAMMABILITY", 51U, 3U, 1U, 0U, 2U, 3U, 4U),
	FUNC_RANGE("PGA_INTEGRATOR_DISABLE", 51U, 4U, 4U, 0U, 1U),
	FUNC_RANGE("PGA_CLAMP_LEVEL", 51U, 7U, 5U, 0U, 7U),
	FUNC_RANGE("PGA_GAIN_CONTROL", 51U, 13U, 13U, 0U, 1U),
	FUNC_RANGE("ACTIVE_TERMINATION_INDIVIDUAL_RESISTOR_CNTL", 52U, 4U, 0U, 0U, 0x1FU),
	FUNC_RANGE("ACTIVE_TERMINATION_INDIVIDUAL_RESISTOR_ENABLE", 52U, 5U, 5U, 0U, 1U),
	FUNC_RANGE("PRESET_ACTIVE_TERMINATIONS", 52U, 7U, 6U, 0U, 3U),
	FUNC_RANGE("ACTIVE_TERMINATION_ENABLE", 52U, 8U, 8U, 0U, 1U),
	FUNC_RANGE("LNA_INPUT_CLAMP_SETTING", 52U, 10U, 9U, 0U, 3U),
	FUNC_RANGE("LNA_INTEGRATOR_DISABLE", 52U, 12U, 12U, 0U, 1U),
	FUNC_RANGE("LNA_GAIN", 52U, 14U, 13U, 0U, 3U),
	FUNC_RANGE("LNA_INDIVIDUAL_CH_CNTL", 52U, 15U, 15U, 0U, 1U),
	FUNC_RANGE("PDN_CH", 53U, 7U, 0U, 0U, 0xFFU),
	FUNC_RANGE("LOW_POWER", 53U, 10U, 10U, 0U, 1U),
	FUNC_RANGE("MED_POWER", 53U, 11U, 11U, 0U, 1U),
	FUNC_RANGE("PDN_VCAT_PGA", 53U, 12U, 12U, 0U, 1U),
	FUNC_RANGE("PDN_LNA", 53U, 13U, 13U, 0U, 1U),
	FUNC_RANGE("VCA_PARTIAL_PDN", 53U, 14U, 14U, 0U, 1U),
	FUNC_RANGE("VCA_COMPLETE_PDN", 53U, 15U, 15U, 0U, 1U),
	FUNC_OPTIONS6("CW_SUM_AMP_GAIN_CNTL", 54U, 4U, 0U, 0U, 1U, 2U, 4U, 8U, 16U),
	FUNC_RANGE("CW_16X_CLK_SEL", 54U, 5U, 5U, 0U, 1U),
	FUNC_RANGE("CW_1X_CLK_SEL", 54U, 6U, 6U, 0U, 1U),
	FUNC_RANGE("CW_TGC_SEL", 54U, 8U, 8U, 0U, 1U),
	FUNC_RANGE("CW_SUM_AMP_ENABLE", 54U, 9U, 9U, 0U, 1U),
	FUNC_RANGE("CW_CLK_MODE_SEL", 54U, 11U, 10U, 0U, 3U),
	FUNC_RANGE("CH1_CW_MIXER_PHASE", 55U, 3U, 0U, 0U, 0xFU),
	FUNC_RANGE("CH2_CW_MIXER_PHASE", 55U, 7U, 4U, 0U, 0xFU),
	FUNC_RANGE("CH3_CW_MIXER_PHASE", 55U, 11U, 8U, 0U, 0xFU),
	FUNC_RANGE("CH4_CW_MIXER_PHASE", 55U, 15U, 12U, 0U, 0xFU),
	FUNC_RANGE("CH5_CW_MIXER_PHASE", 56U, 3U, 0U, 0U, 0xFU),
	FUNC_RANGE("CH6_CW_MIXER_PHASE", 56U, 7U, 4U, 0U, 0xFU),
	FUNC_RANGE("CH7_CW_MIXER_PHASE", 56U, 11U, 8U, 0U, 0xFU),
	FUNC_RANGE("CH8_CW_MIXER_PHASE", 56U, 15U, 12U, 0U, 0xFU),
	FUNC_RANGE("CH1_LNA_GAIN_CNTL", 57U, 1U, 0U, 0U, 3U),
	FUNC_RANGE("CH2_LNA_GAIN_CNTL", 57U, 3U, 2U, 0U, 3U),
	FUNC_RANGE("CH3_LNA_GAIN_CNTL", 57U, 5U, 4U, 0U, 3U),
	FUNC_RANGE("CH4_LNA_GAIN_CNTL", 57U, 7U, 6U, 0U, 3U),
	FUNC_RANGE("CH5_LNA_GAIN_CNTL", 57U, 9U, 8U, 0U, 3U),
	FUNC_RANGE("CH6_LNA_GAIN_CNTL", 57U, 11U, 10U, 0U, 3U),
	FUNC_RANGE("CH7_LNA_GAIN_CNTL", 57U, 13U, 12U, 0U, 3U),
	FUNC_RANGE("CH8_LNA_GAIN_CNTL", 57U, 15U, 14U, 0U, 3U),
	FUNC_RANGE("HPF_LNA", 59U, 3U, 2U, 0U, 3U),
	FUNC_RANGE("DIG_TGC_ATT_GAIN", 59U, 6U, 4U, 0U, 0x7U),
	FUNC_RANGE("DIG_TGC_ATT", 59U, 7U, 7U, 0U, 1U),
	FUNC_RANGE("CW_SUM_AMP_PDN", 59U, 8U, 8U, 0U, 1U),
	FUNC_RANGE("PGA_TEST_MODE", 59U, 9U, 9U, 0U, 1U),
};

static inline void barrier(void)
{
	__asm__ volatile("dmb sy" ::: "memory");
}

static inline void cpu_relax(void)
{
	__asm__ volatile("nop");
}

static inline volatile u32 *reg32(u32 addr)
{
	return (volatile u32 *)(unsigned long)addr;
}

static inline volatile struct vring_desc *vring_descs(const struct vring_state *vq)
{
	return (volatile struct vring_desc *)(unsigned long)vq->base;
}

static inline volatile u16 *vring_avail(const struct vring_state *vq)
{
	return (volatile u16 *)(unsigned long)(vq->base + sizeof(struct vring_desc) * VRING_NUM);
}

static inline volatile u16 *vring_used_idx(const struct vring_state *vq)
{
	return (volatile u16 *)(unsigned long)(vq->base + 0x2000U + 2U);
}

static inline volatile struct vring_used_elem *vring_used_ring(const struct vring_state *vq)
{
	return (volatile struct vring_used_elem *)(unsigned long)(vq->base + 0x2000U + 4U);
}

static u16 avail_idx(const struct vring_state *vq)
{
	volatile u16 *avail = vring_avail(vq);
	return avail[1];
}

static u16 avail_ring_entry(const struct vring_state *vq, u16 index)
{
	volatile u16 *avail = vring_avail(vq);
	return avail[2U + (index & VRING_MASK)];
}

static void add_used(const struct vring_state *vq, u16 desc_id, u32 len)
{
	volatile u16 *used_idx = vring_used_idx(vq);
	volatile struct vring_used_elem *used = vring_used_ring(vq);
	u16 index = *used_idx;

	used[index & VRING_MASK].id = desc_id;
	used[index & VRING_MASK].len = len;
	barrier();
	*used_idx = index + 1U;
	barrier();
}

static void kick_host(void)
{
	*reg32(RPU_IPI_BASE) = RPU_IPI_TARGET_MASK;
	barrier();
}

static u16 get_u16(const u8 *buf, u32 off)
{
	return (u16)buf[off] | ((u16)buf[off + 1U] << 8);
}

static u32 get_u32(const u8 *buf, u32 off)
{
	return (u32)buf[off] |
	       ((u32)buf[off + 1U] << 8) |
	       ((u32)buf[off + 2U] << 16) |
	       ((u32)buf[off + 3U] << 24);
}

static u64 get_u64(const u8 *buf, u32 off)
{
	u64 lo = get_u32(buf, off);
	u64 hi = get_u32(buf, off + 4U);
	return lo | (hi << 32);
}

static void put_u16(u8 *buf, u32 off, u16 value)
{
	buf[off] = (u8)value;
	buf[off + 1U] = (u8)(value >> 8);
}

static void put_u32(u8 *buf, u32 off, u32 value)
{
	buf[off] = (u8)value;
	buf[off + 1U] = (u8)(value >> 8);
	buf[off + 2U] = (u8)(value >> 16);
	buf[off + 3U] = (u8)(value >> 24);
}

static void put_u64(u8 *buf, u32 off, u64 value)
{
	put_u32(buf, off, (u32)value);
	put_u32(buf, off + 4U, (u32)(value >> 32));
}

static void zero_frame(u8 *buf, u32 len)
{
	u32 i;

	for (i = 0; i < len; ++i) {
		buf[i] = 0;
	}
}

static struct command_result result_status(u16 status)
{
	struct command_result result;

	result.status = status;
	result.readback = 0U;
	result.readback_valid = 0U;
	result.fault_code = 0U;
	result.interlock_code = 0U;
	return result;
}

static struct command_result result_readback(u32 value)
{
	struct command_result result = result_status(RPU_WIRE_STATUS_APPLIED);

	result.readback = value;
	result.readback_valid = 1U;
	return result;
}

static struct command_result result_timeout(void)
{
	struct command_result result = result_status(RPU_WIRE_STATUS_TIMEOUT);

	result.fault_code = RPU_FAULT_TIMEOUT;
	return result;
}

static struct command_result result_interlocked(u32 code)
{
	struct command_result result = result_status(RPU_WIRE_STATUS_INTERLOCKED);

	result.interlock_code = code;
	return result;
}

static u32 mmio_read(u32 offset)
{
	u32 value;

	barrier();
	value = *reg32(FPGA_REGISTER_BASE + offset);
	barrier();
	return value;
}

static void mmio_write(u32 offset, u32 value)
{
	barrier();
	*reg32(FPGA_REGISTER_BASE + offset) = value;
	barrier();
}

static u32 bit(u32 value, u8 bit_index)
{
	return (value >> bit_index) & 1U;
}

static u32 bits(u32 value, u8 start, u8 end)
{
	u32 width = (u32)end - (u32)start + 1U;

	return (value >> start) & ((1U << width) - 1U);
}

static int validate_afe(u8 afe_pl)
{
	return afe_pl < AFE_COUNT;
}

static int validate_channel(u8 channel)
{
	return channel < CHANNELS_PER_AFE;
}

static int require_u16(u32 value, u16 *out)
{
	if (value > 0xFFFFU) {
		return -1;
	}
	*out = (u16)value;
	return 0;
}

static int require_12bit(u32 value, u16 *out)
{
	if (value > DAC_12BIT_MAX) {
		return -1;
	}
	*out = (u16)value;
	return 0;
}

static int wait_afe_ready(void)
{
	u32 i;

	for (i = 0U; i < DEFAULT_SPIN_LIMIT; ++i) {
		if (bits(mmio_read(AFE_GLOBAL_CONTROL_OFFSET), AFE_GLOBAL_BUSY_START, AFE_GLOBAL_BUSY_END) == 0U) {
			return 0;
		}
	}
	return -1;
}

static int wait_dac_ready(void)
{
	u32 i;

	for (i = 0U; i < DEFAULT_SPIN_LIMIT; ++i) {
		if (bit(mmio_read(DAC_GAIN_BIAS_CONTROL_OFFSET), DAC_BUSY_BIT) == 0U) {
			return 0;
		}
	}
	return -1;
}

static u32 afe_register_offset(u32 base, u8 afe_pl)
{
	return base + AFE_REGISTER_STRIDE * (u32)afe_pl;
}

static u32 dac_gain_bias_offset(u8 chip)
{
	if (chip == 0U) {
		return DAC_GAIN_BIAS_U50_OFFSET;
	}
	if (chip == 1U) {
		return DAC_GAIN_BIAS_U53_OFFSET;
	}
	return DAC_GAIN_BIAS_U5_OFFSET;
}

static u32 afe_register_word(u16 reg, u16 value)
{
	return (((u32)reg & 0xFFU) << 16) | (u32)value;
}

static u32 afe_register_address_word(u16 reg)
{
	return ((u32)reg & 0xFFU) << 16;
}

static u32 dac_gain_bias_word(struct dac_route route, u16 value)
{
	return (((u32)route.channel & 0x03U) << 14) |
	       (((u32)route.gain & 0x01U) << 13) |
	       (((u32)route.buffer & 0x01U) << 12) |
	       ((u32)value & DAC_12BIT_MAX);
}

static u16 dac_trim_offset_half(u8 channel, u16 value, u8 gain, u8 buffer)
{
	return (u16)((((u16)channel & 0x03U) << 14) |
		     (((u16)gain & 0x01U) << 13) |
		     (((u16)buffer & 0x01U) << 12) |
		     (value & (u16)DAC_12BIT_MAX));
}

static u32 dac_pair_word(u16 low_half, u16 high_half)
{
	return ((u32)high_half << 16) | (u32)low_half;
}

static int dac_companion_channel(u8 channel, u8 *out)
{
	if (channel < 4U) {
		*out = channel + 4U;
		return 0;
	}
	if (channel < CHANNELS_PER_AFE) {
		*out = channel - 4U;
		return 0;
	}
	return -1;
}

static int trigger_dac(void)
{
	u32 value;

	if (wait_dac_ready() != 0) {
		return -1;
	}
	value = mmio_read(DAC_GAIN_BIAS_CONTROL_OFFSET);
	mmio_write(DAC_GAIN_BIAS_CONTROL_OFFSET, value | (1U << DAC_GO_BIT));
	if (wait_dac_ready() != 0) {
		return -1;
	}
	value = mmio_read(DAC_GAIN_BIAS_CONTROL_OFFSET);
	mmio_write(DAC_GAIN_BIAS_CONTROL_OFFSET, value & ~(1U << DAC_GO_BIT));
	return wait_dac_ready();
}

static int write_dac_route(struct dac_route route, u16 value)
{
	if (wait_dac_ready() != 0) {
		return -1;
	}
	mmio_write(dac_gain_bias_offset(route.chip), dac_gain_bias_word(route, value));
	return trigger_dac();
}

static int set_mmio_bit(u32 offset, u8 bit_index, u8 asserted)
{
	u32 value = mmio_read(offset);
	u32 mask = 1U << bit_index;

	if (asserted != 0U) {
		value |= mask;
	} else {
		value &= ~mask;
	}
	mmio_write(offset, value);
	return 0;
}

static int read_afe_register(u8 afe_pl, u16 reg, u32 *readback)
{
	u32 offset;

	if (!validate_afe(afe_pl)) {
		return -2;
	}
	offset = afe_register_offset(AFE_CONTROL_BASE_OFFSET, afe_pl);
	if (wait_afe_ready() != 0) {
		return -1;
	}
	mmio_write(offset, AFE_SPI_TRIGGER_WORD);
	if (wait_afe_ready() != 0) {
		return -1;
	}
	mmio_write(offset, afe_register_address_word(reg));
	if (wait_afe_ready() != 0) {
		return -1;
	}
	*readback = mmio_read(offset) & 0xFFFFU;
	mmio_write(offset, AFE_SPI_IDLE_WORD);
	return 0;
}

static int write_afe_register(u8 afe_pl, u16 reg, u32 value, u32 *readback)
{
	u16 register_value;
	u32 offset;

	if (!validate_afe(afe_pl) || require_u16(value, &register_value) != 0) {
		return -2;
	}
	offset = afe_register_offset(AFE_CONTROL_BASE_OFFSET, afe_pl);
	if (wait_afe_ready() != 0) {
		return -1;
	}
	mmio_write(offset, afe_register_word(reg, register_value));
	if (wait_afe_ready() != 0) {
		return -1;
	}
	mmio_write(offset, AFE_SPI_TRIGGER_WORD);
	if (wait_afe_ready() != 0) {
		return -1;
	}
	mmio_write(offset, afe_register_address_word(reg));
	if (wait_afe_ready() != 0) {
		return -1;
	}
	*readback = mmio_read(offset) & 0xFFFFU;
	mmio_write(offset, AFE_SPI_IDLE_WORD);
	return 0;
}

static int write_trim_or_offset_channel(u16 op, u8 afe_pl, u8 afe_channel, u16 value, u8 gain)
{
	u32 offset;
	u8 companion;
	u16 half;
	u16 companion_half;
	u32 word;
	u16 *halves;

	if (!validate_afe(afe_pl) || dac_companion_channel(afe_channel, &companion) != 0) {
		return -2;
	}
	if (op == RPU_WIRE_OP_SET_TRIM) {
		offset = afe_register_offset(AFE_DAC_TRIM_BASE_OFFSET, afe_pl);
		halves = &trim_halves[afe_pl][0];
	} else if (op == RPU_WIRE_OP_SET_OFFSET) {
		offset = afe_register_offset(AFE_DAC_OFFSET_BASE_OFFSET, afe_pl);
		halves = &offset_halves[afe_pl][0];
	} else {
		return -2;
	}

	half = dac_trim_offset_half(afe_channel, value, gain, 0U);
	halves[afe_channel] = half;
	companion_half = halves[companion];
	if (afe_channel >= 4U) {
		word = dac_pair_word(companion_half, half);
	} else {
		word = dac_pair_word(half, companion_half);
	}

	if (wait_afe_ready() != 0) {
		return -1;
	}
	mmio_write(offset, word);
	return wait_afe_ready();
}

static int read_trim_or_offset_channel(u16 op, u8 afe_pl, u8 afe_channel, u32 *readback)
{
	if (!validate_afe(afe_pl) || !validate_channel(afe_channel)) {
		return -2;
	}
	if (op == RPU_WIRE_OP_READ_TRIM) {
		*readback = (u32)(trim_halves[afe_pl][afe_channel] & (u16)DAC_12BIT_MAX);
		return 0;
	}
	if (op == RPU_WIRE_OP_READ_OFFSET) {
		*readback = (u32)(offset_halves[afe_pl][afe_channel] & (u16)DAC_12BIT_MAX);
		return 0;
	}
	return -2;
}

static int write_channel_scalar(const struct wire_command *command, u32 *readback)
{
	u16 value;
	u8 afe_pl;
	u8 afe_channel;
	int rc;

	if (require_12bit(command->value, &value) != 0) {
		return -2;
	}
	if (command->target == RPU_WIRE_TARGET_CHANNEL) {
		rc = write_trim_or_offset_channel(command->op, command->afe_pl, command->afe_channel, value, command->flags != 0U);
		if (rc != 0) {
			return rc;
		}
	} else if (command->target == RPU_WIRE_TARGET_AFE) {
		if (!validate_afe(command->afe_pl)) {
			return -2;
		}
		for (afe_channel = 0U; afe_channel < CHANNELS_PER_AFE; ++afe_channel) {
			rc = write_trim_or_offset_channel(command->op, command->afe_pl, afe_channel, value, command->flags != 0U);
			if (rc != 0) {
				return rc;
			}
		}
	} else if (command->target == RPU_WIRE_TARGET_ALL) {
		for (afe_pl = 0U; afe_pl < AFE_COUNT; ++afe_pl) {
			for (afe_channel = 0U; afe_channel < CHANNELS_PER_AFE; ++afe_channel) {
				rc = write_trim_or_offset_channel(command->op, afe_pl, afe_channel, value, command->flags != 0U);
				if (rc != 0) {
					return rc;
				}
			}
		}
	} else {
		return -2;
	}
	*readback = (u32)value;
	return 0;
}

static int function_name_matches(const u8 *payload, const char *name)
{
	u8 length = payload[0];
	u8 i;

	if (length == 0U || length > 31U) {
		return 0;
	}
	for (i = 0U; i < length; ++i) {
		if (name[i] == '\0' || (u8)name[i] != payload[1U + i]) {
			return 0;
		}
	}
	return name[length] == '\0';
}

static const struct afe_function_spec *find_afe_function(const u8 *payload)
{
	u32 i;

	for (i = 0U; i < (u32)(sizeof(afe_functions) / sizeof(afe_functions[0])); ++i) {
		if (function_name_matches(payload, afe_functions[i].name)) {
			return &afe_functions[i];
		}
	}
	return (const struct afe_function_spec *)0;
}

static int function_value_allowed(const struct afe_function_spec *spec, u16 value)
{
	u8 i;

	if (spec->option_count == 0U) {
		return value >= spec->min && value <= spec->max;
	}
	for (i = 0U; i < spec->option_count; ++i) {
		if (value == spec->options[i]) {
			return 1;
		}
	}
	return 0;
}

static int afe_function_mask(const struct afe_function_spec *spec, u16 *mask)
{
	u32 width;

	if (spec->msb < spec->lsb || spec->msb >= 16U) {
		return -1;
	}
	width = (u32)spec->msb - (u32)spec->lsb + 1U;
	*mask = (u16)(((1U << width) - 1U) << spec->lsb);
	return 0;
}

static int write_afe_function_payload(u8 afe_pl, const u8 *payload, u32 value, u32 *readback)
{
	const struct afe_function_spec *spec;
	u16 function_value;
	u16 mask;
	u32 current;
	u16 updated;
	u32 raw_readback;

	if (!validate_afe(afe_pl) || require_u16(value, &function_value) != 0) {
		return -2;
	}
	spec = find_afe_function(payload);
	if (spec == (const struct afe_function_spec *)0 ||
	    !function_value_allowed(spec, function_value) ||
	    afe_function_mask(spec, &mask) != 0) {
		return -2;
	}
	if (read_afe_register(afe_pl, spec->reg, &current) != 0) {
		return -1;
	}
	updated = (u16)(((u16)current & ~mask) | ((function_value << spec->lsb) & mask));
	if (write_afe_register(afe_pl, spec->reg, (u32)updated, &raw_readback) != 0) {
		return -1;
	}
	if (read_afe_register(afe_pl, spec->reg, &raw_readback) != 0) {
		return -1;
	}
	*readback = ((u16)raw_readback & mask) >> spec->lsb;
	return 0;
}

static int write_afe_function_name(u8 afe_pl, const char *name, u16 value)
{
	u8 payload[32];
	u8 i;
	u32 readback;

	zero_frame(payload, 32U);
	for (i = 0U; i < 31U && name[i] != '\0'; ++i) {
		payload[1U + i] = (u8)name[i];
	}
	payload[0] = i;
	if (i == 0U || name[i] != '\0') {
		return -2;
	}
	return write_afe_function_payload(afe_pl, payload, (u32)value, &readback);
}

static int apply_staged_channel(struct channel_config config)
{
	u16 trim;
	u16 offset;

	if (require_12bit((u32)config.trim, &trim) != 0 || require_12bit((u32)config.offset, &offset) != 0) {
		return -2;
	}
	if (write_trim_or_offset_channel(RPU_WIRE_OP_SET_TRIM, config.afe_pl, config.afe_channel, trim, 0U) != 0) {
		return -1;
	}
	return write_trim_or_offset_channel(RPU_WIRE_OP_SET_OFFSET, config.afe_pl, config.afe_channel, offset, 0U);
}

static int apply_staged_afe(struct afe_config config)
{
	u16 attenuation_value;
	u16 bias_value;
	int rc;

	if (!validate_afe(config.afe_pl) || require_12bit((u32)config.attenuation, &attenuation_value) != 0) {
		return -2;
	}
	if (write_dac_route(afe_gain_routes[config.afe_pl], attenuation_value) != 0) {
		return -1;
	}
	attenuation[config.afe_pl] = attenuation_value;

	if (config.bias != 0U) {
		if (require_12bit((u32)config.bias, &bias_value) != 0) {
			return -2;
		}
		if (write_dac_route(afe_bias_routes[config.afe_pl], bias_value) != 0) {
			return -1;
		}
		bias_setting[config.afe_pl] = bias_value;
	}

	rc = write_afe_function_name(config.afe_pl, "SERIALIZED_DATA_RATE", 1U);
	if (rc != 0) { return rc; }
	rc = write_afe_function_name(config.afe_pl, "ADC_RESOLUTION_RESET", (u16)(config.adc_flags & 0x01U));
	if (rc != 0) { return rc; }
	rc = write_afe_function_name(config.afe_pl, "ADC_OUTPUT_FORMAT", (u16)((config.adc_flags >> 1) & 0x01U));
	if (rc != 0) { return rc; }
	rc = write_afe_function_name(config.afe_pl, "LSB_MSB_FIRST", (u16)((config.adc_flags >> 2) & 0x01U));
	if (rc != 0) { return rc; }
	rc = write_afe_function_name(config.afe_pl, "LPF_PROGRAMMABILITY", (u16)config.pga_lpf);
	if (rc != 0) { return rc; }
	rc = write_afe_function_name(config.afe_pl, "PGA_INTEGRATOR_DISABLE", (u16)(config.pga_flags & 0x01U));
	if (rc != 0) { return rc; }
	rc = write_afe_function_name(config.afe_pl, "PGA_GAIN_CONTROL", (u16)((config.pga_flags >> 1) & 0x01U));
	if (rc != 0) { return rc; }
	rc = write_afe_function_name(config.afe_pl, "PGA_CLAMP_LEVEL", 2U);
	if (rc != 0) { return rc; }
	rc = write_afe_function_name(config.afe_pl, "ACTIVE_TERMINATION_ENABLE", 0U);
	if (rc != 0) { return rc; }
	rc = write_afe_function_name(config.afe_pl, "LNA_INPUT_CLAMP_SETTING", (u16)config.lna_clamp);
	if (rc != 0) { return rc; }
	rc = write_afe_function_name(config.afe_pl, "LNA_GAIN", (u16)config.lna_gain);
	if (rc != 0) { return rc; }
	rc = write_afe_function_name(config.afe_pl, "LNA_INTEGRATOR_DISABLE", (u16)(config.lna_flags & 0x01U));
	if (rc != 0) { return rc; }
	return 0;
}

static void clear_staged_config(void)
{
	u32 i;

	staged.active = 0U;
	staged.afe_count = 0U;
	staged.channel_count = 0U;
	staged.bias_control = 0U;
	for (i = 0U; i < AFE_COUNT; ++i) {
		staged.afes[i].present = 0U;
	}
	for (i = 0U; i < CHANNEL_COUNT; ++i) {
		staged.channels[i].present = 0U;
	}
}

static int received_staged_afes(void)
{
	u32 i;
	int count = 0;

	for (i = 0U; i < AFE_COUNT; ++i) {
		if (staged.afes[i].present != 0U) {
			++count;
		}
	}
	return count;
}

static int received_staged_channels(void)
{
	u32 i;
	int count = 0;

	for (i = 0U; i < CHANNEL_COUNT; ++i) {
		if (staged.channels[i].present != 0U) {
			++count;
		}
	}
	return count;
}

static int apply_configure_frontend(void)
{
	u32 i;
	u16 bias_value;
	int rc;

	if (staged.active == 0U ||
	    received_staged_afes() != (int)staged.afe_count ||
	    received_staged_channels() != (int)staged.channel_count ||
	    require_12bit((u32)staged.bias_control, &bias_value) != 0) {
		return -2;
	}

	if (set_mmio_bit(AFE_GLOBAL_CONTROL_OFFSET, AFE_GLOBAL_RESET_BIT, 1U) != 0 ||
	    set_mmio_bit(AFE_GLOBAL_CONTROL_OFFSET, AFE_GLOBAL_RESET_BIT, 0U) != 0 ||
	    set_mmio_bit(AFE_GLOBAL_CONTROL_OFFSET, AFE_GLOBAL_POWERSTATE_BIT, 1U) != 0) {
		return -1;
	}

	for (i = 0U; i < CHANNEL_COUNT; ++i) {
		if (staged.channels[i].present != 0U) {
			rc = apply_staged_channel(staged.channels[i]);
			if (rc != 0) {
				return rc;
			}
		}
	}

	if (write_dac_route(vbias_route, bias_value) != 0) {
		return -1;
	}
	mmio_write(BIAS_ENABLE_OFFSET, 1U);
	vbias_control = bias_value;
	vbias_enabled = 1U;

	for (i = 0U; i < AFE_COUNT; ++i) {
		if (staged.afes[i].present != 0U) {
			rc = apply_staged_afe(staged.afes[i]);
			if (rc != 0) {
				return rc;
			}
		}
	}

	if (set_mmio_bit(AFE_GLOBAL_CONTROL_OFFSET, AFE_GLOBAL_POWERSTATE_BIT, 1U) != 0) {
		return -1;
	}
	clear_staged_config();
	return 0;
}

static struct wire_command parse_wire_command(const u8 *cmd)
{
	struct wire_command command;

	command.op = get_u16(cmd, 6U);
	command.target = cmd[16U];
	command.afe_board = cmd[17U];
	command.afe_pl = cmd[18U];
	command.channel = cmd[19U];
	command.afe_channel = cmd[20U];
	command.reg = get_u16(cmd, 22U);
	command.value = get_u32(cmd, 24U);
	command.flags = get_u32(cmd, 28U);
	command.payload = &cmd[32U];
	return command;
}

static struct command_result execute_wire_command(const u8 *cmd)
{
	u16 abi;
	u16 op;
	struct wire_command command;
	u32 readback;
	u16 value;
	int rc;

	if (get_u32(cmd, 0) != RPU_WIRE_MAGIC) {
		return result_status(RPU_WIRE_STATUS_REJECTED);
	}
	abi = get_u16(cmd, 4);
	if (abi != RPU_WIRE_ABI) {
		return result_status(RPU_WIRE_STATUS_REJECTED);
	}
	op = get_u16(cmd, 6);
	command = parse_wire_command(cmd);

	if (op == RPU_WIRE_OP_STATUS) {
		return result_status(RPU_WIRE_STATUS_APPLIED);
	}
	if (op == RPU_WIRE_OP_READ_REGISTER) {
		rc = read_afe_register(command.afe_pl, command.reg, &readback);
		if (rc == 0) {
			return result_readback(readback);
		}
		return rc == -1 ? result_timeout() : result_status(RPU_WIRE_STATUS_REJECTED);
	}
	if (op == RPU_WIRE_OP_WRITE_REGISTER) {
		rc = write_afe_register(command.afe_pl, command.reg, command.value, &readback);
		if (rc == 0) {
			return result_readback(readback);
		}
		return rc == -1 ? result_timeout() : result_status(RPU_WIRE_STATUS_REJECTED);
	}
	if (op == RPU_WIRE_OP_READ_ATTENUATION || op == RPU_WIRE_OP_READ_BIAS) {
		if (!validate_afe(command.afe_pl)) {
			return result_status(RPU_WIRE_STATUS_REJECTED);
		}
		if (op == RPU_WIRE_OP_READ_ATTENUATION) {
			return result_readback((u32)attenuation[command.afe_pl]);
		}
		return result_readback((u32)bias_setting[command.afe_pl]);
	}
	if (op == RPU_WIRE_OP_SET_ATTENUATION || op == RPU_WIRE_OP_SET_BIAS) {
		if (!validate_afe(command.afe_pl) || require_12bit(command.value, &value) != 0) {
			return result_status(RPU_WIRE_STATUS_REJECTED);
		}
		if (op == RPU_WIRE_OP_SET_ATTENUATION) {
			rc = write_dac_route(afe_gain_routes[command.afe_pl], value);
			attenuation[command.afe_pl] = value;
		} else {
			rc = write_dac_route(afe_bias_routes[command.afe_pl], value);
			bias_setting[command.afe_pl] = value;
		}
		return rc == 0 ? result_readback((u32)value) : result_timeout();
	}
	if (op == RPU_WIRE_OP_READ_TRIM || op == RPU_WIRE_OP_READ_OFFSET) {
		if (command.target == RPU_WIRE_TARGET_CHANNEL) {
			rc = read_trim_or_offset_channel(op, command.afe_pl, command.afe_channel, &readback);
			return rc == 0 ? result_readback(readback) : result_status(RPU_WIRE_STATUS_REJECTED);
		}
		if (command.target == RPU_WIRE_TARGET_AFE || command.target == RPU_WIRE_TARGET_ALL) {
			return result_status(RPU_WIRE_STATUS_APPLIED);
		}
		return result_status(RPU_WIRE_STATUS_REJECTED);
	}
	if (op == RPU_WIRE_OP_SET_TRIM || op == RPU_WIRE_OP_SET_OFFSET) {
		rc = write_channel_scalar(&command, &readback);
		if (rc == 0) {
			return result_readback(readback);
		}
		return rc == -1 ? result_timeout() : result_status(RPU_WIRE_STATUS_REJECTED);
	}
	if (op == RPU_WIRE_OP_READ_VBIAS_CONTROL) {
		(void)vbias_enabled;
		return result_readback((u32)vbias_control);
	}
	if (op == RPU_WIRE_OP_SET_VBIAS_CONTROL) {
		if (require_12bit(command.value, &value) != 0) {
			return result_status(RPU_WIRE_STATUS_REJECTED);
		}
		if (write_dac_route(vbias_route, value) != 0) {
			return result_timeout();
		}
		mmio_write(BIAS_ENABLE_OFFSET, command.flags != 0U ? 1U : 0U);
		vbias_control = value;
		vbias_enabled = command.flags != 0U ? 1U : 0U;
		return result_readback((u32)value);
	}
	if (op == RPU_WIRE_OP_SET_RESET) {
		set_mmio_bit(AFE_GLOBAL_CONTROL_OFFSET, AFE_GLOBAL_RESET_BIT, command.flags != 0U);
		return result_status(RPU_WIRE_STATUS_APPLIED);
	}
	if (op == RPU_WIRE_OP_DO_RESET) {
		set_mmio_bit(AFE_GLOBAL_CONTROL_OFFSET, AFE_GLOBAL_RESET_BIT, 1U);
		set_mmio_bit(AFE_GLOBAL_CONTROL_OFFSET, AFE_GLOBAL_RESET_BIT, 0U);
		return result_status(RPU_WIRE_STATUS_APPLIED);
	}
	if (op == RPU_WIRE_OP_SET_POWER_STATE) {
		set_mmio_bit(AFE_GLOBAL_CONTROL_OFFSET, AFE_GLOBAL_POWERSTATE_BIT, command.flags != 0U);
		return result_readback(command.flags != 0U ? 1U : 0U);
	}
	if (op == RPU_WIRE_OP_ALIGN) {
		return result_interlocked(RPU_INTERLOCK_ALIGN_UNVALIDATED);
	}
	if (op == RPU_WIRE_OP_BEGIN_CONFIGURE_FRONTEND) {
		if (require_12bit(command.value, &value) != 0) {
			return result_status(RPU_WIRE_STATUS_REJECTED);
		}
		clear_staged_config();
		staged.active = 1U;
		staged.afe_count = (u16)(command.flags & 0xFFFFU);
		staged.channel_count = (u16)(command.flags >> 16);
		staged.bias_control = value;
		return result_status(RPU_WIRE_STATUS_APPLIED);
	}
	if (op == RPU_WIRE_OP_CONFIGURE_AFE) {
		if (staged.active == 0U || !validate_afe(command.afe_pl) ||
		    require_12bit(command.value, &value) != 0 || command.flags > DAC_12BIT_MAX) {
			return result_status(RPU_WIRE_STATUS_REJECTED);
		}
		staged.afes[command.afe_pl].present = 1U;
		staged.afes[command.afe_pl].afe_board = command.afe_board;
		staged.afes[command.afe_pl].afe_pl = command.afe_pl;
		staged.afes[command.afe_pl].attenuation = value;
		staged.afes[command.afe_pl].bias = (u16)command.flags;
		staged.afes[command.afe_pl].adc_flags = command.payload[0U];
		staged.afes[command.afe_pl].pga_lpf = command.payload[1U];
		staged.afes[command.afe_pl].pga_flags = command.payload[2U];
		staged.afes[command.afe_pl].lna_clamp = command.payload[3U];
		staged.afes[command.afe_pl].lna_gain = command.payload[4U];
		staged.afes[command.afe_pl].lna_flags = command.payload[5U];
		return result_status(RPU_WIRE_STATUS_APPLIED);
	}
	if (op == RPU_WIRE_OP_CONFIGURE_CHANNEL) {
		if (staged.active == 0U || !validate_afe(command.afe_pl) ||
		    !validate_channel(command.afe_channel) || command.channel >= CHANNEL_COUNT ||
		    require_12bit(command.value, &value) != 0 ||
		    (command.flags & 0xFFFFU) > DAC_12BIT_MAX) {
			return result_status(RPU_WIRE_STATUS_REJECTED);
		}
		staged.channels[command.channel].present = 1U;
		staged.channels[command.channel].channel = command.channel;
		staged.channels[command.channel].afe_board = command.afe_board;
		staged.channels[command.channel].afe_pl = command.afe_pl;
		staged.channels[command.channel].afe_channel = command.afe_channel;
		staged.channels[command.channel].trim = value;
		staged.channels[command.channel].offset = (u16)(command.flags & 0xFFFFU);
		staged.channels[command.channel].gain = (u16)(command.flags >> 16);
		return result_status(RPU_WIRE_STATUS_APPLIED);
	}
	if (op == RPU_WIRE_OP_APPLY_CONFIGURE_FRONTEND) {
		rc = apply_configure_frontend();
		if (rc == 0) {
			return result_status(RPU_WIRE_STATUS_APPLIED);
		}
		return rc == -1 ? result_timeout() : result_status(RPU_WIRE_STATUS_REJECTED);
	}
	if (op == RPU_WIRE_OP_WRITE_FUNCTION) {
		rc = write_afe_function_payload(command.afe_pl, command.payload, command.value, &readback);
		if (rc == 0) {
			return result_readback(readback);
		}
		return rc == -1 ? result_timeout() : result_status(RPU_WIRE_STATUS_REJECTED);
	}
	return result_status(RPU_WIRE_STATUS_REJECTED);
}

static int send_wire_reply(u32 host_addr, const u8 *cmd)
{
	volatile struct vring_desc *desc;
	struct rpmsg_hdr *hdr;
	u8 *payload;
	u16 available;
	u16 desc_id;
	u32 desc_addr;
	u64 sequence;
	struct command_result result;

	available = avail_idx(&tx_to_host);
	if (tx_to_host.last_avail == available) {
		return -1;
	}

	desc_id = avail_ring_entry(&tx_to_host, tx_to_host.last_avail);
	tx_to_host.last_avail++;
	desc = &vring_descs(&tx_to_host)[desc_id];
	desc_addr = desc->addr_lo;
	if ((desc->flags & VRING_DESC_F_WRITE) == 0U || desc->len < (RPMSG_HDR_LEN + RPU_WIRE_FRAME_LEN)) {
		add_used(&tx_to_host, desc_id, 0);
		kick_host();
		return -1;
	}

	sequence = get_u64(cmd, 8);
	result = execute_wire_command(cmd);
	heartbeat++;

	hdr = (struct rpmsg_hdr *)(unsigned long)desc_addr;
	payload = (u8 *)(unsigned long)(desc_addr + RPMSG_HDR_LEN);
	zero_frame(payload, RPU_WIRE_FRAME_LEN);

	hdr->src = RPU_ENDPOINT_ADDR;
	hdr->dst = host_addr;
	hdr->reserved = 0;
	hdr->len = RPU_WIRE_FRAME_LEN;
	hdr->flags = 0;

	put_u32(payload, 0, RPU_WIRE_MAGIC);
	put_u16(payload, 4, RPU_WIRE_ABI);
	put_u16(payload, 6, result.status);
	put_u64(payload, 8, sequence);
	put_u32(payload, 16, result.readback);
	put_u32(payload, 20, result.readback_valid);
	put_u64(payload, 24, heartbeat);
	put_u32(payload, 32, result.fault_code);
	put_u32(payload, 36, result.interlock_code);

	barrier();
	add_used(&tx_to_host, desc_id, RPMSG_HDR_LEN + RPU_WIRE_FRAME_LEN);
	kick_host();
	return 0;
}

static void process_host_message(u16 desc_id)
{
	volatile struct vring_desc *desc = &vring_descs(&rx_from_host)[desc_id];
	struct rpmsg_hdr *hdr = (struct rpmsg_hdr *)(unsigned long)desc->addr_lo;
	u8 *payload = (u8 *)(unsigned long)(desc->addr_lo + RPMSG_HDR_LEN);
	u32 payload_len = hdr->len;
	u32 host_addr = hdr->src;

	if (desc->len >= RPMSG_HDR_LEN &&
	    payload_len == RPU_WIRE_FRAME_LEN &&
	    hdr->dst == RPU_ENDPOINT_ADDR &&
	    host_addr != 0xFFFFFFFFU) {
		(void)send_wire_reply(host_addr, payload);
	}

	add_used(&rx_from_host, desc_id, desc->len);
}

void rpu_main(void)
{
	u32 spin = 0;

	while (avail_idx(&tx_to_host) == 0U) {
		if (++spin > 100000000U) {
			spin = 0;
		}
		cpu_relax();
	}

	for (;;) {
		u16 available = avail_idx(&rx_from_host);

		while (rx_from_host.last_avail != available) {
			u16 desc_id = avail_ring_entry(&rx_from_host, rx_from_host.last_avail);
			rx_from_host.last_avail++;
			process_host_message(desc_id);
			available = avail_idx(&rx_from_host);
		}
		cpu_relax();
	}
}
