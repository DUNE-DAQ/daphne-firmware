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

	.data :
	{
		*(.data*)
	} > ATCM

	.bss (NOLOAD) :
	{
		*(.bss*)
		*(COMMON)
	} > ATCM
}
