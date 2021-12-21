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
	constant START_BIT 		: natural := 0;
	signal int_start		: std_logic := '0';
begin
	start <= int_start;
	process(clk, nReset)
		begin
			if nReset = '0' then
				FBuff0 <= (others => '0');
				FBuff1 <= (others => '0');
				int_start <= '0';
			elsif rising_edge(clk) then
				if Wr = '1' then
					case Address is
						when "00" => FBuff0 <= DataWr;
						when "01" => FBuff1 <= DataWr;
						when "10" => int_start <= DataWr(START_BIT);
						when others => null;
					end case;
				end if;
				--reset start-signal after one clock cycle
				if int_start = '1' then
					int_start <= '0'; 
				end if;
			end if;
		end process;
end comp;