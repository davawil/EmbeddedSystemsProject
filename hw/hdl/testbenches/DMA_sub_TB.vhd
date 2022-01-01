library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_DMA_sub is
end tb_DMA_sub;

architecture test of tb_DMA_sub is

		constant CLK_PERIOD : time := 20 ns;		--50 MHz
		signal sim_finished : boolean := false;

		--input signals
		signal clk			: std_logic;
		signal nReset		: std_logic;
		signal WaitRequest 	: std_logic;
		signal Fifo_almost_empty	: std_logic;
		signal RdData		: std_logic_vector(15 downto 0);
		signal FBuff0		: std_logic_vector(31 downto 0);
		signal FBuff1		: std_logic_vector(31 downto 0);
		signal start_DMA	: std_logic;
		--output signals
		signal irq			: std_logic;
		signal Address 		: std_logic_vector(31 downto 0);
		signal Wr			: std_logic;
		signal DataWr		: std_logic_vector(31 downto 0);
		signal RdFifo		: std_logic;
		
begin

dut : entity work.DMA_sub
	port map(
		clk      			=> clk,   	
		nReset      		=> nReset,
		WaitRequest 		=> WaitRequest,
		Fifo_almost_empty	=> Fifo_almost_empty,
		irq					=> irq,
		Address 			=> Address,
		Wr					=> Wr,
		DataWr				=> DataWr,
		RdFifo				=> RdFifo,
		RdData				=> RdData,
		FBuff0				=> FBuff0,
		FBuff1				=> FBuff1,
		start_DMA			=> start_DMA
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

update_fifo : process(Wr, nReset)
begin
	if(nReset = '0') then
		RdData <= "1100110011001100";
	else
		RdData <= std_logic_vector(unsigned(RdData) + 4);
	end if;
end process update_fifo;
  
simulation : process is
begin
	nReset <= '0';
	wait for CLK_PERIOD;
	nReset <= '1';
	WaitRequest <= '1';
	Fifo_almost_empty <= '1';
	FBuff0 <= "11111111111111111111111111111111";
	FBuff1 <= "10101010101010101010101010101010";
	wait for CLK_PERIOD*4;
	start_DMA <= '1';
	wait for CLK_PERIOD;
	start_DMA <= '0';
	wait for CLK_PERIOD*4;
	Fifo_almost_empty <= '0';
	wait for CLK_PERIOD*2;
	--RdData <= "0011001100110011";
	wait for CLK_PERIOD*8;
	WaitRequest <= '0';
	wait for 6 ms;
	--reached
	wait for CLK_PERIOD*8;
	start_DMA <= '1';
	wait for CLK_PERIOD;
	start_DMA <= '0';
	wait for 1 ms;
	sim_finished <= true;
	wait;	
end process simulation;

end architecture;