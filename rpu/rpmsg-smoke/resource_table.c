typedef unsigned char u8;
typedef unsigned int u32;

#define RSC_VDEV 3U
#define VIRTIO_ID_RPMSG 7U
#define VIRTIO_RPMSG_F_NS (1U << 0)

#define NUM_VRINGS 2U
#define VRING_ALIGN 0x1000U
#define VRING_SIZE 256U

#ifndef RPU_RSC_VRING0
#define RPU_RSC_VRING0 0x3ED40000U
#endif

#ifndef RPU_RSC_VRING1
#define RPU_RSC_VRING1 0x3ED44000U
#endif

struct fw_rsc_vdev {
	u32 type;
	u32 id;
	u32 notifyid;
	u32 dfeatures;
	u32 gfeatures;
	u32 config_len;
	u8 status;
	u8 num_of_vrings;
	u8 reserved[2];
} __attribute__((packed));

struct fw_rsc_vdev_vring {
	u32 da;
	u32 align;
	u32 num;
	u32 notifyid;
	u32 reserved;
} __attribute__((packed));

struct remote_resource_table {
	u32 version;
	u32 num;
	u32 reserved[2];
	u32 offset[1];
	struct fw_rsc_vdev rpmsg_vdev;
	struct fw_rsc_vdev_vring rpmsg_vring0;
	struct fw_rsc_vdev_vring rpmsg_vring1;
} __attribute__((packed, aligned(0x100)));

__attribute__((section(".resource_table"), used))
struct remote_resource_table resources = {
	.version = 1,
	.num = 1,
	.reserved = {0, 0},
	.offset = {
		__builtin_offsetof(struct remote_resource_table, rpmsg_vdev),
	},
	.rpmsg_vdev = {
		.type = RSC_VDEV,
		.id = VIRTIO_ID_RPMSG,
		.notifyid = 31,
		.dfeatures = VIRTIO_RPMSG_F_NS,
		.gfeatures = 0,
		.config_len = 0,
		.status = 0,
		.num_of_vrings = NUM_VRINGS,
		.reserved = {0, 0},
	},
	.rpmsg_vring0 = {
		.da = RPU_RSC_VRING0,
		.align = VRING_ALIGN,
		.num = VRING_SIZE,
		.notifyid = 1,
		.reserved = 0,
	},
	.rpmsg_vring1 = {
		.da = RPU_RSC_VRING1,
		.align = VRING_ALIGN,
		.num = VRING_SIZE,
		.notifyid = 2,
		.reserved = 0,
	},
};
