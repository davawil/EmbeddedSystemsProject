library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_AS_sub is
end tb_AS_sub;

architecture test of tb_AS_sub is

		constant CLK_PERIOD : time := 20 ns;		--50 MHz
		signal sim_finished : boolean := false;

		--input signals
		signal clk         		: std_logic;
		signal nReset      		: std_logic;
		signal Address 			: std_logic_vector(1 downto 0);
		signal Wr				: std_logic;
		signal DataWr			: std_logic_vector(31 downto 0);
		--output signals
		signal FBuff0			: std_logic_vector(31 downto 0);
		signal FBuff1			: std_logic_vector(31 downto 0);
		signal start			: std_logic;
		
begin

dut : entity work.AS_sub
	port map(
		clk         	=> clk,
		nReset      	=> nReset,
		Address 		=> Address,
		Wr				=> Wr,
		DataWr			=> DataWr,
		FBuff0			=> FBuff0,
		FBuff1			=> FBuff1,
		start			=> start
	);

clk_generation : process is
begin
	if not sim_finished then
		clk <= '1';
		wait for CLK_PERIOD / 2;
		clk <= '0';
		wait for CLK_PERIOD / 2;
	else 
		wait;
	end if;
end process clk_generation;
  
simulation : process is
begin
	nReset <= '0';
	wait for CLK_PERIOD;
	nReset <= '1';
	--write FBuff0
	Address <= "00";
	--0xFFFAB000
	DataWr <= "11111111111101010110000000000000";
	Wr <= '1';
	wait for CLK_PERIOD;
	--write FBuff1
	Address <= "01";
	--0xFFFA0000
	DataWr <= "11111111111101000000000000000000";
	Wr <= '1';
	wait for CLK_PERIOD;
	--start
	Address <= "10";
	DataWr <= "00000000000000000000000000000001";
	Wr <= '1';
	wait for CLK_PERIOD;
	--start
	Address <= "00";
	DataWr <= "00000000000000000000000000000001";
	Wr <= '0';
	sim_finished <= true;
	wait;	
end process simulation;

end architecture;