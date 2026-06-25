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
#define RPU_WIRE_STATUS_APPLIED 1U
#define RPU_WIRE_STATUS_REJECTED 2U

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

static struct vring_state tx_to_host = { RPU_VRING0_BASE, 0 };
static struct vring_state rx_from_host = { RPU_VRING1_BASE, 0 };
static u64 heartbeat;

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

static u16 wire_status_for_command(const u8 *cmd)
{
	u16 abi;
	u16 op;

	if (get_u32(cmd, 0) != RPU_WIRE_MAGIC) {
		return RPU_WIRE_STATUS_REJECTED;
	}
	abi = get_u16(cmd, 4);
	if (abi != RPU_WIRE_ABI) {
		return RPU_WIRE_STATUS_REJECTED;
	}
	op = get_u16(cmd, 6);
	if (op == 0U) {
		return RPU_WIRE_STATUS_APPLIED;
	}
	return RPU_WIRE_STATUS_REJECTED;
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
	u16 status;

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
	status = wire_status_for_command(cmd);
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
	put_u16(payload, 6, status);
	put_u64(payload, 8, sequence);
	put_u64(payload, 24, heartbeat);

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
