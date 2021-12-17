library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

entity DMA_sub is
	port(
			clk         	: in std_logic;
			nReset      	: in std_logic;
			WaitRequest 	: in std_logic;
			irq				: out std_logic;
			Address 		: out std_logic_vector(31 downto 0);
			Wr				: out std_logic;
			DataWr			: out std_logic_vector(31 downto 0);
			RdFifo			: out std_logic;
			RdData			: in std_logic_vector(15 downto 0);
			FBuff0			: in std_logic_vector(31 downto 0);
			FBuff1			: in std_logic_vector(31 downto 0);
			start_DMA		: in std_logic
		);
	end DMA_sub;
	
architecture comp of DMA_sub is
begin

end comp;