library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_Camera_controller is
end tb_Camera_controller;

architecture test of tb_Camera_controller is
	
		constant FRAME0_ADDR : std_logic_vector(31 downto 0) := x"00000000";
		constant FRAME1_ADDR : std_logic_vector(31 downto 0) := x"00020000";
		constant CLK_PERIOD : time := 20 ns;		--50 MHz
		constant PIX_PERIOD : time := CLK_PERIOD*8;
		signal start_Camera : boolean := false;
		signal sim_finished : boolean := false;

		signal clk					: std_logic := '0';
		signal nReset				: std_logic := '1';
		--DMA
		signal AM_WaitRequest 		: std_logic := '0';
		signal AM_irq				: std_logic;
		signal AM_Address 			: std_logic_vector(31 downto 0);
		signal AM_Write				: std_logic;
		signal AM_DataWr			: std_logic_vector(31 downto 0);
		
		--AVALON Slave
		signal AS_Address 			: std_logic_vector(1 downto 0) := "00";
		signal AS_Wr				: std_logic := '0';
		signal AS_DataWr			: std_logic_vector(31 downto 0) := (others => '0');	
		
		--Camera Interface
		signal C_pixclk				: std_logic := '0';
		signal C_data				: std_logic_vector(11 downto 0) := (others => '0');
		signal C_FVAL				: std_logic := '0';
		signal C_LVAL				: std_logic := '0';
		
		--Camera signals
		signal CameraClk			: std_logic;				--ignored here since no camera peripheral, pixclock generated directly
		signal CameraReset_n		: std_logic;
		
begin

dut : entity work.Camera_controller
	port map(
		clk					=> clk,
		nReset				=> nReset,
		AM_WaitRequest 		=> AM_WaitRequest,
		AM_irq				=> AM_irq,
		AM_Address 			=> AM_Address,
		AM_Write			=> AM_Write,
		AM_DataWr			=> AM_DataWr,
		AS_Address 			=> AS_Address,
		AS_Wr				=> AS_Wr,
		AS_DataWr			=> AS_DataWr,	
		C_pixclk			=> C_pixclk,
		C_data				=> C_data,
		C_FVAL				=> C_FVAL,
		C_LVAL				=> C_LVAL,
		CameraClk			=> CameraClk,
		CameraReset_n		=> CameraReset_n
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

pixclk_generation : process(clk, nReset)
	variable clkDiv_count : natural range 0 to 8 :=0;
begin
	if nReset = '0' then
		clkDiv_count 	:= 0;
		C_pixclk			<= '0';
	elsif rising_edge(clk) then
		clkDiv_count 	:= clkDiv_count + 1;

		if clkDiv_count = 8 then
			C_pixclk <= '1';
			clkDiv_count	:= 0;
		else
			C_pixclk <= '0';
		end if;
	end if;
end process pixclk_generation;

cam_output : process(C_pixclk)
	variable row : natural range 0 to 480 := 0;
	variable col : natural range 0 to 640 := 0;
	variable waitC: natural range 0 to 100 := 0;
	
	variable red : std_logic_vector(11 downto 0) 	:= x"00f";
	variable green : std_logic_vector(11 downto 0) 	:= x"0f0";
	variable blue : std_logic_vector(11 downto 0) 	:= x"f00";
begin
	if rising_edge(C_pixclk) and start_Camera = true then
		if waitC > 0 then
			waitC := waitC - 1;
			if waitC = 1 then
				C_LVAL <= '1';
				C_FVAL <= '1';
			end if;
		else 
			if col = 640 then 
				col := 1;
				row := row + 1;
				C_LVAL <= '0';
				waitC := 10;
			else
				col := col + 1;
			end if;
			if row = 480 then
				row := 1;
				C_FVAL <= '0';
				waitC := 100;
			end if;
					
			--if odd row (starting from 1)
			if row mod 2 = 1 then
				--if odd column (starting from 1)
				if col mod 2 = 1 then
					C_data <= green;
				--if even column (starting from 1)
				else 
					C_data <= red;
				end if;
			--if odd even (starting from 1)
			else
				--if odd column (starting from 1)
				if col mod 2 = 1 then
					C_data <= blue;
				--if even column (starting from 1)
				else 
					C_data <= green;
				end if;
			end if;
		end if;
	end if;
end process;
  
simulation : process is
begin
	nReset <= '0';
	--Configure Camera controller
	wait for CLK_PERIOD;
	nReset <= '1';
	AS_Address <= "00";
	AS_Wr <= '1';
	AS_DataWr <= FRAME0_ADDR;
	wait for CLK_PERIOD;
	AS_Address <= "01";
	AS_Wr <= '1';
	AS_DataWr <= FRAME1_ADDR;
	wait for CLK_PERIOD;
	AS_Address <= "10";
	AS_Wr <= '1';
	AS_DataWr <= x"00000001";
	wait for CLK_PERIOD;
	AS_Address <= "00";
	AS_Wr <= '0';
	AS_DataWr <= x"00000000";
	start_Camera <= true;
	wait for 100 ms;	--wait for more than completion of one frame
	sim_finished <= true;
	wait;	
end process simulation;

end architecture;