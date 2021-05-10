OUTPUT_FORMAT("elf32-i386");
ENTRY(start);
SECTIONS
{
	. = 0x7C00;

	.text :
	{
		*(.text*)
		*(.rodata)
	}

	.data :
	{
		*(.data)
	}

	.sig 0x7DFE :
	{
		SHORT(0xAA55);
	}

	.bss :
	{
		*(.bss)
	}

	/DISCARD/ :
	{
		*(.init_array)
		*(.fini_array*)
		*(.comment)
	}
}