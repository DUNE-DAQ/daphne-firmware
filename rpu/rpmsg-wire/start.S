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
	ldr	sp, =__stack_top

	ldr	r0, =__bss_start
	ldr	r1, =__bss_end
	mov	r2, #0
1:
	cmp	r0, r1
	bhs	2f
	str	r2, [r0], #4
	b	1b
2:
	bl	rpu_main
3:
	wfi
	b	3b
