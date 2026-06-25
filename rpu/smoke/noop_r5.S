	.arm
	.cpu cortex-r5

	.section .vectors, "ax"
	.global _boot
	.global _start

_boot:
	b	_start
	b	.
	b	.
	b	.
	b	.
	b	.
	b	.
	b	.

	.section .text, "ax"
_start:
	cpsid	if
1:
	wfi
	b	1b
