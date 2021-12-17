library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

entity Camera_interface_sub is
	port(
			clk         	: in std_logic;
			nReset      	: in std_logic;
			pixclk			: in std_logic;
			data				: in std_logic_vector(11 downto 0);
			FVAL				: in std_logic;
			LVAL				: in std_logic;
			start_CI			: in std_logic;
			WrFIFO			: out std_logic;
			WrData			: out std_logic_vector(15 downto 0)
		);
	end Camera_interface_sub;
	
architecture comp of Camera_interface_sub is
	
begin

end comp;