ENTRY(_boot)

MEMORY
{
	ATCM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
	.vectors 0x00000000 :
	{
		KEEP(*(.vectors))
	} > ATCM

	.text :
	{
		*(.text*)
		*(.rodata*)
	} > ATCM

	.resource_table ALIGN(0x100) :
	{
		KEEP(*(.resource_table))
	} > ATCM

	.data :
	{
		__data_start = .;
		*(.data*)
		__data_end = .;
	} > ATCM

	.bss (NOLOAD) :
	{
		__bss_start = .;
		*(.bss*)
		*(COMMON)
		__bss_end = .;
	} > ATCM

	.stack (NOLOAD) :
	{
		. = ALIGN(8);
		__stack_bottom = .;
		. += 0x1000;
		__stack_top = .;
	} > ATCM
}
