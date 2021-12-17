library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

entity AS_sub is
	port(
			clk         	: in std_logic;
			nReset      	: in std_logic;
			Address 		: in std_logic_vector(1 downto 0);
			Wr				: in std_logic;
			DataWr			: in std_logic_vector(31 downto 0);
			FBuff0			: out std_logic_vector(31 downto 0);
			FBuff1			: out std_logic_vector(31 downto 0);
			start			: out std_logic
		);
	end AS_sub;
	
architecture comp of AS_sub is	
begin
end comp;